import CoreGraphics

struct WeatherMaterials {
    enum Kind {
        case rain, drizzle, leaf, petal

        var isWater: Bool { self == .rain || self == .drizzle }

        init?(_ effect: Effect) {
            switch effect {
            case .rain: self = .rain
            case .drizzle: self = .drizzle
            case .leaves: self = .leaf
            case .sakura: self = .petal
            default: return nil
            }
        }
    }

    struct Particle {
        let kind: Kind
        var point: CGPoint
        var velocity: CGVector
        let radius: CGFloat
        let phase: CGFloat
        var angle: CGFloat
        var carriedWater: CGFloat?
    }

    struct Settled {
        var edge: DesktopEdge
        var offset: CGFloat
        var particle: Particle
        var layer: CGFloat = 0
        var wetness: CGFloat = 0
        var missing: CGFloat = 0

        var x: CGFloat { edge.minX + (edge.maxX - edge.minX) * offset }
    }

    struct Puddle {
        let edgeID: Int
        var offset: CGFloat
        var water: CGFloat
    }

    struct Splash {
        var point: CGPoint
        var velocity: CGVector
        var life: CGFloat
    }

    private(set) var falling: [Particle] = []
    private(set) var loose: [Particle] = []
    private(set) var litter: [Settled] = []
    private(set) var puddles: [Puddle] = []
    private(set) var splashes: [Splash] = []
    private(set) var surfaces: [Int: DesktopEdge] = [:]
    private var covered: [Int: [ClosedRange<CGFloat>]] = [:]
    private var source: Kind?
    private var previousPointer: CGPoint?
    private var time: CGFloat = 0

    var hasDeposits: Bool { !litter.isEmpty || !puddles.isEmpty }

    mutating func setSurfaces(_ edges: [DesktopEdge], width: CGFloat, covered: [Int: [ClosedRange<CGFloat>]]) {
        surfaces = Dictionary(uniqueKeysWithValues: edges.map { ($0.id, $0) })
        surfaces[-1] = DesktopEdge(minX: 0, maxX: width, y: 0, id: -1)
        self.covered = covered
    }

    mutating func select(_ effect: Effect) {
        let next = Kind(effect)
        if source != next { falling.removeAll(keepingCapacity: true) }
        source = next
        previousPointer = nil
    }

    mutating func advance(dt: CGFloat, size: CGSize, count: Int, wind: CGFloat, pointer: CGPoint?,
                          snow: inout SnowSimulation) {
        guard dt > 0, size.width > 0, size.height > 0 else { return }
        time += dt
        if source?.isWater == true { snow.melt(dt * (source == .rain ? 1.25 : 0.42)) }
        moveLitter(dt: dt, wind: wind, pointer: pointer)
        moveWater(dt: dt, wind: wind)

        if let source {
            if falling.count > count { falling.removeLast(falling.count - count) }
            while falling.count < count {
                falling.append(spawn(source, size: size, acrossScreen: true))
            }
            for index in falling.indices {
                var particle = falling[index]
                let start = particle.point
                integrate(&particle, dt: dt, wind: wind)
                if hit(&particle, from: start, snow: &snow) || outside(particle.point, size: size) {
                    particle = spawn(source, size: size, acrossScreen: false)
                }
                falling[index] = particle
            }
        }

        for index in loose.indices.reversed() {
            var particle = loose[index]
            let start = particle.point
            integrate(&particle, dt: dt, wind: wind)
            if hit(&particle, from: start, snow: &snow) || outside(particle.point, size: size) {
                loose.swapAt(index, loose.count - 1)
                loose.removeLast()
            } else {
                loose[index] = particle
            }
        }
    }

    private mutating func moveLitter(dt: CGFloat, wind: CGFloat, pointer: CGPoint?) {
        let stroke: CGVector
        if let pointer, let previousPointer {
            stroke = CGVector(dx: pointer.x - previousPointer.x, dy: pointer.y - previousPointer.y)
        } else { stroke = .zero }
        previousPointer = pointer
        for index in litter.indices.reversed() {
            var leaf = litter[index]
            let oldX = leaf.x
            if let edge = surfaces[leaf.edge.id] {
                leaf.edge = edge
                leaf.missing = 0
            } else {
                leaf.missing += dt
            }
            if source?.isWater == true { leaf.wetness = min(1, leaf.wetness + dt * 0.12) }
            else { leaf.wetness = max(0, leaf.wetness - dt * 0.07) }
            let cursorHit = pointer.map { point in
                let distanceSquared = stroke.dx * stroke.dx + stroke.dy * stroke.dy
                guard distanceSquared > 4, distanceSquared < 240 * 240 else { return false }
                let deltaX = leaf.x - point.x
                let deltaY = leaf.edge.y + leaf.layer - point.y
                let t = min(0, max(-1, (deltaX * stroke.dx + deltaY * stroke.dy) / distanceSquared))
                return hypot(deltaX - stroke.dx * t, deltaY - stroke.dy * t) < 30
            } ?? false
            let gust = wind * (0.72 + 0.28 * sin(time * 1.75 + leaf.particle.phase))
            let swept = abs(gust) > (0.76 + leaf.wetness * 0.19)
            let shaken = abs(oldX - leaf.x) > 23
            let washed = leaf.wetness > 0.82 && abs(wind) > 0.4
                && (leaf.offset < 0.12 || leaf.offset > 0.88)
            let exposed = covered[leaf.edge.id]?.contains { $0.contains(leaf.x) } != true
            if loose.count < 160, (leaf.missing > 0.75 || (exposed && (cursorHit || swept || shaken || washed))) {
                var released = leaf.particle
                released.point = CGPoint(x: leaf.x, y: leaf.edge.y + leaf.layer + 3)
                released.velocity = CGVector(dx: cursorHit ? min(150, max(-150, stroke.dx * 5)) : gust * 115,
                                             dy: leaf.missing > 0.75 ? -18 : 42 + abs(gust) * 55)
                loose.append(released)
                litter.remove(at: index)
            } else {
                litter[index] = leaf
            }
        }
    }

    private mutating func moveWater(dt: CGFloat, wind: CGFloat) {
        for index in puddles.indices.reversed() {
            var patch = puddles[index]
            patch.water -= dt * (patch.edgeID == -1 ? 0.11 : 0.33)
            guard let edge = surfaces[patch.edgeID], patch.water > 0.04 else {
                puddles.remove(at: index)
                continue
            }
            if edge.id != -1 {
                let direction: CGFloat = abs(wind) > 0.18 ? (wind < 0 ? -1 : 1) : (patch.offset < 0.5 ? -1 : 1)
                patch.offset += direction * (18 + patch.water * 4) * dt / (edge.maxX - edge.minX)
                if !(0...1).contains(patch.offset) {
                    if loose.count < 160 {
                        let x = direction < 0 ? edge.minX - 2 : edge.maxX + 2
                        loose.append(Particle(kind: .drizzle, point: CGPoint(x: x, y: edge.y - 1),
                                              velocity: CGVector(dx: direction * 31, dy: -40),
                                              radius: 0.8, phase: 0, angle: 0, carriedWater: patch.water))
                    }
                    puddles.remove(at: index)
                    continue
                }
            }
            puddles[index] = patch
        }
        for index in splashes.indices.reversed() {
            splashes[index].life -= dt
            if splashes[index].life <= 0 {
                splashes.swapAt(index, splashes.count - 1)
                splashes.removeLast()
                continue
            }
            splashes[index].point.x += splashes[index].velocity.dx * dt
            splashes[index].point.y += splashes[index].velocity.dy * dt
            splashes[index].velocity.dy -= 455 * dt
        }
    }

    private func integrate(_ particle: inout Particle, dt: CGFloat, wind: CGFloat) {
        let flutter = particle.kind.isWater ? 0 : sin(time * 4.2 + particle.phase) * 42
        let targetX = wind * (particle.kind.isWater ? 126 : 152) + flutter
        particle.velocity.dx += (targetX - particle.velocity.dx) * min(1, dt * 2.4)
        let terminal: CGFloat
        let gravity: CGFloat
        switch particle.kind {
        case .rain: (terminal, gravity) = (545, 880)
        case .drizzle: (terminal, gravity) = (310, 570)
        case .leaf: (terminal, gravity) = (62, 126)
        case .petal: (terminal, gravity) = (42, 94)
        }
        particle.velocity.dy = max(-terminal * (0.76 + particle.radius * 0.15), particle.velocity.dy - gravity * dt)
        particle.angle += (flutter * 0.037 + wind * 1.4) * dt
        particle.point.x += particle.velocity.dx * dt
        particle.point.y += particle.velocity.dy * dt
    }

    mutating func hit(_ particle: inout Particle, from start: CGPoint, snow: inout SnowSimulation) -> Bool {
        let end = particle.point
        guard start.y > end.y else { return false }
        var collision = snow.snowImpact(from: start, to: end)
        for edge in surfaces.values {
            let t = (start.y - edge.y) / (start.y - end.y)
            guard t >= 0, t <= 1, t < (collision?.fraction ?? 2) else { continue }
            let x = start.x + (end.x - start.x) * t
            if (edge.minX...edge.maxX).contains(x), covered[edge.id]?.contains(where: { $0.contains(x) }) != true {
                collision = (edge, t)
            }
        }
        guard let (edge, t) = collision else { return false }
        let x = start.x + (end.x - start.x) * t
        let y = start.y + (end.y - start.y) * t
        let offset = (x - edge.minX) / (edge.maxX - edge.minX)
        if particle.kind.isWater {
            trackRain(at: CGPoint(x: x, y: y), edge: edge, offset: offset, heavy: particle.kind == .rain,
                      carriedWater: particle.carriedWater)
            snow.melt(particle.kind == .rain ? 0.65 : 0.19, at: x, on: edge.id)
        } else {
            if litter.count >= 320 { litter.removeFirst() }
            particle.angle *= 0.36
            let layer = litter.filter { $0.edge.id == edge.id && abs($0.x - x) < 8 }
                .map(\.layer).max().map { min(6.6, $0 + 1.1) } ?? 0
            litter.append(Settled(edge: edge, offset: offset, particle: particle, layer: layer))
        }
        return true
    }

    private mutating func trackRain(at point: CGPoint, edge: DesktopEdge, offset: CGFloat, heavy: Bool,
                                    carriedWater: CGFloat?) {
        let volume = carriedWater ?? (heavy ? 0.49 : 0.19)
        if let index = puddles.firstIndex(where: {
            $0.edgeID == edge.id && abs($0.offset - offset) * (edge.maxX - edge.minX) < 15
        }) {
            puddles[index].water = min(3.4, puddles[index].water + volume)
        } else {
            if puddles.count >= 140 { puddles.removeFirst() }
            puddles.append(Puddle(edgeID: edge.id, offset: offset, water: volume))
        }
        if splashes.count < 180 {
            for sign in [-1.0, 1.0] {
                splashes.append(Splash(point: point, velocity: CGVector(dx: sign * (heavy ? 47 : 25),
                                                                        dy: heavy ? 68 : 42),
                                       life: heavy ? 0.22 : 0.13))
            }
        }
    }

    private func outside(_ point: CGPoint, size: CGSize) -> Bool {
        point.y < -12 || point.x < -125 || point.x > size.width + 125
    }

    private func spawn(_ kind: Kind, size: CGSize, acrossScreen: Bool) -> Particle {
        let y = acrossScreen ? CGFloat.random(in: 0...size.height) : size.height + CGFloat.random(in: 3...85)
        return Particle(kind: kind, point: CGPoint(x: CGFloat.random(in: -60...(size.width + 60)), y: y),
                        velocity: CGVector(dx: 0, dy: kind.isWater ? -270 : -34),
                        radius: CGFloat.random(in: kind.isWater ? 0.58...1.32 : 2.1...4.9),
                        phase: CGFloat.random(in: 0...(2 * .pi)), angle: CGFloat.random(in: -.pi...(.pi)))
    }
}
