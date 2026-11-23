import AppKit
import IOKit.pwr_mgt

/// An app-owned presentation, never a replacement for the macOS lock screen.
@MainActor
final class DesktopSaver {
    static let delays = [0, 1, 2, 5, 10, 15, 30]
    private var windows: [NSWindow] = []

    static var idleSeconds: TimeInterval {
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .mouseMoved, .leftMouseDown,
                                    .rightMouseDown, .otherMouseDown, .leftMouseDragged,
                                    .rightMouseDragged, .otherMouseDragged, .scrollWheel, .tabletPointer]
        return types.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }.min() ?? 0
    }

    static var mediaKeepsDisplayAwake: Bool {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&raw) == kIOReturnSuccess,
              let values = raw?.takeRetainedValue() as? [String: NSNumber] else { return true }
        return ["PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion", "PreventSystemSleep"]
            .contains { values[$0]?.intValue ?? 0 > 0 }
    }

    static func readDisplaySleepMinutes() -> Int? {
        let command = Process()
        command.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        command.arguments = ["-g"]
        let output = Pipe()
        command.standardOutput = output
        command.standardError = FileHandle.nullDevice
        guard (try? command.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
        for line in lines {
            let fields = line.split(whereSeparator: \.isWhitespace)
            if fields.count >= 2, fields[0] == "displaysleep",
               let minutes = Int(fields[1]), minutes > 0 { return minutes }
        }
        return nil
    }
    private var inputMonitor: Any?
    private weak var previousKeyWindow: NSWindow?
    private var previousApp: NSRunningApplication?
    var isRunning: Bool { !windows.isEmpty }
    var onDismiss: (() -> Void)?

    func show(_ scene: Wallpaper) -> Bool {
        guard !isRunning else { return true }
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return false }
        let presentations: [(NSScreen, NSImage)] = screens.compactMap { screen in
            let ratio = screen.frame.width / max(screen.frame.height, 1)
            guard let url = scene.url(for: .auto, aspectRatio: ratio),
                  let image = NSImage(contentsOf: url) else { return nil }
            return (screen, image)
        }
        guard presentations.count == screens.count else { return false }

        previousKeyWindow = NSApp.keyWindow
        previousApp = NSWorkspace.shared.frontmostApplication
        windows = presentations.map { screen, image in
            let window = SaverWindow(contentRect: screen.frame, styleMask: .borderless,
                                     backing: .buffered, defer: false, screen: screen)
            window.setFrame(screen.frame, display: false)
            window.title = "DynUtils Screen Saver"
            window.isReleasedWhenClosed = false
            window.backgroundColor = .black
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.acceptsMouseMovedEvents = true
            let imageView = NSImageView(frame: CGRect(origin: .zero, size: screen.frame.size))
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.setAccessibilityLabel(scene.title + " screen saver. Press Escape to exit.")
            window.contentView = imageView
            return window
        }

        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
                                          .mouseMoved, .scrollWheel]
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let dismissed = MainActor.assumeIsolated {
                guard let self, self.isRunning else { return false }
                self.stop(restoreFocus: true)
                return true
            }
            return dismissed ? nil : event
        }

        NSApp.activate()
        for window in windows { window.orderFrontRegardless() }
        let primaryFrame = NSScreen.main?.frame
        (windows.first { $0.frame == primaryFrame } ?? windows.first)?.makeKeyAndOrderFront(nil)
        return true
    }

    func stop(restoreFocus: Bool) {
        guard isRunning else { return }
        if let inputMonitor {
            NSEvent.removeMonitor(inputMonitor)
            self.inputMonitor = nil
        }
        let active = windows
        windows.removeAll()
        for window in active { window.orderOut(nil); window.close() }
        if restoreFocus {
            if let previousApp, previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                previousApp.activate()
            } else {
                previousKeyWindow?.makeKeyAndOrderFront(nil)
            }
        }
        previousApp = nil
        previousKeyWindow = nil
        onDismiss?()
    }
}

private final class SaverWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
