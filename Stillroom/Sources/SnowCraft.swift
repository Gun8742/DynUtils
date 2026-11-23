import CoreGraphics

struct SnowCraft {
    struct Ball {
        let center: CGPoint
        let radius: CGFloat
    }

    private struct Stack {
        let surface: Int
        let offset: CGFloat
        var balls: [CGFloat]

        func base(on edge: DesktopEdge) -> CGPoint {
            CGPoint(x: edge.minX + (edge.maxX - edge.minX) * offset, y: edge.y)
        }

        func render(on edge: DesktopEdge) -> [Ball] {
            let base = base(on: edge)
            var height = base.y
            return balls.map { mass in
                let radius = SnowCraft.radius(for: mass)
                let center = CGPoint(x: base.x, y: height + radius)
                height += radius * 1.77
                return Ball(center: center, radius: radius)
            }
        }
    }

    private static let maximumMass: CGFloat = 315
    private static let minimumMass: CGFloat = 14
    private static let floorID = -1
    private static let stackLimit = 24

    private var stacks: [Stack] = []
    private var heldMass: CGFloat = 0
    private var previousPoint: CGPoint?
    private var observedPress = false
    private var lastCollection: (surface: Int, x: CGFloat)?
    private(set) var visibleBalls: [Ball] = []

    // A drag already in progress when entering this display must not start a second ball.
    private var readyForPress = false

    mutating func update(size: CGSize, pointer: CGPoint?, pressed: Bool, banks: inout [SnowBank]) -> CGPoint? {
        let floor = DesktopEdge(minX: 0, maxX: size.width, y: 0, id: Self.floorID)
        let ledges = banks.map(\.edge).filter { $0.id != Self.floorID }
        let surfaces = Dictionary(uniqueKeysWithValues: (ledges + [floor]).map { ($0.id, $0) })
        stacks.removeAll { surfaces[$0.surface] == nil }
        var snowman: CGPoint?

        if let point = pointer {
            if pressed, readyForPress, !observedPress {
                observedPress = true
                pickUp(at: point, surfaces: surfaces)
                previousPoint = point
            }
            if observedPress, let previousPoint, hypot(point.x - previousPoint.x, point.y - previousPoint.y) < 340 {
                collect(from: previousPoint, to: point, banks: &banks)
            }
            if observedPress, !pressed {
                snowman = putDown(at: point, floor: floor, ledges: ledges, banks: &banks)
            }
            previousPoint = point
        } else if observedPress {
            // Finish the current ball on this display before the pointer enters another one.
            if let point = previousPoint {
                snowman = putDown(at: point, floor: floor, ledges: ledges, banks: &banks)
            }
            previousPoint = nil
            readyForPress = false
        }
        if pointer == nil || !pressed { readyForPress = !pressed }

        visibleBalls = stacks.flatMap { stack -> [Ball] in
            guard let edge = surfaces[stack.surface] else { return [] }
            return stack.render(on: edge)
        }
        if observedPress, let point = pointer, heldMass > 0 {
            let radius = Self.radius(for: heldMass)
            visibleBalls.append(Ball(center: CGPoint(x: point.x, y: max(radius, point.y)), radius: radius))
        }
        return snowman
    }

    private mutating func pickUp(at point: CGPoint, surfaces: [Int: DesktopEdge]) {
        for index in stacks.indices.reversed() {
            let stack = stacks[index]
            guard let edge = surfaces[stack.surface], let top = stack.render(on: edge).last,
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
                                  banks: inout [SnowBank]) -> CGPoint? {
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
            guard stack.surface == edge.id, let top = stack.render(on: edge).last else { return false }
            return abs(point.x - top.center.x) <= top.radius + Self.radius(for: heldMass)
                && point.y <= top.center.y + top.radius + 24
        }) {
            stacks[index].balls.append(heldMass)
            guard stacks[index].balls.count == 3 else { return nil }
            return stacks.remove(at: index).base(on: edge)
        }

        if stacks.count >= Self.stackLimit { stacks.removeFirst() }
        let radius = min(Self.radius(for: heldMass), (edge.maxX - edge.minX) / 2)
        let x = min(edge.maxX - radius, max(edge.minX + radius, point.x))
        stacks.append(Stack(surface: edge.id, offset: (x - edge.minX) / (edge.maxX - edge.minX), balls: [heldMass]))
        return nil
    }

    private static func radius(for mass: CGFloat) -> CGFloat { 3 + sqrt(mass) * 0.75 }
}
