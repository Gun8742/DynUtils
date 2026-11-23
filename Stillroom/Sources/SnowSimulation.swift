import CoreGraphics

struct SnowBank {
    var edge: DesktopEdge
    private(set) var depths: [CGFloat]

    init(edge: DesktopEdge) {
        self.edge = edge
        depths = Array(repeating: 0, count: max(1, min(512, Int(ceil((edge.maxX - edge.minX) / 7)))))
    }

    var spacing: CGFloat { (edge.maxX - edge.minX) / CGFloat(depths.count) }

    func center(of index: Int) -> CGFloat {
        edge.minX + (CGFloat(index) + 0.5) * spacing
    }

    func depth(at x: CGFloat) -> CGFloat {
        let column = min(CGFloat(depths.count - 1), max(0, (x - edge.minX) / spacing - 0.5))
        let left = Int(column)
        let fraction = column - CGFloat(left)
        return depths[left] * (1 - fraction) + depths[min(left + 1, depths.count - 1)] * fraction
    }

    mutating func deposit(_ mass: CGFloat, at x: CGFloat) {
        let index = min(depths.count - 1, max(0, Int((x - edge.minX) / spacing)))
        depths[index] += mass / spacing
    }

    mutating func move(to edge: DesktopEdge) {
        let width = edge.maxX - edge.minX
        if abs(width - (self.edge.maxX - self.edge.minX)) < 0.01 {
            self.edge = edge
            return
        }
        var resized = SnowBank(edge: edge)
        // Keep snow attached to the same relative position on the ledge when it resizes.
        for index in depths.indices where depths[index] > 0 {
            let position = (CGFloat(index) + 0.5) / CGFloat(depths.count)
            resized.deposit(depths[index] * spacing, at: edge.minX + width * position)
        }
        self = resized
    }

    mutating func settle(dt: CGFloat, wind: CGFloat, maximum: CGFloat) -> (left: CGFloat, right: CGFloat) {
        let old = depths
        let slope = spacing * 0.46
        let rate = min(0.22, dt * 6)
        for index in 1..<old.count {
            let difference = old[index - 1] - old[index] + wind * slope * 0.52
            let excess = abs(difference) - slope
            guard excess > 0 else { continue }
            let source = difference > 0 ? index - 1 : index
            let destination = difference > 0 ? index : index - 1
            let amount = min(old[source], excess) * rate
            depths[source] -= amount
            depths[destination] += amount
        }

        // Pressure from a full column feeds its neighbors before snow leaves the ledge.
        for index in old.indices where old[index] > maximum {
            let amount = (old[index] - maximum) * rate
            if index > 0, old[index - 1] < old[index] {
                let transfer = min(amount * (0.5 - wind * 0.24), (old[index] - old[index - 1]) * rate)
                depths[index] -= transfer
                depths[index - 1] += transfer
            }
            if index + 1 < old.count, old[index + 1] < old[index] {
                let transfer = min(amount * (0.5 + wind * 0.24), (old[index] - old[index + 1]) * rate)
                depths[index] -= transfer
                depths[index + 1] += transfer
            }
        }
        let last = old.count - 1
        let lip = min(maximum * 0.46, spacing * 0.76)
        let left = max(0, old[0] - lip * (1 + wind * 0.40)) * rate
        let right = max(0, old[last] - lip * (1 - wind * 0.40)) * rate
        depths[0] -= left
        depths[last] -= right
        return (left * spacing, right * spacing)
    }

    mutating func sweep(from: CGPoint, to: CGPoint, capacity: CGFloat = .infinity) -> (x: CGFloat, height: CGFloat, mass: CGFloat)? {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = hypot(dx, dy)
        guard distance >= 1 else { return nil }
        let radius: CGFloat = 21
        guard max(from.y, to.y) + radius >= edge.y,
              min(from.x, to.x) - radius <= edge.maxX,
              max(from.x, to.x) + radius >= edge.minX else { return nil }

        let start = max(0, Int((min(from.x, to.x) - radius - edge.minX) / spacing))
        let end = min(depths.count - 1, Int((max(from.x, to.x) + radius - edge.minX) / spacing))
        guard start <= end else { return nil }
        var mass: CGFloat = 0
        var lastHeight: CGFloat = edge.y
        var lastX: CGFloat = dx < 0 ? edge.maxX : edge.minX
        for index in start...end where depths[index] > 0 {
            let x = center(of: index)
            let y = edge.y + depths[index]
            let t = min(1, max(0, ((x - from.x) * dx + (y - from.y) * dy) / (distance * distance)))
            let separation = hypot(x - from.x - t * dx, y - from.y - t * dy)
            guard separation < radius else { continue }
            let available = depths[index] * (1 - separation / radius) * min(0.6, distance / 21) * spacing
            let taken = min(available, capacity - mass)
            guard taken > 0 else { break }
            let amount = taken / spacing
            depths[index] -= amount
            mass += taken
            lastX = dx < 0 ? min(lastX, x) : max(lastX, x)
            lastHeight = max(lastHeight, y)
        }
        guard mass > 0 else { return nil }
        let shift = min(radius * 2, max(spacing, abs(dx) + radius * 0.65))
        if abs(dx) < 1 { return (lastX, lastHeight, mass) }
        return (lastX + (dx < 0 ? -shift : shift), lastHeight, mass)
    }

    func impact(from start: CGPoint, to end: CGPoint) -> CGFloat? {
        guard start.y >= edge.y, end.y < start.y else { return nil }
        let dx = end.x - start.x
        let dy = end.y - start.y
        var entry: CGFloat = 0
        var exit: CGFloat = 1
        if dx != 0 {
            let left = (edge.minX - start.x) / dx
            let right = (edge.maxX - start.x) / dx
            entry = max(0, min(left, right))
            exit = min(1, max(left, right))
        } else if !(edge.minX...edge.maxX).contains(start.x) {
            return nil
        }
        guard entry <= exit else { return nil }
        func clearance(at t: CGFloat) -> CGFloat {
            start.y + dy * t - edge.y - depth(at: start.x + dx * t)
        }
        let before = clearance(at: entry)
        let after = clearance(at: exit)
        guard start.y + dy * entry >= edge.y else { return nil }
        if before <= 0 { return entry }
        guard after <= 0 else { return nil }
        return entry + (exit - entry) * before / (before - after)
    }
}

struct SnowSimulation {
    struct Flake {
        var position: CGPoint
        var velocity: CGVector
        let radius: CGFloat
        let phase: CGFloat
        var mass: CGFloat = 0
    }

    private(set) var banks: [SnowBank] = []
    private(set) var flakes: [Flake] = []
    private(set) var clumps: [Flake] = []
    private var spill: [Int: CGVector] = [:]
    private var previousPointer: CGPoint?
    private var time: CGFloat = 0

    mutating func sync(width: CGFloat, ground: Bool, ledges: [DesktopEdge]) {
        var surfaces = ledges
        if ground {
            surfaces.append(DesktopEdge(minX: 0, maxX: width, y: 0, id: -1))
        }
        guard banks.count != surfaces.count || zip(banks, surfaces).contains(where: { $0.edge != $1 }) else { return }
        var remaining = Dictionary(uniqueKeysWithValues: banks.map { ($0.edge.id, $0) })
        banks = surfaces.map { edge in
            var bank = remaining.removeValue(forKey: edge.id) ?? SnowBank(edge: edge)
            bank.move(to: edge)
            return bank
        }
        for id in remaining.keys { spill.removeValue(forKey: id) }
    }

    mutating func updateCraft(_ craft: inout SnowCraft, size: CGSize,
                              pointer: CGPoint?, pressed: Bool) -> CGPoint? {
        craft.update(size: size, pointer: pointer, pressed: pressed, banks: &banks)
    }

    mutating func resetPointer() { previousPointer = nil }

    mutating func advance(dt: CGFloat, size: CGSize, count: Int, heavy: Bool, deeper: Bool,
                          wind: CGFloat, pointer: CGPoint?) {
        guard size.width > 0, size.height > 0 else { return }
        time += dt
        if let from = previousPointer, let pointer, hypot(pointer.x - from.x, pointer.y - from.y) < 340 {
            for index in banks.indices {
                guard let swept = banks[index].sweep(from: from, to: pointer) else { continue }
                let edge = banks[index].edge
                if !(edge.minX...edge.maxX).contains(swept.x), clumps.count < 160 {
                    emit(mass: swept.mass, x: swept.x < edge.minX ? edge.minX - 1 : edge.maxX + 1,
                         y: swept.height, speed: min(105, max(-105, (pointer.x - from.x) * 4)), rise: 15)
                } else if abs(pointer.x - from.x) < 1, clumps.count < 160 {
                    emit(mass: swept.mass, x: swept.x, y: swept.height + 1, speed: wind * 32, rise: 42)
                } else {
                    banks[index].deposit(swept.mass, at: swept.x)
                }
            }
        }
        previousPointer = pointer

        for index in banks.indices {
            let edge = banks[index].edge
            let cap: CGFloat = edge.id == -1 ? (deeper ? 30 : 17) : (deeper ? 22 : 12)
            let outflow = banks[index].settle(dt: dt, wind: wind, maximum: cap)
            if edge.id == -1 { continue }
            var pending = spill[edge.id] ?? .zero
            pending.dx += outflow.left
            pending.dy += outflow.right
            if pending.dx >= 2, clumps.count < 160 {
                emit(mass: pending.dx, x: edge.minX - 1, y: edge.y + 1, speed: -21 + wind * 10, rise: -5)
                pending.dx = 0
            }
            if pending.dy >= 2, clumps.count < 160 {
                emit(mass: pending.dy, x: edge.maxX + 1, y: edge.y + 1, speed: 21 + wind * 10, rise: -5)
                pending.dy = 0
            }
            spill[edge.id] = pending
        }

        if count < flakes.count { flakes.removeLast(flakes.count - count) }
        while flakes.count < count {
            flakes.append(newFlake(in: size, heavy: heavy, spread: true))
        }
        for index in flakes.indices {
            var flake = flakes[index]
            let targetX = wind * 83 + sin(time * 1.9 + flake.phase) * 23
            let terminal = (heavy ? 113.0 : 78.0) * (0.66 + flake.radius * 0.19)
            flake.velocity.dx += (targetX - flake.velocity.dx) * min(1, dt * 1.8)
            flake.velocity.dy = max(-terminal, flake.velocity.dy - 140 * dt)
            let next = moved(flake, dt: dt)
            if deposit(from: flake.position, to: next, mass: flake.radius * (heavy ? 2.6 : 2.1))
                || next.y < -9 || next.x < -120 || next.x > size.width + 120 {
                flake = newFlake(in: size, heavy: heavy, spread: false)
            } else {
                flake.position = next
            }
            flakes[index] = flake
        }

        for index in clumps.indices.reversed() {
            var clump = clumps[index]
            clump.velocity.dy -= 265 * dt
            clump.velocity.dx += (wind * 68 - clump.velocity.dx) * min(1, dt * 0.77)
            let next = moved(clump, dt: dt)
            if deposit(from: clump.position, to: next, mass: clump.mass)
                || next.y < -12 || next.x < -120 || next.x > size.width + 120 {
                clumps.swapAt(index, clumps.count - 1)
                clumps.removeLast()
            } else {
                clump.position = next
                clumps[index] = clump
            }
        }
    }

    @discardableResult
    mutating func deposit(from start: CGPoint, to end: CGPoint, mass: CGFloat) -> Bool {
        var hit: Int?
        var time: CGFloat = 2
        for index in banks.indices {
            if let impact = banks[index].impact(from: start, to: end), impact < time {
                hit = index
                time = impact
            }
        }
        guard let hit else { return false }
        banks[hit].deposit(mass, at: start.x + (end.x - start.x) * time)
        return true
    }

    private func moved(_ flake: Flake, dt: CGFloat) -> CGPoint {
        CGPoint(x: flake.position.x + flake.velocity.dx * dt, y: flake.position.y + flake.velocity.dy * dt)
    }

    private func newFlake(in size: CGSize, heavy: Bool, spread: Bool) -> Flake {
        let y = spread ? CGFloat.random(in: 0...size.height) : size.height + CGFloat.random(in: 4...70)
        return Flake(position: CGPoint(x: CGFloat.random(in: -52...(size.width + 52)), y: y),
                     velocity: CGVector(dx: 0, dy: heavy ? -70 : -48),
                     radius: CGFloat.random(in: 0.68...(heavy ? 2.75 : 2.35)), phase: CGFloat.random(in: 0...(.pi * 2)))
    }

    private mutating func emit(mass: CGFloat, x: CGFloat, y: CGFloat, speed: CGFloat, rise: CGFloat) {
        guard clumps.count < 160 else { return }
        clumps.append(Flake(position: CGPoint(x: x, y: y), velocity: CGVector(dx: speed, dy: rise),
                            radius: min(5, 0.8 + sqrt(mass) * 0.35), phase: 0, mass: mass))
    }
}
