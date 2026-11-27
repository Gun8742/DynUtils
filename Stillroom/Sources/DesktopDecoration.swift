import AppKit

@MainActor
enum DesktopDecoration {
    private static let space = CGColorSpace(name: CGColorSpace.sRGB)
    private static let snow = gradient([0xffffff, 0xecf6fa, 0xa2b9d4], at: [0, 0.54, 1])
    private static let needles = gradient([0x69a789, 0x2d695a, 0x163c3b], at: [0, 0.45, 1])

    static func draw(_ props: Set<DesktopProp>, layouts: [DesktopProp: DecorationLayout],
                     in context: CGContext, bounds: CGRect, treeFloor: CGFloat = 0) {
        for prop in DesktopProp.allCases where props.contains(prop) {
            let layout = layouts[prop] ?? .initial(prop)
            context.saveGState()
            switch prop {
            case .snowman:
                context.translateBy(x: bounds.width * layout.x, y: bounds.height * layout.y)
                context.rotate(by: layout.angle * .pi / 180)
                drawSnowman(in: context, parts: layout.snowballs?.parts ?? SnowmanSnowballs.legacyParts)
            case .tree:
                let placement = layout.groundedTree(in: bounds, floor: treeFloor)
                ellipse(in: context, x: placement.origin.x, y: treeFloor + 2.5,
                        rx: 25, ry: 2.5, color: 0x1b3943, alpha: 0.32)
                context.translateBy(x: placement.origin.x, y: placement.origin.y)
                context.rotate(by: placement.radians)
                drawTree(lights: layout.lights, in: context)
            }
            context.restoreGState()
        }
    }

    static func drawCraftBall(_ ball: SnowCraft.Ball, in context: CGContext) {
        let radius = ball.radius
        context.saveGState()
        context.translateBy(x: ball.center.x, y: ball.center.y)
        context.scaleBy(x: 1 + ball.compression * 0.55, y: 1 - ball.compression)
        drawSnowball(in: context, rect: CGRect(x: -radius, y: -radius, width: 2 * radius, height: 2 * radius))
        context.rotate(by: ball.rotation)
        for (x, y, size) in [(-0.53, 0.28, 0.13), (-0.17, 0.55, 0.10), (0.38, -0.35, 0.16), (0.53, 0.14, 0.084)] {
            ellipse(in: context, x: x * radius, y: y * radius, rx: radius * size, ry: radius * size * 0.65,
                    color: 0x6685a2, alpha: 0.37)
        }
        context.restoreGState()
    }

    private static func drawSnowball(in context: CGContext, rect: CGRect) {
        shade(CGPath(ellipseIn: rect, transform: nil), in: context) {
            context.drawRadialGradient(snow,
                                       startCenter: CGPoint(x: rect.midX - rect.width * 0.15,
                                                            y: rect.midY + rect.height * 0.19),
                                       startRadius: 1, endCenter: CGPoint(x: rect.midX, y: rect.midY),
                                       endRadius: rect.width * 0.68, options: .drawsAfterEndLocation)
        }
    }

    private static func drawSnowman(in context: CGContext, parts: [CGRect]) {
        let references = SnowmanSnowballs.legacyParts
        let baseRadius = parts[0].width / 2
        ellipse(in: context, x: baseRadius * 0.12, y: 1, rx: baseRadius * 1.16,
                ry: baseRadius * 0.2, color: 0x21394c, alpha: 0.23)
        context.saveGState()
        fit(references[1], to: parts[1], in: context)
        for elbow in [-1.0, 1.0] {
            let arm = CGMutablePath()
            arm.move(to: CGPoint(x: elbow * 15, y: 48))
            arm.addLines(between: [CGPoint(x: elbow * 15, y: 48), CGPoint(x: elbow * 29, y: 53),
                                   CGPoint(x: elbow * 37, y: 62)])
            arm.move(to: CGPoint(x: elbow * 30, y: 55))
            arm.addLine(to: CGPoint(x: elbow * 30, y: 63))
            stroke(arm, color: 0x614e45, width: 2.4, in: context)
        }

        context.restoreGState()
        for ball in parts { drawSnowball(in: context, rect: ball) }

        context.saveGState()
        fit(references[1], to: parts[1], in: context)
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: 11, y: 62))
        tail.addQuadCurve(to: CGPoint(x: 20, y: 37), control: CGPoint(x: 9, y: 46))
        tail.addLine(to: CGPoint(x: 27, y: 42))
        tail.addQuadCurve(to: CGPoint(x: 19, y: 61), control: CGPoint(x: 19, y: 50))
        tail.closeSubpath()
        context.setFillColor(color(0x964252))
        context.addPath(tail)
        context.fillPath()
        let scarf = CGMutablePath()
        scarf.move(to: CGPoint(x: -16, y: 63))
        scarf.addQuadCurve(to: CGPoint(x: 18, y: 65), control: CGPoint(x: 0, y: 55))
        stroke(scarf, color: 0xa5495c, width: 7.2, in: context)
        stroke(scarf, color: 0xd96e78, width: 2.1, in: context)
        for y in [35.0, 43.0, 51.0] {
            ellipse(in: context, x: 0, y: y, rx: 1.7, ry: 1.8, color: 0x30404c)
        }

        context.restoreGState()

        context.saveGState()
        fit(references[2], to: parts[2], in: context)
        for x in [-5.0, 7.0] {
            ellipse(in: context, x: x, y: 76, rx: 1.6, ry: 1.9, color: 0x263746)
            ellipse(in: context, x: x - 0.45, y: 76.65, rx: 0.45, ry: 0.45, color: 0xffffff)
            ellipse(in: context, x: x * 1.4, y: 70.5, rx: 2.65, ry: 1.4, color: 0xe597a1, alpha: 0.58)
        }
        let carrot = CGMutablePath()
        carrot.move(to: CGPoint(x: -0.5, y: 75))
        carrot.addQuadCurve(to: CGPoint(x: 12, y: 71), control: CGPoint(x: 7, y: 74.5))
        carrot.addQuadCurve(to: CGPoint(x: 0, y: 70), control: CGPoint(x: 4, y: 68.5))
        carrot.closeSubpath()
        context.setFillColor(color(0xe98a49))
        context.addPath(carrot)
        context.fillPath()
        for point in [CGPoint(x: -2, y: 68), CGPoint(x: 0.7, y: 67), CGPoint(x: 3.4, y: 68)] {
            ellipse(in: context, x: point.x, y: point.y, rx: 0.76, ry: 0.8, color: 0x485469)
        }

        context.saveGState()
        context.translateBy(x: -1, y: 85)
        context.rotate(by: 0.13)
        context.setFillColor(color(0x293f56))
        context.addPath(CGPath(roundedRect: CGRect(x: -10, y: -1, width: 23, height: 16),
                               cornerWidth: 4, cornerHeight: 4, transform: nil))
        context.fillPath()
        context.setFillColor(color(0x4b6980))
        context.fill(CGRect(x: -9, y: 1, width: 21, height: 3))
        ellipse(in: context, x: 1, y: 0, rx: 16, ry: 2.6, color: 0x26394e)
        ellipse(in: context, x: -6, y: 13, rx: 3.5, ry: 1.15, color: 0xd6e8f2, alpha: 0.71)
        context.restoreGState()
        context.restoreGState()
    }

    private static func fit(_ reference: CGRect, to part: CGRect, in context: CGContext) {
        context.translateBy(x: part.midX, y: part.midY)
        context.scaleBy(x: part.width / reference.width, y: part.height / reference.height)
        context.translateBy(x: -reference.midX, y: -reference.midY)
    }

    private static func drawTree(lights: Bool, in context: CGContext) {
        context.setFillColor(color(0x614d41))
        context.fill(DecorationLayout.treeTrunk)
        context.setFillColor(color(0x96755a))
        context.fill(CGRect(x: -3, y: 3, width: 1.8, height: 15))
        for (center, base, width, height) in [(0.0, 13.0, 39.0, 55.0), (-2, 36, 30, 49), (1, 57, 23, 42)] {
            context.saveGState()
            context.translateBy(x: center, y: base)
            context.scaleBy(x: width, y: height)
            let bough = CGMutablePath()
            bough.move(to: CGPoint(x: 0.05, y: 1))
            bough.addQuadCurve(to: CGPoint(x: 0.64, y: 0.38), control: CGPoint(x: 0.26, y: 0.65))
            bough.addQuadCurve(to: CGPoint(x: 0.98, y: 0.14), control: CGPoint(x: 0.76, y: 0.22))
            bough.addQuadCurve(to: CGPoint(x: 0.55, y: 0.085), control: CGPoint(x: 0.89, y: -0.026))
            bough.addQuadCurve(to: CGPoint(x: 0.12, y: 0.005), control: CGPoint(x: 0.35, y: -0.058))
            bough.addQuadCurve(to: CGPoint(x: -0.43, y: 0.065), control: CGPoint(x: -0.11, y: -0.062))
            bough.addQuadCurve(to: CGPoint(x: -0.97, y: 0.16), control: CGPoint(x: -0.77, y: -0.016))
            bough.addQuadCurve(to: CGPoint(x: 0.05, y: 1), control: CGPoint(x: -0.32, y: 0.43))
            bough.closeSubpath()
            shade(bough, in: context) {
                context.drawLinearGradient(needles, start: CGPoint(x: -0.45, y: 0.87),
                                           end: CGPoint(x: 0.42, y: -0.06),
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            context.setFillColor(color(0xcde3e7, alpha: 0.87))
            context.move(to: CGPoint(x: -0.63, y: 0.24))
            context.addQuadCurve(to: CGPoint(x: -0.12, y: 0.58), control: CGPoint(x: -0.31, y: 0.36))
            context.addQuadCurve(to: CGPoint(x: 0.42, y: 0.32), control: CGPoint(x: 0.12, y: 0.46))
            context.addQuadCurve(to: CGPoint(x: -0.11, y: 0.42), control: CGPoint(x: 0.16, y: 0.25))
            context.addQuadCurve(to: CGPoint(x: -0.63, y: 0.24), control: CGPoint(x: -0.45, y: 0.22))
            context.fillPath()
            context.restoreGState()
        }
        guard lights else { return }
        let bulbs: [(CGFloat, CGFloat, UInt32)] = [
            (-28, 22, 0xffd58b), (-12, 19, 0xff9690), (7, 23, 0xffe1a7), (26, 25, 0xb2e8e9),
            (-20, 44, 0xb2e8e9), (-5, 40, 0xffd58b), (15, 44, 0xff9690),
            (-12, 66, 0xffd58b), (4, 63, 0xb2e8e9), (15, 68, 0xffd58b), (0, 82, 0xff9690)
        ]
        for (x, y, hue) in bulbs {
            ellipse(in: context, x: x, y: y, rx: 4.7, ry: 4.7, color: hue, alpha: 0.20)
            ellipse(in: context, x: x, y: y, rx: 1.7, ry: 1.9, color: hue)
        }
        let star = CGMutablePath()
        for index in 0..<10 {
            let angle = CGFloat(index) * .pi / 5 + .pi / 2
            let radius: CGFloat = index.isMultiple(of: 2) ? 7 : 3
            let point = CGPoint(x: 2 + cos(angle) * radius, y: 99 + sin(angle) * radius)
            if index == 0 { star.move(to: point) } else { star.addLine(to: point) }
        }
        star.closeSubpath()
        context.setFillColor(color(0xffdb8b))
        context.addPath(star)
        context.fillPath()
    }

    private static func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }

    private static func gradient(_ colors: [UInt32], at locations: [CGFloat]) -> CGGradient {
        CGGradient(colorsSpace: space, colors: colors.map { color($0) } as CFArray, locations: locations)!
    }

    private static func shade(_ path: CGPath, in context: CGContext,
                              draw: () -> Void) {
        context.saveGState()
        context.addPath(path)
        context.clip()
        draw()
        context.restoreGState()
    }

    private static func ellipse(in context: CGContext, x: CGFloat, y: CGFloat, rx: CGFloat,
                                ry: CGFloat, color hex: UInt32, alpha: CGFloat = 1) {
        context.setFillColor(color(hex, alpha: alpha))
        context.fillEllipse(in: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
    }

    private static func stroke(_ path: CGPath, color hex: UInt32, width: CGFloat, in context: CGContext) {
        context.setStrokeColor(color(hex))
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()
    }
}
