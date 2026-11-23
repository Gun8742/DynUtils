import CoreGraphics

@main
struct SnowSimulationTests {
    private static let size = CGSize(width: 240, height: 220)

    static func main() {
        localizedImpactAndMovingLedge()
        sidewaysFlowFollowsWind()
        cursorSweepsOnlyWhileMoving()
        overflowReachesLowerLedge()
        print("Passed 4 snow physics regression checks")
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

    private static func step(_ snow: inout SnowSimulation, wind: CGFloat = 0, pointer: CGPoint? = nil) {
        snow.advance(dt: 1.0 / 30, size: size, count: 0, heavy: false, deeper: false,
                     wind: wind, pointer: pointer)
    }
}
