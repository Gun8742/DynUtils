import CoreGraphics
import Foundation

struct SnowBank {
    var edge: DesktopEdge
    private(set) var depths: [CGFloat]
    private var motion = WindowMotion()

    private struct WindowMotion {
        var sampledAt: TimeInterval?
        var windowBottom: CGFloat?
        var velocity = CGVector.zero
        var slide: CGFloat = 0
        var lift: CGFloat = 0
    }

    struct Shedding {
        let x: CGFloat
        let y: CGFloat
        let mass: CGFloat
        let velocity: CGVector
    }

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

    mutating func melt(_ amount: CGFloat, near x: CGFloat? = nil) {
        if let x {
            let index = min(depths.count - 1, max(0, Int((x - edge.minX) / spacing)))
            for column in max(0, index - 1)...min(depths.count - 1, index + 1) {
                let loss = column == index ? amount : amount * 0.42
                depths[column] = max(0, depths[column] - loss)
            }
        } else {
            for index in depths.indices where depths[index] > 0 {
                depths[index] = max(0, depths[index] - amount)
            }
        }
    }

    mutating func move(to edge: DesktopEdge, sampledAt: TimeInterval? = nil, windowBottom: CGFloat? = nil) {
        if let sampledAt, edge.id != -1, !edge.isDock {
            observeMotion(to: edge, sampledAt: sampledAt, windowBottom: windowBottom)
        }
        let width = edge.maxX - edge.minX
        if abs(width - (self.edge.maxX - self.edge.minX)) < 0.01 {
            self.edge = edge
            return
        }
        var resized = SnowBank(edge: edge)
        var prefix: [CGFloat] = [0]
        for depth in depths {
            prefix.append(prefix[prefix.count - 1] + depth * spacing)
        }
        // Integrate over each new bin so resizing cannot concentrate a whole old bin in one column.
        var previousMass: CGFloat = 0
        for index in resized.depths.indices {
            let boundary = CGFloat(index + 1) * CGFloat(depths.count) / CGFloat(resized.depths.count)
            let oldBin = min(depths.count - 1, Int(boundary))
            let total = prefix[oldBin] + (boundary - CGFloat(oldBin)) * depths[oldBin] * spacing
            resized.depths[index] = max(0, (total - previousMass) / resized.spacing)
            previousMass = total
        }
        resized.motion = motion
        self = resized
    }

    mutating func resetMotion() { motion = WindowMotion() }

    private mutating func observeMotion(to next: DesktopEdge, sampledAt: TimeInterval, windowBottom: CGFloat?) {
        let previous = motion.sampledAt
        if let previous, sampledAt <= previous { return }
        let previousBottom = motion.windowBottom
        motion.sampledAt = sampledAt
        motion.windowBottom = windowBottom
        guard let previous else { return }
        let interval = sampledAt - previous
        let left = next.minX - edge.minX
        let right = next.maxX - edge.maxX
        let vertical = next.y - edge.y
        guard interval < 0.25, max(abs(left), abs(right), abs(vertical)) < 280 else {
            motion = WindowMotion(sampledAt: sampledAt, windowBottom: windowBottom)
            return
        }

        // Opposing or stationary edges are resizing. Only the shared displacement translates the bank.
        func sharedDisplacement(_ first: CGFloat, _ second: CGFloat) -> CGFloat {
            first * second > 0 ? (first < 0 ? -1 : 1) * min(abs(first), abs(second)) : 0
        }
        let horizontal = sharedDisplacement(left, right)
        let bottomDelta = (windowBottom ?? 0) - (previousBottom ?? 0)
        let rise = windowBottom != nil && previousBottom != nil ? sharedDisplacement(vertical, bottomDelta) : vertical
        let velocity = CGVector(dx: horizontal / interval, dy: rise / interval)
        let impulse = motion.velocity.dx - velocity.dx
        let grip = max(42, 390 * interval)
        let excess = max(0, abs(impulse) - grip)
        motion.slide = min(800, max(-800, motion.slide + (impulse < 0 ? -1 : 1) * excess * 0.72))
        let downwardsChange = motion.velocity.dy - velocity.dy
        motion.lift = max(motion.lift, min(0.46, max(0, (downwardsChange - 180) * 0.00062)))
        motion.velocity = velocity
    }

    mutating func advanceInertia(dt: CGFloat) -> [Shedding] {
        let shift = motion.slide * dt / spacing
        guard abs(shift) > 0.001 || motion.lift > 0 else { return [] }
        var output: [Shedding] = []

        if motion.lift > 0 {
            for section in 0..<3 {
                let start = section * depths.count / 3
                let end = (section + 1) * depths.count / 3
                var amount: CGFloat = 0
                var centroid: CGFloat = 0
                var height: CGFloat = 0
                for index in start..<end {
                    let taken = depths[index] * motion.lift
                    height = max(height, depths[index])
                    depths[index] -= taken
                    amount += taken
                    centroid += center(of: index) * taken
                }
                if amount > 0 {
                    output.append(Shedding(x: centroid / amount, y: edge.y + height + 4,
                                           mass: amount * spacing,
                                           velocity: CGVector(dx: motion.velocity.dx * 0.5 + CGFloat(section - 1) * 42, dy: 6)))
                }
            }
            motion.lift = 0
        }

        if abs(shift) > 0.001 {
            let whole = Int(floor(shift))
            let fraction = shift - CGFloat(whole)
            let old = depths
            depths = Array(repeating: 0, count: old.count)
            var overflow: CGFloat = 0
            for index in old.indices where old[index] > 0 {
                let target = index + whole
                let left = old[index] * (1 - fraction)
                let right = old[index] * fraction
                if depths.indices.contains(target) { depths[target] += left }
                else { overflow += left }
                if depths.indices.contains(target + 1) { depths[target + 1] += right }
                else { overflow += right }
            }
            if overflow > 0 {
                output.append(Shedding(x: shift < 0 ? edge.minX - 6 : edge.maxX + 6, y: edge.y - 0.5,
                                       mass: overflow * spacing,
                                       velocity: CGVector(dx: motion.velocity.dx + motion.slide, dy: min(0, motion.velocity.dy))))
            }
        }
        motion.slide *= exp(-4.3 * dt)
        if abs(motion.slide) < 3 { motion.slide = 0 }
        return output
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

    mutating func enforceLimit(_ maximum: CGFloat, wind: CGFloat) -> CGVector {
        var overflow = CGVector.zero
        for index in depths.indices where depths[index] > maximum {
            var remaining = depths[index] - maximum
            depths[index] = maximum
            let direction = wind == 0 ? (index < depths.count / 2 ? -1 : 1) : (wind > 0 ? 1 : -1)
            for offset in [direction, -direction, 2 * direction, -2 * direction] {
                let neighbor = index + offset
                guard depths.indices.contains(neighbor), remaining > 0 else { continue }
                let shifted = min(remaining, max(0, maximum - depths[neighbor]))
                depths[neighbor] += shifted
                remaining -= shifted
            }
            if direction < 0 { overflow.dx += remaining * spacing }
            else { overflow.dy += remaining * spacing }
        }
        return overflow
    }

    mutating func sweep(from: CGPoint, to: CGPoint, capacity: CGFloat = .infinity, radius: CGFloat = 21) -> (x: CGFloat, height: CGFloat, mass: CGFloat)? {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = hypot(dx, dy)
        guard distance >= 0.08 else { return nil }
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
    struct WallContact {
        let windowID: Int
        let leftSide: Bool

        func x(in bounds: CGRect, radius: CGFloat) -> CGFloat {
            leftSide ? bounds.minX - radius : bounds.maxX + radius
        }
    }

    struct Flake {
        var position: CGPoint
        var velocity: CGVector
        let radius: CGFloat
        let phase: CGFloat
        var mass: CGFloat = 0
        var wall: WallContact?
    }

    private(set) var banks: [SnowBank] = []
    private(set) var flakes: [Flake] = []
    private(set) var clumps: [Flake] = []
    private var spill: [Int: CGVector] = [:]
    private var detached: [Int: (bank: SnowBank, expires: CGFloat)] = [:]
    private var coveredLedges: [Int: [ClosedRange<CGFloat>]] = [:]
    private var walls: [DesktopSnowWall] = []
    private var previousPointer: CGPoint?
    private var time: CGFloat = 0

    mutating func sync(width: CGFloat, ground: Bool, ledges: [DesktopEdge],
                       coveredLedges: [Int: [ClosedRange<CGFloat>]] = [:], walls: [DesktopSnowWall] = [],
                       sampledAt: TimeInterval? = nil) {
        self.coveredLedges = coveredLedges
        self.walls = walls
        for id in detached.keys.filter({ (detached[$0]?.expires ?? 0) <= time }) {
            detached.removeValue(forKey: id)
            spill.removeValue(forKey: id)
        }
        let bottoms = sampledAt == nil ? [:] : Dictionary(uniqueKeysWithValues: walls.map { ($0.windowID, $0.bounds.minY) })
        var surfaces = ledges
        if ground {
            surfaces.append(DesktopEdge(minX: 0, maxX: width, y: 0, id: -1))
        }
        if banks.count == surfaces.count, !zip(banks, surfaces).contains(where: { $0.edge != $1 }) {
            if let sampledAt {
                for index in banks.indices { banks[index].move(to: surfaces[index], sampledAt: sampledAt, windowBottom: bottoms[surfaces[index].id]) }
            }
            return
        }
        var remaining = Dictionary(uniqueKeysWithValues: banks.map { ($0.edge.id, $0) })
        banks = surfaces.map { edge in
            var bank = remaining.removeValue(forKey: edge.id)
                ?? detached.removeValue(forKey: edge.id)?.bank ?? SnowBank(edge: edge)
            bank.move(to: edge, sampledAt: sampledAt, windowBottom: bottoms[edge.id])
            return bank
        }
        for (id, var bank) in remaining where id != -1 {
            bank.resetMotion()
            detached[id] = (bank, time + 0.75)
        }
    }

    var hasDeposits: Bool {
        banks.contains { $0.depths.contains(where: { $0 > 0 }) } || !detached.isEmpty
    }

    mutating func melt(_ amount: CGFloat) {
        for index in banks.indices { banks[index].melt(amount) }
        for id in Array(detached.keys) { detached[id]?.bank.melt(amount) }
    }

    mutating func melt(_ amount: CGFloat, at x: CGFloat, on edgeID: Int) {
        if let index = banks.firstIndex(where: { $0.edge.id == edgeID }) {
            banks[index].melt(amount, near: x)
        }
    }

    func depth(at x: CGFloat, on edgeID: Int) -> CGFloat {
        banks.first { $0.edge.id == edgeID }?.depth(at: x) ?? 0
    }

    mutating func clearAirborne() {
        flakes.removeAll(keepingCapacity: true)
    }

    mutating func updateCraft(_ craft: inout SnowCraft, size: CGSize,
                              pointer: CGPoint?, pressed: Bool, dt: CGFloat) -> SnowCraft.CompletedSnowman? {
        let snowman = craft.update(size: size, pointer: pointer, pressed: pressed, dt: dt, banks: &banks)
        for hit in craft.impacts { scatter(hit) }
        return snowman
    }

    mutating func scatter(_ hit: SnowCraft.Impact) {
        let amount = min(hit.speed >= 390 ? 18 : 8, 160 - clumps.count)
        guard amount > 0 else {
            if let bank = banks.firstIndex(where: { $0.edge.id == hit.surface }) {
                banks[bank].deposit(hit.mass, at: hit.point.x)
            }
            return
        }
        let scatter = min(180, hit.speed * 0.27)
        let mass = hit.mass / CGFloat(amount)
        for index in 0..<amount {
            let spread = CGFloat(index) / CGFloat(max(1, amount - 1)) * 2 - 1
            let speed = spread * scatter + hit.sideways * 0.28
            let rise = 24 + scatter * (0.18 + CGFloat(index % 4) * 0.21)
            emit(mass: mass, x: hit.point.x, y: hit.point.y + 1.6, speed: speed, rise: rise)
        }
    }

    mutating func resetPointer() {
        previousPointer = nil
        for index in banks.indices { banks[index].resetMotion() }
    }

    mutating func advance(dt: CGFloat, size: CGSize, count: Int, heavy: Bool, limits: SnowDepthLimits,
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
            for shedding in banks[index].advanceInertia(dt: dt) {
                let available = min(5, 160 - clumps.count)
                if available == 0 {
                    banks[index].deposit(shedding.mass, at: shedding.x)
                    continue
                }
                let count = min(available, max(1, Int(ceil(shedding.mass / 14))))
                for fragment in 0..<count {
                    let dispersion = CGFloat(fragment) - CGFloat(count - 1) / 2
                    emit(mass: shedding.mass / CGFloat(count), x: shedding.x, y: shedding.y + abs(dispersion) * 0.8,
                         speed: shedding.velocity.dx + dispersion * 14, rise: shedding.velocity.dy)
                }
            }
            let cap = CGFloat(edge.id == -1 ? limits.ground : limits.surfaces)
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
            if flake.wall == nil {
                flake.velocity.dx += (targetX - flake.velocity.dx) * min(1, dt * 1.8)
                flake.velocity.dy = max(-terminal, flake.velocity.dy - 140 * dt)
            }
            if moveFlake(&flake, dt: dt, mass: flake.radius * (heavy ? 2.6 : 2.1))
                || flake.position.y < -9 || flake.position.x < -120 || flake.position.x > size.width + 120 {
                flake = newFlake(in: size, heavy: heavy, spread: false)
            }
            flakes[index] = flake
        }

        for index in clumps.indices.reversed() {
            var clump = clumps[index]
            if clump.wall == nil {
                clump.velocity.dy -= 265 * dt
                clump.velocity.dx += (wind * 68 - clump.velocity.dx) * min(1, dt * 0.77)
            }
            if moveFlake(&clump, dt: dt, mass: clump.mass)
                || clump.position.y < -12 || clump.position.x < -120 || clump.position.x > size.width + 120 {
                clumps.swapAt(index, clumps.count - 1)
                clumps.removeLast()
            } else {
                clumps[index] = clump
            }
        }

        for index in banks.indices {
            let id = banks[index].edge.id
            let cap = CGFloat(id == -1 ? limits.ground : limits.surfaces)
            let excess = banks[index].enforceLimit(cap, wind: wind)
            if id != -1, excess != .zero {
                spill[id, default: .zero].dx += excess.dx
                spill[id, default: .zero].dy += excess.dy
            }
        }
    }

    private func firstBankImpact(from start: CGPoint, to end: CGPoint) -> (index: Int, fraction: CGFloat)? {
        var hit: Int?
        var time: CGFloat = 2
        for index in banks.indices {
            guard let impact = banks[index].impact(from: start, to: end), impact < time else { continue }
            let x = start.x + (end.x - start.x) * impact
            if coveredLedges[banks[index].edge.id]?.contains(where: { $0.contains(x) }) == true { continue }
            hit = index
            time = impact
        }
        return hit.map { ($0, time) }
    }

    func snowImpact(from start: CGPoint, to end: CGPoint) -> (edge: DesktopEdge, fraction: CGFloat)? {
        guard let hit = firstBankImpact(from: start, to: end) else { return nil }
        let x = start.x + (end.x - start.x) * hit.fraction
        // Empty columns are handled by the common window/desktop collision.
        guard banks[hit.index].depth(at: x) > 0 else { return nil }
        return (banks[hit.index].edge, hit.fraction)
    }

    @discardableResult
    mutating func deposit(from start: CGPoint, to end: CGPoint, mass: CGFloat) -> Bool {
        guard let hit = firstBankImpact(from: start, to: end) else { return false }
        banks[hit.index].deposit(mass, at: start.x + (end.x - start.x) * hit.fraction)
        return true
    }

    mutating func moveFlake(_ flake: inout Flake, dt: CGFloat, mass: CGFloat) -> Bool {
        var start = flake.position
        if let contact = flake.wall {
            flake.wall = nil
            if let wall = walls.first(where: { $0.windowID == contact.windowID }) {
                let side = contact.x(in: wall.bounds, radius: flake.radius)
                let point = CGPoint(x: side, y: start.y)
                if (wall.bounds.minY...wall.bounds.maxY).contains(start.y), !wall.covered(at: point) {
                    start = point
                    flake.velocity.dy = -43 + (flake.velocity.dy + 43) * exp(-7 * dt)
                    let end = CGPoint(x: side, y: start.y + flake.velocity.dy * dt)
                    if end.y >= wall.bounds.minY, !wall.covered(at: end) {
                        flake.wall = contact
                    }
                    flake.position = end
                    return deposit(from: start, to: end, mass: mass)
                }
            }
        }

        let end = CGPoint(x: start.x + flake.velocity.dx * dt, y: start.y + flake.velocity.dy * dt)
        if let collision = firstWall(from: start, to: end, radius: flake.radius) {
            if deposit(from: start, to: collision.point, mass: mass) { return true }
            flake.wall = collision.contact
            flake.position = collision.point
            flake.velocity = CGVector(dx: 0, dy: -min(46, max(18, abs(flake.velocity.dy) * 0.46)))
            return false
        }

        flake.position = end
        return deposit(from: start, to: end, mass: mass)
    }

    private func firstWall(from start: CGPoint, to end: CGPoint, radius: CGFloat)
        -> (contact: WallContact, point: CGPoint)? {
        let dx = end.x - start.x
        guard dx != 0 else { return nil }
        var earliest: CGFloat = 2
        var impact: (contact: WallContact, point: CGPoint)?
        for wall in walls {
            let contact = WallContact(windowID: wall.windowID, leftSide: dx > 0)
            let x = contact.x(in: wall.bounds, radius: radius)
            let time = (x - start.x) / dx
            guard time >= 0, time <= 1, time < earliest else { continue }
            let y = start.y + (end.y - start.y) * time
            guard y > wall.bounds.minY, y < wall.bounds.maxY else { continue }
            let point = CGPoint(x: x, y: y)
            guard !wall.covered(at: point) else { continue }
            earliest = time
            impact = (contact, point)
        }
        return impact
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
