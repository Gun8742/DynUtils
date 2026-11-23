import AppKit
import QuartzCore

@MainActor
final class WeatherOverlay: NSObject {
    struct Style: Equatable {
        var effect: Effect
        var wind: Double
        var reduceMotion: Bool
        var lowPower: Bool
        var rainbow: Bool
        var lightning: Bool
    }

    private let window: NSWindow
    private let renderer: ParticleView

    init(screen: NSScreen, style: Style) {
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                          backing: .buffered, defer: false, screen: screen)
        renderer = ParticleView(frame: NSRect(origin: .zero, size: screen.frame.size), style: style)
        super.init()
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
        NotificationCenter.default.addObserver(
            self, selector: #selector(visibilityChanged),
            name: NSWindow.didChangeOcclusionStateNotification, object: window
        )
        window.orderFrontRegardless()
        visibilityChanged()
    }

    func update(screen: NSScreen, style: Style) {
        if window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
        renderer.style = style
        visibilityChanged()
    }

    func close() {
        NotificationCenter.default.removeObserver(self)
        renderer.stop()
        window.orderOut(nil)
        window.close()
    }

    @objc private func visibilityChanged() {
        if window.occlusionState.contains(.visible) { renderer.start() } else { renderer.stop() }
    }
}

@MainActor
private final class ParticleView: NSView {
    private struct Particle {
        let x = CGFloat.random(in: 0...1)
        let y = CGFloat.random(in: 0...1)
        let size = CGFloat.random(in: 0.9...2.8)
        let speed = CGFloat.random(in: 0.55...1.35)
        let phase = CGFloat.random(in: 0...(2 * .pi))
    }

    private let particles = (0..<240).map { _ in Particle() }
    private var timer: Timer?
    private var elapsed: CGFloat = 0
    private var lastTick = 0.0
    var style: WeatherOverlay.Style {
        didSet {
            if oldValue.effect != style.effect { elapsed = 0 }
        }
    }

    init(frame: NSRect, style: WeatherOverlay.Style) {
        self.style = style
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    func start() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let tick = Timer(timeInterval: 1.0 / 30, target: self,
                         selector: #selector(redraw), userInfo: nil, repeats: true)
        tick.tolerance = 0.004
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func redraw() {
        let now = CACurrentMediaTime()
        elapsed += min(now - lastTick, 0.1) * (style.reduceMotion ? 0.35 : 1)
        lastTick = now
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 0, bounds.height > 0,
              let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(dirtyRect)

        let count: Int
        let speed: CGFloat
        let color: NSColor
        switch style.effect {
        case .off: return
        case .snow: (count, speed, color) = (120, 42, .white)
        case .heavySnow: (count, speed, color) = (230, 64, .white)
        case .rain: (count, speed, color) = (145, 440, NSColor(srgbRed: 0.70, green: 0.84, blue: 1, alpha: 1))
        case .leaves: (count, speed, color) = (70, 55, NSColor(srgbRed: 0.94, green: 0.58, blue: 0.20, alpha: 1))
        case .sakura: (count, speed, color) = (90, 43, NSColor(srgbRed: 1, green: 0.68, blue: 0.78, alpha: 1))
        case .fireflies: (count, speed, color) = (48, 10, NSColor(srgbRed: 1, green: 0.92, blue: 0.44, alpha: 1))
        case .starfall: (count, speed, color) = (24, 205, NSColor(srgbRed: 0.77, green: 0.89, blue: 1, alpha: 1))
        }

        let divisor = style.reduceMotion ? 3 : (style.lowPower ? 2 : 1)
        let height = bounds.height + 90
        let width = bounds.width + 120
        let wind = CGFloat(style.wind) * 100
        for p in particles.prefix(count / divisor) {
            let drift: CGFloat = style.effect == .starfall ? 180 : wind
            let travel = (p.y * height + elapsed * speed * p.speed).truncatingRemainder(dividingBy: height)
            let x = (p.x * width + elapsed * drift + sin(elapsed * 0.65 + p.phase) * 17)
                .truncatingRemainder(dividingBy: width)
            let point = CGPoint(x: (x < 0 ? x + width : x) - 60, y: height - travel - 45)
            let r = p.size
            let opacity = style.effect == .fireflies ? 0.42 + 0.29 * sin(elapsed * 1.8 + p.phase) : 0.73
            context.setFillColor(color.withAlphaComponent(opacity).cgColor)
            switch style.effect {
            case .rain, .starfall:
                let star = style.effect == .starfall
                let trail = star ? 17 * r : 7 * r
                context.setStrokeColor(color.withAlphaComponent(star ? 0.76 : 0.48).cgColor)
                context.setLineWidth(star ? 1.4 : 0.8)
                context.move(to: point)
                context.addLine(to: CGPoint(x: point.x - trail * (star ? 0.83 : 0.26 * wind / 100),
                                            y: point.y + trail))
                context.strokePath()
            case .leaves, .sakura:
                context.saveGState()
                context.translateBy(x: point.x, y: point.y)
                context.rotate(by: elapsed * p.speed + p.phase)
                context.fillEllipse(in: CGRect(x: -r * 1.8, y: -r, width: r * 3.6, height: r * 2))
                context.restoreGState()
            default:
                context.fillEllipse(in: CGRect(x: point.x, y: point.y, width: r * 2, height: r * 2))
            }
        }

        guard style.effect == .rain else { return }
        if style.rainbow {
            let center = CGPoint(x: bounds.width * 0.58, y: bounds.height * 0.12)
            for (index, hue) in [0.0, 0.11, 0.19, 0.33, 0.56, 0.69].enumerated() {
                context.setStrokeColor(NSColor(hue: hue, saturation: 0.7, brightness: 1, alpha: 0.19).cgColor)
                context.setLineWidth(4)
                context.addArc(center: center, radius: min(bounds.width, bounds.height) * 0.52 - CGFloat(index * 4),
                               startAngle: 0, endAngle: .pi, clockwise: false)
                context.strokePath()
            }
        }
        if style.lightning, !style.reduceMotion {
            let cycle = elapsed.truncatingRemainder(dividingBy: 18)
            if cycle > 17.88 {
                context.setFillColor(gray: 1, alpha: 0.10 * (18 - cycle) / 0.12)
                context.fill(bounds)
            }
        }
    }
}
