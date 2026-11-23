import CoreGraphics

@main
struct SnowSimulationTests {
    private static let size = CGSize(width: 240, height: 220)

    static func main() {
        localizedImpactAndMovingLedge()
        sidewaysFlowFollowsWind()
        cursorSweepsOnlyWhileMoving()
        overflowReachesLowerLedge()
        draggingUsesBankSnowAndStacksThreeBalls()
        pickingUpMovesAnExistingBall()
        enteringAnotherDisplayDoesNotStartDrag()
        treeTrunkStaysOnFloor()
        cursorRollsSnowballAndPicksUpMoreSnow()
        rollingOffLedgeRespondsToImpactSpeed()
        print("Passed 10 snow, crafting, and decoration regression checks")
    }

    private static func localizedImpactAndMovingLedge() {
        var snow = SnowSimulation()
        let edge = DesktopEdge(minX: 40, maxX: 110, y: 120, id: 1)
        snow.sync(width: size.width, ground: true, ledges: [edge])
        precondition(snow.deposit(from: CGPoint(x: 61, y: 175), to: CGPoint(x: 61, y: -2), mass: 28))
        precondition(snow.banks[0].depths.filter { $0 > 0 }.count == 1)
        precondition(snow.banks[1].depths.allSatisfy { $0 == 0 })

        let moved = DesktopEdge(minX: 65, maxX: 135, y: 149, id: edge.id)
        snow.sync(width: size.width, ground: true, ledges: [moved])
        precondition(snow.banks[0].depth(at: 86) > 0 && snow.banks[0].depth(at: 61) == 0)
        snow.sync(width: size.width, ground: true, ledges: [])
        precondition(snow.banks.count == 1 && snow.banks[0].edge.y == 0)
    }

    private static func sidewaysFlowFollowsWind() {
        var rightWind = SnowBank(edge: DesktopEdge(minX: 0, maxX: 63, y: 20))
        rightWind.deposit(77, at: rightWind.center(of: 4))
        var leftWind = rightWind
        for _ in 0..<15 {
            _ = rightWind.settle(dt: 1.0 / 30, wind: 1, maximum: 12)
            _ = leftWind.settle(dt: 1.0 / 30, wind: -1, maximum: 12)
        }
        precondition(rightWind.depths[5] > rightWind.depths[3])
        precondition(leftWind.depths[3] > leftWind.depths[5])
        precondition(abs(rightWind.depths.reduce(0, +) * rightWind.spacing - 77) < 0.01)
    }

    private static func cursorSweepsOnlyWhileMoving() {
        var snow = SnowSimulation()
        snow.sync(width: size.width, ground: true, ledges: [])
        precondition(snow.deposit(from: CGPoint(x: 82, y: 20), to: CGPoint(x: 82, y: -1), mass: 12))
        let original = snow.banks[0].depths
        let start = CGPoint(x: 73, y: 2)
        step(&snow, pointer: start)
        step(&snow, pointer: start)
        precondition(snow.banks[0].depths == original)
        step(&snow, pointer: CGPoint(x: 96, y: 2))
        precondition(snow.banks[0].depth(at: 82) < 1 && snow.banks[0].depth(at: 116) > 0)
    }

    private static func overflowReachesLowerLedge() {
        var snow = SnowSimulation()
        let upper = DesktopEdge(minX: 40, maxX: 110, y: 140, id: 1)
        let lower = DesktopEdge(minX: 15, maxX: 210, y: 75, id: 2)
        snow.sync(width: size.width, ground: true, ledges: [lower, upper])
        precondition(snow.deposit(from: CGPoint(x: 108, y: 200), to: CGPoint(x: 108, y: 20), mass: 140))
        var emitted = false
        for _ in 0..<150 {
            step(&snow, wind: 1)
            emitted = emitted || !snow.clumps.isEmpty
        }
        precondition(emitted && snow.banks[0].depths.reduce(0, +) > 0)
        precondition(snow.banks[2].depths.allSatisfy { $0 == 0 })
    }

    private static func draggingUsesBankSnowAndStacksThreeBalls() {
        var craft = SnowCraft()
        var banks = [makeCraftBank()]
        let originalMass = banks[0].depths.reduce(0, +)
        let start = CGPoint(x: 26, y: 9)
        _ = craft.update(size: size, pointer: start, pressed: false, banks: &banks)
        _ = craft.update(size: size, pointer: start, pressed: true, banks: &banks)
        _ = craft.update(size: size, pointer: start, pressed: false, banks: &banks)
        precondition(craft.visibleBalls.isEmpty && banks[0].depths.reduce(0, +) == originalMass)

        for count in 1...3 {
            let drop = CGPoint(x: 178, y: CGFloat(16 + (count - 1) * 15))
            let snowman = roll(&craft, bank: &banks, to: drop)
            if count < 3 {
                precondition(snowman == nil && craft.visibleBalls.count == count)
                precondition(craft.visibleBalls.last!.center.x == drop.x)
            } else {
                precondition(snowman == CGPoint(x: 178, y: 0) && craft.visibleBalls.isEmpty)
            }
        }
        precondition(banks[0].depths.reduce(0, +) < originalMass)
    }

    private static func pickingUpMovesAnExistingBall() {
        var craft = SnowCraft()
        var banks = [makeCraftBank()]
        _ = roll(&craft, bank: &banks, to: CGPoint(x: 172, y: 13))
        let center = craft.visibleBalls[0].center
        let newPosition = CGPoint(x: 208, y: 18)
        let bankBefore = banks[0].depths
        _ = craft.update(size: size, pointer: center, pressed: true, banks: &banks)
        _ = craft.update(size: size, pointer: newPosition, pressed: true, banks: &banks)
        _ = craft.update(size: size, pointer: newPosition, pressed: false, banks: &banks)
        precondition(craft.visibleBalls.count == 1 && craft.visibleBalls[0].center.x == newPosition.x)
        precondition(banks[0].depths == bankBefore)
    }

    private static func enteringAnotherDisplayDoesNotStartDrag() {
        var craft = SnowCraft()
        var banks = [makeCraftBank()]
        let original = banks[0].depths
        _ = craft.update(size: size, pointer: nil, pressed: false, banks: &banks)
        _ = craft.update(size: size, pointer: nil, pressed: true, banks: &banks)
        _ = craft.update(size: size, pointer: CGPoint(x: 20, y: 9), pressed: true, banks: &banks)
        _ = craft.update(size: size, pointer: CGPoint(x: 112, y: 9), pressed: true, banks: &banks)
        _ = craft.update(size: size, pointer: CGPoint(x: 130, y: 9), pressed: false, banks: &banks)
        precondition(craft.visibleBalls.isEmpty && banks[0].depths == original)
    }

    private static func makeCraftBank() -> SnowBank {
        var bank = SnowBank(edge: DesktopEdge(minX: 0, maxX: size.width, y: 0, id: -1))
        for index in bank.depths.indices where bank.center(of: index) < 120 {
            bank.deposit(bank.spacing * 11, at: bank.center(of: index))
        }
        return bank
    }

    private static func roll(_ craft: inout SnowCraft, bank: inout [SnowBank], to drop: CGPoint) -> CGPoint? {
        let start = CGPoint(x: 26, y: 9)
        _ = craft.update(size: size, pointer: start, pressed: false, banks: &bank)
        _ = craft.update(size: size, pointer: start, pressed: true, banks: &bank)
        _ = craft.update(size: size, pointer: CGPoint(x: 108, y: 9), pressed: true, banks: &bank)
        _ = craft.update(size: size, pointer: drop, pressed: true, banks: &bank)
        return craft.update(size: size, pointer: drop, pressed: false, banks: &bank)
    }

    private static func cursorRollsSnowballAndPicksUpMoreSnow() {
        var craft = SnowCraft()
        var banks = [makeCraftBank()]
        _ = roll(&craft, bank: &banks, to: CGPoint(x: 153, y: 13))
        let original = craft.visibleBalls[0]
        for index in banks[0].depths.indices where banks[0].center(of: index) >= 160 {
            banks[0].deposit(banks[0].spacing * 25, at: banks[0].center(of: index))
        }
        _ = craft.update(size: size, pointer: CGPoint(x: 110, y: original.center.y), pressed: false, banks: &banks)
        _ = craft.update(size: size, pointer: CGPoint(x: 193, y: original.center.y), pressed: false, banks: &banks)
        let atContact = craft.visibleBalls[0].center.x
        for _ in 0..<10 {
            _ = craft.update(size: size, pointer: nil, pressed: false, banks: &banks)
        }
        let moved = craft.visibleBalls[0]
        precondition(moved.center.x > atContact && moved.center.x > original.center.x)
        precondition(moved.rotation < 0 && moved.radius > original.radius)
    }

    private static func rollingOffLedgeRespondsToImpactSpeed() {
        for height: CGFloat in [20, 70, 175] {
            var craft = SnowCraft()
            var upper = SnowBank(edge: DesktopEdge(minX: 25, maxX: 142, y: height, id: 1))
            for index in upper.depths.indices where upper.center(of: index) < 100 {
                upper.deposit(upper.spacing * 16, at: upper.center(of: index))
            }
            var banks = [upper]
            let start = CGPoint(x: 33, y: height + 9)
            let drop = CGPoint(x: 121, y: height + 11)
            _ = craft.update(size: size, pointer: start, pressed: false, banks: &banks)
            _ = craft.update(size: size, pointer: start, pressed: true, banks: &banks)
            _ = craft.update(size: size, pointer: drop, pressed: true, banks: &banks)
            _ = craft.update(size: size, pointer: drop, pressed: false, banks: &banks)
            let original = craft.visibleBalls[0]
            _ = craft.update(size: size, pointer: CGPoint(x: 74, y: original.center.y), pressed: false, banks: &banks)
            _ = craft.update(size: size, pointer: CGPoint(x: 174, y: original.center.y), pressed: false, banks: &banks)

            var fell = false
            var bounced = false
            var hitFloor = false
            var emitted: [SnowCraft.Impact] = []
            for _ in 0..<110 {
                _ = craft.update(size: size, pointer: nil, pressed: false, banks: &banks)
                emitted.append(contentsOf: craft.impacts)
                if let ball = craft.visibleBalls.first {
                    let bottom = ball.center.y - ball.radius * (1 - ball.compression)
                    fell = fell || (bottom > 0.01 && bottom < height - 0.01)
                    bounced = bounced || (hitFloor && bottom > 0.01)
                    hitFloor = hitFloor || abs(bottom) < 0.01
                }
            }
            precondition(fell)
            switch height {
            case 20:
                precondition(bounced && hitFloor && emitted.isEmpty && craft.visibleBalls[0].compression == 0)
            case 70:
                precondition(hitFloor && emitted.count == 1 && craft.visibleBalls[0].compression > 0)
                precondition(craft.visibleBalls[0].radius < original.radius)
            default:
                precondition(emitted.count == 1 && emitted[0].speed >= 390 && craft.visibleBalls.isEmpty)
            }
        }
    }

    private static func treeTrunkStaysOnFloor() {
        let display = CGRect(origin: .zero, size: size)
        for floor: CGFloat in [0, 48] {
            for angle: CGFloat in [0, 15, -30, 345, 150] {
                let saved = DecorationLayout(x: 0.8, y: 0.63, angle: angle)
                let tree = saved.groundedTree(in: display, floor: floor)
                let trunk = DecorationLayout.treeTrunk.applying(CGAffineTransform(rotationAngle: tree.radians))
                precondition(abs(tree.origin.y + trunk.minY - floor) < 0.001)
                precondition(abs(tree.origin.x - display.width * saved.x) < 0.001)
            }
        }
    }

    private static func step(_ snow: inout SnowSimulation, wind: CGFloat = 0, pointer: CGPoint? = nil) {
        snow.advance(dt: 1.0 / 30, size: size, count: 0, heavy: false, deeper: false,
                     wind: wind, pointer: pointer)
    }
}
