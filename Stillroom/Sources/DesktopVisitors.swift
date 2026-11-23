import AppKit

enum DesktopVisitor: String, CaseIterable, Codable, Identifiable {
    case santa, elves, yeti, fight, snowplough, train
    var id: String { rawValue }
    var title: String { self == .fight ? "Snowman fight" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .santa: "gift.fill"
        case .elves: "wand.and.stars"
        case .yeti: "pawprint.fill"
        case .fight: "snowflake"
        case .snowplough: "truck.box.fill"
        case .train: "tram.fill"
        }
    }
}

struct DesktopVisit: Equatable {
    static let duration = 6.0
    let visitor: DesktopVisitor?
    let start: TimeInterval

    var age: TimeInterval { ProcessInfo.processInfo.systemUptime - start }
    var expired: Bool { age >= (visitor == nil ? 1.5 : Self.duration) }

    static func snowballImpact(origin: CGPoint, vx: CGFloat, vy: CGFloat,
                               gravity: CGFloat, edges: [DesktopEdge]) -> CGFloat? {
        edges.compactMap { edge -> CGFloat? in
            let discriminant = vy * vy + 2 * gravity * (origin.y - edge.y)
            guard discriminant >= 0, gravity > 0 else { return nil }
            let t = (vy + sqrt(discriminant)) / gravity
            let x = origin.x + vx * t
            return t > 0 && x >= edge.minX && x <= edge.maxX ? t : nil
        }.min()
    }
}

struct DecorationLayout: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var angle: CGFloat = 0
    var lights = true

    static func initial(_ prop: DesktopProp) -> Self {
        prop == .snowman ? Self(x: 0.14, y: 0.015) : Self(x: 0.84, y: 0)
    }
}

extension DecorationLayout {
    static let treeTrunk = CGRect(x: -5, y: 0, width: 11, height: 24)
    static let maxTreeLean: CGFloat = 30

    var treeLean: CGFloat {
        let angle = angle.truncatingRemainder(dividingBy: 360)
        let signed = angle > 180 ? angle - 360 : (angle < -180 ? angle + 360 : angle)
        return min(Self.maxTreeLean, max(-Self.maxTreeLean, signed))
    }

    func groundedTree(in bounds: CGRect, floor: CGFloat) -> (origin: CGPoint, radians: CGFloat) {
        let radians = treeLean * .pi / 180
        let trunk = Self.treeTrunk.applying(CGAffineTransform(rotationAngle: radians))
        return (CGPoint(x: bounds.minX + bounds.width * x, y: floor - trunk.minY), radians)
    }
}
