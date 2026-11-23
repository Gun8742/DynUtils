import CoreGraphics

struct SnowCraft {
    struct CompletedSnowman {
        let origin: CGPoint
        let snowballs: SnowmanSnowballs
    }


    struct Ball {
        let center: CGPoint
        let radius: CGFloat
        var rotation: CGFloat = 0
        var compression: CGFloat = 0
    }

    struct Impact {
        let point: CGPoint
        let mass: CGFloat
        let speed: CGFloat
        let sideways: CGFloat
        let surface: Int
    }

    private struct Stack {
        var base: CGPoint
        var surface: DesktopEdge?
        var balls: [CGFloat]
        var velocity = CGVector.zero
        var rotation: CGFloat = 0
        var compression: CGFloat = 0

        var radius: CGFloat { SnowCraft.radius(for: balls[0]) }

        func render() -> [Ball] {
            var height = base.y
            return balls.enumerated().map { index, mass in
                let radius = SnowCraft.radius(for: mass)
                let squash = index == 0 ? compression : 0
                let heightRadius = radius * (1 - squash)
                let center = CGPoint(x: base.x, y: height + heightRadius)
                height += heightRadius * 1.77
                return Ball(center: center, radius: radius, rotation: index == 0 ? rotation : 0, compression: squash)
            }
        }

        mutating func advance(dt: CGFloat, size: CGSize, cursor: (CGPoint, CGPoint)?,
                              surfaces: [DesktopEdge], banks: inout [SnowBank]) -> (alive: Bool, impact: Impact?) {
            if let support = surface {
                surface = surfaces.first { $0.id == support.id }
                if let edge = surface {
                    if support != edge {
                        let offset = (base.x - support.minX) / (support.maxX - support.minX)
                        base.x = edge.minX + (edge.maxX - edge.minX) * offset
                    }
                    base.y = edge.y
                }
            }

            if let (from, to) = cursor {
                push(from: from, to: to, dt: dt)
            }

            let old = base
            base.x += velocity.dx * dt
            if base.x < radius || base.x > size.width - radius {
                let margin = min(radius, size.width / 2)
                base.x = min(size.width - margin, max(margin, base.x))
                velocity.dx *= -0.25
            }
            let distance = base.x - old.x
            rotation -= distance / radius
            if let edge = surface, (edge.minX...edge.maxX).contains(base.x) {
                if abs(distance) >= 0.08, balls[0] < SnowCraft.maximumMass,
                   let index = banks.firstIndex(where: { $0.edge.id == edge.id }) {
                    let y = edge.y + radius * (1 - compression) * 0.45
                    if let snow = banks[index].sweep(from: CGPoint(x: old.x, y: y), to: CGPoint(x: base.x, y: y),
                                                     capacity: SnowCraft.maximumMass - balls[0],
                                                     radius: max(13, radius * 0.85)) {
                        balls[0] += snow.mass
                    }
                }
                velocity.dx *= exp(-dt * 2.15)
                if abs(velocity.dx) < 4 { velocity.dx = 0 }
                return (true, nil)
            }

            let departed = surface
            surface = nil
            var start = old
            var fallTime = dt
            if let departed, distance != 0 {
                start.x = distance > 0 ? departed.maxX : departed.minX
                fallTime *= min(1, abs(base.x - start.x) / abs(distance))
            }
            let gravity: CGFloat = 680
            let initialVerticalSpeed = velocity.dy
            base.y += initialVerticalSpeed * fallTime - 0.5 * gravity * fallTime * fallTime
            velocity.dy -= gravity * fallTime
            guard base.y < start.y else { return (true, nil) }

            // Intersect the path of the ball's bottom with each ledge and take the first it reaches.
            var contact: (edge: DesktopEdge, x: CGFloat, speed: CGFloat)?
            for edge in surfaces where edge.id != departed?.id && start.y >= edge.y && base.y <= edge.y {
                let speed = sqrt(initialVerticalSpeed * initialVerticalSpeed + 2 * gravity * (start.y - edge.y))
                let timeToImpact = (initialVerticalSpeed + speed) / gravity
                let x = start.x + (base.x - start.x) * min(1, timeToImpact / fallTime)
                if (edge.minX...edge.maxX).contains(x), edge.y > (contact?.edge.y ?? -.infinity) {
                    contact = (edge, x, speed)
                }
            }
            guard let contact else { return (true, nil) }
            base = CGPoint(x: contact.x, y: contact.edge.y)
            let speed = contact.speed
            if speed >= 390 {
                return (false, Impact(point: base, mass: balls.reduce(0, +), speed: speed,
                                      sideways: velocity.dx, surface: contact.edge.id))
            }
            if speed >= 220 {
                let shed = balls[0] * min(0.45, 0.20 + (speed - 220) / 690)
                balls[0] -= shed
                compression = min(0.40, compression + 0.28)
                surface = contact.edge
                let spray = Impact(point: base, mass: shed, speed: speed,
                                   sideways: velocity.dx, surface: contact.edge.id)
                velocity = CGVector(dx: velocity.dx * 0.30, dy: 0)
                return (true, spray)
            }
            velocity.dx *= 0.75
            if speed > 66 {
                velocity.dy = speed * 0.28
            } else {
                velocity.dy = 0
                surface = contact.edge
            }
            return (true, nil)
        }

        private mutating func push(from: CGPoint, to: CGPoint, dt: CGFloat) {
            let dx = to.x - from.x
            let dy = to.y - from.y
            let squared = dx * dx + dy * dy
            guard abs(dx) >= 1, squared <= 180 * 180, dx * (base.x - from.x) > 0 else { return }
            let touched = render().contains { ball in
                let t = min(1, max(0, ((ball.center.x - from.x) * dx + (ball.center.y - from.y) * dy) / squared))
                let closest = CGPoint(x: from.x + t * dx, y: from.y + t * dy)
                return hypot(ball.center.x - closest.x, ball.center.y - closest.y) < ball.radius + 7
            }
            guard touched else { return }
            let gain = 0.34 / (1 + radius / 42)
            velocity.dx = min(540, max(-540, velocity.dx * 0.65 + dx / max(dt, 0.01) * gain))
        }
    }

    private static let maximumMass: CGFloat = 4500
    private static let minimumMass: CGFloat = 14
    private static let floorID = -1
    private static let stackLimit = 24

    private var stacks: [Stack] = []
    private var heldMass: CGFloat = 0
    private var previousPoint: CGPoint?
    private var observedPress = false
    private var lastCollection: (surface: Int, x: CGFloat)?
    private(set) var visibleBalls: [Ball] = []
    private(set) var impacts: [Impact] = []

    // A drag already in progress when entering this display must not start a second ball.
    private var readyForPress = false

    mutating func update(size: CGSize, pointer: CGPoint?, pressed: Bool, dt: CGFloat = 1.0 / 30,
                         banks: inout [SnowBank]) -> CompletedSnowman? {
        let floor = DesktopEdge(minX: 0, maxX: size.width, y: 0, id: Self.floorID)
        let ledges = banks.map(\.edge).filter { $0.id != Self.floorID }
        let surfaces = ledges + [floor]
        let cursor = !pressed && !observedPress ? previousPoint.flatMap { from in pointer.map { (from, $0) } } : nil
        impacts.removeAll(keepingCapacity: true)
        for index in stacks.indices.reversed() {
            let result = stacks[index].advance(dt: dt, size: size, cursor: cursor, surfaces: surfaces, banks: &banks)
            if let impact = result.impact { impacts.append(impact) }
            if !result.alive { stacks.remove(at: index) }
        }
        var snowman: CompletedSnowman?

        if let point = pointer {
            if pressed, readyForPress, !observedPress {
                observedPress = true
                pickUp(at: point)
                previousPoint = point
            }
            if observedPress, let previousPoint, hypot(point.x - previousPoint.x, point.y - previousPoint.y) < 340 {
                collect(from: previousPoint, to: point, banks: &banks)
            }
            if observedPress, !pressed {
                snowman = putDown(at: point, floor: floor, ledges: ledges, banks: &banks)
            }
            previousPoint = point
        } else {
            if observedPress, let point = previousPoint {
                snowman = putDown(at: point, floor: floor, ledges: ledges, banks: &banks)
            }
            previousPoint = nil
        }
        if pointer == nil || !pressed { readyForPress = !pressed }

        visibleBalls = stacks.flatMap { $0.render() }
        if observedPress, let point = pointer, heldMass > 0 {
            let radius = Self.radius(for: heldMass)
            visibleBalls.append(Ball(center: CGPoint(x: point.x, y: max(radius, point.y)), radius: radius))
        }
        return snowman
    }

    private mutating func pickUp(at point: CGPoint) {
        for index in stacks.indices.reversed() {
            guard let top = stacks[index].render().last,
                  hypot(point.x - top.center.x, point.y - top.center.y) <= top.radius + 7 else { continue }
            heldMass = stacks[index].balls.removeLast()
            if stacks[index].balls.isEmpty { stacks.remove(at: index) }
            return
        }
    }

    private mutating func collect(from previous: CGPoint, to point: CGPoint, banks: inout [SnowBank]) {
        guard heldMass < Self.maximumMass else { return }
        for index in banks.indices {
            guard let collected = banks[index].sweep(from: previous, to: point, capacity: Self.maximumMass - heldMass)
            else { continue }
            heldMass += collected.mass
            lastCollection = (banks[index].edge.id, point.x)
        }
    }

    private mutating func putDown(at point: CGPoint, floor: DesktopEdge, ledges: [DesktopEdge],
                                  banks: inout [SnowBank]) -> CompletedSnowman? {
        defer {
            observedPress = false
            heldMass = 0
            lastCollection = nil
        }

        guard heldMass >= Self.minimumMass else {
            if let source = lastCollection, let index = banks.firstIndex(where: { $0.edge.id == source.surface }) {
                banks[index].deposit(heldMass, at: source.x)
            }
            return nil
        }

        let edge = ledges.filter {
            point.x >= $0.minX && point.x <= $0.maxX && point.y >= $0.y - 10
        }.max { $0.y < $1.y } ?? floor
        if let index = stacks.lastIndex(where: { stack in
            guard stack.surface?.id == edge.id, let top = stack.render().last else { return false }
            return abs(point.x - top.center.x) <= top.radius + Self.radius(for: heldMass)
                && point.y <= top.center.y + top.radius + 24
        }) {
            stacks[index].balls.append(heldMass)
            guard stacks[index].balls.count == 3 else { return nil }
            let stack = stacks.remove(at: index)
            return CompletedSnowman(origin: stack.base, snowballs: SnowmanSnowballs(
                base: stack.balls[0], torso: stack.balls[1], head: stack.balls[2]
            ))
        }

        if stacks.count >= Self.stackLimit { stacks.removeFirst() }
        let radius = Self.radius(for: heldMass)
        let margin = edge.id == Self.floorID ? min(radius, floor.maxX / 2) : 0
        let x = min(edge.maxX - margin, max(edge.minX + margin, point.x))
        let airborne = point.y - radius - edge.y > 18
        let y = airborne ? point.y - radius : edge.y
        stacks.append(Stack(base: CGPoint(x: x, y: y), surface: airborne ? nil : edge, balls: [heldMass]))
        return nil
    }

    static func radius(for mass: CGFloat) -> CGFloat { 3 + sqrt(mass) * 0.75 }
}
