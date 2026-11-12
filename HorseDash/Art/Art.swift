import SwiftUI
import UIKit

extension RGB {
    var ui: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
    var color: Color { Color(red: Double(r), green: Double(g), blue: Double(b)) }
}

extension UIColor {
    func shade(_ f: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(1, r * f), green: min(1, g * f), blue: min(1, b * f), alpha: a)
    }
}

/// Procedural, original cartoon art: chunky dark outlines and saturated fills.
/// Everything is drawn once into images, then used as SpriteKit textures
/// or SwiftUI images.
enum Art {
    static let ink = UIColor(red: 0.13, green: 0.09, blue: 0.16, alpha: 1)

    static func render(_ size: CGSize, _ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            draw(ctx.cgContext)
        }
    }

    // MARK: Path helpers

    static func rr(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        let rad = max(0, min(radius, min(r.width, r.height) / 2 - 0.01))
        return CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
    }

    static func ellipse(_ r: CGRect) -> CGPath {
        CGPath(ellipseIn: r, transform: nil)
    }

    static func circle(_ c: CGPoint, _ radius: CGFloat) -> CGPath {
        ellipse(CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
    }

    static func poly(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: pts)
        p.closeSubpath()
        return p
    }

    static func fill(_ c: CGContext, _ path: CGPath, _ color: UIColor, stroke: CGFloat = 3) {
        c.addPath(path)
        c.setFillColor(color.cgColor)
        c.fillPath()
        guard stroke > 0 else { return }
        c.addPath(path)
        c.setStrokeColor(ink.cgColor)
        c.setLineWidth(stroke)
        c.setLineJoin(.round)
        c.strokePath()
    }

    static func stripes(_ c: CGContext, in path: CGPath, base: UIColor, stripe: UIColor,
                        width: CGFloat, diagonal: Bool) {
        let box = path.boundingBox
        c.saveGState()
        c.addPath(path)
        c.clip()
        c.setFillColor(base.cgColor)
        c.fill(box)
        c.setFillColor(stripe.cgColor)
        let skew = diagonal ? box.height : 0
        var x = box.minX - box.height - width
        var on = false
        while x < box.maxX + box.height {
            if on {
                c.addPath(poly([
                    CGPoint(x: x, y: box.maxY), CGPoint(x: x + width, y: box.maxY),
                    CGPoint(x: x + width + skew, y: box.minY), CGPoint(x: x + skew, y: box.minY),
                ]))
                c.fillPath()
            }
            on.toggle()
            x += width
        }
        c.restoreGState()
        c.addPath(path)
        c.setStrokeColor(ink.cgColor)
        c.setLineWidth(3)
        c.strokePath()
    }

    // MARK: Horse (seen from behind, as the camera follows it)

    enum HorsePose: Equatable {
        case run(Int)
        case jump
    }

    static let horseCanvas = CGSize(width: 120, height: 150)

    static func horse(_ skin: Skin, pose: HorsePose) -> UIImage {
        render(horseCanvas) { c in
            let coat = skin.coat.ui
            let far = skin.coat.shade(0.78).ui
            let mane = skin.mane.ui
            let blanket = skin.blanket.ui
            let ground: CGFloat = 147

            var bob: CGFloat = 0, liftL: CGFloat = 0, liftR: CGFloat = 0, tail: CGFloat = 0
            switch pose {
            case .run(let f):
                let i = ((f % 4) + 4) % 4
                bob = [0, -4, 0, -4][i]
                liftL = [0, 14, 4, 0][i]
                liftR = [4, 0, 0, 14][i]
                tail = [-8, 0, 8, 0][i]
            case .jump:
                bob = -6
                liftL = 18
                liftR = 18
                tail = 12
            }

            func leg(_ cx: CGFloat, top: CGFloat, lift: CGFloat, width: CGFloat, color: UIColor) {
                let bottom = ground - lift
                fill(c, rr(CGRect(x: cx - width / 2, y: top, width: width, height: bottom - top), width / 2), color)
                if skin.pattern == .socks {
                    fill(c, rr(CGRect(x: cx - width / 2, y: bottom - 22, width: width, height: 14), 3), .white, stroke: 2)
                }
                fill(c, rr(CGRect(x: cx - width / 2 - 1, y: bottom - 9, width: width + 2, height: 9), 3), ink, stroke: 0)
            }

            // Far (front) legs peek between the hind legs.
            leg(49, top: 92 + bob, lift: liftR * 0.6, width: 11, color: far)
            leg(71, top: 92 + bob, lift: liftL * 0.6, width: 11, color: far)

            // Neck and head, behind the body.
            fill(c, rr(CGRect(x: 44, y: 20 + bob, width: 32, height: 58), 14), coat)
            fill(c, poly([CGPoint(x: 45, y: 28 + bob), CGPoint(x: 49, y: 6 + bob), CGPoint(x: 57, y: 24 + bob)]), coat)
            fill(c, poly([CGPoint(x: 63, y: 24 + bob), CGPoint(x: 71, y: 6 + bob), CGPoint(x: 75, y: 28 + bob)]), coat)
            fill(c, rr(CGRect(x: 54, y: 14 + bob, width: 12, height: 58), 6), mane)

            // Back and saddle blanket.
            fill(c, ellipse(CGRect(x: 24, y: 50 + bob, width: 72, height: 44)), coat)
            stripes(c, in: rr(CGRect(x: 27, y: 55 + bob, width: 66, height: 20), 9),
                    base: blanket, stripe: blanket.shade(1.35), width: 10, diagonal: false)

            // Hind legs.
            leg(36, top: 100 + bob, lift: liftL, width: 18, color: coat)
            leg(84, top: 100 + bob, lift: liftR, width: 18, color: coat)

            // Rump.
            let rump = ellipse(CGRect(x: 14, y: 62 + bob, width: 92, height: 62))
            fill(c, rump, coat)
            c.saveGState()
            c.addPath(rump)
            c.clip()
            switch skin.pattern {
            case .dapple:
                c.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
                for p in [(30, 80), (48, 98), (78, 84), (88, 104), (62, 112), (36, 108), (70, 70)] {
                    c.addPath(circle(CGPoint(x: CGFloat(p.0), y: CGFloat(p.1) + bob), 6))
                    c.fillPath()
                }
            case .stripes:
                c.setStrokeColor(ink.cgColor)
                c.setLineWidth(6)
                for x in stride(from: CGFloat(20), through: 100, by: 16) {
                    c.move(to: CGPoint(x: x, y: 60 + bob))
                    c.addQuadCurve(to: CGPoint(x: x - 6, y: 126 + bob), control: CGPoint(x: x + 10, y: 92 + bob))
                }
                c.strokePath()
            case .sparkle:
                c.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
                for p in [(32, 82), (80, 78), (56, 104), (90, 106), (40, 110)] {
                    let o = CGPoint(x: CGFloat(p.0), y: CGFloat(p.1) + bob)
                    c.addPath(poly([
                        CGPoint(x: o.x, y: o.y - 6), CGPoint(x: o.x + 2, y: o.y - 2), CGPoint(x: o.x + 6, y: o.y),
                        CGPoint(x: o.x + 2, y: o.y + 2), CGPoint(x: o.x, y: o.y + 6), CGPoint(x: o.x - 2, y: o.y + 2),
                        CGPoint(x: o.x - 6, y: o.y), CGPoint(x: o.x - 2, y: o.y - 2),
                    ]))
                    c.fillPath()
                }
            case .solid, .socks:
                break
            }
            // Soft highlight for volume.
            c.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            c.addPath(ellipse(CGRect(x: 26, y: 68 + bob, width: 40, height: 20)))
            c.fillPath()
            c.restoreGState()

            c.setStrokeColor(ink.cgColor)
            c.setLineWidth(2)
            c.move(to: CGPoint(x: 60, y: 72 + bob))
            c.addLine(to: CGPoint(x: 60, y: 112 + bob))
            c.strokePath()

            // Tail.
            let t = CGMutablePath()
            t.move(to: CGPoint(x: 52, y: 70 + bob))
            t.addQuadCurve(to: CGPoint(x: 60 + tail, y: 134 + bob), control: CGPoint(x: 42 + tail, y: 100 + bob))
            t.addQuadCurve(to: CGPoint(x: 68, y: 70 + bob), control: CGPoint(x: 78 + tail, y: 100 + bob))
            t.closeSubpath()
            fill(c, t, mane)
        }
    }

    // MARK: Hay bale (the coin)

    static func hayBale(diameter d: CGFloat) -> UIImage {
        render(CGSize(width: d, height: d)) { c in
            let center = CGPoint(x: d / 2, y: d / 2)
            fill(c, circle(center, d / 2 - 2), UIColor(red: 1, green: 0.79, blue: 0.16, alpha: 1), stroke: 2.5)
            c.setStrokeColor(UIColor(red: 0.85, green: 0.58, blue: 0.0, alpha: 1).cgColor)
            c.setLineWidth(max(1.5, d * 0.06))
            for f in [0.26, 0.5] as [CGFloat] {
                c.addPath(circle(center, d / 2 * f + d * 0.04))
                c.strokePath()
            }
            c.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            c.addPath(ellipse(CGRect(x: d * 0.22, y: d * 0.16, width: d * 0.28, height: d * 0.16)))
            c.fillPath()
        }
    }

    // MARK: Obstacles

    static func obstacleSize(_ kind: ObstacleKind, laneWidth: CGFloat) -> CGSize {
        switch kind {
        case .hurdle: return CGSize(width: laneWidth * 0.92, height: Tuning.hurdleHeight)
        case .overhead: return CGSize(width: laneWidth * 0.98, height: Tuning.overheadHeight)
        case .block: return CGSize(width: laneWidth * 0.94, height: Tuning.blockHeight)
        }
    }

    static func obstacle(_ kind: ObstacleKind, size: CGSize, main: UIColor, accent: UIColor) -> UIImage {
        render(size) { c in
            let w = size.width, h = size.height
            switch kind {
            case .hurdle:
                for x in [CGFloat(5), w - 17] {
                    fill(c, rr(CGRect(x: x, y: 4, width: 12, height: h - 8), 4), accent)
                }
                for y in [CGFloat(14), 42] {
                    stripes(c, in: rr(CGRect(x: 2, y: y, width: w - 4, height: 15), 7),
                            base: main, stripe: accent, width: 16, diagonal: false)
                }
                for x in [CGFloat(1), w - 23] {
                    fill(c, rr(CGRect(x: x, y: h - 10, width: 22, height: 8), 3), main)
                }
            case .overhead:
                for x in [CGFloat(3), w - 17] {
                    fill(c, rr(CGRect(x: x, y: 2, width: 14, height: h - 4), 5), main.shade(0.85))
                }
                let beamBottom = h - Tuning.overheadClearance
                stripes(c, in: rr(CGRect(x: 1, y: beamBottom - 62, width: w - 2, height: 62), 10),
                        base: main, stripe: accent, width: 18, diagonal: true)
                fill(c, rr(CGRect(x: w * 0.3, y: 4, width: w * 0.4, height: beamBottom - 70), 6), accent)
                // Arrow pointing down: "slide!"
                let cx = w / 2, top = beamBottom - 62 - 30
                fill(c, poly([
                    CGPoint(x: cx - 8, y: top), CGPoint(x: cx + 8, y: top), CGPoint(x: cx + 8, y: top + 10),
                    CGPoint(x: cx + 14, y: top + 10), CGPoint(x: cx, y: top + 22), CGPoint(x: cx - 14, y: top + 10),
                    CGPoint(x: cx - 8, y: top + 10),
                ]), main, stroke: 2)
            case .block:
                fill(c, rr(CGRect(x: 0, y: 4, width: w, height: 70), 34), accent)
                let body = CGRect(x: 4, y: 40, width: w - 8, height: h - 40 - 30)
                fill(c, rr(body, 12), main)
                c.setStrokeColor(main.shade(0.7).cgColor)
                c.setLineWidth(3)
                for i in 1..<4 {
                    let y = body.minY + body.height * CGFloat(i) / 5
                    c.move(to: CGPoint(x: body.minX + 8, y: y))
                    c.addLine(to: CGPoint(x: body.maxX - 8, y: y))
                }
                c.strokePath()
                stripes(c, in: rr(CGRect(x: 10, y: body.maxY - 34, width: w - 20, height: 24), 6),
                        base: ink, stripe: accent, width: 14, diagonal: true)
                for x in [w * 0.24, w * 0.76] {
                    fill(c, circle(CGPoint(x: x, y: h - 22), 20), ink.shade(1.6))
                    fill(c, circle(CGPoint(x: x, y: h - 22), 7), accent, stroke: 2)
                }
            }
        }
    }

    // MARK: Scenery

    static func decorSize(_ kind: DecorKind) -> CGSize {
        switch kind {
        case .tree: return CGSize(width: 160, height: 220)
        case .barn: return CGSize(width: 240, height: 200)
        case .sunflower: return CGSize(width: 90, height: 210)
        case .cactus: return CGSize(width: 120, height: 210)
        case .mesa: return CGSize(width: 280, height: 170)
        case .pine: return CGSize(width: 140, height: 240)
        case .snowman: return CGSize(width: 110, height: 170)
        case .lavaRock: return CGSize(width: 180, height: 140)
        case .crystal: return CGSize(width: 120, height: 200)
        case .lollipop: return CGSize(width: 100, height: 230)
        case .gumdrop: return CGSize(width: 130, height: 110)
        }
    }

    static func decor(_ kind: DecorKind) -> UIImage {
        let size = decorSize(kind)
        return render(size) { c in
            let w = size.width, h = size.height
            switch kind {
            case .tree:
                fill(c, rr(CGRect(x: w / 2 - 12, y: h * 0.55, width: 24, height: h * 0.45 - 2), 6), UIColor(red: 0.47, green: 0.29, blue: 0.16, alpha: 1))
                let leaf = UIColor(red: 0.18, green: 0.72, blue: 0.26, alpha: 1)
                fill(c, circle(CGPoint(x: w * 0.32, y: h * 0.42), w * 0.26), leaf)
                fill(c, circle(CGPoint(x: w * 0.68, y: h * 0.42), w * 0.26), leaf)
                fill(c, circle(CGPoint(x: w * 0.5, y: h * 0.28), w * 0.3), leaf.shade(1.15))
                for p in [(0.3, 0.38), (0.62, 0.24), (0.7, 0.46), (0.46, 0.44)] {
                    fill(c, circle(CGPoint(x: w * p.0, y: h * p.1), 6), UIColor(red: 0.95, green: 0.16, blue: 0.2, alpha: 1), stroke: 2)
                }
            case .barn:
                let red = UIColor(red: 0.89, green: 0.17, blue: 0.17, alpha: 1)
                fill(c, poly([CGPoint(x: 6, y: h * 0.42), CGPoint(x: w / 2, y: 6), CGPoint(x: w - 6, y: h * 0.42)]), red.shade(0.7))
                fill(c, rr(CGRect(x: 18, y: h * 0.38, width: w - 36, height: h * 0.62 - 2), 4), red)
                let door = CGRect(x: w / 2 - 34, y: h * 0.58, width: 68, height: h * 0.42 - 4)
                fill(c, rr(door, 3), .white)
                c.setStrokeColor(red.cgColor)
                c.setLineWidth(6)
                c.move(to: CGPoint(x: door.minX + 6, y: door.minY + 6))
                c.addLine(to: CGPoint(x: door.maxX - 6, y: door.maxY - 6))
                c.move(to: CGPoint(x: door.maxX - 6, y: door.minY + 6))
                c.addLine(to: CGPoint(x: door.minX + 6, y: door.maxY - 6))
                c.strokePath()
                fill(c, rr(CGRect(x: w / 2 - 14, y: h * 0.22, width: 28, height: 26), 3), .white)
            case .sunflower:
                fill(c, rr(CGRect(x: w / 2 - 5, y: h * 0.35, width: 10, height: h * 0.65 - 2), 5), UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1))
                fill(c, ellipse(CGRect(x: w / 2, y: h * 0.6, width: 34, height: 16)), UIColor(red: 0.3, green: 0.7, blue: 0.25, alpha: 1))
                let center = CGPoint(x: w / 2, y: h * 0.25)
                for i in 0..<12 {
                    let a = CGFloat(i) / 12 * .pi * 2
                    fill(c, circle(CGPoint(x: center.x + cos(a) * 26, y: center.y + sin(a) * 26), 13),
                         UIColor(red: 1, green: 0.82, blue: 0.1, alpha: 1), stroke: 2)
                }
                fill(c, circle(center, 20), UIColor(red: 0.42, green: 0.25, blue: 0.1, alpha: 1))
            case .cactus:
                let green = UIColor(red: 0.13, green: 0.62, blue: 0.3, alpha: 1)
                fill(c, rr(CGRect(x: 6, y: h * 0.32, width: 26, height: h * 0.32), 13), green)
                fill(c, rr(CGRect(x: w - 32, y: h * 0.2, width: 26, height: h * 0.36), 13), green)
                fill(c, rr(CGRect(x: 6, y: h * 0.56, width: w / 2, height: 22), 11), green)
                fill(c, rr(CGRect(x: w / 2, y: h * 0.48, width: w / 2 - 6, height: 22), 11), green)
                fill(c, rr(CGRect(x: w / 2 - 20, y: 14, width: 40, height: h - 16), 20), green.shade(1.12))
                fill(c, circle(CGPoint(x: w / 2, y: 16), 10), UIColor(red: 1, green: 0.3, blue: 0.6, alpha: 1), stroke: 2)
            case .mesa:
                let base = UIColor(red: 0.85, green: 0.33, blue: 0.13, alpha: 1)
                let shape = poly([CGPoint(x: 0, y: h), CGPoint(x: w * 0.18, y: 12), CGPoint(x: w * 0.82, y: 12), CGPoint(x: w, y: h)])
                fill(c, shape, base)
                c.saveGState()
                c.addPath(shape)
                c.clip()
                c.setFillColor(base.shade(1.25).cgColor)
                c.fill(CGRect(x: 0, y: h * 0.35, width: w, height: 18))
                c.fill(CGRect(x: 0, y: h * 0.65, width: w, height: 14))
                c.restoreGState()
            case .pine:
                let green = UIColor(red: 0.05, green: 0.45, blue: 0.3, alpha: 1)
                fill(c, rr(CGRect(x: w / 2 - 10, y: h * 0.82, width: 20, height: h * 0.18 - 2), 4), UIColor(red: 0.4, green: 0.25, blue: 0.15, alpha: 1))
                for (i, top) in [CGFloat(0.02), 0.26, 0.5].enumerated() {
                    let spread = w * (0.3 + 0.1 * CGFloat(i))
                    let tri = poly([CGPoint(x: w / 2, y: h * top), CGPoint(x: w / 2 + spread, y: h * (top + 0.34)), CGPoint(x: w / 2 - spread, y: h * (top + 0.34))])
                    fill(c, tri, green.shade(1 + 0.12 * CGFloat(i)))
                    fill(c, poly([CGPoint(x: w / 2, y: h * top), CGPoint(x: w / 2 + spread * 0.35, y: h * (top + 0.12)), CGPoint(x: w / 2 - spread * 0.35, y: h * (top + 0.12))]), .white, stroke: 2)
                }
            case .snowman:
                fill(c, circle(CGPoint(x: w / 2, y: h - 38), 36), .white)
                fill(c, circle(CGPoint(x: w / 2, y: h - 92), 27), .white)
                fill(c, circle(CGPoint(x: w / 2, y: h - 134), 20), .white)
                fill(c, rr(CGRect(x: w / 2 - 28, y: h - 118, width: 56, height: 12), 6), UIColor(red: 0.9, green: 0.15, blue: 0.3, alpha: 1), stroke: 2)
                fill(c, poly([CGPoint(x: w / 2, y: h - 138), CGPoint(x: w / 2 + 22, y: h - 133), CGPoint(x: w / 2, y: h - 129)]), UIColor(red: 1, green: 0.5, blue: 0.1, alpha: 1), stroke: 1.5)
                fill(c, rr(CGRect(x: w / 2 - 18, y: h - 168, width: 36, height: 18), 3), ink, stroke: 0)
            case .lavaRock:
                let rock = poly([CGPoint(x: 6, y: h), CGPoint(x: 20, y: h * 0.4), CGPoint(x: w * 0.4, y: 10), CGPoint(x: w * 0.7, y: h * 0.3), CGPoint(x: w - 8, y: h * 0.55), CGPoint(x: w - 4, y: h)])
                fill(c, rock, UIColor(red: 0.2, green: 0.15, blue: 0.17, alpha: 1))
                c.setStrokeColor(UIColor(red: 1, green: 0.45, blue: 0.0, alpha: 1).cgColor)
                c.setLineWidth(5)
                c.setLineCap(.round)
                c.move(to: CGPoint(x: w * 0.4, y: 22))
                c.addLine(to: CGPoint(x: w * 0.45, y: h * 0.5))
                c.addLine(to: CGPoint(x: w * 0.3, y: h * 0.8))
                c.move(to: CGPoint(x: w * 0.45, y: h * 0.5))
                c.addLine(to: CGPoint(x: w * 0.7, y: h * 0.75))
                c.strokePath()
            case .crystal:
                let colors = [UIColor(red: 0.0, green: 0.9, blue: 1, alpha: 1), UIColor(red: 0.88, green: 0.25, blue: 0.98, alpha: 1), UIColor(red: 0.46, green: 1, blue: 0.0, alpha: 1)]
                let shards: [(CGFloat, CGFloat, CGFloat)] = [(0.28, 0.35, 22), (0.72, 0.25, 24), (0.5, 0.02, 30)]
                for (i, s) in shards.enumerated() {
                    let cx = w * s.0
                    fill(c, poly([CGPoint(x: cx, y: h * s.1), CGPoint(x: cx + s.2, y: h * s.1 + s.2 * 1.4), CGPoint(x: cx + s.2 * 0.7, y: h), CGPoint(x: cx - s.2 * 0.7, y: h), CGPoint(x: cx - s.2, y: h * s.1 + s.2 * 1.4)]), colors[i])
                }
            case .lollipop:
                fill(c, rr(CGRect(x: w / 2 - 5, y: h * 0.38, width: 10, height: h * 0.62 - 2), 5), .white)
                let center = CGPoint(x: w / 2, y: h * 0.22)
                fill(c, circle(center, w * 0.44), UIColor(red: 1, green: 0.25, blue: 0.5, alpha: 1))
                c.setStrokeColor(UIColor.white.cgColor)
                c.setLineWidth(7)
                let spiral = CGMutablePath()
                for i in 0...60 {
                    let t = CGFloat(i) / 60
                    let a = t * .pi * 5
                    let r = t * w * 0.38
                    let p = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
                    if i == 0 { spiral.move(to: p) } else { spiral.addLine(to: p) }
                }
                c.addPath(spiral)
                c.strokePath()
            case .gumdrop:
                let dome = CGMutablePath()
                dome.move(to: CGPoint(x: 6, y: h - 4))
                dome.addCurve(to: CGPoint(x: w - 6, y: h - 4), control1: CGPoint(x: 6, y: -10), control2: CGPoint(x: w - 6, y: -10))
                dome.closeSubpath()
                fill(c, dome, UIColor(red: 0.49, green: 0.3, blue: 1, alpha: 1))
                c.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
                for p in [(0.3, 0.5), (0.55, 0.35), (0.7, 0.62), (0.45, 0.7), (0.4, 0.3)] {
                    c.addPath(circle(CGPoint(x: w * p.0, y: h * p.1), 3.5))
                    c.fillPath()
                }
            }
        }
    }

    static func hills(pointy: Bool) -> UIImage {
        let size = CGSize(width: 720, height: 90)
        return render(size) { c in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: size.height))
            for xi in stride(from: 0, through: Int(size.width), by: 6) {
                let x = CGFloat(xi)
                let height: CGFloat
                if pointy {
                    let u = (x / 120).truncatingRemainder(dividingBy: 2)
                    let tri = 1 - abs(u - 1)
                    height = 18 + 60 * tri + 8 * sin(x / 17)
                } else {
                    height = 34 + 20 * sin(x / 70) + 12 * sin(x / 27 + 1)
                }
                p.addLine(to: CGPoint(x: x, y: size.height - height))
            }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
            c.addPath(p)
            c.setFillColor(UIColor.white.cgColor)
            c.fillPath()
        }
    }

    /// White fading from transparent (top) to opaque (bottom); tinted at runtime.
    static func verticalFade() -> UIImage {
        let size = CGSize(width: 8, height: 256)
        return render(size) { c in
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
    }

    static func glowDisc() -> UIImage {
        let size = CGSize(width: 160, height: 160)
        return render(size) { c in
            let center = CGPoint(x: 80, y: 80)
            let colors = [UIColor.white.withAlphaComponent(0.6).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                c.drawRadialGradient(g, startCenter: center, startRadius: 30, endCenter: center, endRadius: 80, options: [])
            }
            c.setFillColor(UIColor.white.cgColor)
            c.addPath(circle(center, 32))
            c.fillPath()
        }
    }

    static func softDot(diameter d: CGFloat, alpha: CGFloat = 1) -> UIImage {
        render(CGSize(width: d, height: d)) { c in
            let center = CGPoint(x: d / 2, y: d / 2)
            let colors = [UIColor.white.withAlphaComponent(alpha).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.35, 1]) {
                c.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: d / 2, options: [])
            }
        }
    }
}

/// Cached horse frames for SwiftUI screens.
enum HorseImages {
    private static var cache: [String: UIImage] = [:]

    static func frame(_ skin: Skin, _ index: Int) -> UIImage {
        let key = "\(skin.id)-\(index % 4)"
        if let img = cache[key] { return img }
        let img = Art.horse(skin, pose: .run(index))
        cache[key] = img
        return img
    }

    static let hayIcon = Art.hayBale(diameter: 64)
}
