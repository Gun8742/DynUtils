import CoreGraphics
import Foundation

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
        flickThrowsSnowballAlongMouseMotion()
        stationaryReleaseDropsSnowball()
        enteringAnotherDisplayDoesNotStartDrag()
        treeTrunkStaysOnFloor()
        cursorRollsSnowballAndPicksUpMoreSnow()
        rollingOffLedgeRespondsToImpactSpeed()
        depthLimitsAreIndependentAndCanBeLowered()
        legacyDeepSnowMigratesToDepthControls()
        snowmanFollowsItsWindowAndLandsOnLowerLedge()
        snowmanCanToppleOrShatter()
        snowmanSizesSurviveSavingAndAffectPhysics()
        foregroundWindowsCoverOnlyTheirOverlaps()
        snowPersistsAcrossABriefWindowTransition()
        resizingPreservesSnowMass()
        snowSlidesDownWallAndAccumulatesBelow()
        wallCollisionsRespectVisibilityAndBothSides()
        fasterWindowMovementShedsMoreSnow()
        centerSnowLagsThenMovesForwardWhenWindowBrakes()
        suddenDownwardMotionLiftsSnow()
        rainMeltsExistingSnowWithoutClearingIt()
        foliageStaysOnItsSurfaceAndCanBeSwept()
        rainSplashesAndRunsOffToLowerSurfaces()
        batterySaverDefaultsOffAndPersists()
        print("Passed 29 weather, snow, crafting, and decoration regression checks")
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

        var radii: [CGFloat] = []
        for count in 1...3 {
            let drop = CGPoint(x: 178, y: CGFloat(16 + (count - 1) * 15))
            let (snowman, radius) = roll(&craft, bank: &banks, to: drop)
            radii.append(radius)
            if count < 3 {
                precondition(snowman == nil && craft.visibleBalls.count == count)
                precondition(craft.visibleBalls.last!.center.x == drop.x)
            } else {
                precondition(snowman?.origin == CGPoint(x: 178, y: 0) && craft.visibleBalls.isEmpty)
                precondition(snowman?.snowballs.parts.map { $0.width / 2 } == radii)
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

    private static func flickThrowsSnowballAlongMouseMotion() {
        for direction: CGFloat in [-1, 1] {
            var craft = SnowCraft()
            var banks = [makeCraftBank()]
            _ = roll(&craft, bank: &banks, to: CGPoint(x: 155, y: 13))
            let center = craft.visibleBalls[0].center
            _ = craft.update(size: size, pointer: center, pressed: true, banks: &banks)
            _ = craft.update(size: size, pointer: CGPoint(x: 150, y: 64), pressed: true, banks: &banks)
            let release = CGPoint(x: 150 + direction * 28, y: 83)
            _ = craft.update(size: size, pointer: release, pressed: true, banks: &banks)
            precondition(craft.update(size: size, pointer: release, pressed: false, banks: &banks) == nil)
            _ = craft.update(size: size, pointer: nil, pressed: false, banks: &banks)
            let airborne = craft.visibleBalls[0].center
            precondition(direction * (airborne.x - release.x) > 2)
            precondition(airborne.y > release.y)
        }
    }

    private static func stationaryReleaseDropsSnowball() {
        var craft = SnowCraft()
        var banks = [makeCraftBank()]
        _ = roll(&craft, bank: &banks, to: CGPoint(x: 155, y: 13))
        let center = craft.visibleBalls[0].center
        _ = craft.update(size: size, pointer: center, pressed: true, banks: &banks)
        _ = craft.update(size: size, pointer: CGPoint(x: 150, y: 64), pressed: true, banks: &banks)
        let release = CGPoint(x: 183, y: 85)
        _ = craft.update(size: size, pointer: release, pressed: true, banks: &banks)
        for _ in 0..<3 {
            _ = craft.update(size: size, pointer: release, pressed: true, banks: &banks)
        }
        _ = craft.update(size: size, pointer: release, pressed: false, banks: &banks)
        _ = craft.update(size: size, pointer: nil, pressed: false, banks: &banks)
        let dropped = craft.visibleBalls[0].center
        precondition(dropped.x == release.x && dropped.y < release.y)
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

    private static func roll(_ craft: inout SnowCraft, bank: inout [SnowBank], to drop: CGPoint) -> (SnowCraft.CompletedSnowman?, CGFloat) {
        let start = CGPoint(x: 26, y: 9)
        _ = craft.update(size: size, pointer: start, pressed: false, banks: &bank)
        _ = craft.update(size: size, pointer: start, pressed: true, banks: &bank)
        _ = craft.update(size: size, pointer: CGPoint(x: 108, y: 9), pressed: true, banks: &bank)
        _ = craft.update(size: size, pointer: drop, pressed: true, banks: &bank)
        let radius = craft.visibleBalls.last!.radius
        return (craft.update(size: size, pointer: drop, pressed: false, banks: &bank), radius)
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

    private static func depthLimitsAreIndependentAndCanBeLowered() {
        var snow = SnowSimulation()
        let ledge = DesktopEdge(minX: 60, maxX: 180, y: 65, id: 1)
        snow.sync(width: size.width, ground: true, ledges: [ledge])
        for x: CGFloat in [15, 90] {
            precondition(snow.deposit(from: CGPoint(x: x, y: 100), to: CGPoint(x: x, y: -1), mass: 900))
        }
        let limits = SnowDepthLimits(ground: 9, surfaces: 4)
        snow.advance(dt: 1.0 / 30, size: size, count: 0, heavy: false, limits: limits, wind: 1, pointer: nil)
        precondition(snow.banks[0].depths.max() == 4)
        precondition(snow.banks[1].depths.max() == 9)
        let lowered = SnowDepthLimits(ground: 3, surfaces: 4)
        snow.advance(dt: 1.0 / 30, size: size, count: 0, heavy: false, limits: lowered, wind: 1, pointer: nil)
        precondition(snow.banks[1].depths.max() == 3)
        precondition(snow.banks[0].depths.max() == 4)
        precondition(!snow.clumps.isEmpty)
    }

    private static func legacyDeepSnowMigratesToDepthControls() {
        let initial = Preferences()
        precondition(initial.groundSnowDepth == 17 && initial.surfaceSnowDepth == 12)
        let data = try! JSONEncoder().encode(initial)
        var old = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        old["deeperSnow"] = true
        var migrated = try! JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: old))
        precondition(migrated.groundSnowDepth == 30 && migrated.surfaceSnowDepth == 22)
        migrated.groundSnowDepth = 40
        migrated.surfaceSnowDepth = 100
        let saved = try! JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(migrated))
        precondition(saved.groundSnowDepth == 40 && saved.surfaceSnowDepth == 64)
    }

    private static func snowmanFollowsItsWindowAndLandsOnLowerLedge() {
        let upper = DesktopEdge(minX: 25, maxX: 180, y: 80, id: 1)
        let moved = DesktopEdge(minX: 45, maxX: 200, y: 85, id: 1)
        let lower = DesktopEdge(minX: 30, maxX: 220, y: 66, id: 2)
        var body = SnowmanPhysics(origin: CGPoint(x: 100, y: 80), angle: 0, surfaces: [upper, lower])
        precondition(body.advance(dt: 1.0 / 30, width: size.width, surfaces: [moved, lower], pointer: nil) == nil)
        precondition(abs(body.origin.x - 120) < 0.01 && body.origin.y == 85)
        let firstFall = body.advance(dt: 1.0 / 30, width: size.width, surfaces: [lower], pointer: nil)
        precondition(firstFall == nil && (66..<85).contains(body.origin.y))
        for _ in 0..<30 {
            precondition(body.advance(dt: 1.0 / 30, width: size.width, surfaces: [lower], pointer: nil) == nil)
        }
        precondition(body.origin.y == 66 && body.isResting)
    }

    private static func snowmanCanToppleOrShatter() {
        let floor = DesktopEdge(minX: 0, maxX: size.width, y: 0, id: -1)
        var body = SnowmanPhysics(origin: CGPoint(x: 115, y: 0), angle: 0, surfaces: [floor])
        _ = body.advance(dt: 1.0 / 30, width: size.width, surfaces: [floor], pointer: CGPoint(x: 55, y: 69))
        _ = body.advance(dt: 1.0 / 30, width: size.width, surfaces: [floor], pointer: CGPoint(x: 145, y: 69))
        precondition(body.angle < 0 && body.origin.x > 115)
        var toppled: SnowCraft.Impact?
        for _ in 0..<20 where toppled == nil {
            toppled = body.advance(dt: 1.0 / 30, width: size.width, surfaces: [floor], pointer: nil)
        }
        precondition(toppled?.surface == floor.id && toppled!.point.x > 115)

        let ledge = DesktopEdge(minX: 50, maxX: 180, y: 150, id: 1)
        var falling = SnowmanPhysics(origin: CGPoint(x: 115, y: 150), angle: 0, surfaces: [floor, ledge])
        var landed: SnowCraft.Impact?
        for _ in 0..<50 where landed == nil {
            landed = falling.advance(dt: 1.0 / 30, width: size.width, surfaces: [floor], pointer: nil)
        }
        precondition(landed?.surface == floor.id && landed?.point.y == 0)
    }

    private static func snowmanSizesSurviveSavingAndAffectPhysics() {
        let snowballs = SnowmanSnowballs(base: 2_500, torso: 900, head: 400)
        let layout = DecorationLayout(x: 0.4, y: 0, snowballs: snowballs)
        let encoded = try! JSONEncoder().encode(layout)
        let saved = try! JSONDecoder().decode(DecorationLayout.self, from: encoded)
        precondition(saved.snowballs == snowballs)
        let parts = saved.snowballs!.parts
        precondition(parts.map(\.width) == [81, 51, 36])
        precondition(parts[0].minY == 0 && parts[2].minY < parts[1].maxY)

        let old = Data(#"{"x":0.4,"y":0,"angle":0,"lights":true}"#.utf8)
        precondition(try! JSONDecoder().decode(DecorationLayout.self, from: old).snowballs == nil)

        let floor = DesktopEdge(minX: 0, maxX: size.width, y: 0, id: -1)
        var body = SnowmanPhysics(origin: CGPoint(x: 120, y: 160), angle: 0, surfaces: [floor], snowballs: snowballs)
        var impact: SnowCraft.Impact?
        for _ in 0..<35 where impact == nil {
            impact = body.advance(dt: 1.0 / 30, width: size.width, surfaces: [floor], pointer: nil)
        }
        precondition(impact?.mass == snowballs.totalMass)
    }

    private static func foregroundWindowsCoverOnlyTheirOverlaps() {
        let frame = CGRect(origin: .zero, size: size)
        let front = DesktopWindowSnapshot.Surface(id: 1, bounds: CGRect(x: 82, y: 35, width: 65, height: 135))
        let back = DesktopWindowSnapshot.Surface(id: 2, bounds: CGRect(x: -35, y: 24, width: 249, height: 91))
        let dock = DesktopWindowSnapshot.Surface(id: 3, bounds: CGRect(x: 20, y: 0, width: 190, height: 53), isDock: true)
        let menu = DesktopWindowSnapshot.Surface(id: 4, bounds: CGRect(x: 54, y: 57, width: 88, height: 75), isDock: true)
        let snapshot = DesktopWindowSnapshot(frame: frame, surfaces: [dock, menu, front, back])
        precondition(snapshot.edges.map(\.id) == [3, 1, 2])
        precondition(snapshot.edges[2].minX == -35 && snapshot.edges[2].maxX == 214)
        precondition(snapshot.coveredLedges[2] == [82...147] && snapshot.coveredLedges[1] == nil)
        precondition(snapshot.foreground[2] == [dock.bounds, front.bounds])

        var snow = SnowSimulation()
        snow.sync(width: size.width, ground: false, ledges: snapshot.edges, coveredLedges: snapshot.coveredLedges)
        precondition(!snow.deposit(from: CGPoint(x: 95, y: 155), to: CGPoint(x: 95, y: 70), mass: 24))
        precondition(snow.deposit(from: CGPoint(x: 180, y: 155), to: CGPoint(x: 180, y: 70), mass: 24))
        let reordered = DesktopWindowSnapshot(frame: frame, surfaces: [dock, back, front])
        snow.sync(width: size.width, ground: false, ledges: reordered.edges, coveredLedges: reordered.coveredLedges)
        precondition(snow.banks.first(where: { $0.edge.id == 2 })!.depth(at: 180) > 0)
        precondition(snow.deposit(from: CGPoint(x: 95, y: 155), to: CGPoint(x: 95, y: 70), mass: 24))
    }

    private static func snowPersistsAcrossABriefWindowTransition() {
        var snow = SnowSimulation()
        let edge = DesktopEdge(minX: 45, maxX: 185, y: 90, id: 1)
        snow.sync(width: size.width, ground: false, ledges: [edge])
        precondition(snow.deposit(from: CGPoint(x: 95, y: 150), to: CGPoint(x: 95, y: 65), mass: 24))
        snow.sync(width: size.width, ground: false, ledges: [])
        precondition(snow.banks.isEmpty)
        precondition(!snow.deposit(from: CGPoint(x: 95, y: 150), to: CGPoint(x: 95, y: 65), mass: 24))
        for _ in 0..<10 { step(&snow) }
        snow.sync(width: size.width, ground: false, ledges: [edge])
        precondition(snow.banks[0].depth(at: 95) > 0)

        snow.sync(width: size.width, ground: false, ledges: [])
        for _ in 0..<30 { step(&snow) }
        snow.sync(width: size.width, ground: false, ledges: [edge])
        precondition(snow.banks[0].depths.allSatisfy { $0 == 0 })
    }

    private static func resizingPreservesSnowMass() {
        var bank = SnowBank(edge: DesktopEdge(minX: 25, maxX: 81, y: 120, id: 1))
        bank.deposit(56, at: bank.center(of: 3))
        bank.move(to: DesktopEdge(minX: -20, maxX: 106, y: 120, id: 1))
        precondition(abs(bank.depths.reduce(0, +) * bank.spacing - 56) < 0.001)
        precondition(bank.depths.filter { $0 > 0 }.count > 1)
    }

    private static func snowSlidesDownWallAndAccumulatesBelow() {
        let frame = CGRect(origin: .zero, size: size)
        let topWindow = DesktopWindowSnapshot.Surface(id: 1, bounds: CGRect(x: 65, y: 44, width: 95, height: 96))
        let lowerWindow = DesktopWindowSnapshot.Surface(id: 2, bounds: CGRect(x: 20, y: 3, width: 120, height: 25))
        let snapshot = DesktopWindowSnapshot(frame: frame, surfaces: [topWindow, lowerWindow])
        var snow = SnowSimulation()
        snow.sync(width: size.width, ground: true, ledges: snapshot.edges,
                  coveredLedges: snapshot.coveredLedges, walls: snapshot.snowWalls)
        var flake = SnowSimulation.Flake(position: CGPoint(x: 42, y: 100), velocity: CGVector(dx: 75, dy: -65),
                                         radius: 2, phase: 0)
        precondition(!snow.moveFlake(&flake, dt: 0.35, mass: 32))
        precondition(flake.wall?.windowID == 1 && flake.wall?.leftSide == true)
        precondition(flake.position.x == 63 && flake.velocity.dx == 0 && abs(flake.velocity.dy) < 65)
        let impacted = flake.position
        precondition(!snow.moveFlake(&flake, dt: 1.0 / 30, mass: 32))
        precondition(flake.position.x == impacted.x && flake.position.y < impacted.y)

        let moved = DesktopWindowSnapshot.Surface(id: 1, bounds: topWindow.bounds.offsetBy(dx: 12, dy: 0))
        let updated = DesktopWindowSnapshot(frame: frame, surfaces: [moved, lowerWindow])
        snow.sync(width: size.width, ground: true, ledges: updated.edges,
                  coveredLedges: updated.coveredLedges, walls: updated.snowWalls)
        precondition(!snow.moveFlake(&flake, dt: 1.0 / 30, mass: 32))
        precondition(flake.position.x == 75)
        var landed = false
        for _ in 0..<80 where !landed {
            landed = snow.moveFlake(&flake, dt: 1.0 / 30, mass: 32)
        }
        precondition(landed)
        precondition(snow.banks[1].depth(at: 75) > 0 && snow.banks[0].depths.allSatisfy { $0 == 0 })
        precondition(snow.banks[2].depths.allSatisfy { $0 == 0 })
    }

    private static func wallCollisionsRespectVisibilityAndBothSides() {
        let frame = CGRect(origin: .zero, size: size)
        let foreground = DesktopWindowSnapshot.Surface(id: 1, bounds: CGRect(x: 42, y: 74, width: 44, height: 41))
        let background = DesktopWindowSnapshot.Surface(id: 2, bounds: CGRect(x: 66, y: 40, width: 80, height: 115))
        let snapshot = DesktopWindowSnapshot(frame: frame, surfaces: [foreground, background])
        var snow = SnowSimulation()
        snow.sync(width: size.width, ground: false, ledges: snapshot.edges, walls: snapshot.snowWalls)
        var hidden = SnowSimulation.Flake(position: CGPoint(x: 59, y: 94), velocity: CGVector(dx: 68, dy: -20),
                                          radius: 2, phase: 0)
        precondition(!snow.moveFlake(&hidden, dt: 0.2, mass: 5) && hidden.wall == nil)
        var fromRight = SnowSimulation.Flake(position: CGPoint(x: 154, y: 104), velocity: CGVector(dx: -68, dy: -20),
                                             radius: 2, phase: 0)
        precondition(!snow.moveFlake(&fromRight, dt: 0.2, mass: 5))
        precondition(fromRight.wall?.windowID == 2 && fromRight.wall?.leftSide == false && fromRight.position.x == 148)
        var fromAbove = SnowSimulation.Flake(position: CGPoint(x: 115, y: 166), velocity: CGVector(dx: 4, dy: -40),
                                             radius: 2, phase: 0)
        precondition(snow.moveFlake(&fromAbove, dt: 0.4, mass: 5) && fromAbove.wall == nil)
        precondition(snow.banks[1].depth(at: 116) > 0)
    }

    private static func fasterWindowMovementShedsMoreSnow() {
        let original = DesktopEdge(minX: 35, maxX: 175, y: 120, id: 1)
        var initial = SnowBank(edge: original)
        initial.deposit(35, at: original.minX + 7)
        initial.deposit(35, at: original.minX + 63)
        initial.move(to: original, sampledAt: 0)
        let dt = 1.0 / 30
        func moved(by offset: CGFloat) -> DesktopEdge {
            DesktopEdge(minX: original.minX + offset, maxX: original.maxX + offset, y: original.y, id: original.id)
        }
        var slow = initial
        var moderate = initial
        var fast = initial
        slow.move(to: moved(by: 2), sampledAt: dt)
        moderate.move(to: moved(by: 14), sampledAt: dt)
        fast.move(to: moved(by: 36), sampledAt: dt)
        let slowShed = slow.advanceInertia(dt: dt)
        let moderateShed = moderate.advanceInertia(dt: dt)
        let fastShed = fast.advanceInertia(dt: dt)
        precondition(slowShed.isEmpty && !moderateShed.isEmpty && !fastShed.isEmpty)
        precondition(fastShed[0].mass > moderateShed[0].mass && fastShed[0].x < fast.edge.minX)
        precondition(abs(fast.depths.reduce(0, +) * fast.spacing + fastShed[0].mass - 70) < 0.001)
    }

    private static func centerSnowLagsThenMovesForwardWhenWindowBrakes() {
        let edge = DesktopEdge(minX: 0, maxX: 320, y: 120, id: 1)
        let dt = 1.0 / 30
        var bank = SnowBank(edge: edge)
        bank.deposit(36, at: 170)
        bank.move(to: edge, sampledAt: 0)
        func relativeCenter(_ bank: SnowBank) -> CGFloat {
            let weighted = bank.depths.indices.reduce(CGFloat(0)) { result, index in
                result + (bank.center(of: index) - bank.edge.minX) * bank.depths[index]
            }
            return weighted / bank.depths.reduce(0, +)
        }
        let original = relativeCenter(bank)
        for frame in 1...8 {
            let displacement = CGFloat(frame) * 19
            let moved = DesktopEdge(minX: displacement, maxX: 320 + displacement, y: 120, id: 1)
            bank.move(to: moved, sampledAt: CGFloat(frame) * dt)
            precondition(bank.advanceInertia(dt: dt).isEmpty)
        }
        let lagged = relativeCenter(bank)
        precondition(lagged < original - 35)
        bank.move(to: bank.edge, sampledAt: 9 * dt)
        precondition(bank.advanceInertia(dt: dt).isEmpty)
        precondition(relativeCenter(bank) > lagged)
    }

    private static func suddenDownwardMotionLiftsSnow() {
        let high = DesktopEdge(minX: 30, maxX: 200, y: 142, id: 1)
        let low = DesktopEdge(minX: 30, maxX: 200, y: 110, id: 1)
        let firstWall = DesktopSnowWall(windowID: 1, bounds: CGRect(x: 30, y: 62, width: 170, height: 80), foreground: [])
        let movedWall = DesktopSnowWall(windowID: 1, bounds: CGRect(x: 30, y: 30, width: 170, height: 80), foreground: [])
        let resizedWall = DesktopSnowWall(windowID: 1, bounds: CGRect(x: 30, y: 62, width: 170, height: 48), foreground: [])
        let dt = 1.0 / 30
        var snow = SnowSimulation()
        snow.sync(width: size.width, ground: true, ledges: [high], walls: [firstWall], sampledAt: 0)
        precondition(snow.deposit(from: CGPoint(x: 115, y: 172), to: CGPoint(x: 115, y: 139), mass: 45))
        var resizing = snow
        resizing.sync(width: size.width, ground: true, ledges: [low], walls: [resizedWall], sampledAt: dt)
        step(&resizing)
        precondition(resizing.clumps.isEmpty)

        snow.sync(width: size.width, ground: true, ledges: [low], walls: [movedWall], sampledAt: dt)
        step(&snow)
        precondition(snow.clumps.contains { $0.position.y > low.y && $0.mass > 0 })
        precondition(snow.banks[1].depths.allSatisfy { $0 == 0 })
    }

    private static func rainMeltsExistingSnowWithoutClearingIt() {
        var snow = SnowSimulation()
        snow.sync(width: size.width, ground: true, ledges: [])
        for x: CGFloat in [55, 92] {
            precondition(snow.deposit(from: CGPoint(x: x, y: 50), to: CGPoint(x: x, y: -1), mass: 60))
        }
        var materials = WeatherMaterials()
        materials.setSurfaces([], width: size.width, covered: [:])
        let original = snow.depth(at: 55, on: -1)
        let baseline = snow
        materials.select(.rain)
        precondition(snow.depth(at: 55, on: -1) == original)
        materials.advance(dt: 1.0 / 30, size: size, count: 0, wind: 0, pointer: nil, snow: &snow)
        precondition(snow.depth(at: 55, on: -1) < original && snow.depth(at: 55, on: -1) > 0)
        var drop = material(.rain, at: CGPoint(x: 55, y: 0))
        precondition(materials.hit(&drop, from: CGPoint(x: 55, y: 35), snow: &snow))
        precondition(snow.depth(at: 55, on: -1) < snow.depth(at: 92, on: -1))
        for _ in 0..<260 {
            materials.advance(dt: 1.0 / 30, size: size, count: 0, wind: 0, pointer: nil, snow: &snow)
        }
        precondition(!snow.hasDeposits)

        var drizzleSnow = baseline
        materials.select(.drizzle)
        for _ in 0..<260 {
            materials.advance(dt: 1.0 / 30, size: size, count: 0, wind: 0, pointer: nil, snow: &drizzleSnow)
        }
        precondition(drizzleSnow.hasDeposits)
    }

    private static func foliageStaysOnItsSurfaceAndCanBeSwept() {
        var snow = SnowSimulation()
        let edge = DesktopEdge(minX: 25, maxX: 135, y: 72, id: 1)
        var materials = WeatherMaterials()
        materials.setSurfaces([edge], width: size.width, covered: [:])
        materials.select(.leaves)
        for kind in [WeatherMaterials.Kind.leaf, .petal] {
            var leaf = material(kind, at: CGPoint(x: 91, y: 55))
            precondition(materials.hit(&leaf, from: CGPoint(x: 90, y: 85), snow: &snow))
        }
        precondition(materials.litter.count == 2 && materials.litter[1].layer > 0)
        materials.select(.rain)
        let moved = DesktopEdge(minX: 46, maxX: 156, y: 85, id: 1)
        materials.setSurfaces([moved], width: size.width, covered: [:])
        let originalX = materials.litter[0].x
        materials.advance(dt: 0.03, size: size, count: 0, wind: 0, pointer: nil, snow: &snow)
        precondition(abs(materials.litter[0].x - originalX - 21) < 0.01 && materials.litter[0].wetness > 0)
        materials.select(.snow)
        for x: CGFloat in [65, 174] {
            materials.advance(dt: 0.03, size: size, count: 0, wind: 0,
                              pointer: CGPoint(x: x, y: 85), snow: &snow)
        }
        precondition(materials.litter.isEmpty && materials.loose.count == 2)
    }

    private static func rainSplashesAndRunsOffToLowerSurfaces() {
        var snow = SnowSimulation()
        let edge = DesktopEdge(minX: 26, maxX: 132, y: 72, id: 1)
        var materials = WeatherMaterials()
        materials.setSurfaces([edge], width: size.width, covered: [:])
        var drop = material(.rain, at: CGPoint(x: 128, y: 59))
        precondition(materials.hit(&drop, from: CGPoint(x: 128, y: 100), snow: &snow))
        precondition(materials.splashes.count == 2 && materials.puddles.first?.edgeID == 1)
        var ranOff = false
        var reachedFloor = false
        for _ in 0..<60 {
            materials.advance(dt: 1.0 / 30, size: size, count: 0, wind: 0.5, pointer: nil, snow: &snow)
            ranOff = ranOff || materials.loose.contains(where: { $0.kind == .drizzle && $0.point.x > edge.maxX })
            reachedFloor = reachedFloor || materials.puddles.contains(where: { $0.edgeID == -1 && $0.water > 0.19 })
        }
        precondition(ranOff && reachedFloor)
        for _ in 0..<100 {
            materials.advance(dt: 1.0 / 30, size: size, count: 0, wind: 0, pointer: nil, snow: &snow)
        }
        precondition(materials.puddles.isEmpty)
    }

    private static func material(_ kind: WeatherMaterials.Kind, at point: CGPoint) -> WeatherMaterials.Particle {
        WeatherMaterials.Particle(kind: kind, point: point, velocity: CGVector(dx: 0, dy: -250),
                                  radius: 2, phase: 0, angle: 0)
    }

    private static func step(_ snow: inout SnowSimulation, wind: CGFloat = 0, pointer: CGPoint? = nil) {
        snow.advance(dt: 1.0 / 30, size: size, count: 0, heavy: false, limits: .standard,
                     wind: wind, pointer: pointer)
    }
    private static func batterySaverDefaultsOffAndPersists() {
        var preferences = Preferences()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let legacy = try! encoder.encode(preferences)
        precondition(!(try! decoder.decode(Preferences.self, from: legacy)).batterySaver)
        preferences.batterySaver = true
        let saved = try! encoder.encode(preferences)
        precondition((try! decoder.decode(Preferences.self, from: saved)).batterySaver)
    }

}
