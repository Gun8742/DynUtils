import AppKit
import QuartzCore

@MainActor
final class WeatherOverlay: NSObject {
    struct Style: Equatable {
        var effect: Effect
        var density: EffectDensity
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

    private static let particleLimit = 480
    private let particles = (0..<particleLimit).map { _ in Particle() }
    private static let mistGradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            NSColor(srgbRed: 0.82, green: 0.91, blue: 0.93, alpha: 0.19).cgColor,
            NSColor(srgbRed: 0.82, green: 0.91, blue: 0.93, alpha: 0).cgColor
        ] as CFArray, locations: [0, 1]
    )
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

        if style.effect == .mist {
            drawMist(in: context)
            return
        }

        let count: Int
        let speed: CGFloat
        let color: NSColor
        switch style.effect {
        case .off, .mist: return
        case .snow: (count, speed, color) = (185, 54, .white)
        case .heavySnow: (count, speed, color) = (290, 86, .white)
        case .drizzle: (count, speed, color) = (115, 290, NSColor(srgbRed: 0.80, green: 0.90, blue: 1, alpha: 1))
        case .rain: (count, speed, color) = (245, 490, NSColor(srgbRed: 0.70, green: 0.84, blue: 1, alpha: 1))
        case .leaves: (count, speed, color) = (110, 58, NSColor(srgbRed: 0.94, green: 0.58, blue: 0.20, alpha: 1))
        case .sakura: (count, speed, color) = (145, 49, NSColor(srgbRed: 1, green: 0.68, blue: 0.78, alpha: 1))
        case .fireflies: (count, speed, color) = (74, 10, NSColor(srgbRed: 1, green: 0.92, blue: 0.44, alpha: 1))
        case .starfall: (count, speed, color) = (40, 210, NSColor(srgbRed: 0.77, green: 0.89, blue: 1, alpha: 1))
        }

        let divisor = style.reduceMotion ? 3 : (style.lowPower ? 2 : 1)
        let height = bounds.height + 90
        let width = bounds.width + 120
        let wind = CGFloat(style.wind) * 100
        let areaScale = min(1.35, max(0.65, sqrt(bounds.width * bounds.height / (1440 * 900))))
        let budget = min(Self.particleLimit, Int(Double(count) * style.density.multiplier * areaScale))
        let isStarfall = style.effect == .starfall
        let isDrizzle = style.effect == .drizzle
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        for p in particles.prefix(budget / divisor) {
            let drift: CGFloat = (isStarfall ? 180 : 0) + wind
            let travel = (p.y * height + elapsed * speed * p.speed).truncatingRemainder(dividingBy: height)
            let x = (p.x * width + elapsed * drift + sin(elapsed * 0.65 + p.phase) * 17)
                .truncatingRemainder(dividingBy: width)
            let point = CGPoint(x: (x < 0 ? x + width : x) - 60, y: height - travel - 45)
            let r = p.size * (style.effect == .heavySnow ? 1.45 : 1.2)
            context.setAlpha(0.80)
            switch style.effect {
            case .drizzle, .rain, .starfall:
                let trail = r * (isStarfall ? 22 : (isDrizzle ? 4 : 10))
                let slope = (isStarfall ? 0.83 : 0) + 0.28 * wind / 100
                context.setAlpha(isStarfall ? 0.74 : (isDrizzle ? 0.35 : 0.59))
                context.setLineWidth(isStarfall ? 1.6 : (isDrizzle ? 0.65 : 1.15))
                context.move(to: point)
                context.addLine(to: CGPoint(x: point.x - trail * slope, y: point.y + trail))
                context.strokePath()
                if isStarfall {
                    context.fillEllipse(in: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2))
                }
            case .leaves, .sakura:
                context.saveGState()
                context.translateBy(x: point.x, y: point.y)
                context.rotate(by: elapsed * p.speed + p.phase)
                context.move(to: CGPoint(x: -2.6 * r, y: 0))
                context.addQuadCurve(to: CGPoint(x: 2.6 * r, y: 0), control: CGPoint(x: 0, y: 2.8 * r))
                context.addQuadCurve(to: CGPoint(x: -2.6 * r, y: 0),
                                     control: CGPoint(x: 0, y: (style.effect == .leaves ? -2 : -3.8) * r))
                context.fillPath()
                context.restoreGState()
            case .fireflies:
                let glow = 0.50 + 0.30 * sin(elapsed * 1.8 + p.phase)
                context.setAlpha(glow * 0.19)
                context.fillEllipse(in: CGRect(x: point.x - r * 3, y: point.y - r * 3,
                                               width: 6 * r, height: 6 * r))
                context.setAlpha(glow)
                context.fillEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: 2 * r, height: 2 * r))
            default:
                context.fillEllipse(in: CGRect(x: point.x, y: point.y, width: r * 2, height: r * 2))
            }
        }

        context.setAlpha(1)
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

    private func drawMist(in context: CGContext) {
        guard let gradient = Self.mistGradient else { return }
        let density = CGFloat(style.density.multiplier) * (style.lowPower || style.reduceMotion ? 0.65 : 1)
        let hazeHeight = bounds.height * min(0.61, 0.31 * density)
        context.saveGState()
        context.setAlpha(min(1, density))
        for layer in 0..<3 {
            let phase = CGFloat(layer) * 2
            let travel = elapsed * (0.11 + abs(style.wind) * 0.19)
            let shift = sin(travel + phase) * bounds.width * 0.27 * (style.wind < 0 ? -1 : 1)
            context.saveGState()
            context.translateBy(x: bounds.width * (0.25 + 0.24 * CGFloat(layer)) + shift, y: -hazeHeight * 0.17)
            context.scaleBy(x: bounds.width * 0.70, y: hazeHeight)
            context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                       endCenter: .zero, endRadius: 1, options: [])
            context.restoreGState()
        }
        context.restoreGState()
    }
}
