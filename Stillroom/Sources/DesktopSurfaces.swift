import AppKit

struct DesktopEdge: Equatable {
    let minX: CGFloat
    let maxX: CGFloat
    let y: CGFloat
    var id: Int = 0
    var isDock = false

    static func firstImpact(from origin: CGPoint, velocity: CGVector, before end: CGFloat,
                            edges: [Self]) -> CGFloat? {
        guard velocity.dy < 0 else { return nil }
        return edges.compactMap { edge -> CGFloat? in
            let time = (edge.y - origin.y) / velocity.dy
            guard time >= 0, time < end else { return nil }
            let x = origin.x + time * velocity.dx
            return (edge.minX...edge.maxX).contains(x) ? time : nil
        }.min()
    }

    static func nearby(x: CGFloat, y: CGFloat, height: CGFloat, edges: [Self]) -> Self? {
        edges.first { edge in
            x >= edge.minX && x <= edge.maxX && y >= edge.y && y - edge.y < height
        }
    }

    @MainActor
    static func visible(in frame: CGRect) -> [Self] {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return [] }
        let mainTop = CGDisplayBounds(CGMainDisplayID()).height
        return Array(windows.lazy.compactMap { info -> Self? in
            let dockLayer = Int(CGWindowLevelForKey(.dockWindow))
            guard let layer = info[kCGWindowLayer as String] as? Int,
                  let id = info[kCGWindowNumber as String] as? Int,
                  layer == 0 || (layer == dockLayer && (info[kCGWindowOwnerName as String] as? String) == "Dock"),
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.05,
                  let raw = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: raw),
                  rect.width >= 40, rect.height >= 40 else { return nil }
            let left = max(frame.minX, rect.minX)
            let right = min(frame.maxX, rect.maxX)
            let top = mainTop - rect.minY
            guard left < right, top > frame.minY, top < frame.maxY else { return nil }
            let isDock = layer == dockLayer
            if isDock && rect.width >= frame.width * 0.95 && rect.height >= frame.height * 0.95 { return nil }
            return Self(minX: left - frame.minX, maxX: right - frame.minX, y: top - frame.minY,
                        id: id, isDock: isDock)
        }.prefix(24))
    }
}

enum DesktopProp: String, CaseIterable, Codable, Identifiable {
    case snowman, tree
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@MainActor
enum DesktopDecoration {
    static func draw(_ props: Set<DesktopProp>, layouts: [DesktopProp: DecorationLayout],
                     in context: CGContext, bounds: CGRect) {
        if props.contains(.snowman) {
            context.saveGState()
            let layout = layouts[.snowman] ?? .initial(.snowman)
            context.translateBy(x: bounds.width * layout.x, y: bounds.height * layout.y)
            context.rotate(by: layout.angle * .pi / 180)
            context.setFillColor(NSColor(srgbRed: 0.89, green: 0.96, blue: 0.98, alpha: 0.95).cgColor)
            let snowballs: [(CGFloat, CGFloat)] = [(0, 28), (36, 22), (67, 16)]
            for (y, radius) in snowballs {
                context.fillEllipse(in: CGRect(x: -radius, y: y, width: radius * 2, height: radius * 2))
            }
            context.setFillColor(NSColor(srgbRed: 0.10, green: 0.19, blue: 0.24, alpha: 1).cgColor)
            for x in [-7.0, 6.0] {
                context.fillEllipse(in: CGRect(x: x, y: 85, width: 3, height: 3))
            }
            context.setFillColor(NSColor(srgbRed: 0.76, green: 0.28, blue: 0.18, alpha: 1).cgColor)
            context.fill(CGRect(x: -19, y: 64, width: 37, height: 5))
            context.restoreGState()
        }
        if props.contains(.tree) {
            context.saveGState()
            let layout = layouts[.tree] ?? .initial(.tree)
            context.translateBy(x: bounds.width * layout.x, y: bounds.height * layout.y)
            context.rotate(by: layout.angle * .pi / 180)
            context.setFillColor(NSColor(srgbRed: 0.49, green: 0.34, blue: 0.25, alpha: 1).cgColor)
            context.fill(CGRect(x: -6, y: 0, width: 12, height: 25))
            for tier in 0..<3 {
                let y = CGFloat(tier) * 22 + 12
                let width = 42 - CGFloat(tier) * 9
                context.setFillColor(NSColor(srgbRed: 0.14, green: 0.42 + CGFloat(tier) * 0.06,
                                             blue: 0.35, alpha: 0.97).cgColor)
                context.move(to: CGPoint(x: -width, y: y))
                context.addLine(to: CGPoint(x: 0, y: y + 57))
                context.addLine(to: CGPoint(x: width, y: y))
                context.closePath()
                context.fillPath()
            }
            if layout.lights {
                context.setFillColor(NSColor(srgbRed: 1, green: 0.79, blue: 0.32, alpha: 1).cgColor)
                for origin in [CGPoint(x: -19, y: 28), CGPoint(x: 13, y: 43), CGPoint(x: -5, y: 64)] {
                    context.fillEllipse(in: CGRect(origin: origin, size: CGSize(width: 4, height: 4)))
                }
            }
            context.restoreGState()
        }
    }
}
