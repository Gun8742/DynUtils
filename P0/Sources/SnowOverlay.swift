import AppKit
import QuartzCore

@MainActor
final class SnowOverlay {
    private var window: NSWindow?
    private var renderer: SnowView?
    private var displayID: CGDirectDisplayID?

    var isRunning: Bool { renderer?.isRunning == true }

    func show(on screen: NSScreen) {
        if window != nil, displayID == screen.displayID {
            window?.setFrame(screen.frame, display: true)
            return
        }
        stop()
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                              backing: .buffered, defer: false, screen: screen)
        let renderer = SnowView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.setFrame(screen.frame, display: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.contentView = renderer
        self.window = window
        self.renderer = renderer
        displayID = screen.displayID
        window.orderFrontRegardless()
        renderer.start()
    }

    func stop() {
        renderer?.stop()
        window?.orderOut(nil)
        window?.close()
        renderer = nil
        window = nil
        displayID = nil
    }
}

@MainActor
private final class SnowView: NSView {
    private struct Flake {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let speed: CGFloat
        let phase: CGFloat
    }

    private let flakes = (0..<120).map { _ in
        Flake(x: .random(in: 0...1), y: .random(in: 0...1), radius: .random(in: 0.9...2.8),
              speed: .random(in: 22...70), phase: .random(in: 0...(2 * .pi)))
    }
    private var timer: Timer?
    private var started = CACurrentMediaTime()
    var isRunning: Bool { timer?.isValid == true }

    func start() {
        guard timer == nil else { return }
        started = CACurrentMediaTime()
        let tick = Timer(timeInterval: 1.0 / 30, target: self,
                         selector: #selector(redraw), userInfo: nil, repeats: true)
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func redraw() { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 0, bounds.height > 0,
              let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(dirtyRect)
        let time = CGFloat(CACurrentMediaTime() - started)
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let height = bounds.height + 12
        for flake in flakes.prefix(reducedMotion ? 45 : flakes.count) {
            let speed = reducedMotion ? flake.speed * 0.35 : flake.speed
            let traveled = (flake.y * height + time * speed).truncatingRemainder(dividingBy: height)
            let x = flake.x * bounds.width + sin(time * 0.65 + flake.phase) * 15
            let y = height - traveled - 6
            context.setFillColor(gray: 1, alpha: 0.62 + flake.radius * 0.10)
            context.fillEllipse(in: CGRect(x: x, y: y, width: 2 * flake.radius, height: 2 * flake.radius))
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    static var primary: NSScreen? {
        screens.first { $0.displayID == CGMainDisplayID() } ?? screens.first
    }
}
