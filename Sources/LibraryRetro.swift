import Foundation

// Retro: demo scene, arcade, and CRT nostalgia.

extension EffectCore {

    func plasma(_ t: Double) {
        let hD = H
        canvas.shadeSmooth { (x: Double, y: Double) -> RGB in
            let xs: Double = x / hD * 0.95, ys: Double = y / hD * 1.6
            var v: Double = sin(xs + t)
            v += sin(ys * 0.9 + xs * 0.35 + t * 0.7)
            v += sin(xs * 0.6 + ys * 0.8 - t * 0.6)
            let cx: Double = xs * 0.35 + 0.8 * sin(t * 0.33), cy: Double = ys + 0.8 * cos(t * 0.5)
            v += sin((cx * cx + cy * cy).squareRoot() * 1.6 + t)
            let a: Double = .pi * v * 0.5
            return RGB(r: 0.5 + 0.5 * sin(a), g: 0.5 + 0.5 * sin(a + 2.09), b: 0.5 + 0.5 * sin(a + 4.19))
        }
    }

    func bouncingLogo(_ t: Double) {
        canvas.clear()
        let dot = max(1, (H / 15).rounded())
        let label = "REVIVE"
        let tw = Canvas.textWidth(label, dot: dot)
        let bw = tw + dot * 5, bh = dot * 7 + dot * 3.5
        let field = view
        let travelX = max(1, field.w - bw), travelY = max(1, H - bh)
        // Cross the bar in about 14 s. Vertical rate is chosen so it hits a corner every second lap.
        let tx = travelX / (H * 2.2)
        let k = max(1, (tx / 1.4).rounded())
        let ty = 2 * tx / (2 * k + 1)
        let tt = t + 2 * tx - 5                        // first corner about 5 s in
        let bx = bounce(tt / tx), by = bounce(tt / ty)
        let colors: [RGB] = [RGB(0xFF2BD6), RGB(0x00E5FF), RGB(0xFFD600), RGB(0x44D62C), RGB(0xFF7A00), RGB(0x9D4DFF), RGB(0x2979FF)]
        let c = colors[(bx.hits + by.hits) % colors.count]
        let x = field.x + bx.pos * travelX, y = by.pos * travelY
        let age = tt.truncatingRemainder(dividingBy: 2 * tx)
        let party = age < 1.6
        let flash = party && Int(age * 8) % 2 == 0
        canvas.glow(x + bw / 2, y + bh / 2, bh * 0.9, c, 0.35)
        canvas.roundedRect(x, y, bw, bh, radius: bh / 2, flash ? .white : c)
        canvas.text(label, x: (x + (bw - tw) / 2).rounded(), y: (y + (bh - dot * 7) / 2).rounded(), dot: dot, RGB(r: 0.02, g: 0.02, b: 0.04))
        if party {
            for i in 0..<18 {
                let a = Double(i) / 18 * 2 * .pi + Double(i)
                let r = age * H * (1.2 + rand01(i, 7))
                canvas.glow(x + bw / 2 + cos(a) * r * 2, y + bh / 2 + sin(a) * r * 0.6, H * 0.06, colors[i % colors.count], 1.2 * (1 - age / 1.6))
            }
            let d2 = max(1, (H / 11).rounded())
            let msg = "CORNER!"
            let mx = x + bw / 2 < field.x + field.w / 2 ? field.x + field.w * 0.62 : field.x + field.w * 0.38
            canvas.text(msg, centerX: mx, centerY: H / 2, dot: d2, colors[Int(age * 6) % colors.count], alpha: min(1, (1.6 - age) * 3))
        }
    }

    private static let terminalLines = [
        "$ SUDO REVIVE --TOUCHBAR", "LOADING NEON.DRV ........ OK", "CALIBRATING RGB ......... OK",
        "MOUNTING /DEV/TOUCHBAR .. OK", "WELCOME BACK, OPERATOR.", "$ RUN VIBES.EXE",
    ]

    func terminal(_ p: Params, _ t: Double) {
        let phosphor = p.color
        canvas.clear(phosphor.scaled(0.035))
        let lines = EffectCore.terminalLines
        let cps = 18.0, hold = 1.1, roll = 0.22
        let slots = lines.map { Double($0.count) / cps + hold + roll }
        let total = slots.reduce(0, +)
        var local = t.truncatingRemainder(dividingBy: total)
        var i = 0
        while local >= slots[i] { local -= slots[i]; i += 1 }
        let line = lines[i]
        let typeTime = Double(line.count) / cps
        let shown = local < typeTime ? String(line.prefix(Int(local * cps))) : line
        let dot = dotSize(fill: 0.6, maxWidth: W * 0.94, text: lines.max { $0.count < $1.count }!)
        let x0 = (dot * 3).rounded()
        let ty = ((H - dot * 7) / 2).rounded()
        let s = local > typeTime + hold ? (local - typeTime - hold) / roll : 0
        let yLine = ty - s * H
        let w = canvas.text(shown, x: x0, y: yLine, dot: dot, phosphor, glow: 0.22)
        // Block cursor: solid while typing, blinking while it waits, then on the next line.
        let blinkOn = local < typeTime || Int(t * 2.2) % 2 == 0
        if s > 0 {
            canvas.rect(x0, ty + (1 - s) * H, dot * 5, dot * 7, phosphor, alpha: 0.9)
        } else if blinkOn {
            canvas.rect(x0 + w + (shown.isEmpty ? 0 : dot), yLine, dot * 5, dot * 7, phosphor, alpha: 0.9)
        }
        // Scanlines and a soft vignette at the ends.
        let wD = W
        canvas.multiply { (x: Double, y: Double) -> Double in
            let scan: Double = Int(y) % 2 == 0 ? 1 : 0.72
            let edge: Double = min(1, min(x, wD - x) / (wD * 0.04) + 0.55)
            return scan * edge
        }
    }

    func paddleBall(_ t: Double) {
        canvas.clear(RGB(r: 0.01, g: 0.01, b: 0.02))
        let u = max(1, H / 15)
        let padW = u * 2.2, padH = H * 0.55, ball = u * 2.4
        let field = view
        let leftX = field.x + u * 3, rightX = field.x + field.w - u * 3 - padW
        let travel = max(1, rightX - leftX - padW - ball)
        let tx = travel / (H * 11)
        let ty = tx / 3.37
        func ballAt(_ tt: Double) -> (x: Double, y: Double) {
            (leftX + padW + bounce(tt / tx).pos * travel, bounce(tt / ty + 0.31).pos * (H - ball))
        }
        let (bxp, byp) = ballAt(t)
        // Dashed net.
        var ny = 0.0
        while ny < H { canvas.rect((field.x + field.w / 2 - u / 2).rounded(), ny, u, u * 1.6, .white, alpha: 0.35); ny += u * 3.2 }
        // Paddles follow the ball a beat late.
        let lag = ballAt(t - 0.1).y
        for px in [leftX, rightX] {
            let py = min(H - padH, max(0, lag + ball / 2 - padH / 2))
            canvas.rect(px, py, padW, padH, .white)
        }
        for k in 1...4 {
            let g = ballAt(t - Double(k) * 0.018)
            canvas.rect(g.x, g.y, ball, ball, .white, alpha: 0.12 * Double(5 - k) / 4)
        }
        canvas.glow(bxp + ball / 2, byp + ball / 2, ball * 1.6, RGB(r: 0.7, g: 0.9, b: 1), 0.35)
        canvas.rect(bxp, byp, ball, ball, .white)
    }

    func loadingBar(_ p: Params, _ t: Double) {
        canvas.clear(RGB(r: 0.01, g: 0.01, b: 0.015))
        let c = p.color
        let cycle = 7.0, fillTime = 5.2
        let local = t.truncatingRemainder(dividingBy: cycle)
        let f = min(1, local / fillTime)
        let prog = local >= fillTime ? 1 : f - sin(2 * .pi * f * 4) / (2 * .pi * 4) * 0.9
        let done = local >= fillTime
        let dot = dotSize(fill: 0.5)
        let label = done ? "COMPLETE!" : "LOADING"
        let labelW = Canvas.textWidth("COMPLETE!", dot: dot)
        let pct = "\(Int((prog * 100).rounded(.down)))%"
        let pctW = Canvas.textWidth("100%", dot: dot)
        let ty = ((H - dot * 7) / 2).rounded()
        let flashOn = !done || Int((local - fillTime) * 6) % 2 == 0
        canvas.text(label, x: dot * 3, y: ty, dot: dot, c, alpha: flashOn ? 1 : 0.35, glow: 0.12)
        canvas.text(pct, x: W - dot * 3 - pctW, y: ty, dot: dot, c, glow: 0.12)
        let x0 = dot * 3 + labelW + dot * 4, x1 = W - dot * 3 - pctW - dot * 4
        let bh = H * 0.62, by = (H - bh) / 2
        let edge = max(1, dot * 0.5)
        canvas.rect(x0, by, x1 - x0, edge, c); canvas.rect(x0, by + bh - edge, x1 - x0, edge, c)
        canvas.rect(x0, by, edge, bh, c); canvas.rect(x1 - edge, by, edge, bh, c)
        let seg = max(3, dot * 2.2), gap = max(1, dot * 0.8)
        let inner0 = x0 + edge + gap, inner1 = x1 - edge - gap
        let count = max(1, Int((inner1 - inner0 + gap) / (seg + gap)))
        let lit = prog * Double(count)
        for s in 0..<count {
            let a = clamp01(lit - Double(s))
            if a <= 0 { break }
            canvas.rect(inner0 + Double(s) * (seg + gap), by + edge + gap, seg, bh - 2 * (edge + gap), c, alpha: a * (flashOn ? 1 : 0.5))
        }
    }

    /// Snake's route: always moving right (so it never runs into itself), switching rows at random.
    private func snakePath(cols: Int, rows: Int) -> [(Int, Int)] {
        var path: [(Int, Int)] = []
        var x = 0, y = rows / 2, seg = 0
        while x < cols * 3 {
            let run = 3 + Int(rand01(seg, 71) * 7)
            for _ in 0..<run { path.append((x, y)); x += 1 }
            var ny = Int(rand01(seg, 72) * Double(rows))
            if ny == y { ny = (y + 2) % rows }
            while y != ny { path.append((x, y)); y += ny > y ? 1 : -1 }
            seg += 1
        }
        return path
    }

    func snake(_ t: Double) {
        let lcd = RGB(r: 0.52, g: 0.6, b: 0.34), ink = RGB(r: 0.1, g: 0.14, b: 0.07)
        canvas.clear(lcd)
        let rows = 5
        let cell = H / Double(rows)
        let field = view
        let cols = max(8, Int(field.w / cell))
        let ox = field.x + (field.w - Double(cols) * cell) / 2
        let path = cached("snake\(cols)x\(rows)") { snakePath(cols: cols, rows: rows) }
        let step = Int((t * 12).rounded(.down)) % path.count
        let foods = stride(from: 14, to: path.count, by: 19).map { $0 + Int(rand01($0, 73) * 6) }
        let eaten = foods.filter { $0 <= step }.count
        let length = 7 + eaten * 3
        // Faint LCD grid.
        for c in 0...cols { canvas.rect(ox + Double(c) * cell - 0.25, 0, 0.5, H, ink, alpha: 0.06) }
        for f in foods where f > step && f < step + cols {
            let (fx, fy) = path[f]
            let cx = ox + (Double(fx % cols) + 0.5) * cell, cy = (Double(fy) + 0.5) * cell
            canvas.rect(cx - cell * 0.18, cy - cell * 0.35, cell * 0.36, cell * 0.7, ink)
            canvas.rect(cx - cell * 0.35, cy - cell * 0.18, cell * 0.7, cell * 0.36, ink)
        }
        for i in max(0, step - length + 1)...step {
            let (sx, sy) = path[i]
            let inset = i == step ? 0.06 : 0.12
            canvas.rect(ox + Double(sx % cols) * cell + cell * inset, Double(sy) * cell + cell * inset, cell * (1 - 2 * inset), cell * (1 - 2 * inset), ink)
        }
    }

    func synthwave(_ t: Double) {
        let hD = H, wD = W
        let horizon = hD * 0.5
        let cx = wD / 2, sunR = hD * 0.5, sunCy = horizon
        let camH = hD * 4, spX = hD * 1.6, spZ = hD * 1.2, speed = hD * 1.4
        canvas.shade { (x: Double, y: Double) -> RGB in
            if y < horizon {
                let v: Double = y / horizon
                var c = RGB(r: 0.06 + 0.4 * v * v, g: 0.0 + 0.04 * v, b: 0.14 + 0.28 * v)
                let dx: Double = x - cx, dy: Double = y - sunCy
                if dx * dx + dy * dy < sunR * sunR {
                    let sv: Double = (y - (sunCy - sunR)) / (sunR * 2)
                    let stripe: Bool = sv > 0.2 && fract((sv - 0.2) * 14) < (sv - 0.2) * 2.4
                    if !stripe { c = RGB(r: 1, g: 0.85 - 0.65 * sv, b: 0.3 + 0.2 * sv) }
                }
                return c
            }
            // The bar is far too wide for a single vanishing point, so the floor lines run straight
            // up and only the cross lines use perspective (they rush toward you).
            let dy: Double = max(0.5, y - horizon)
            let dv: Double = abs(fract((x - cx) / spX + 0.5) - 0.5) * spX
            let z: Double = camH / dy
            let zz: Double = z + t * speed
            let dzdy: Double = camH / (dy * dy)
            let dh: Double = abs(fract(zz / spZ + 0.5) - 0.5) * spZ / dzdy
            let lineK: Double = max(clamp01(1.2 - dv / 0.8) * 0.8, clamp01(1.2 - dh / 0.8))
            let fade: Double = pow(clamp01((y - horizon) / (hD - horizon)), 0.7)
            let ground = RGB(r: 0.05, g: 0.0, b: 0.09)
            return ground.adding(RGB(r: 1, g: 0.18, b: 0.85).scaled(lineK * fade))
        }
        // Mountains in front of the sun.
        canvas.overlay(fromRow: Int(horizon - hD * 0.25)) { (x: Double, y: Double) -> RGB? in
            let m: Double = hD * (0.05 + 0.18 * pow(noise1(x / hD * 0.9, 17), 2.2) * (0.4 + 0.6 * clamp01(abs(x - cx) / (sunR * 2))))
            let top = horizon - m
            guard y >= top && y < horizon else { return nil }
            return y < top + 1 ? RGB(r: 0.9, g: 0.2, b: 0.9) : RGB(r: 0.08, g: 0.01, b: 0.14)
        }
        for i in 0..<Int(wD / 30) {
            let sx = rand01(i, 1) * wD, sy = rand01(i, 2) * horizon * 0.7
            if abs(sx - cx) < sunR * 1.1 { continue }
            canvas.circle(sx, sy, max(0.45, hD * 0.018), .white, alpha: 0.4 + 0.4 * sin(t * 2 + Double(i)))
        }
    }

    func equalizer(_ t: Double) {
        canvas.clear(RGB(r: 0.01, g: 0.01, b: 0.015))
        let bars = max(8, Int(W / (H * 0.7)))
        let bw = W / Double(bars)
        let segs = 8
        let gap = max(1, H * 0.04)
        let segH = (H - gap * Double(segs + 1)) / Double(segs)
        func level(_ i: Int, _ tt: Double) -> Double {
            let f = Double(i) / Double(bars)
            let kick = exp(-fract(tt / 0.5) * 5) * (1 - f) * 0.5
            let base = 0.08 + 0.85 * pow(noise1(tt * 3.1 + Double(i) * 0.61, 3), 1.6) * (0.55 + 0.45 * sin(f * 7 + tt * 0.8))
            return clamp01(base + kick + 0.18 * noise1(tt * 9 + Double(i) * 1.3, 9))
        }
        for i in 0..<bars {
            let lv = level(i, t)
            var peak = lv
            for k in 1...6 { peak = max(peak, level(i, t - Double(k) * 0.1) - Double(k) * 0.05) }
            let lit = lv * Double(segs)
            let x = Double(i) * bw + bw * 0.12, w = bw * 0.76
            for s in 0..<segs {
                let y = H - gap - Double(s + 1) * (segH + gap) + gap
                let col: RGB = s >= segs - 1 ? RGB(0xFF1744) : s >= segs - 3 ? RGB(0xFFD600) : RGB(0x44D62C)
                let a = clamp01(lit - Double(s))
                canvas.rect(x, y, w, segH, col, alpha: 0.08 + 0.92 * a)
            }
            let py = H - gap - peak * Double(segs) * (segH + gap)
            canvas.rect(x, max(0, py - max(1, segH * 0.3)), w, max(1, segH * 0.3), .white, alpha: 0.85)
        }
    }

    func vhs(_ t: Double) {
        let hD = H, wD = W
        let frame = UInt32(truncatingIfNeeded: Int(t * 30))
        let burst = fract(t / 4.3)
        let glitch = burst < 0.08 ? 1.0 : 0.15
        let band = fract(t / 3.1) * (hD * 1.6) - hD * 0.3
        let bars: [RGB] = [RGB(r: 0.75, g: 0.75, b: 0.75), RGB(r: 0.75, g: 0.75, b: 0), RGB(r: 0, g: 0.75, b: 0.75), RGB(r: 0, g: 0.75, b: 0),
                           RGB(r: 0.75, g: 0, b: 0.75), RGB(r: 0.75, g: 0, b: 0), RGB(r: 0, g: 0, b: 0.75)]
        func bar(_ x: Double) -> RGB { bars[min(bars.count - 1, max(0, Int(x / wD * Double(bars.count))))] }
        canvas.shade { (x: Double, y: Double) -> RGB in
            let inBand: Bool = abs(y - band) < hD * 0.14
            let jitter: Double = (noise1(y * 0.7 + t * 23, 5) - 0.5) * hD * (inBand ? 1.4 : 0.25 * glitch)
            let xs: Double = x + jitter
            let split: Double = hD * 0.09 * (0.4 + glitch)
            var c = RGB(r: bar(xs - split).r, g: bar(xs).g, b: bar(xs + split).b)
            let n: Double = Double(hash32(UInt32(truncatingIfNeeded: Int(x)) &* 73_856_093 ^ UInt32(truncatingIfNeeded: Int(y)) &* 19_349_663 ^ frame &* 83_492_791) & 255) / 255
            c = c.mixed(with: RGB(r: n, g: n, b: n), inBand ? 0.55 : 0.1)
            return c
        }
        let dot = dotSize(fill: 0.52)
        let ty = ((hD - dot * 7) / 2).rounded()
        let secs = Int(t) % 3600
        let counter = String(format: "SP 0:%02d:%02d", secs / 60, secs % 60)
        for (s, x) in [("PLAY ▶", dot * 3), (counter, wD - dot * 3 - Canvas.textWidth(counter, dot: dot))] {
            canvas.text(s, x: x + dot * 0.6, y: ty + dot * 0.6, dot: dot, .black, alpha: 0.7)
            canvas.text(s, x: x, y: ty, dot: dot, .white)
        }
    }
}
