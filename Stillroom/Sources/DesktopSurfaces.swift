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

}

struct DesktopWindowSnapshot {
    struct Surface {
        let id: Int
        let bounds: CGRect
        var isDock = false
    }

    let edges: [DesktopEdge]
    let foreground: [Int: [CGRect]]

    init(frame: CGRect, surfaces: [Surface]) {
        let visible = surfaces.filter { surface in
            guard surface.bounds.intersects(frame) else { return false }
            guard surface.isDock else { return true }
            let bounds = surface.bounds
            let nearSide = bounds.minX <= frame.minX + 28 || bounds.maxX >= frame.maxX - 28
            let nearBottom = bounds.minY <= frame.minY + 28
            return (nearSide && bounds.width <= 160) || (nearBottom && bounds.height <= 160)
        }.prefix(48)
        var edges: [DesktopEdge] = []
        var foreground: [Int: [CGRect]] = [:]
        var earlier: [CGRect] = []

        // The window list is ordered from front to back. Keep full ledge coordinates for each bank.
        for surface in visible {
            let local = surface.bounds.offsetBy(dx: -frame.minX, dy: -frame.minY)
            if edges.count < 24, local.maxY > 0, local.maxY < frame.height {
                edges.append(DesktopEdge(minX: local.minX, maxX: local.maxX, y: local.maxY,
                                         id: surface.id, isDock: surface.isDock))
                foreground[surface.id] = earlier.filter { $0.maxX > local.minX && $0.minX < local.maxX }
            }
            earlier.append(local)
        }
        foreground[-1] = earlier
        self.edges = edges
        self.foreground = foreground
    }

    var coveredLedges: [Int: [ClosedRange<CGFloat>]] {
        var ranges: [Int: [ClosedRange<CGFloat>]] = [:]
        for edge in edges {
            let spans = (foreground[edge.id] ?? []).compactMap { window -> ClosedRange<CGFloat>? in
                guard window.minY <= edge.y, window.maxY > edge.y else { return nil }
                let left = max(edge.minX, window.minX)
                let right = min(edge.maxX, window.maxX)
                return left <= right ? left...right : nil
            }
            if !spans.isEmpty { ranges[edge.id] = spans }
        }
        return ranges
    }
}

@MainActor
enum DesktopWindowSampler {
    private static var lastCapture = -Double.infinity
    private static var surfaces: [DesktopWindowSnapshot.Surface] = []

    static func snapshot(in frame: CGRect, at now: TimeInterval) -> DesktopWindowSnapshot {
        // Multiple display overlays share the same WindowServer read within a tick.
        if now - lastCapture >= 1.0 / 60 {
            lastCapture = now
            surfaces = capture() ?? surfaces
        }
        return DesktopWindowSnapshot(frame: frame, surfaces: surfaces)
    }

    private static func capture() -> [DesktopWindowSnapshot.Surface]? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return nil }
        let mainTop = CGDisplayBounds(CGMainDisplayID()).height
        let dockLayer = Int(CGWindowLevelForKey(.dockWindow))
        return windows.compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? Int,
                  let id = info[kCGWindowNumber as String] as? Int,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.05,
                  let raw = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: raw),
                  rect.width >= 40, rect.height >= 40 else { return nil }
            let dock = layer == dockLayer && (info[kCGWindowOwnerName as String] as? String) == "Dock"
            guard layer == 0 || dock else { return nil }
            let bounds = CGRect(x: rect.minX, y: mainTop - rect.maxY, width: rect.width, height: rect.height)
            return DesktopWindowSnapshot.Surface(id: id, bounds: bounds, isDock: dock)
        }
    }
}

enum DesktopProp: String, CaseIterable, Codable, Identifiable {
    case snowman, tree
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
