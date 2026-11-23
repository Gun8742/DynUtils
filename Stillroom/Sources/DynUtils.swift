import AppKit
import ServiceManagement
import SwiftUI

@main
struct DynUtils: App {
    @NSApplicationDelegateAdaptor(DesktopSession.self) private var session

    var body: some Scene {
        Window("DynUtils", id: "main") {
            Studio(session: session)
        }
        .defaultSize(width: 900, height: 660)

        MenuBarExtra("DynUtils", systemImage: "cloud.snow") {
            QuickControls(session: session)
        }
    }
}

private struct QuickControls: View {
    @ObservedObject var session: DesktopSession
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(session.weatherStatus)
        if session.prefs.effect == .off {
            Button("Start \(session.prefs.lastEffect.title)") {
                session.prefs.manualPause = false
                session.selectEffect(session.prefs.lastEffect)
            }
        } else {
            Button(session.prefs.manualPause ? "Resume weather" : "Pause weather") {
                session.prefs.manualPause.toggle()
            }
        }
        Menu("Choose effect") {
            ForEach(Effect.allCases) { effect in
                Button(effect.title) { session.selectEffect(effect) }
            }
        }
        Divider()
        Button("Open DynUtils") {
            openWindow(id: "main")
            NSApp.activate()
        }
        .keyboardShortcut("o")
        Button("Quit DynUtils") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

private struct Studio: View {
    enum Section: String, CaseIterable, Identifiable {
        case wallpapers, effects, settings
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .wallpapers: "photo"
            case .effects: "cloud.snow"
            case .settings: "gearshape"
            }
        }
    }

    @ObservedObject var session: DesktopSession
    @State private var section: Section = .wallpapers
    @State private var selectedWallpaper = Wallpaper.catalog[0].id
    @State private var target: String? = nil
    @State private var decorationDisplay: String?

    private var scene: Wallpaper {
        Wallpaper.catalog.first { $0.id == selectedWallpaper } ?? Wallpaper.catalog[0]
    }

    var body: some View {
        if !session.prefs.onboardingComplete {
            VStack(alignment: .leading, spacing: 16) {
                wallpaperPreview(scene)
                Text("Make the desktop feel like yours.").font(.largeTitle.bold())
                Text("Preview a bundled scene and add weather. Everything works offline.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Explore wallpapers") { session.prefs.onboardingComplete = true }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    Button("Skip") { session.prefs.onboardingComplete = true }
                }
            }
            .padding(26)
            .frame(minWidth: 560, minHeight: 460)
        } else {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("DynUtils").font(.title2.bold()).padding(.bottom, 10)
                    ForEach(Section.allCases) { item in
                        Button { section = item } label: {
                            Label(item.rawValue.capitalized, systemImage: item.icon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(section == item ? Color.accentColor.opacity(0.15) : .clear,
                                            in: .rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                    }
                    Spacer()
                    Text(session.weatherStatus).font(.caption).foregroundStyle(.secondary)
                }
                .frame(width: 158)
                .padding(18)
                .background(.bar)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(section.rawValue.capitalized).font(.largeTitle.bold())
                        switch section {
                        case .wallpapers: wallpapers
                        case .effects: effects
                        case .settings: settings
                        }
                    }
                    .frame(maxWidth: 850, alignment: .leading)
                    .padding(26)
                }
            }
            .frame(minWidth: 700, minHeight: 520)
        }
    }

    private var wallpapers: some View {
        VStack(alignment: .leading, spacing: 14) {
            wallpaperPreview(scene)
            HStack {
                Text(scene.title).font(.title2.bold())
                Spacer()
                Picker("Scene", selection: $selectedWallpaper) {
                    ForEach(Wallpaper.catalog) { Text($0.title).tag($0.id) }
                }.fixedSize()
            }
            Text(inUse).foregroundStyle(.secondary)
            HStack {
                Picker("Apply to", selection: $target) {
                    Text("All displays").tag(String?.none)
                    ForEach(session.displays) { Text($0.name).tag(Optional($0.id)) }
                    if let target, !session.displays.contains(where: { $0.id == target }) {
                        Text("Disconnected display").tag(Optional(target))
                    }
                }
                Button("Apply wallpaper") { session.apply(scene, to: target) }
                    .buttonStyle(.borderedProminent)
                    .disabled(session.displays.isEmpty && target == nil)
            }
            HStack(alignment: .top) {
                Picker("Resolution", selection: Binding(
                    get: { session.prefs.resolution[scene.id] ?? .auto },
                    set: { session.prefs.resolution[scene.id] = $0 }
                )) {
                    ForEach(Resolution.allCases) { Text($0.title).tag($0) }
                }
                Picker("Scene rule", selection: Binding(get: { session.prefs.rule }, set: { session.setRule($0) })) {
                    ForEach(WallpaperRule.allCases) { Text($0.title).tag($0) }
                }
            }
            if session.prefs.resolution[scene.id] == .ultrawide {
                Text("This scene uses the standard image when a wide version is unavailable.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            if session.displays.isEmpty {
                Text("No displays are available. Reconnect a display and try again.")
            }
            ForEach(session.displays) { display in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(display.name).font(.headline)
                        Text(session.results[display.id] ?? displayWallpaper(display))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if session.failedDisplays.contains(display.id) {
                        Button("Retry") {
                            let pending = Wallpaper.catalog.first { $0.id == session.prefs.desired[display.id] }
                            session.apply(pending ?? scene, to: display.id)
                        }
                    }
                    if session.canRestore(display) {
                        Button("Restore previous") { session.restore(display.id) }
                    }
                }
            }
            if let target, !session.displays.contains(where: { $0.id == target }),
               let error = session.results[target] {
                Text(error).foregroundStyle(.secondary)
            }
        }
    }

    private var inUse: String {
        let names = session.displays.filter { $0.appliedWallpaper == scene.id }.map(\.name)
        return names.isEmpty ? "Preview · Not applied" : "In use on " + names.joined(separator: ", ")
    }

    private func displayWallpaper(_ display: DesktopSession.Display) -> String {
        Wallpaper.catalog.first { $0.id == display.appliedWallpaper }?.title ?? "System wallpaper"
    }

    @ViewBuilder private func wallpaperPreview(_ wallpaper: Wallpaper) -> some View {
        if let url = wallpaper.url(for: .normal, aspectRatio: 1.77), let image = NSImage(contentsOf: url) {
            Color.clear.aspectRatio(2.35, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        Image(nsImage: image).resizable().scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                }
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityLabel("\(wallpaper.title) wallpaper preview")
        } else {
            ContentUnavailableView("Image unavailable", systemImage: "photo")
        }
    }

    private var effects: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Effects run independently of your wallpaper unless Match effect is enabled.")
                .foregroundStyle(.secondary)
            Picker("Weather", selection: Binding(get: { session.prefs.effect }, set: { session.selectEffect($0) })) {
                ForEach(Effect.allCases) { Text($0.title).tag($0) }
            }.fixedSize()
            Picker("Density", selection: $session.prefs.density) {
                ForEach(EffectDensity.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Effect density")
            .disabled(session.prefs.effect == .off)
            HStack {
                Text("Wind")
                Slider(value: $session.prefs.wind, in: -1...1) { Text("Wind") }
                Text(session.prefs.wind < -0.05 ? "Left" : (session.prefs.wind > 0.05 ? "Right" : "Still"))
                    .monospacedDigit().frame(width: 54)
                Button("Reset") { session.prefs.wind = 0 }
            }
            if session.prefs.effect == .snow || session.prefs.effect == .heavySnow {
                Toggle("Accumulate snow at the bottom", isOn: Binding(
                    get: { session.prefs.groundSnow == true },
                    set: { session.prefs.groundSnow = $0 }
                ))
            }
            if session.prefs.effect == .rain {
                Toggle("Rainbow", isOn: $session.prefs.rainbow)
                Toggle("Lightning", isOn: $session.prefs.lightning)
            }
            Text(session.weatherStatus).foregroundStyle(.secondary)
            Button(session.prefs.manualPause ? "Resume weather" : "Pause weather") {
                session.prefs.manualPause.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(session.prefs.effect == .off)
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Displays").font(.headline)
            if session.displays.isEmpty { Text("No displays connected.").foregroundStyle(.secondary) }
            ForEach(session.displays) { display in
                Toggle("Weather on \(display.name)", isOn: Binding(
                    get: { !session.prefs.weatherDisabled.contains(display.id) },
                    set: {
                        if $0 { session.prefs.weatherDisabled.remove(display.id) }
                        else { session.prefs.weatherDisabled.insert(display.id) }
                    }
                ))
            }
            Divider()
            Text("Power & motion").font(.headline)
            Toggle("Pause on battery", isOn: $session.prefs.pauseOnBattery)
            Toggle("Reduce motion", isOn: $session.prefs.reduceMotion)
            Text("Weather runs behind windows at up to 30 FPS.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Open at login", isOn: Binding(
                get: { session.loginStatus == .enabled || session.loginStatus == .requiresApproval },
                set: { session.setLaunchAtLogin($0) }
            ))
            if session.loginStatus == .requiresApproval {
                Button("Open Login Items settings") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let error = session.loginError { Text(error).foregroundStyle(.secondary) }
            Divider()
            Text("Desktop decorations").font(.headline)
            if let first = session.displays.first {
                let display = session.displays.first { $0.id == decorationDisplay } ?? first
                Picker("Decorate display", selection: Binding(
                    get: { display.id }, set: { decorationDisplay = $0 }
                )) {
                    ForEach(session.displays) { Text($0.name).tag($0.id) }
                }.fixedSize()
                ForEach(DesktopProp.allCases) { prop in
                    Toggle(prop.title, isOn: Binding(
                        get: { session.decoration(prop, on: display.id) },
                        set: { session.setDecoration(prop, on: display.id, enabled: $0) }
                    ))
                }
                Button("Undo decoration change") { session.undoDecoration() }
                    .disabled(!session.canUndoDecoration)
            } else {
                Text("Connect a display to place decorations.").foregroundStyle(.secondary)
            }
            Divider()
            Button("Reset preferences") { session.resetPreferences() }
        }
    }
}
