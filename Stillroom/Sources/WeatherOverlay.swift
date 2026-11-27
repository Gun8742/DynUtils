import AppKit
import QuartzCore

@MainActor
final class WeatherOverlay: NSObject {
    enum SnowmanUpdate {
        case crafted(DecorationLayout)
        case rested(DecorationLayout)
        case shattered
    }

    struct Style: Equatable {
        var effect: Effect
        var density: EffectDensity
        var wind: Double
        var reduceMotion: Bool
        var lowPower: Bool
        var rainbow: Bool
        var lightning: Bool
        var groundSnow: Bool
        var surfaceSnow: Bool
        var snowDepth: SnowDepthLimits
        var snowmanPhysics: Bool
        var snowCrafting: Bool
        var props: Set<DesktopProp>
        var layouts: [DesktopProp: DecorationLayout]
        var visit: DesktopVisit?
        var aboveWindows: Bool

        var preferredFPS: Float { lowPower || reduceMotion ? 30 : 60 }
        var particleDivisor: Int { reduceMotion ? 3 : (lowPower ? 2 : 1) }
    }

    private let window: NSWindow
    private let renderer: ParticleView
    var hasDeposits: Bool { renderer.hasDeposits }

    init(screen: NSScreen, style: Style, onSnowman: @escaping (WeatherOverlay.SnowmanUpdate) -> Void) {
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                          backing: .buffered, defer: false, screen: screen)
        renderer = ParticleView(frame: NSRect(origin: .zero, size: screen.frame.size), style: style,
                                onSnowman: onSnowman)
        super.init()
        window.setFrame(screen.frame, display: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.level = Self.level(aboveWindows: style.aboveWindows)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        renderer.treeFloor = max(0, screen.visibleFrame.minY - screen.frame.minY)
        window.contentView = renderer
        NotificationCenter.default.addObserver(
            self, selector: #selector(visibilityChanged),
            name: NSWindow.didChangeOcclusionStateNotification, object: window
        )
        refreshPresentation()
    }

    func update(screen: NSScreen, style: Style) {
        if window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
        if style.aboveWindows != renderer.style.aboveWindows {
            window.level = Self.level(aboveWindows: style.aboveWindows)
        }
        renderer.treeFloor = max(0, screen.visibleFrame.minY - screen.frame.minY)
        renderer.style = style
        refreshPresentation()
    }

    private func refreshPresentation() {
        let style = renderer.style
        let hasVisibleContent = style.effect != .off || !style.props.isEmpty || style.visit?.expired == false
        if hasVisibleContent, !window.isVisible {
            window.orderFrontRegardless()
        } else if !hasVisibleContent, window.isVisible {
            window.orderOut(nil)
        }
        visibilityChanged()
    }

    private static func level(aboveWindows: Bool) -> NSWindow.Level {
        aboveWindows ? .floating : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
    }

    func close() {
        NotificationCenter.default.removeObserver(self)
        renderer.stop()
        window.orderOut(nil)
        window.close()
    }

    @objc private func visibilityChanged() {
        if window.occlusionState.contains(.visible),
           renderer.style.effect != .off || renderer.style.visit?.expired == false {
            renderer.start()
        } else {
            renderer.stop()
        }
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
    private static let meteorGradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            NSColor(srgbRed: 0.38, green: 0.64, blue: 0.99, alpha: 0).cgColor,
            NSColor(srgbRed: 0.64, green: 0.81, blue: 1, alpha: 0.37).cgColor,
            NSColor(srgbRed: 0.96, green: 0.98, blue: 1, alpha: 0.92).cgColor
        ] as CFArray, locations: [0, 0.55, 1]
    )
    private static let snowColor = NSColor.white.withAlphaComponent(0.84).cgColor
    private static let snowballColor = NSColor(srgbRed: 0.86, green: 0.94, blue: 1, alpha: 0.94).cgColor
    private static let bankBodyColor = NSColor(srgbRed: 0.80, green: 0.89, blue: 0.98, alpha: 0.88).cgColor
    private static let bankRimColor = NSColor(srgbRed: 0.97, green: 0.99, blue: 1, alpha: 0.91).cgColor
    private static let rainColor = NSColor(srgbRed: 0.67, green: 0.83, blue: 1, alpha: 0.63).cgColor
    private static let drizzleColor = NSColor(srgbRed: 0.67, green: 0.83, blue: 1, alpha: 0.42).cgColor
    private static let splashColor = NSColor(srgbRed: 0.76, green: 0.91, blue: 1, alpha: 1).cgColor
    private static let puddleColor = NSColor(srgbRed: 0.36, green: 0.67, blue: 0.89, alpha: 1).cgColor
    private static let leafVeinColor = NSColor(srgbRed: 0.33, green: 0.16, blue: 0.07, alpha: 0.61).cgColor
    private static let foliagePalette = [false, true].map { petal in
        (0...4).map { moisture in
            (0..<32).map { index in
                let tone = CGFloat(index) / 31
                let wetness = CGFloat(moisture) / 4
                return NSColor(hue: petal ? 0.92 + tone * 0.07 : 0.034 + tone * 0.08,
                               saturation: petal ? 0.42 : 0.83,
                               brightness: (petal ? 0.99 : 0.77 + tone * 0.19) - wetness * 0.22,
                               alpha: 0.92).cgColor
            }
        }
    }
    private static let foliageShapes = [false, true].map { petal -> CGPath in
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -1.7, y: 0))
        path.addQuadCurve(to: CGPoint(x: 1.7, y: 0), control: CGPoint(x: 0, y: 1.55))
        path.addQuadCurve(to: CGPoint(x: -1.7, y: 0), control: CGPoint(x: 0, y: petal ? -1.5 : -0.92))
        return path
    }
    private static let veinShape: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -1.72, y: 0))
        path.addQuadCurve(to: CGPoint(x: 1.42, y: 0), control: CGPoint(x: -0.1, y: 0.32))
        return path
    }()

    private var frameLink: CADisplayLink?
    private var elapsed: CGFloat = 0
    private var lastTick = 0.0
    private var nextEdgeSample: TimeInterval = 0
    private var lastEdgeSample: TimeInterval = 0
    private var followWindowsUntil: TimeInterval = 0
    private var edges: [DesktopEdge] = []
    private var foregroundWindows: [Int: [CGRect]] = [:]
    private var coveredLedges: [Int: [ClosedRange<CGFloat>]] = [:]
    private var snowWalls: [DesktopSnowWall] = []
    private var snow = SnowSimulation()
    private var materials = WeatherMaterials()
    var hasDeposits: Bool { snow.hasDeposits || materials.hasDeposits }
    private var craft = SnowCraft()
    private var snowman: SnowmanPhysics?
    private var appliedSnowmanLayout: DecorationLayout?
    private var lastSnowmanMovement: CGFloat = 0
    private let onSnowman: (WeatherOverlay.SnowmanUpdate) -> Void
    private var pointer = CGPoint(x: -.infinity, y: -.infinity)
    private var pointerStillSince: CGFloat = 0
    var style: WeatherOverlay.Style {
        didSet {
            guard oldValue != style else { return }
            if oldValue.effect != style.effect {
                elapsed = 0
                nextEdgeSample = 0
                materials.select(style.effect)
                snow.clearAirborne()
                snow.resetPointer()
                snowman?.resetPointer()
                lastSnowmanMovement = 0
                if !snowing { craft = SnowCraft() }
            }
            if style.visit?.visitor == .snowplough, oldValue.visit != style.visit {
                snow = SnowSimulation()
                craft = SnowCraft()
            }
            if oldValue.snowCrafting != style.snowCrafting { craft = SnowCraft() }
            if oldValue.surfaceSnow != style.surfaceSnow || oldValue.props != style.props { nextEdgeSample = 0 }
            if !style.props.contains(.snowman) {
                snowman = nil
                appliedSnowmanLayout = nil
            }
            needsDisplay = true
        }
    }

    var treeFloor: CGFloat = 0 {
        didSet { if oldValue != treeFloor { needsDisplay = true } }
    }

    private var snowing: Bool { style.effect == .snow || style.effect == .heavySnow }

    init(frame: NSRect, style: WeatherOverlay.Style, onSnowman: @escaping (WeatherOverlay.SnowmanUpdate) -> Void) {
        self.style = style
        self.onSnowman = onSnowman
        super.init(frame: frame)
        materials.select(style.effect)
    }

    required init?(coder: NSCoder) { nil }

    func start() {
        let frameRate = CAFrameRateRange(minimum: 30, maximum: style.preferredFPS, preferred: style.preferredFPS)
        if let frameLink {
            if frameLink.preferredFrameRateRange != frameRate { frameLink.preferredFrameRateRange = frameRate }
            return
        }
        lastTick = 0
        nextEdgeSample = 0
        let link = displayLink(target: self, selector: #selector(redraw(_:)))
        link.preferredFrameRateRange = frameRate
        link.add(to: .main, forMode: .common)
        frameLink = link
    }

    func stop() {
        frameLink?.invalidate()
        frameLink = nil
        snow.resetPointer()
        snowman?.resetPointer()
        craft = SnowCraft()
    }

    @objc private func redraw(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let frameTime = link.targetTimestamp
        let step = lastTick == 0 ? frameTime - link.timestamp : frameTime - lastTick
        let dt = min(max(0, step), 0.067) * (style.reduceMotion ? 0.35 : 1)
        elapsed += dt
        lastTick = frameTime
        if style.effect == .off, style.visit?.expired != false { stop() }

        let material = WeatherMaterials.Kind(style.effect)
        let tracksSnowSurfaces = style.effect != .off &&
            (material != nil || hasDeposits || (snowing && (style.surfaceSnow || style.props.contains(.snowman))))
        let buttonDown = tracksSnowSurfaces && NSEvent.pressedMouseButtons & 1 != 0
        if buttonDown { followWindowsUntil = now + 0.18 }
        var sampledAt: TimeInterval?
        if let window, now >= nextEdgeSample || (buttonDown && now - lastEdgeSample >= 1.0 / 30 - 0.002),
           tracksSnowSurfaces || [.rain, .sakura, .starfall].contains(style.effect)
                || (style.visit != nil && style.visit?.visitor == nil) {
            let snapshot = DesktopWindowSampler.snapshot(in: window.frame, at: now)
            sampledAt = now
            lastEdgeSample = now
            if tracksSnowSurfaces, edges != snapshot.edges { followWindowsUntil = now + 0.18 }
            edges = snapshot.edges
            foregroundWindows = snapshot.foreground
            coveredLedges = snapshot.coveredLedges
            snowWalls = snapshot.snowWalls
            nextEdgeSample = now + (tracksSnowSurfaces && now < followWindowsUntil ? 1.0 / 30 - 0.002 : 0.06)
        }

        if style.effect != .off, let frame = window?.frame, bounds.width > 0, bounds.height > 0 {
            let heavy = style.effect == .heavySnow
            let divisor = style.particleDivisor
            let count = snowing ? particleBudget(base: heavy ? 290 : 185) / divisor : 0
            let mouse = NSEvent.mouseLocation
            let cursor = CGPoint(x: mouse.x - frame.minX, y: mouse.y - frame.minY)
            let pointer = bounds.insetBy(dx: -25, dy: -25).contains(cursor) ? cursor : nil

            let ledges = style.surfaceSnow ? edges : []
            snow.sync(width: bounds.width, ground: style.groundSnow, ledges: ledges, coveredLedges: coveredLedges,
                      walls: style.surfaceSnow ? snowWalls : [], sampledAt: sampledAt)
            let pressing = snowing && style.snowCrafting && NSEvent.pressedMouseButtons & 1 != 0
            let crafted = snowing && style.snowCrafting
                ? snow.updateCraft(&craft, size: bounds.size,
                                   pointer: bounds.contains(cursor) ? cursor : nil, pressed: pressing, dt: dt)
                : nil
            let snowmanUpdate: WeatherOverlay.SnowmanUpdate?
            if let crafted {
                snowman = nil
                appliedSnowmanLayout = nil
                snowmanUpdate = .crafted(DecorationLayout(x: crafted.origin.x / bounds.width,
                                                          y: crafted.origin.y / bounds.height,
                                                          snowballs: crafted.snowballs))
            } else {
                snowmanUpdate = snowing ? advanceSnowman(dt: dt, pointer: pressing ? nil : pointer) : nil
            }
            snow.advance(dt: dt, size: bounds.size, count: count, heavy: heavy, limits: style.snowDepth,
                         wind: CGFloat(style.wind), pointer: pressing ? nil : pointer)
            if sampledAt != nil || materials.surfaces[-1]?.maxX != bounds.width {
                materials.setSurfaces(edges, width: bounds.width, covered: coveredLedges)
            }
            let emission: Int
            switch material {
            case .rain: emission = 245
            case .drizzle: emission = 115
            case .leaf: emission = 110
            case .petal: emission = 145
            case nil: emission = 0
            }
            materials.advance(dt: dt, size: bounds.size, count: particleBudget(base: emission) / divisor,
                              wind: CGFloat(style.wind), pointer: pressing ? nil : pointer, snow: &snow)
            if let snowmanUpdate { onSnowman(snowmanUpdate) }
        }
        needsDisplay = true
    }

    private func advanceSnowman(dt: CGFloat, pointer: CGPoint?) -> WeatherOverlay.SnowmanUpdate? {
        guard style.snowmanPhysics, style.props.contains(.snowman) else { return nil }
        let saved = style.layouts[.snowman] ?? .initial(.snowman)
        let floor = DesktopEdge(minX: 0, maxX: bounds.width, y: 0, id: -1)
        let surfaces = edges + [floor]
        if appliedSnowmanLayout != saved || snowman == nil {
            let origin = CGPoint(x: bounds.width * saved.x, y: bounds.height * saved.y)
            snowman = SnowmanPhysics(origin: origin, angle: saved.angle * .pi / 180, surfaces: surfaces,
                                     snowballs: saved.snowballs)
            appliedSnowmanLayout = saved
            lastSnowmanMovement = elapsed
        }
        guard var body = snowman else { return nil }
        let previousOrigin = body.origin
        if let impact = body.advance(dt: dt, width: bounds.width, surfaces: surfaces, pointer: pointer) {
            snow.scatter(impact)
            snowman = nil
            appliedSnowmanLayout = nil
            return .shattered
        }
        snowman = body
        if body.origin != previousOrigin || !body.isResting { lastSnowmanMovement = elapsed }
        guard elapsed - lastSnowmanMovement >= 0.45 else { return nil }

        let layout = renderedLayout(for: body)
        guard abs(layout.x - saved.x) > 0.0005 || abs(layout.y - saved.y) > 0.0005
            || abs(layout.angle - saved.angle) > 0.2 else { return nil }
        appliedSnowmanLayout = layout
        return .rested(layout)
    }

    private func renderedLayout(for body: SnowmanPhysics) -> DecorationLayout {
        DecorationLayout(x: body.origin.x / bounds.width, y: body.origin.y / bounds.height,
                         angle: body.angle * 180 / .pi, snowballs: body.snowballs)
    }

    private func particleBudget(base: Int) -> Int {
        let areaScale = min(1.35, max(0.65, sqrt(bounds.width * bounds.height / (1440 * 900))))
        return min(Self.particleLimit, Int(Double(base) * style.density.multiplier * areaScale))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 0, bounds.height > 0,
              let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(dirtyRect)
        if style.effect != .off {
            drawSnowBanks(in: context)
            drawSettledMaterials(in: context)
        }
        if snowing {
            for ball in craft.visibleBalls {
                DesktopDecoration.drawCraftBall(ball, in: context)
            }
        }
        if !style.props.isEmpty {
            var layouts = style.layouts
            if snowing, style.snowmanPhysics, let snowman,
               appliedSnowmanLayout == (layouts[.snowman] ?? .initial(.snowman)) {
                layouts[.snowman] = renderedLayout(for: snowman)
            }
            DesktopDecoration.draw(style.props, layouts: layouts, in: context, bounds: bounds,
                                   treeFloor: treeFloor)
        }

        if let visit = style.visit, visit.age >= 0, !visit.expired {
            drawVisit(visit, in: context)
        }
        guard style.effect != .off else { return }
        drawFallingSnow(in: context)
        drawWeatherMaterials(in: context)
        switch style.effect {
        case .mist: drawMist(in: context)
        case .starfall: drawStarfall(in: context)
        case .fireflies: drawFireflies(in: context)
        case .rain: drawRainSky(in: context)
        default: break
        }
    }

    private func drawFireflies(in context: CGContext) {
        let divisor = style.particleDivisor
        let height = bounds.height + 90
        let width = bounds.width + 120
        let wind = CGFloat(style.wind) * 100
        if let frame = window?.frame {
            let mouse = NSEvent.mouseLocation
            let next = CGPoint(x: mouse.x - frame.minX, y: mouse.y - frame.minY)
            if hypot(next.x - pointer.x, next.y - pointer.y) >= 2 {
                pointer = next
                pointerStillSince = elapsed
            }
        }
        context.setFillColor(NSColor(srgbRed: 1, green: 0.92, blue: 0.44, alpha: 1).cgColor)
        for p in particles.prefix(particleBudget(base: 74) / divisor) {
            let travel = (p.y * height + elapsed * 10 * p.speed).truncatingRemainder(dividingBy: height)
            let x = (p.x * width + elapsed * wind + sin(elapsed * 0.65 + p.phase) * 17)
                .truncatingRemainder(dividingBy: width)
            var point = CGPoint(x: (x < 0 ? x + width : x) - 60, y: height - travel - 45)
            let dx = point.x - pointer.x
            let dy = point.y - pointer.y
            let proximity = hypot(dx, dy)
            if !style.reduceMotion, proximity > 0, proximity < 150 {
                let attraction = min(1, max(0, elapsed - pointerStillSince - 0.75)) * 0.38
                point.x -= dx * attraction
                point.y -= dy * attraction
            }
            let r = p.size * 1.2
            let glow = 0.50 + 0.30 * sin(elapsed * 1.8 + p.phase)
            context.setAlpha(glow * 0.19)
            context.fillEllipse(in: CGRect(x: point.x - r * 3, y: point.y - r * 3, width: 6 * r, height: 6 * r))
            context.setAlpha(glow)
            context.fillEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: 2 * r, height: 2 * r))
        }
        context.setAlpha(1)
    }

    private func drawRainSky(in context: CGContext) {
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

    private func drawStarfall(in context: CGContext) {
        guard let gradient = Self.meteorGradient else { return }
        let reduced = style.reduceMotion
        let spacing = 2.7 / style.density.multiplier * (style.lowPower ? 1.45 : 1)
        let current = Int(elapsed / spacing)
        // Jitter each flight within its slot and also draw the previous slot if it overlaps.
        for slot in max(0, current - 1)...current {
            let p = particles[slot % particles.count]
            let age = elapsed - CGFloat(slot) * spacing - 0.12 - p.phase / (2 * .pi) * spacing * 0.68
            let duration = 0.65 + p.speed * 0.54
            guard age >= 0, age < duration + 0.40 else { continue }
            let scale = min(1.35, max(0.60, bounds.width / 1440))
            let vx = (580 + p.speed * 265) * scale * (p.x < 0.15 ? -1 : 1)
            let vy = -(320 + p.y * 285) * scale
            let heading = atan2(vy, vx)
            let origin = CGPoint(x: bounds.width * (0.14 + p.y * 0.56),
                                 y: bounds.height * (0.84 + p.x * 0.19))
            if let impact = DesktopEdge.firstImpact(from: origin, velocity: CGVector(dx: vx, dy: vy),
                                                    before: duration, edges: edges), age >= impact {
                if !reduced {
                    let hit = CGPoint(x: origin.x + impact * vx, y: origin.y + impact * vy)
                    drawSparks(in: context, at: hit, age: age - impact)
                }
                continue
            }
            guard age < duration else { continue }
            let t = age / duration
            let alpha = min(1, t * 9, (1 - t) * 3) * (reduced ? 0.66 : 0.95)
            let head = CGPoint(x: origin.x + age * vx, y: origin.y + age * vy)
            let length = min(hypot(vx, vy) * age,
                             (70 + p.size * 24) * scale * (reduced ? 0.7 : 1))
            let radius = (0.85 + p.size * 0.36) * scale
            guard length > 2 else { continue }

            context.saveGState()
            context.translateBy(x: head.x, y: head.y)
            context.rotate(by: heading)
            context.setAlpha(alpha)
            context.saveGState()
            context.move(to: CGPoint(x: -length, y: 0))
            context.addQuadCurve(to: CGPoint(x: 0, y: radius),
                                 control: CGPoint(x: -length * 0.21, y: radius * 0.40))
            context.addLine(to: CGPoint(x: 0, y: -radius))
            context.addQuadCurve(to: CGPoint(x: -length, y: 0),
                                 control: CGPoint(x: -length * 0.21, y: -radius * 0.40))
            context.closePath()
            context.clip()
            context.drawLinearGradient(gradient, start: CGPoint(x: -length, y: 0), end: .zero, options: [])
            context.restoreGState()
            context.setFillColor(gray: 1, alpha: 0.23)
            context.fillEllipse(in: CGRect(x: -radius * 2, y: -radius * 2,
                                           width: radius * 4, height: radius * 4))
            context.setFillColor(gray: 1, alpha: 0.95)
            context.fillEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
            context.restoreGState()
        }
    }

    private func drawVisit(_ visit: DesktopVisit, in context: CGContext) {
        let age = visit.age
        if let visitor = visit.visitor {
            let progress = style.reduceMotion ? 0.5 : age / DesktopVisit.duration
            let x = bounds.width * (0.06 + 0.88 * progress)
            let y: CGFloat = 58
            let alpha = min(1, age * 2, (DesktopVisit.duration - age) * 2)
            context.saveGState()
            context.setAlpha(alpha)
            context.setFillColor(NSColor(srgbRed: 0.12, green: 0.25, blue: 0.27, alpha: 0.92).cgColor)
            context.fillEllipse(in: CGRect(x: x - 20, y: y - 20, width: 40, height: 40))
            if let image = NSImage(systemSymbolName: visitor.symbol, accessibilityDescription: visitor.title) {
                image.draw(in: CGRect(x: x - 12, y: y - 12, width: 24, height: 24), from: .zero,
                           operation: .sourceOver, fraction: alpha)
            }
            context.restoreGState()
            // These visits add ephemeral artwork; they never alter saved decorations.
            if visitor == .elves && age > 2.2 {
                DesktopDecoration.draw([.snowman],
                    layouts: [.snowman: DecorationLayout(x: min(0.93, max(0.07, progress)), y: 0.08)],
                    in: context, bounds: bounds)
            } else if visitor == .fight && !style.reduceMotion {
                drawSparks(in: context, at: CGPoint(x: x, y: y + 20), age: age.truncatingRemainder(dividingBy: 0.5))
            }
            return
        }

        let origin = CGPoint(x: bounds.width * 0.17, y: 42)
        let vx = min(bounds.width * 0.64, 650)
        let vy: CGFloat = 275
        let gravity: CGFloat = 650
        let impact = DesktopVisit.snowballImpact(origin: origin, vx: vx, vy: vy, gravity: gravity, edges: edges)
            ?? (2 * vy / gravity)
        let t = min(age, impact)
        let point = CGPoint(x: origin.x + vx * t, y: origin.y + vy * t - gravity * t * t / 2)
        if age < impact, !style.reduceMotion {
            context.setFillColor(gray: 1, alpha: 0.9)
            context.fillEllipse(in: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
        } else if age >= impact {
            drawSparks(in: context, at: point, age: age - impact)
        }
    }

    private func drawSparks(in context: CGContext, at hit: CGPoint, age: CGFloat) {
        guard age < 0.40 else { return }
        context.saveGState()
        context.setFillColor(NSColor(srgbRed: 0.68, green: 0.86, blue: 1, alpha: 1).cgColor)
        context.setAlpha(0.85 * (1 - age / 0.40))
        for p in particles.prefix(11) {
            let x = hit.x + (p.x - 0.5) * 190 * age
            let y = hit.y + (30 + p.y * 100) * age - 140 * age * age
            if y >= hit.y {
                context.fillEllipse(in: CGRect(x: x, y: y, width: p.size, height: p.size))
            }
        }
        context.restoreGState()
    }

    private func omitForeground(on edgeID: Int, in region: CGRect, context: CGContext) {
        guard style.aboveWindows else { return }
        for window in foregroundWindows[edgeID] ?? [] {
            let covered = region.intersection(window)
            guard !covered.isNull, !covered.isEmpty else { continue }
            context.beginPath()
            context.addRect(region)
            context.addRect(covered)
            context.clip(using: .evenOdd)
        }
    }

    private func drawSettledMaterials(in context: CGContext) {
        for patch in materials.puddles {
            guard let edge = materials.surfaces[patch.edgeID] else { continue }
            let x = edge.minX + (edge.maxX - edge.minX) * patch.offset
            let y = edge.y + snow.depth(at: x, on: edge.id)
            let width = 6 + patch.water * 15
            let region = CGRect(x: x - width / 2, y: y, width: width, height: 1.2 + patch.water * 1.3)
            context.saveGState()
            omitForeground(on: edge.id, in: region, context: context)
            context.setFillColor(Self.puddleColor)
            context.setAlpha(min(0.48, patch.water * 0.32))
            context.fillEllipse(in: region)
            context.restoreGState()
        }
        for leaf in materials.litter where leaf.missing == 0 {
            let x = leaf.x
            let y = leaf.edge.y + snow.depth(at: x, on: leaf.edge.id) + leaf.layer + 1.5
            context.saveGState()
            omitForeground(on: leaf.edge.id, in: CGRect(x: x - 18, y: y - 12, width: 36, height: 26), context: context)
            drawFoliage(leaf.particle, at: CGPoint(x: x, y: y), wet: leaf.wetness, in: context)
            context.restoreGState()
        }
    }

    private func drawWeatherMaterials(in context: CGContext) {
        for group in [materials.falling, materials.loose] {
            for p in group {
                if p.kind.isWater {
                    let featured = p.kind == .rain
                    let trail: CGFloat = featured ? 0.031 : 0.022
                    context.setStrokeColor(featured ? Self.rainColor : Self.drizzleColor)
                    context.setLineWidth(p.radius * (featured ? 1.14 : 0.74))
                    context.move(to: p.point)
                    context.addLine(to: CGPoint(x: p.point.x - p.velocity.dx * trail,
                                                y: p.point.y - p.velocity.dy * trail))
                    context.strokePath()
                } else {
                    drawFoliage(p, at: p.point, wet: 0, in: context)
                }
            }
        }
        context.setFillColor(Self.splashColor)
        for splash in materials.splashes {
            context.setAlpha(min(0.78, splash.life * 4.4))
            context.fillEllipse(in: CGRect(x: splash.point.x - 1, y: splash.point.y - 1, width: 2, height: 2))
        }
        context.setAlpha(1)
    }

    private func drawFoliage(_ p: WeatherMaterials.Particle, at point: CGPoint, wet: CGFloat, in context: CGContext) {
        let petal = p.kind == .petal
        let tone = (sin(p.phase) + 1) / 2
        let r = p.radius
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: p.angle)
        context.scaleBy(x: r, y: r)
        let shape = petal ? 1 : 0
        context.setFillColor(Self.foliagePalette[shape][Int((wet * 4).rounded())][Int((tone * 31).rounded())])
        context.addPath(Self.foliageShapes[shape])
        context.fillPath()
        if !petal {
            context.setStrokeColor(Self.leafVeinColor)
            context.setLineWidth(0.55 / r)
            context.addPath(Self.veinShape)
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawSnowBanks(in context: CGContext) {
        for bank in snow.banks {
            let base = bank.edge.y
            let maxDepth = bank.depths.max() ?? 0
            guard maxDepth >= 0.45 else { continue }
            let band = CGRect(x: bank.edge.minX - 1, y: base - 1,
                              width: bank.edge.maxX - bank.edge.minX + 2, height: maxDepth + 2)
                .intersection(bounds)
            guard !band.isNull, !band.isEmpty else { continue }

            context.saveGState()
            defer { context.restoreGState() }
            omitForeground(on: bank.edge.id, in: band, context: context)
            var column = 0
            while column < bank.depths.count {
                guard bank.depths[column] >= 0.45 else {
                    column += 1
                    continue
                }
                let start = column
                while column < bank.depths.count, bank.depths[column] >= 0.45 { column += 1 }

                let left = max(bank.edge.minX, bank.center(of: start) - bank.spacing)
                let right = min(bank.edge.maxX, bank.center(of: column - 1) + bank.spacing)
                let contour = CGMutablePath()
                contour.move(to: CGPoint(x: left, y: base))
                var previous = CGPoint(x: left, y: base)
                for index in start...column {
                    let point = index == column ? CGPoint(x: right, y: base)
                        : CGPoint(x: bank.center(of: index), y: base + bank.depths[index])
                    let third = (point.x - previous.x) / 3
                    contour.addCurve(to: point,
                                     control1: CGPoint(x: previous.x + third, y: previous.y),
                                     control2: CGPoint(x: point.x - third, y: point.y))
                    previous = point
                }

                context.addPath(contour)
                context.closePath()
                context.setFillColor(Self.bankBodyColor)
                context.fillPath()
                context.addPath(contour)
                context.setStrokeColor(Self.bankRimColor)
                context.setLineWidth(0.85)
                context.strokePath()
            }
        }
    }

    private func drawFallingSnow(in context: CGContext) {
        context.setFillColor(Self.snowColor)
        for flake in snow.flakes {
            let diameter = flake.radius * 2
            context.fillEllipse(in: CGRect(x: flake.position.x - flake.radius, y: flake.position.y - flake.radius,
                                           width: diameter, height: diameter))
        }
        context.setFillColor(Self.snowballColor)
        for clump in snow.clumps {
            let radius = clump.radius
            context.fillEllipse(in: CGRect(x: clump.position.x - radius, y: clump.position.y - radius,
                                           width: radius * 2, height: radius * 1.45))
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
