import CoreGraphics

struct SnowmanPhysics {
    private(set) var origin: CGPoint
    private(set) var angle: CGFloat
    let snowballs: SnowmanSnowballs?
    private let parts: [CGRect]
    private var surface: DesktopEdge?
    private var speed = CGVector.zero
    private var angularSpeed: CGFloat = 0
    private var previousPointer: CGPoint?

    var isResting: Bool { surface != nil && speed.dx == 0 && angularSpeed == 0 }

    init(origin: CGPoint, angle: CGFloat, surfaces: [DesktopEdge], snowballs: SnowmanSnowballs? = nil) {
        self.origin = origin
        self.angle = angle
        self.snowballs = snowballs
        parts = snowballs?.parts ?? SnowmanSnowballs.legacyParts
        surface = surfaces.filter {
            abs($0.y - origin.y) <= 8 && ($0.minX...$0.maxX).contains(origin.x)
        }.min { abs($0.y - origin.y) < abs($1.y - origin.y) }
    }

    mutating func advance(dt: CGFloat, width: CGFloat, surfaces: [DesktopEdge], pointer: CGPoint?) -> SnowCraft.Impact? {
        guard dt > 0 else { return nil }
        if let previous = surface {
            surface = surfaces.first { $0.id == previous.id }
            if let current = surface, previous != current {
                origin.x = current.minX + (current.maxX - current.minX) *
                    (origin.x - previous.minX) / (previous.maxX - previous.minX)
            }
        }
        if let surface { origin.y = surface.y }
        if let from = previousPointer, let pointer { push(from: from, to: pointer, dt: dt) }
        previousPointer = pointer

        let start = origin
        let margin = min(parts[0].width / 2, width / 2)
        origin.x = min(width - margin, max(margin, origin.x + speed.dx * dt))
        angle += angularSpeed * dt

        let departing = surface
        if let support = surface, (support.minX...support.maxX).contains(origin.x) {
            if abs(angle) > 0.8, angularSpeed != 0 {
                return breakApart(on: support, sideways: -angularSpeed * 37 + speed.dx, impactSpeed: 390)
            }
            speed.dx *= exp(-dt * 6)
            if abs(speed.dx) < 2 { speed.dx = 0 }
            if angularSpeed != 0 {
                angularSpeed = (angularSpeed - angle * 18 * dt) * exp(-dt * 3.3)
                if abs(angle) < 0.025, abs(angularSpeed) < 0.10 {
                    angle = 0
                    angularSpeed = 0
                }
            }
            return nil
        }

        surface = nil
        let gravity: CGFloat = 680
        let previousDY = speed.dy
        origin.y += previousDY * dt - 0.5 * gravity * dt * dt
        speed.dy -= gravity * dt
        guard origin.y < start.y else { return nil }
        let landing = surfaces.filter { edge in
            guard edge.id != departing?.id, start.y >= edge.y, origin.y <= edge.y else { return false }
            let fraction = (start.y - edge.y) / (start.y - origin.y)
            let x = start.x + (origin.x - start.x) * fraction
            return (edge.minX...edge.maxX).contains(x)
        }.max { $0.y < $1.y }
        guard let landing else { return nil }

        let impactSpeed = sqrt(previousDY * previousDY + 2 * gravity * (start.y - landing.y))
        origin.y = landing.y
        if impactSpeed > 275 || (impactSpeed > 110 && abs(angle) > 0.55) {
            return breakApart(on: landing, sideways: speed.dx, impactSpeed: max(390, impactSpeed))
        }
        surface = landing
        speed.dy = 0
        speed.dx *= 0.30
        angularSpeed -= speed.dx * 0.04
        return nil
    }

    mutating func resetPointer() { previousPointer = nil }

    private mutating func push(from: CGPoint, to: CGPoint, dt: CGFloat) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = dx * dx + dy * dy
        guard abs(dx) > 1, length < 180 * 180 else { return }
        let transform = CGAffineTransform(rotationAngle: angle)
        for part in parts.reversed() {
            let pivot = CGPoint(x: part.midX, y: part.midY).applying(transform)
            let center = CGPoint(x: origin.x + pivot.x, y: origin.y + pivot.y)
            let radius = part.width / 2
            guard dx * (center.x - from.x) > 0 else { continue }
            let t = min(1, max(0, ((center.x - from.x) * dx + (center.y - from.y) * dy) / length))
            let separation = hypot(center.x - from.x - t * dx, center.y - from.y - t * dy)
            guard separation <= radius + 5 else { continue }
            let impulse = min(1500, max(-1500, dx / max(dt, 1.0 / 30)))
            speed.dx = min(235, max(-235, speed.dx * 0.65 + impulse * 0.15))
            angularSpeed = min(10, max(-10, angularSpeed * 0.6 - impulse * part.midY * 0.00015))
            break
        }
    }

    private func breakApart(on edge: DesktopEdge, sideways: CGFloat, impactSpeed: CGFloat) -> SnowCraft.Impact {
        let x = min(edge.maxX, max(edge.minX, origin.x - sin(angle) * parts[1].midY * 0.58))
        return SnowCraft.Impact(point: CGPoint(x: x, y: edge.y), mass: snowballs?.totalMass ?? 840, speed: impactSpeed,
                                sideways: sideways, surface: edge.id)
    }
}
