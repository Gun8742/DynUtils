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
