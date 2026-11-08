import Foundation

// Ambient: slow, calm light. Most of these are per-pixel fields plus a few drawn particles.

extension EffectCore {

    func aurora(_ t: Double) {
        let hD = H
        let green = RGB(r: 0.12, g: 1.0, b: 0.5), violet = RGB(r: 0.62, g: 0.22, b: 1.0), pink = RGB(r: 1.0, g: 0.25, b: 0.6)
        canvas.shadeSmooth { (x: Double, y: Double) -> RGB in
            let v = y / hD, xs = x / hD
            let warp = fbm(xs * 0.05 + t * 0.025, t * 0.04, octaves: 3, 11) * 5
            let edge = 0.66 + 0.2 * sin(xs * 0.16 + warp) + 0.07 * sin(xs * 0.85 - t * 0.55)
            let d: Double = v - edge
            let body = d < 0 ? exp(d / 0.5) : exp(-d / 0.06)
            let envelope = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(xs * 0.09 + warp * 1.2 - t * 0.18), 2)
            let rays = 0.45 + 0.55 * noise1(xs * 1.8 + warp * 0.7 + t * 0.35, 5)
            let k = body * envelope * rays
            let high = clamp01(-d * 1.7)
            let col = green.mixed(with: violet, high).mixed(with: pink, clamp01(high - 0.6) * 0.8)
            let sky = RGB(r: 0.008, g: 0.018 + 0.02 * v, b: 0.05 + 0.02 * v)
            return sky.adding(col.scaled(k * 1.15))
        }
        // A few faint stars above the lights.
        let n = Int(W / 40)
        for i in 0..<n {
            let tw = 0.5 + 0.5 * sin(t * (1.3 + rand01(i, 3)) + rand01(i, 4) * 6.3)
            canvas.circle(rand01(i, 1) * W, rand01(i, 2) * H * 0.5, max(0.5, H * 0.02), .white, alpha: 0.25 + 0.35 * tw)
        }
    }

    func rain(_ t: Double) {
        let hD = H, wD = W
        canvas.shade { (_: Double, y: Double) -> RGB in
            let v = y / hD
            return RGB(r: 0.02 + 0.025 * v, g: 0.03 + 0.035 * v, b: 0.065 + 0.05 * v)
        }
        // Lightning, now and then: a bright flash and a softer echo.
        let storm = fract(t / 11)
        let flash = storm < 0.012 ? 1 - storm / 0.012 : (storm > 0.02 && storm < 0.03 ? 0.55 : 0)
        if flash > 0 { canvas.rect(0, 0, wD, hD, RGB(r: 0.55, g: 0.6, b: 0.85), alpha: flash * 0.45, additive: true) }

        let slant = 0.22
        let n = max(14, Int(wD / 7))
        let drop = RGB(r: 0.62, g: 0.74, b: 0.98)
        for i in 0..<n {
            let period = 0.5 + rand01(i, 1) * 0.45
            let cyc = t / period + rand01(i, 2)
            let k = Int(cyc.rounded(.down)), f = cyc - Double(k)
            let depth = rand01(i, 5)
            let x0 = rand01(i &* 131 &+ k, 3) * (wD + hD) - hD * 0.5
            let len = hD * (0.3 + depth * 0.45)
            let fall = 0.62
            if f < fall {
                let yh = -len + (hD + len) * (f / fall)
                let xh = x0 + yh * slant
                canvas.line(xh - len * slant, yh - len, xh, yh, width: 0.55 + depth * 0.8, drop, alpha: 0.18 + depth * 0.5, additive: true)
            } else if f < fall + 0.14 {
                let a = (f - fall) / 0.14
                let xs = x0 + hD * slant
                canvas.ellipse(xs, hD - 1.2, 0.8 + a * hD * 0.22, 0.6 + a * 0.9, drop, alpha: (1 - a) * (0.2 + depth * 0.4), additive: true)
            }
        }
        // Wet ground catches a little light.
        canvas.rect(0, hD - max(1, hD * 0.06), wD, max(1, hD * 0.06), RGB(r: 0.25, g: 0.32, b: 0.45), alpha: 0.35 + flash * 0.4)
    }

    private static let fishShapes: [[String]] = [
        ["a...bbb...",
         "aa.aaaaaa.",
         "aaaabaaaea",
         "aa.aaaaaa.",
         "a...bbb..."],
        ["..bb...",
         ".aaaa.a",
         "aaaeaaa",
         ".aaaa.a",
         "..bb..."],
        ["...b.....",
         "a.aaaa...",
         "aaaaaaaa.",
         "aaabbaaea",
         "a.aaaaa..",
         "...b....."],
    ]

    func aquarium(_ t: Double) {
        let hD = H, wD = W
        canvas.shade { (x: Double, y: Double) -> RGB in
            let v = y / hD
            let c1 = sin(x * 0.07 + 1.4 * sin(y * 0.25 + t * 0.9) + t * 0.7)
            let c2 = sin(x * 0.043 - t * 0.55 + y * 0.18)
            let caustic = pow(max(0, c1 * c2), 2) * (1 - v)
            return RGB(r: 0.0 + 0.04 * caustic, g: 0.2 - 0.12 * v + 0.35 * caustic, b: 0.36 - 0.18 * v + 0.35 * caustic)
        }
        // Sand.
        let sandH = hD * 0.12
        canvas.rect(0, hD - sandH, wD, sandH, RGB(r: 0.55, g: 0.45, b: 0.26))
        // Seaweed swaying.
        let strands = max(3, Int(wD / (hD * 5)))
        for i in 0..<strands {
            let bx = (Double(i) + 0.3 + rand01(i, 21) * 0.4) / Double(strands) * wD
            let tall = hD * (0.45 + rand01(i, 22) * 0.4)
            let segs = 14
            var px = bx, py = hD - sandH
            for s in 1...segs {
                let f = Double(s) / Double(segs)
                let nx = bx + sin(t * 1.4 + Double(i) * 1.7 + f * 3) * hD * 0.12 * f
                let ny = hD - sandH - tall * f
                canvas.line(px, py, nx, ny, width: max(1, hD * 0.07 * (1.2 - f)), RGB(r: 0.1, g: 0.55 - 0.2 * f, b: 0.25), alpha: 0.95)
                px = nx; py = ny
            }
        }
        // Fish.
        let palettes: [(RGB, RGB)] = [
            (RGB(0xFF7A00), .white), (RGB(0x2979FF), RGB(0xFFD600)), (RGB(0xFFD600), RGB(0xFF7A00)),
            (RGB(0xFF2BD6), RGB(0x9D4DFF)), (RGB(0x00E5FF), .white), (RGB(0xFF1744), RGB(0xFFD600)),
        ]
        let dot = max(1, hD / 12)
        let count = max(4, Int(wD / (hD * 4.5)))
        for i in 0..<count {
            let shape = EffectCore.fishShapes[i % EffectCore.fishShapes.count]
            let (body, fin) = palettes[(i * 7 + 3) % palettes.count]
            let sprite = cached("fish\(i)") { Sprite(shape, ["a": body, "b": fin, "e": RGB(r: 0.02, g: 0.02, b: 0.05)]) }
            let right = i % 2 == 0
            let speed = hD * (0.7 + rand01(i, 31) * 1.3)
            let span = wD + Double(sprite.w) * dot * 2
            let travel = fract(rand01(i, 32) + t * speed / span) * span - Double(sprite.w) * dot
            let x = right ? travel : wD - travel - Double(sprite.w) * dot
            let y = hD * (0.12 + rand01(i, 33) * 0.5) + sin(t * 1.6 + Double(i)) * hD * 0.05
            canvas.sprite(sprite, x: x, y: y, dot: dot, flip: !right)
        }
        // Bubbles.
        let bubbles = max(6, Int(wD / (hD * 2)))
        for i in 0..<bubbles {
            let period = 2.5 + rand01(i, 41) * 2.5
            let f = fract(t / period + rand01(i, 42))
            let bx = rand01(i &* 17 &+ Int((t / period + rand01(i, 42)).rounded(.down)), 43) * wD + sin(t * 3 + Double(i)) * hD * 0.05
            let by = hD - sandH - f * hD
            let r = hD * (0.035 + rand01(i, 44) * 0.045)
            canvas.circle(bx, by, r, RGB(r: 0.7, g: 0.95, b: 1), alpha: 0.28)
            canvas.circle(bx - r * 0.3, by - r * 0.3, r * 0.35, .white, alpha: 0.6)
        }
    }

    func galaxy(_ t: Double) {
        let hD = H
        let deep = RGB(r: 0.02, g: 0.01, b: 0.07), magenta = RGB(r: 0.75, g: 0.12, b: 0.6), teal = RGB(r: 0.05, g: 0.45, b: 0.75)
        canvas.shadeSmooth { (x: Double, y: Double) -> RGB in
            let xs = x / hD, v = y / hD
            let n1 = fbm(xs * 0.28 - t * 0.03, v * 1.2 + 3, octaves: 4, 1)
            let n2 = fbm(xs * 0.2 + 7 - t * 0.02, v * 1.6 - t * 0.01, octaves: 3, 2)
            let a = pow(n1, 2.4) * 2.2, b = pow(n2, 3) * 2.4
            return deep.adding(magenta.scaled(a)).adding(teal.scaled(b))
        }
        let n = Int(W / 6)
        for i in 0..<n {
            let x = fract(rand01(i, 1) - t * 0.004 * (0.5 + rand01(i, 9))) * W
            let tw = 0.55 + 0.45 * sin(t * (0.8 + rand01(i, 3) * 2) + rand01(i, 4) * 6.3)
            let big = rand01(i, 5) > 0.93
            canvas.circle(x, rand01(i, 2) * hD, max(0.45, hD * (big ? 0.035 : 0.018)), RGB.hsv(0.55 + rand01(i, 6) * 0.15, 0.2, 1), alpha: 0.35 + 0.6 * tw)
            if big {
                let s = hD * 0.18 * tw
                canvas.line(x - s, rand01(i, 2) * hD, x + s, rand01(i, 2) * hD, width: 0.6, .white, alpha: 0.5, additive: true)
                canvas.line(x, rand01(i, 2) * hD - s, x, rand01(i, 2) * hD + s, width: 0.6, .white, alpha: 0.5, additive: true)
            }
        }
        // A distant spiral galaxy drifting by.
        let gx = fract(0.35 - t * 0.006) * (W + hD * 4) - hD * 2
        canvas.glow(gx, hD * 0.5, hD * 0.5, RGB(r: 0.35, g: 0.3, b: 0.6), 0.5)
        canvas.glow(gx, hD * 0.5, hD * 0.18, RGB(r: 1, g: 0.85, b: 0.7), 0.9)
        for arm in 0..<2 {
            for k in 0..<24 {
                let f = Double(k) / 24
                let ang = f * 5.5 + Double(arm) * .pi + t * 0.15
                let r = hD * (0.1 + f * 0.9)
                canvas.glow(gx + cos(ang) * r * 1.6, hD * 0.5 + sin(ang) * r * 0.45, hD * 0.09, RGB(r: 0.55, g: 0.6, b: 1), 0.35 * (1 - f))
            }
        }
    }

    func fireflies(_ t: Double) {
        let hD = H, wD = W
        canvas.shade { (x: Double, y: Double) -> RGB in
            let v = y / hD
            let grass = hD * (0.14 + 0.16 * noise1(x * 0.35, 3) + 0.1 * noise1(x * 1.3, 4))
            if y > hD - grass { return RGB(r: 0.01, g: 0.07, b: 0.03) }
            return RGB(r: 0.005, g: 0.02 + 0.03 * v, b: 0.06 + 0.02 * v)
        }
        let n = max(10, Int(wD / (hD * 0.7)))
        for i in 0..<n {
            let base = (Double(i) + rand01(i, 1)) / Double(n) * wD
            let x = base + (noise1(t * 0.18 + Double(i) * 3.1, 7) - 0.5) * hD * 3
            let y = hD * (0.12 + 0.62 * noise1(t * 0.22 + Double(i) * 7.7, 3))
            let blink: Double = pow(max(0, sin(t * (1.1 + rand01(i, 2) * 1.4) + rand01(i, 3) * 6.28)), 2)
            let warm = RGB(r: 0.78, g: 1.0, b: 0.28)
            canvas.glow(x, y, hD * 0.28, warm, 0.7 * blink)
            canvas.circle(x, y, max(0.8, hD * 0.06), RGB(r: 0.95, g: 1, b: 0.7), alpha: 0.2 + 0.8 * blink)
        }
    }

    func sunset(_ t: Double) {
        let hD = H, wD = W
        let horizon = hD * 0.6
        let sx = wD * 0.5, sr = hD * 0.62, sy = horizon + hD * 0.12
        canvas.shade { (x: Double, y: Double) -> RGB in
            if y < horizon {
                let v = y / horizon
                let top = RGB(r: 0.16, g: 0.04, b: 0.3), mid = RGB(r: 0.85, g: 0.22, b: 0.38), low = RGB(r: 1, g: 0.62, b: 0.22)
                var c = v < 0.55 ? top.mixed(with: mid, v / 0.55) : mid.mixed(with: low, (v - 0.55) / 0.45)
                let dx = (x - sx) / hD, dy = (y - sy) / hD
                let sunGlow: Double = 0.5 * exp(-(dx * dx * 0.15 + dy * dy * 2))
                c = c.adding(RGB(r: 1, g: 0.55, b: 0.2).scaled(sunGlow))
                return c
            }
            let d = (y - horizon) / (hD - horizon)
            var c = RGB(r: 0.16 - 0.08 * d, g: 0.05, b: 0.2 - 0.05 * d)
            let spread: Double = sr * (1.2 + d * 2.5)
            let col: Double = exp(-pow((x - sx) / spread, 2))
            let shimmer: Double = pow(0.5 + 0.5 * sin(x * 0.45 + y * 2.1 - t * 2.4 + 2 * sin(x * 0.05 + t)), 3)
            c = c.adding(RGB(r: 1, g: 0.55, b: 0.25).scaled(col * shimmer * (0.95 - d * 0.5)))
            let bands: Double = 0.5 + 0.5 * sin(y * 2.4 + t * 1.2 + x * 0.02)
            return c.adding(RGB(r: 0.3, g: 0.08, b: 0.2).scaled(bands * 0.15))
        }
        // The sun, clipped by the horizon.
        for py in 0..<Int(horizon.rounded(.up)) {
            let yc = Double(py) + 0.5
            let dy = yc - sy
            guard abs(dy) < sr else { continue }
            let half = (sr * sr - dy * dy).squareRoot()
            let cov = min(1, horizon - Double(py))
            let heat = clamp01((yc - (sy - sr)) / (sr * 1.4))
            canvas.rect(sx - half, Double(py), half * 2, 1, RGB(r: 1, g: 0.85 - 0.3 * heat, b: 0.45 - 0.3 * heat), alpha: cov)
        }
        // Thin clouds.
        for i in 0..<3 {
            let cx = fract(rand01(i, 5) + t * 0.004 * Double(i + 1)) * (wD + hD * 8) - hD * 4
            canvas.ellipse(cx, hD * (0.15 + 0.12 * Double(i)), hD * (2.5 + Double(i)), hD * 0.05, RGB(r: 0.45, g: 0.12, b: 0.35), alpha: 0.7)
        }
        // A few birds cross now and then.
        let flock = fract(t / 24)
        if flock < 0.5 {
            let fx = -hD * 2 + flock / 0.5 * (wD + hD * 4)
            for b in 0..<3 {
                let bx = fx - Double(b) * hD * 0.7, by = hD * (0.22 + 0.08 * Double(b % 2))
                let flap = sin(t * 9 + Double(b)) * hD * 0.04
                let s = hD * 0.09
                canvas.line(bx - s, by - s * 0.4 + flap, bx, by, width: 0.9, RGB(r: 0.12, g: 0.03, b: 0.12))
                canvas.line(bx, by, bx + s, by - s * 0.4 + flap, width: 0.9, RGB(r: 0.12, g: 0.03, b: 0.12))
            }
        }
    }

    func lavaLamp(_ t: Double) {
        let hD = H, wD = W
        let n = max(5, Int(wD / (hD * 2.2)))
        var blobs: [(x: Double, y: Double, r2: Double)] = []
        for i in 0..<n {
            let x = fract(rand01(i, 1) + t * 0.006 * (rand01(i, 2) - 0.5)) * wD + sin(t * 0.35 + Double(i) * 2) * hD * 0.8
            let y = hD * (0.5 + 0.42 * sin(t * (0.25 + rand01(i, 3) * 0.3) + rand01(i, 4) * 6.28))
            let r = hD * (0.28 + rand01(i, 5) * 0.22)
            blobs.append((x, y, r * r))
        }
        let hot = RGB(r: 1, g: 0.18, b: 0.5), warm = RGB(r: 1, g: 0.58, b: 0.1)
        canvas.shadeSmooth { (x: Double, y: Double) -> RGB in
            var f = 0.0
            for b in blobs {
                var dx = x - b.x
                if dx > wD / 2 { dx -= wD } else if dx < -wD / 2 { dx += wD }
                let dy = y - b.y
                f += b.r2 / (dx * dx + dy * dy + 1)
            }
            let v = y / hD
            let body = smoothstep(0.85, 1.15, f)
            let col = hot.mixed(with: warm, v)
            let rim = exp(-pow((f - 1.05) / 0.12, 2)) * 0.5
            let bg = RGB(r: 0.1, g: 0.015, b: 0.16).adding(col.scaled(min(0.35, f * 0.12)))
            return bg.mixed(with: col.adding(RGB(r: rim, g: rim * 0.8, b: rim * 0.6)), body)
        }
    }

    func snowfall(_ t: Double) {
        let hD = H, wD = W
        canvas.shade { (_: Double, y: Double) -> RGB in
            let v = y / hD
            return RGB(r: 0.02 + 0.03 * v, g: 0.03 + 0.04 * v, b: 0.08 + 0.06 * v)
        }
        let n = max(20, Int(wD / 5))
        for i in 0..<n {
            let depth = rand01(i, 1)
            let speed = hD * (0.18 + depth * 0.35)
            let span = hD * 1.3
            let y = fract(rand01(i, 2) + t * speed / span) * span - hD * 0.15
            let x = fract(rand01(i, 3) + t * 0.004 * (0.5 + depth)) * (wD + hD) - hD * 0.5 + sin(t * (0.6 + depth) + Double(i)) * hD * 0.25
            let r = hD * (0.02 + depth * 0.05)
            canvas.circle(x, y, max(0.5, r), .white, alpha: 0.35 + depth * 0.6)
            if depth > 0.8 { canvas.glow(x, y, r * 2.5, RGB(r: 0.7, g: 0.8, b: 1), 0.25) }
        }
        // Snow on the ground.
        canvas.overlay(fromRow: Int(hD * 0.82)) { x, y in
            let top = hD * (0.9 - 0.05 * noise1(x * 0.08, 5) - 0.03 * noise1(x * 0.4, 6))
            return y >= top ? RGB(r: 0.8, g: 0.85, b: 0.95).scaled(0.75 + 0.25 * (y - top) / hD) : nil
        }
    }
}
