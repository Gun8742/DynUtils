import SwiftUI
import AppKit

private let controlWindowTitle = "Stillroom P0"

@main
struct Stillroom: App {
    @NSApplicationDelegateAdaptor(DesktopSession.self) private var session

    var body: some Scene {
        Window(controlWindowTitle, id: "main") {
            ContentView(session: session)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
private struct ContentView: View {
    @ObservedObject var session: DesktopSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let url = session.artwork, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 540, height: 245)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 10))
                    .accessibilityLabel("Salt Marsh landscape preview")
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Salt Marsh").font(.title2.bold())
                Text("A bundled wallpaper and snow for the primary display.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Apply wallpaper", action: session.applyWallpaper)
                    .buttonStyle(.borderedProminent)
                    .disabled(session.artwork == nil)
                Button("Restore previous", action: session.restoreWallpaper)
                    .disabled(!session.canRestore)
                Spacer()
                Toggle("Snow", isOn: $session.snowEnabled)
                    .toggleStyle(.switch)
            }
            Text(session.wallpaperStatus)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("wallpaperStatus")
            Text(session.snowStatus)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("snowStatus")
        }
        .padding(24)
        .frame(width: 588)
    }
}

@MainActor
final class DesktopSession: NSObject, ObservableObject, NSApplicationDelegate {
    private struct PreviousWallpaper {
        let display: CGDirectDisplayID?
        let url: URL
        let options: [NSWorkspace.DesktopImageOptionKey: Any]
    }

    private enum PauseReason: Hashable { case sessionInactive, screenSleep, locked }

    let artwork = Bundle.main.url(forResource: "Salt-Marsh", withExtension: "png")
    @Published private(set) var wallpaperStatus = "Preview only. Apply to change the desktop."
    @Published private(set) var canRestore = false
    @Published private(set) var snowStatus = "Snow is off."
    @Published var snowEnabled = false { didSet { updateOverlay() } }

    private let workspace = NSWorkspace.shared
    private let overlay = SnowOverlay()
    private var previousWallpaper: PreviousWallpaper?
    private var pauseReasons: Set<PauseReason> = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        let nc = workspace.notificationCenter
        for (name, selector) in [
            (NSWorkspace.sessionDidResignActiveNotification, #selector(sessionInactive)),
            (NSWorkspace.sessionDidBecomeActiveNotification, #selector(sessionActive)),
            (NSWorkspace.screensDidSleepNotification, #selector(screenSlept)),
            (NSWorkspace.screensDidWakeNotification, #selector(screenWoke)),
            (NSWorkspace.activeSpaceDidChangeNotification, #selector(displayChanged))
        ] {
            nc.addObserver(self, selector: selector, name: name, object: nil)
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(displayChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification, object: nil
        )
        // This lock signal supplements the public session and display sleep notifications.
        // Window level keeps the overlay below the lock UI independently of this signal.
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenLocked),
                                name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenUnlocked),
                                name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.title == controlWindowTitle, window.styleMask.contains(.titled) else { return }
        overlay.stop()
        // The overlay is itself a window, so don't depend on last-window detection.
        Task { @MainActor in NSApp.terminate(nil) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        overlay.stop()
    }

    func applyWallpaper() {
        guard let artwork, let screen = NSScreen.primary else {
            wallpaperStatus = "The bundled image or primary display is unavailable."
            return
        }
        let current = workspace.desktopImageURL(for: screen)
        guard current?.standardizedFileURL != artwork.standardizedFileURL else {
            wallpaperStatus = "Salt Marsh is already in use."
            return
        }
        let snapshot = current.map { PreviousWallpaper(
            display: screen.displayID, url: $0, options: workspace.desktopImageOptions(for: screen) ?? [:]
        ) }
        do {
            try workspace.setDesktopImageURL(artwork, for: screen,
                options: [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                          .allowClipping: true])
            previousWallpaper = snapshot
            canRestore = snapshot != nil
            wallpaperStatus = snapshot == nil
                ? "Salt Marsh applied. macOS did not provide a previous image to restore."
                : "Salt Marsh applied to \(screen.localizedName)."
        } catch {
            wallpaperStatus = "Couldn’t apply wallpaper: \(error.localizedDescription)"
        }
    }

    func restoreWallpaper() {
        guard let prior = previousWallpaper,
              let screen = NSScreen.screens.first(where: { $0.displayID == prior.display }) else {
            wallpaperStatus = "Reconnect the original display to restore its wallpaper."
            return
        }
        guard workspace.desktopImageURL(for: screen)?.standardizedFileURL == artwork?.standardizedFileURL else {
            wallpaperStatus = "The desktop now uses another image. It was left in place."
            return
        }
        do {
            try workspace.setDesktopImageURL(prior.url, for: screen, options: prior.options)
            previousWallpaper = nil
            canRestore = false
            wallpaperStatus = "Previous wallpaper restored."
        } catch {
            wallpaperStatus = "Couldn’t restore wallpaper: \(error.localizedDescription)"
        }
    }

    private func updateOverlay() {
        guard snowEnabled, pauseReasons.isEmpty, let screen = NSScreen.primary else {
            overlay.stop()
            snowStatus = snowEnabled ? "Snow paused while the display or session is unavailable." : "Snow is off."
            return
        }
        overlay.show(on: screen)
        snowStatus = overlay.isRunning ? "Snow is running on \(screen.localizedName)." : "Snow couldn’t start."
    }

    private func setPaused(_ reason: PauseReason, _ paused: Bool) {
        if paused { pauseReasons.insert(reason) } else { pauseReasons.remove(reason) }
        updateOverlay()
    }

    @objc private func sessionInactive() { setPaused(.sessionInactive, true) }
    @objc private func sessionActive() { setPaused(.sessionInactive, false) }
    @objc private func screenSlept() { setPaused(.screenSleep, true) }
    @objc private func screenWoke() { setPaused(.screenSleep, false) }
    @objc private func screenLocked() { setPaused(.locked, true) }
    @objc private func screenUnlocked() { setPaused(.locked, false) }
    @objc private func displayChanged() { updateOverlay() }
}
