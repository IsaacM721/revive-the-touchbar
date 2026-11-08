import Foundation

/// A small floating-point RGB canvas the effects draw into, in pixel coordinates (x right, y down).
/// Shapes are anti-aliased so things can move by fractions of a pixel without shimmering.
final class Canvas {
    let w: Int, h: Int
    /// Interleaved RGB, linear 0...1 (values above 1 are clipped on output, so glows can stack).
    private(set) var buf: [Float]
    /// A preview can show a window onto a wider bar: effects draw in the full bar's coordinates
    /// (`layoutW` wide) and the canvas keeps the part starting at `ox`.
    var ox: Double = 0
    var layoutW: Double

    init(width: Int, height: Int) {
        w = width; h = height
        layoutW = Double(width)
        buf = [Float](repeating: 0, count: width * height * 3)
    }

    var W: Double { Double(w) }
    var H: Double { Double(h) }

    // MARK: Whole canvas

    func clear(_ c: RGB = .black) {
        let r = Float(c.r), g = Float(c.g), b = Float(c.b)
        buf.withUnsafeMutableBufferPointer { p in
            var i = 0
            while i < p.count { p[i] = r; p[i + 1] = g; p[i + 2] = b; i += 3 }
        }
    }

    /// Sets every pixel from a function of normalized coordinates (u across, v down, both 0...1, at pixel centers).
    func shadeUV(_ f: (Double, Double) -> RGB) {
        let lw = layoutW, hD = H, x0 = ox
        buf.withUnsafeMutableBufferPointer { p in
            for y in 0..<h {
                let v = (Double(y) + 0.5) / hD
                var o = y * w * 3
                for x in 0..<w {
                    let c = f((Double(x) + 0.5 + x0) / lw, v)
                    p[o] = Float(c.r); p[o + 1] = Float(c.g); p[o + 2] = Float(c.b)
                    o += 3
                }
            }
        }
    }

    /// Sets every pixel from a function of pixel coordinates (pixel centers, so the first is 0.5).
    func shade(_ f: (Double, Double) -> RGB) {
        let x0 = ox
        buf.withUnsafeMutableBufferPointer { p in
            for y in 0..<h {
                let yc = Double(y) + 0.5
                var o = y * w * 3
                for x in 0..<w {
                    let c = f(Double(x) + 0.5 + x0, yc)
                    p[o] = Float(c.r); p[o + 1] = Float(c.g); p[o + 2] = Float(c.b)
                    o += 3
                }
            }
        }
    }

    /// Like `shade`, but evaluates `f` on every other column and row and blends between them. A quarter
    /// of the cost, and invisible for smooth fields (nebulas, auroras, plasma, flames).
    func shadeSmooth(_ f: (Double, Double) -> RGB) {
        let n = w / 2 + 2, m = h / 2 + 2
        var grid = [RGB](repeating: .black, count: n * m)
        for j in 0..<m {
            let yc = Double(j * 2) + 0.5
            for k in 0..<n { grid[j * n + k] = f(Double(k * 2) + 0.5 + ox, yc) }
        }
        buf.withUnsafeMutableBufferPointer { p in
            for y in 0..<h {
                let j = y / 2, fy = y % 2 == 0 ? 0.0 : 0.5
                var o = y * w * 3
                for x in 0..<w {
                    let k = x / 2, fx = x % 2 == 0 ? 0.0 : 0.5
                    var c = grid[j * n + k]
                    if fx > 0 { c = c.mixed(with: grid[j * n + k + 1], fx) }
                    if fy > 0 {
                        var d = grid[(j + 1) * n + k]
                        if fx > 0 { d = d.mixed(with: grid[(j + 1) * n + k + 1], fx) }
                        c = c.mixed(with: d, fy)
                    }
                    p[o] = Float(c.r); p[o + 1] = Float(c.g); p[o + 2] = Float(c.b)
                    o += 3
                }
            }
        }
    }

    /// Multiplies every pixel by a function of pixel coordinates (vignettes, scanlines).
    func multiply(_ f: (Double, Double) -> Double) {
        buf.withUnsafeMutableBufferPointer { p in
            for y in 0..<h {
                var o = y * w * 3
                for x in 0..<w {
                    let k = Float(f(Double(x) + 0.5 + ox, Double(y) + 0.5))
                    p[o] *= k; p[o + 1] *= k; p[o + 2] *= k
                    o += 3
                }
            }
        }
    }

    /// Paints over pixels (rows from `y0` down) wherever `f` returns a color. For ground, overlays.
    func overlay(fromRow y0: Int = 0, _ f: (Double, Double) -> RGB?) {
        guard y0 < h else { return }
        buf.withUnsafeMutableBufferPointer { p in
            for y in max(0, y0)..<h {
                var o = y * w * 3
                for x in 0..<w {
                    if let c = f(Double(x) + 0.5 + ox, Double(y) + 0.5) { p[o] = Float(c.r); p[o + 1] = Float(c.g); p[o + 2] = Float(c.b) }
                    o += 3
                }
            }
        }
    }

    /// Slides rows `y0..<y1` sideways by `dx` pixels (glitches). Pixels pushed off one end are dropped.
    func shiftRows(_ y0: Int, _ y1: Int, by dx: Int) {
        guard dx != 0 else { return }
        for y in max(0, y0)..<min(h, max(y0, y1)) {
            let row = y * w * 3
            if dx > 0 {
                for x in stride(from: w - 1, through: 0, by: -1) {
                    let sx = x - dx, o = row + x * 3
                    if sx >= 0 { let so = row + sx * 3; buf[o] = buf[so]; buf[o + 1] = buf[so + 1]; buf[o + 2] = buf[so + 2] }
                    else { buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0 }
                }
            } else {
                for x in 0..<w {
                    let sx = x - dx, o = row + x * 3
                    if sx < w { let so = row + sx * 3; buf[o] = buf[so]; buf[o + 1] = buf[so + 1]; buf[o + 2] = buf[so + 2] }
                    else { buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0 }
                }
            }
        }
    }

    // MARK: Pixels

    @inline(__always) func blend(_ x: Int, _ y: Int, _ c: RGB, _ a: Double) {
        guard x >= 0, y >= 0, x < w, y < h, a > 0 else { return }
        let o = (y * w + x) * 3, k = Float(min(1, a))
        buf[o] += (Float(c.r) - buf[o]) * k
        buf[o + 1] += (Float(c.g) - buf[o + 1]) * k
        buf[o + 2] += (Float(c.b) - buf[o + 2]) * k
    }

    @inline(__always) func add(_ x: Int, _ y: Int, _ c: RGB, _ a: Double) {
        guard x >= 0, y >= 0, x < w, y < h, a > 0 else { return }
        let o = (y * w + x) * 3, k = Float(a)
        buf[o] += Float(c.r) * k; buf[o + 1] += Float(c.g) * k; buf[o + 2] += Float(c.b) * k
    }

    func pixel(_ x: Int, _ y: Int) -> RGB {
        guard x >= 0, y >= 0, x < w, y < h else { return .black }
        let o = (y * w + x) * 3
        return RGB(r: Double(buf[o]), g: Double(buf[o + 1]), b: Double(buf[o + 2]))
    }

    // MARK: Shapes

    /// Anti-aliased rectangle. `additive` adds light instead of painting over.
    func rect(_ x: Double, _ y: Double, _ rw: Double, _ rh: Double, _ c: RGB, alpha: Double = 1, additive: Bool = false) {
        guard rw > 0, rh > 0, alpha > 0 else { return }
        let x = x - ox
        let x1 = x + rw, y1 = y + rh
        let ix0 = max(0, Int(x.rounded(.down))), ix1 = min(w - 1, Int((x1 - 1e-9).rounded(.down)))
        let iy0 = max(0, Int(y.rounded(.down))), iy1 = min(h - 1, Int((y1 - 1e-9).rounded(.down)))
        guard ix0 <= ix1, iy0 <= iy1 else { return }
        for py in iy0...iy1 {
            let cy = min(y1, Double(py + 1)) - max(y, Double(py))
            if cy <= 0 { continue }
            for px in ix0...ix1 {
                let cx = min(x1, Double(px + 1)) - max(x, Double(px))
                if cx <= 0 { continue }
                let a = alpha * cx * cy
                additive ? add(px, py, c, a) : blend(px, py, c, a)
            }
        }
    }

    /// Filled, anti-aliased circle.
    func circle(_ cx: Double, _ cy: Double, _ r: Double, _ c: RGB, alpha: Double = 1, additive: Bool = false) {
        guard r > 0, alpha > 0 else { return }
        let cx = cx - ox
        let ix0 = max(0, Int((cx - r - 1).rounded(.down))), ix1 = min(w - 1, Int((cx + r + 1).rounded(.up)))
        let iy0 = max(0, Int((cy - r - 1).rounded(.down))), iy1 = min(h - 1, Int((cy + r + 1).rounded(.up)))
        guard ix0 <= ix1, iy0 <= iy1 else { return }
        for py in iy0...iy1 {
            let dy = Double(py) + 0.5 - cy
            for px in ix0...ix1 {
                let dx = Double(px) + 0.5 - cx
                let cov = min(1, max(0, r - (dx * dx + dy * dy).squareRoot() + 0.5))
                if cov > 0 { additive ? add(px, py, c, alpha * cov) : blend(px, py, c, alpha * cov) }
            }
        }
    }

    /// Filled, anti-aliased ellipse.
    func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: RGB, alpha: Double = 1, additive: Bool = false) {
        guard rx > 0.05, ry > 0.05, alpha > 0 else { return }
        let cx = cx - ox
        let ix0 = max(0, Int((cx - rx - 1).rounded(.down))), ix1 = min(w - 1, Int((cx + rx + 1).rounded(.up)))
        let iy0 = max(0, Int((cy - ry - 1).rounded(.down))), iy1 = min(h - 1, Int((cy + ry + 1).rounded(.up)))
        guard ix0 <= ix1, iy0 <= iy1 else { return }
        let m = min(rx, ry)
        for py in iy0...iy1 {
            let dy = (Double(py) + 0.5 - cy) / ry
            for px in ix0...ix1 {
                let dx = (Double(px) + 0.5 - cx) / rx
                // Distance to the edge in pixels, roughly: good enough for anti-aliasing.
                let cov = min(1, max(0, (1 - (dx * dx + dy * dy).squareRoot()) * m + 0.5))
                if cov > 0 { additive ? add(px, py, c, alpha * cov) : blend(px, py, c, alpha * cov) }
            }
        }
    }

    /// Filled, anti-aliased rounded rectangle. `r` is clamped to half the shorter side.
    func roundedRect(_ x: Double, _ y: Double, _ rw: Double, _ rh: Double, radius: Double, _ c: RGB, alpha: Double = 1) {
        guard rw > 0, rh > 0, alpha > 0 else { return }
        let x = x - ox
        let r = min(radius, rw / 2, rh / 2)
        let ix0 = max(0, Int(x.rounded(.down))), ix1 = min(w - 1, Int((x + rw).rounded(.up)))
        let iy0 = max(0, Int(y.rounded(.down))), iy1 = min(h - 1, Int((y + rh).rounded(.up)))
        guard ix0 <= ix1, iy0 <= iy1 else { return }
        let cx = x + rw / 2, cy = y + rh / 2, hx = rw / 2 - r, hy = rh / 2 - r
        for py in iy0...iy1 {
            let qy = max(0, abs(Double(py) + 0.5 - cy) - hy)
            for px in ix0...ix1 {
                let qx = max(0, abs(Double(px) + 0.5 - cx) - hx)
                let d = (qx * qx + qy * qy).squareRoot() - r
                let cov = min(1, max(0, 0.5 - d))
                if cov > 0 { blend(px, py, c, alpha * cov) }
            }
        }
    }

    /// Soft additive light, a Gaussian blob. `r` is the spread (the light fades out by about 2.5r).
    func glow(_ cx: Double, _ cy: Double, _ r: Double, _ c: RGB, _ strength: Double = 1) {
        guard r > 0, strength > 0 else { return }
        let cx = cx - ox
        let reach = r * 2.6
        let ix0 = max(0, Int((cx - reach).rounded(.down))), ix1 = min(w - 1, Int((cx + reach).rounded(.up)))
        let iy0 = max(0, Int((cy - reach).rounded(.down))), iy1 = min(h - 1, Int((cy + reach).rounded(.up)))
        guard ix0 <= ix1, iy0 <= iy1 else { return }
        let inv = 1 / (r * r)
        for py in iy0...iy1 {
            let dy = Double(py) + 0.5 - cy
            for px in ix0...ix1 {
                let dx = Double(px) + 0.5 - cx
                let e = exp(-(dx * dx + dy * dy) * inv)
                if e > 0.004 { add(px, py, c, strength * e) }
            }
        }
    }

    /// Anti-aliased line with round ends.
    func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, width lw: Double, _ c: RGB, alpha: Double = 1, additive: Bool = false) {
        let x0 = x0 - ox, x1 = x1 - ox
        let half = lw / 2
        let ix0 = max(0, Int((min(x0, x1) - half - 1).rounded(.down))), ix1 = min(w - 1, Int((max(x0, x1) + half + 1).rounded(.up)))
        let iy0 = max(0, Int((min(y0, y1) - half - 1).rounded(.down))), iy1 = min(h - 1, Int((max(y0, y1) + half + 1).rounded(.up)))
        guard ix0 <= ix1, iy0 <= iy1 else { return }
        let dx = x1 - x0, dy = y1 - y0, len2 = max(1e-9, dx * dx + dy * dy)
        for py in iy0...iy1 {
            for px in ix0...ix1 {
                let qx = Double(px) + 0.5, qy = Double(py) + 0.5
                let t = min(1, max(0, ((qx - x0) * dx + (qy - y0) * dy) / len2))
                let ex = qx - (x0 + t * dx), ey = qy - (y0 + t * dy)
                let cov = min(1, max(0, half - (ex * ex + ey * ey).squareRoot() + 0.5))
                if cov > 0 { additive ? add(px, py, c, alpha * cov) : blend(px, py, c, alpha * cov) }
            }
        }
    }

    // MARK: Text

    enum TextStyle {
        /// Square dots that touch, like a pixel font.
        case block
        /// Round dots with a gap and a soft halo, like an LED sign.
        case led
    }

    /// Width of `s` in pixels at a dot size.
    static func textWidth(_ s: String, dot: Double) -> Double { Double(PixelFont.width(s)) * dot }

    /// Draws `s` with its top-left corner at (x, y). Returns the width drawn. Characters outside the
    /// canvas are skipped cheaply, so long scrolling strings are fine.
    @discardableResult
    func text(_ s: String, x: Double, y: Double, dot: Double, _ c: RGB, style: TextStyle = .block, alpha: Double = 1, glow halo: Double = 0) -> Double {
        var pen = x
        for ch in s {
            let g = PixelFont.glyph(ch)
            let gw = Double(g.width) * dot
            if pen - ox + gw >= -dot && pen - ox < W + dot {
                for (dx, dy) in g.dots {
                    let px = pen + Double(dx) * dot, py = y + Double(dy) * dot
                    switch style {
                    case .block:
                        rect(px, py, dot, dot, c, alpha: alpha)
                        if halo > 0 { glow(px + dot / 2, py + dot / 2, dot * 1.1, c, halo * alpha) }
                    case .led:
                        circle(px + dot / 2, py + dot / 2, dot * 0.46, c, alpha: alpha)
                        glow(px + dot / 2, py + dot / 2, dot * 0.9, c, 0.12 * alpha)
                    }
                }
            }
            pen += gw + dot
        }
        return pen - x - dot
    }

    /// Text centered on (cx, cy).
    @discardableResult
    func text(_ s: String, centerX cx: Double, centerY cy: Double, dot: Double, _ c: RGB, style: TextStyle = .block, alpha: Double = 1, glow halo: Double = 0) -> Double {
        let tw = Canvas.textWidth(s, dot: dot)
        return text(s, x: (cx - tw / 2).rounded(), y: (cy - Double(PixelFont.rows) * dot / 2).rounded(), dot: dot, c, style: style, alpha: alpha, glow: halo)
    }

    /// Draws a coverage mask (0...255, `mw` x `mh`) with its top-left at (x, y), tinted. Used for text
    /// rendered by the system (any language) in Your Text.
    func mask(_ m: [UInt8], _ mw: Int, _ mh: Int, x: Int, y: Int, _ c: RGB, alpha: Double = 1) {
        let x = x - Int(ox.rounded())
        let x0 = max(0, -x), x1 = min(mw, w - x), y0 = max(0, -y), y1 = min(mh, h - y)
        guard x0 < x1, y0 < y1 else { return }
        for my in y0..<y1 {
            for mx in x0..<x1 {
                let v = m[my * mw + mx]
                if v > 0 { blend(x + mx, y + my, c, alpha * Double(v) / 255) }
            }
        }
    }

    // MARK: Sprites

    /// Draws a pixel-art sprite scaled so each cell is `dot` pixels. `flip` mirrors it left to right.
    func sprite(_ s: Sprite, x: Double, y: Double, dot: Double, flip: Bool = false, alpha: Double = 1, tint: RGB? = nil) {
        for cell in s.cells {
            let cx = flip ? s.w - 1 - cell.x : cell.x
            rect(x + Double(cx) * dot, y + Double(cell.y) * dot, dot, dot, tint ?? cell.c, alpha: alpha)
        }
    }

    // MARK: Output

    /// Writes 8-bit RGBA (alpha untouched), scaled by `brightness`.
    func write(to px: UnsafeMutablePointer<UInt8>, brightness k: Double) {
        let kf = Float(k)
        buf.withUnsafeBufferPointer { p in
            var i = 0, o = 0
            let n = w * h
            for _ in 0..<n {
                px[o] = Canvas.byte(p[i] * kf); px[o + 1] = Canvas.byte(p[i + 1] * kf); px[o + 2] = Canvas.byte(p[i + 2] * kf)
                i += 3; o += 4
            }
        }
    }

    @inline(__always) private static func byte(_ x: Float) -> UInt8 { UInt8(min(1, max(0, x)) * 255 + 0.5) }
}

/// Pixel art. Rows of characters; each character maps to a color in the palette, "." and " " are clear.
struct Sprite {
    struct Cell { let x: Int, y: Int, c: RGB }
    let w: Int, h: Int
    let cells: [Cell]

    init(_ rows: [String], _ palette: [Character: RGB]) {
        h = rows.count
        w = rows.map(\.count).max() ?? 0
        var out: [Cell] = []
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." && ch != " " {
                if let c = palette[ch] { out.append(Cell(x: x, y: y, c: c)) }
            }
        }
        cells = out
    }
}

// MARK: - Randomness that repeats (so every frame is a pure function of time)

@inline(__always) func hash32(_ x: UInt32) -> UInt32 {
    var h = x &* 0x9E37_79B1
    h ^= h >> 15; h = h &* 0x85EB_CA77
    h ^= h >> 13; h = h &* 0xC2B2_AE3D
    h ^= h >> 16
    return h
}

/// A stable pseudo-random number in 0..<1 for (i, salt).
@inline(__always) func rand01(_ i: Int, _ salt: UInt32 = 0) -> Double {
    Double(hash32(UInt32(truncatingIfNeeded: i) &* 2_654_435_761 &+ salt &* 40_503 &+ 0x68E3_1DA4)) / 4_294_967_296
}

/// Smooth value noise in 1D, 0...1.
func noise1(_ x: Double, _ salt: UInt32 = 0) -> Double {
    let i = Int(x.rounded(.down)), f = x - x.rounded(.down)
    let s = f * f * (3 - 2 * f)
    return rand01(i, salt) * (1 - s) + rand01(i + 1, salt) * s
}

/// Smooth value noise in 2D, 0...1.
func noise2(_ x: Double, _ y: Double, _ salt: UInt32 = 0) -> Double {
    let ix = Int(x.rounded(.down)), iy = Int(y.rounded(.down))
    let fx = x - Double(ix), fy = y - Double(iy)
    let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
    @inline(__always) func r(_ a: Int, _ b: Int) -> Double { rand01(a &* 7919 &+ b &* 104_729, salt) }
    let a = r(ix, iy), b = r(ix + 1, iy), c = r(ix, iy + 1), d = r(ix + 1, iy + 1)
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy
}

/// Fractal noise: a few octaves of noise2, 0...1.
func fbm(_ x: Double, _ y: Double, octaves: Int = 4, _ salt: UInt32 = 0) -> Double {
    var sum = 0.0, amp = 0.5, fx = x, fy = y, norm = 0.0
    for o in 0..<octaves {
        sum += amp * noise2(fx, fy, salt &+ UInt32(o) &* 131)
        norm += amp; amp *= 0.5; fx *= 2.03; fy *= 2.03
    }
    return sum / norm
}

@inline(__always) func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(1, max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

@inline(__always) func fract(_ x: Double) -> Double { x - x.rounded(.down) }

@inline(__always) func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
