import Foundation

/// Smooth 0...1 "inhale/exhale" curve with a slightly lingering peak. `p` is in cycles.
func breath(_ p: Double) -> Double {
    let x = 0.5 - 0.5 * cos(2 * .pi * p)
    return 0.03 + 0.97 * pow(x, 1.6)
}

/// Draws a text string for Your Text when the dot font can't (other scripts, emoji). The Mac supplies
/// one backed by the system font; it returns a coverage mask `height` pixels tall.
typealias TextRasterizer = (_ text: String, _ height: Int) -> (mask: [UInt8], width: Int)?

/// The renderer itself: turns (effect, time) into pixels. Plain Swift, so it runs anywhere; the Mac
/// wraps it in `EffectRenderer` (Effects.swift). Every effect is a pure function of time, so previews,
/// the Touch Bar, and the website's clips all show the same thing.
final class EffectCore {
    /// Pixels drawn.
    let w: Int, h: Int
    let canvas: Canvas
    /// The bar width effects lay out for. Usually `w`; wider for previews that show a window onto the bar.
    let layoutWidth: Double
    var W: Double { layoutWidth }
    var H: Double { Double(h) }
    /// The part of the bar actually drawn: all of it on the Touch Bar, a window in previews. Effects that
    /// roam (a bouncing logo, a ball) use this as their field so previews always show the action.
    var view: (x: Double, w: Double) { (canvas.ox, Double(w)) }

    struct Star { var u: Double; var period: Double; var offset: Double; var hue: Double }
    let stars: [Star]
    let glyphs: GlyphAtlas
    let rasterizer: TextRasterizer?
    /// Your Text rendered by the system font, cached by string.
    var textCache: (key: String, mask: [UInt8], width: Int)?
    /// When the Focus Timer started (wall clock), so switching effects restarts it.
    var focusStart: Double?
    /// Per-effect precomputed data (paths, layouts), keyed by name. See `cached`.
    var cache: [String: Any] = [:]

    init(width: Int, height: Int, layoutWidth: Double? = nil, glyphs: GlyphAtlas? = nil, rasterizer: TextRasterizer? = nil) {
        w = max(1, width); h = max(1, height)
        self.layoutWidth = max(Double(w), layoutWidth ?? 0)
        canvas = Canvas(width: w, height: h)
        canvas.layoutW = self.layoutWidth
        self.glyphs = glyphs ?? GlyphAtlas.dotFont(height: h)
        self.rasterizer = rasterizer
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func rnd() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        stars = (0..<70).map { _ in Star(u: rnd(), period: 2.2 + rnd() * 3.5, offset: rnd(), hue: rnd()) }
    }

    /// Renders one frame into 8-bit RGBA pixels (`w * h * 4` bytes; alpha is left alone).
    func render(_ p: Params, time t: Double, into px: UnsafeMutablePointer<UInt8>) {
        draw(p, time: t)
        canvas.write(to: px, brightness: p.brightness)
    }

    /// Renders one frame into the canvas.
    func draw(_ p: Params, time t: Double) {
        if layoutWidth > Double(w) {
            let focus = p.scene?.focus ?? p.effect.previewFocus
            canvas.ox = min(layoutWidth - Double(w), max(0, focus * layoutWidth - Double(w) / 2)).rounded()
        }
        if p.effect != .focusTimer { focusStart = nil }
        if let scene = p.scene {
            drawScene(scene, p, t)
        } else if let shader = classicShader(p, t) {
            canvas.shadeUV(shader)
        } else {
            drawLibrary(p, t)
        }
        if p.badge { drawBadge() }
    }

    // MARK: Free-plan tag

    /// A small "REVIVE" tag at the left end, on a dark plate so it reads over anything.
    private func drawBadge() {
        let dot = max(1, (H / 13).rounded(.down))
        let tw = Canvas.textWidth("REVIVE", dot: dot)
        let padX = dot * 2, plateH = dot * 7 + dot * 3
        let x = (H * 0.35).rounded(), y = ((H - plateH) / 2).rounded()
        canvas.rect(x, y, tw + padX * 2, plateH, .black, alpha: 0.72)
        canvas.text("REVIVE", x: x + padX, y: y + dot * 1.5, dot: dot, .white, alpha: 0.9)
    }

    // MARK: Direction

    /// Coordinates along a chosen direction, computed in real pixel space so 45° is a true diagonal.
    struct Axis {
        let cosT: Double, sinT: Double, w: Double, h: Double
        let pMin: Double, invSpan: Double, waveScale: Double
        /// Bar extent along the direction relative to the bar's width (1 when horizontal).
        let extent: Double

        init(degrees: Double, w: Int, h: Int) {
            let t = degrees * .pi / 180
            cosT = cos(t); sinT = sin(t); self.w = Double(w); self.h = Double(h)
            let corners = [0.0, self.w * cosT, self.h * sinT, self.w * cosT + self.h * sinT]
            pMin = corners.min()!
            let span = corners.max()! - pMin
            invSpan = 1 / span
            extent = span / self.w
            waveScale = abs(cosT) / self.w + abs(sinT) / self.h
        }

        /// `wave` repeats about once per bar length horizontally, or per bar height vertically (for repeating
        /// patterns). `along` runs 0...1 across the whole bar in that direction (for centered or travelling ones).
        @inline(__always) func at(_ u: Double, _ v: Double) -> (wave: Double, along: Double) {
            let p = u * w * cosT + v * h * sinT
            return (p * waveScale, (p - pMin) * invSpan)
        }
    }

    // MARK: The original ten (per-pixel shaders)

    private func classicShader(_ p: Params, _ t: Double) -> ((Double, Double) -> RGB)? {
        let c = p.color
        switch p.effect {

        case .rainbowWave:
            let slide = t * 0.06, width = p.width, ax = Axis(degrees: p.angle, w: Int(W), h: h)
            return { u, v in
                let c = ax.at(u, v)
                return .hsv(c.wave * width - slide + 0.05 * sin(2 * .pi * (c.along * 0.8 - slide * 0.9)), 1, 1)
            }

        case .spectrumCycle:
            let hue = t * 0.04, ax = Axis(degrees: p.angle, w: Int(W), h: h)
            return { u, v in .hsv(hue + ax.at(u, v).along * 0.05, 1, 1) }

        case .breathing:
            let b = breath(t * 0.28)
            return { _, v in c.scaled(b * (1 - 0.25 * abs(v - 0.5) * 2)) }

        case .neonBreath:
            let ph = t * 0.22, ax = Axis(degrees: p.angle, w: Int(W), h: h)
            return { u, v in
                let d = abs(ax.at(u, v).along - 0.5) * 2
                let b = breath(ph - d * 0.18)
                let core = pow(b, 6) * 0.55
                return RGB.hsv(t * 0.03 + d * 0.22, 1 - core, 1).scaled(b)
            }

        case .heartbeat:
            let per = 1.6, ph = (t * 1.0).truncatingRemainder(dividingBy: per), ax = Axis(degrees: p.angle, w: Int(W), h: h)
            return { u, v in
                let d = abs(ax.at(u, v).along - 0.5) * 2
                let tl = (ph - d * 0.35 + per).truncatingRemainder(dividingBy: per)
                let a = (tl - 0.12) / 0.08, b = (tl - 0.40) / 0.09
                let e = min(1, 0.95 * exp(-a * a) + 0.6 * exp(-b * b))
                return c.mixed(with: .white, pow(e, 3) * 0.5).scaled(0.05 + 0.95 * e)
            }

        case .scanner:
            let a = t * 0.55
            let pos = 0.5 + 0.47 * sin(a), dir = cos(a) >= 0 ? 1.0 : -1.0, ax = Axis(degrees: p.angle, w: Int(W), h: h)
            // Keep the comet a similar size in pixels when the bar is short along the chosen direction.
            let squeeze = 1 / ax.extent
            let headW = min(0.2, 0.012 * pow(squeeze, 0.8)), tailW = min(0.45, 0.09 * pow(squeeze, 0.5))
            return { u, v in
                let d = ax.at(u, v).along - pos
                let head = exp(-pow(d / headW, 2))
                let tail = d * dir < 0 ? 0.8 * exp(-abs(d) / tailW) : 0
                return c.mixed(with: .white, head * 0.6).scaled(0.04 + 0.96 * min(1, head + tail))
            }

        case .inferno:
            let s = t * 1.4
            return { u, v in
                let n = 0.5 * sin(u * 80 + s * 2.3 + 1.6 * sin(v * 6 - s * 3.1))
                    + 0.3 * sin(u * 150 - s * 1.9 + v * 11)
                    + 0.2 * sin(u * 41 + s * 1.1 - v * 4)
                let heat = min(1, max(0, 0.25 + v * 0.95 + n * 0.5 - 0.3))
                return RGB(r: min(1, heat * 2.6),
                           g: min(1, max(0, heat * 2.6 - 0.9)),
                           b: min(1, max(0, heat * 3 - 2.2)))
            }

        case .matrix:
            let g = glyphs
            let cw = Double(g.cellW), ch = Double(g.cellH), wD = W, hD = H
            let rows = hD / ch, trail = 7.0, atlas = g.mask, n = g.count, gw = g.cellW, gh = g.cellH, aw = g.cellW * g.count
            let flicker = UInt32(truncatingIfNeeded: Int(t * 5))
            return { u, v in
                let px = u * wD, py = v * hD, yy = py / ch
                let col = Int(px / cw), fx = px / cw - Double(col)
                let seed = hash32(UInt32(truncatingIfNeeded: col) &+ 17)
                let speed = 1.1 + Double(seed & 0xFF) / 255 * 2.4
                let period = rows + trail + 2 + Double((seed >> 8) & 0xF) * 0.7
                let offset = Double((seed >> 12) & 0xFFFF) / 65535 * period
                let head = (t * speed + offset).truncatingRemainder(dividingBy: period)
                var d = head - yy
                if d < 0 { d += period }
                let row = Int(yy.rounded(.down))
                let gid = Int(hash32(UInt32(truncatingIfNeeded: col) &* 7919 &+ UInt32(truncatingIfNeeded: row) &* 104729 &+ flicker &* (seed & 3)) % UInt32(n))
                let gx = gid * gw + min(gw - 1, Int(fx * cw))
                let gy = min(gh - 1, Int((yy - Double(row)) * ch))
                let mask = Double(atlas[gy * aw + gx]) / 255
                let rain = d < trail ? pow(1 - d / trail, 1.1) : 0
                let lit = min(1, rain * 1.15 + 0.09)
                return c.mixed(with: .white, d < 0.9 ? 0.75 : 0).scaled(mask * lit)
            }

        case .starfield:
            let n = Int(W)
            var cols = [RGB](repeating: RGB(r: 0.015, g: 0, b: 0.045), count: n)
            let wD = W
            for s in stars {
                let ph = (t / s.period + s.offset).truncatingRemainder(dividingBy: 1)
                let e = pow(max(0, sin(.pi * ph)), 6)
                if e < 0.01 { continue }
                let col = RGB.hsv(s.hue, 0.75, 1).mixed(with: .white, e * 0.5).scaled(e)
                let centre = s.u * wD, radius = max(2.0, wD * 0.004)
                for x in max(0, Int(centre - radius * 4))...min(n - 1, Int(centre + radius * 4)) {
                    let g = exp(-pow((Double(x) + 0.5 - centre) / radius, 2))
                    cols[x].r += col.r * g; cols[x].g += col.g * g; cols[x].b += col.b * g
                }
            }
            let last = n - 1
            return { u, v in cols[min(last, Int(u * wD))].scaled(1 - 0.35 * abs(v - 0.5) * 2) }

        case .solid:
            return { _, _ in c }

        default:
            return nil
        }
    }
}
