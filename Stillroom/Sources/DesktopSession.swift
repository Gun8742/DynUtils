import AppKit
import IOKit.ps
import ServiceManagement
import SwiftUI

extension NSScreen {
    var displayKey: String {
        guard let id = (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else {
            return localizedName
        }
        if let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return String(id)
    }
}

@MainActor
final class DesktopSession: NSObject, ObservableObject, NSApplicationDelegate {
    struct Display: Identifiable {
        let id: String
        let name: String
        let appliedWallpaper: String?
    }

    private struct Snapshot {
        let url: URL
        let options: [NSWorkspace.DesktopImageOptionKey: Any]
    }

    private enum Pause: Hashable { case lock, sleeping, inactive }

    @Published var prefs = Preferences.load() {
        didSet {
            prefs.save()
            reconcileWeather()
        }
    }
    @Published private(set) var displays: [Display] = []
    @Published private(set) var results: [String: String] = [:]
    @Published private(set) var failedDisplays: Set<String> = []
    @Published private(set) var weatherStatus = "Off"
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    @Published private(set) var loginError: String?

    private var overlays: [String: WeatherOverlay] = [:]
    private var priorWallpapers: [String: Snapshot] = [:]
    private var pauseReasons: Set<Pause> = []
    private var powerTimer: Timer?
    private let workspace = NSWorkspace.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        let nc = workspace.notificationCenter
        for (name, selector) in [
            (NSWorkspace.screensDidSleepNotification, #selector(screenSlept)),
            (NSWorkspace.screensDidWakeNotification, #selector(screenWoke)),
            (NSWorkspace.sessionDidResignActiveNotification, #selector(sessionInactive)),
            (NSWorkspace.sessionDidBecomeActiveNotification, #selector(sessionActive)),
            (NSWorkspace.activeSpaceDidChangeNotification, #selector(refresh))
        ] {
            nc.addObserver(self, selector: selector, name: name, object: nil)
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh), name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenLocked),
                                name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenUnlocked),
                                name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        refresh()
        powerTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(powerChanged),
                                          userInfo: nil, repeats: true)
        powerTimer?.tolerance = 1
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        loginStatus = SMAppService.mainApp.status
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        powerTimer?.invalidate()
        closeOverlays()
    }

    func selectEffect(_ effect: Effect) {
        guard prefs.effect != effect else { return }
        var updated = prefs
        updated.effect = effect
        if effect != .off { updated.lastEffect = effect }
        prefs = updated
        if prefs.rule == .matchEffect { applyMatchedWallpaper() }
    }

    func setRule(_ rule: WallpaperRule) {
        guard prefs.rule != rule else { return }
        prefs.rule = rule
        if rule == .matchEffect { applyMatchedWallpaper() }
    }

    func apply(_ wallpaper: Wallpaper, to target: String?) {
        let screens = NSScreen.screens.filter { target == nil || $0.displayKey == target }
        guard !screens.isEmpty else {
            if let target {
                prefs.rule = .manual
                prefs.desired[target] = wallpaper.id
                results[target] = "Display disconnected. Reconnect it and retry."
                failedDisplays.insert(target)
            }
            return
        }
        prefs.rule = .manual
        if target == nil { prefs.defaultWallpaper = wallpaper.id }
        for screen in screens {
            prefs.desired[screen.displayKey] = wallpaper.id
            apply(wallpaper, on: screen)
        }
        readDisplays()
    }

    func restore(_ display: String) {
        guard let screen = NSScreen.screens.first(where: { $0.displayKey == display }),
              let prior = priorWallpapers[display],
              let url = workspace.desktopImageURL(for: screen),
              let applied = wallpaperID(for: url) else { return }
        do {
            try workspace.setDesktopImageURL(prior.url, for: screen, options: prior.options)
            priorWallpapers[display] = nil
            prefs.rule = .manual
            prefs.desired[display] = wallpaperID(for: prior.url)
            results[display] = "Restored previous wallpaper."
            failedDisplays.remove(display)
            readDisplays()
        } catch {
            results[display] = "Couldn’t restore \(applied): \(error.localizedDescription)"
        }
    }

    func canRestore(_ display: Display) -> Bool {
        display.appliedWallpaper != nil && priorWallpapers[display.id] != nil
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { loginError = error.localizedDescription }
        loginStatus = SMAppService.mainApp.status
    }

    func resetPreferences() {
        prefs = Preferences()
        refresh()
    }

    private func applyMatchedWallpaper() {
        guard let wallpaper = Wallpaper.catalog.first(where: { $0.effects.contains(prefs.effect) }) else { return }
        prefs.defaultWallpaper = wallpaper.id
        for screen in NSScreen.screens {
            prefs.desired[screen.displayKey] = wallpaper.id
            apply(wallpaper, on: screen)
        }
        readDisplays()
    }

    private func apply(_ wallpaper: Wallpaper, on screen: NSScreen) {
        let id = screen.displayKey
        do {
            let ratio = screen.frame.width / max(1, screen.frame.height)
            guard let asset = wallpaper.url(for: prefs.resolution[wallpaper.id] ?? .auto, aspectRatio: ratio) else {
                results[id] = "Bundled image unavailable."
                failedDisplays.insert(id)
                return
            }
            // macOS may retain the URL after the app quits or is rebuilt.
            let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                                  in: .userDomainMask, appropriateFor: nil, create: true)
            let folder = base.appendingPathComponent("Stillroom/Wallpapers", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let stableURL = folder.appendingPathComponent(asset.lastPathComponent)
            if !FileManager.default.fileExists(atPath: stableURL.path) {
                try Data(contentsOf: asset).write(to: stableURL, options: .atomic)
            }
            let old = workspace.desktopImageURL(for: screen)
            let oldOptions = workspace.desktopImageOptions(for: screen) ?? [:]
            if old?.standardizedFileURL != stableURL.standardizedFileURL {
                try workspace.setDesktopImageURL(stableURL, for: screen,
                    options: [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                              .allowClipping: true])
                if let old, wallpaperID(for: old) == nil || priorWallpapers[id] == nil {
                    priorWallpapers[id] = Snapshot(url: old, options: oldOptions)
                }
            }
            results[id] = "Applied \(wallpaper.title)."
            failedDisplays.remove(id)
        } catch {
            results[id] = "Couldn’t apply: \(error.localizedDescription)"
            failedDisplays.insert(id)
        }
    }

    private func wallpaperID(for url: URL) -> String? {
        guard url.deletingLastPathComponent().path.hasSuffix("/Stillroom/Wallpapers") else { return nil }
        return Wallpaper.catalog.first {
            let filename = url.deletingPathExtension().lastPathComponent
            return filename == $0.resource || filename == $0.resource + "-Wide"
        }?.id
    }

    private func readDisplays() {
        let previouslyApplied = Set(displays.filter { $0.appliedWallpaper != nil }.map(\.id))
        displays = NSScreen.screens.map { screen in
            let applied = workspace.desktopImageURL(for: screen).flatMap(wallpaperID(for:))
            let id = screen.displayKey
            if applied == nil, previouslyApplied.contains(id), results[id]?.hasPrefix("Applied ") == true {
                results[id] = nil
            }
            return Display(id: id, name: screen.localizedName, appliedWallpaper: applied)
        }
    }

    @objc func refresh() {
        for screen in NSScreen.screens where !prefs.seenDisplays.contains(screen.displayKey) {
            let id = screen.displayKey
            prefs.seenDisplays.insert(id)
            if let fallback = Wallpaper.catalog.first(where: { $0.id == prefs.defaultWallpaper }) {
                prefs.desired[id] = fallback.id
                apply(fallback, on: screen)
            }
        }
        readDisplays()
        reconcileWeather()
    }

    private var onBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return false }
        return IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? == kIOPSBatteryPowerValue
    }

    @objc private func powerChanged() { reconcileWeather() }

    private func reconcileWeather() {
        let effect = prefs.effect
        let battery = onBattery
        var causes: [String] = []
        if prefs.manualPause { causes.append("manual") }
        if prefs.pauseOnBattery && battery { causes.append("on battery") }
        if pauseReasons.contains(.lock) { causes.append("screen locked") }
        if pauseReasons.contains(.sleeping) { causes.append("display asleep") }
        if pauseReasons.contains(.inactive) { causes.append("inactive session") }
        guard effect != .off, causes.isEmpty else {
            closeOverlays()
            weatherStatus = effect == .off ? "Off" : "Paused: " + causes.joined(separator: ", ")
            return
        }
        let screens = NSScreen.screens.filter { !prefs.weatherDisabled.contains($0.displayKey) }
        let active = Set(screens.map(\.displayKey))
        for key in overlays.keys.filter({ !active.contains($0) }) {
            overlays.removeValue(forKey: key)?.close()
        }
        let style = WeatherOverlay.Style(
            effect: effect, density: prefs.density, wind: prefs.wind,
            reduceMotion: prefs.reduceMotion || workspace.accessibilityDisplayShouldReduceMotion,
            lowPower: battery || ProcessInfo.processInfo.isLowPowerModeEnabled,
            rainbow: prefs.rainbow, lightning: prefs.lightning
        )
        for screen in screens {
            if let overlay = overlays[screen.displayKey] { overlay.update(screen: screen, style: style) }
            else { overlays[screen.displayKey] = WeatherOverlay(screen: screen, style: style) }
        }
        weatherStatus = screens.isEmpty ? "No displays enabled" : "\(effect.title) · \(screens.count) display(s)"
    }

    private func closeOverlays() {
        for overlay in overlays.values { overlay.close() }
        overlays.removeAll()
    }

    private func pause(_ reason: Pause, _ paused: Bool) {
        if paused { pauseReasons.insert(reason) } else { pauseReasons.remove(reason) }
        reconcileWeather()
    }

    @objc private func screenLocked() { pause(.lock, true) }
    @objc private func screenUnlocked() { pause(.lock, false) }
    @objc private func screenSlept() { pause(.sleeping, true) }
    @objc private func screenWoke() { pause(.sleeping, false); refresh() }
    @objc private func sessionInactive() { pause(.inactive, true) }
    @objc private func sessionActive() { pause(.inactive, false); refresh() }
}
