import Foundation

// Productivity: the bar shows something real. Time and system numbers come from `Params.info`,
// which the app fills once a second; animation still uses `t`.

extension EffectCore {

    /// Draws pieces of text one after another (one dot apart), each with its own alpha. Returns the width.
    @discardableResult
    func textRun(_ pieces: [(String, Double)], x: Double, y: Double, dot: Double, _ c: RGB,
                 style: Canvas.TextStyle = .block, glow: Double = 0) -> Double {
        var pen = x
        for (s, a) in pieces {
            let w = canvas.text(s, x: pen, y: y, dot: dot, c, style: style, alpha: a, glow: glow * a)
            pen += w + dot
        }
        return pen - x - dot
    }

    static func runWidth(_ pieces: [String], dot: Double) -> Double {
        pieces.map { Canvas.textWidth($0, dot: dot) }.reduce(0, +) + Double(max(0, pieces.count - 1)) * dot
    }

    /// Hours, minutes, seconds from seconds since midnight, and an AM/PM label when using 12-hour time.
    func clockParts(_ info: LiveInfo) -> (h: Int, m: Int, s: Int, suffix: String) {
        let total = Int(info.secondsOfDay.rounded(.down)) % 86_400
        var h = total / 3600
        let m = (total / 60) % 60, s = total % 60
        var suffix = ""
        if !info.use24Hour {
            suffix = h < 12 ? "AM" : "PM"
            h %= 12
            if h == 0 { h = 12 }
        }
        return (h, m, s, suffix)
    }

    func clock(_ p: Params) {
        let c = p.color
        canvas.clear(c.scaled(0.03))
        let (h, m, s, suffix) = clockParts(p.info)
        let colon = fract(p.info.secondsOfDay) < 0.5 ? 1.0 : 0.25
        let hs = p.info.use24Hour ? String(format: "%02d", h) : "\(h)"
        let pieces = [(hs, 1.0), (":", colon), (String(format: "%02d", m), 1.0), (":", colon), (String(format: "%02d", s), 1.0)]
        let dot = dotSize(fill: 0.8)
        let tw = EffectCore.runWidth(pieces.map(\.0), dot: dot)
        let y = ((H - dot * 7) / 2).rounded()
        textRun(pieces, x: (view.x + (view.w - tw) / 2).rounded(), y: y, dot: dot, c, style: .led)
        let sd = dotSize(fill: 0.45)
        let sy = ((H - sd * 7) / 2).rounded()
        // Side labels only when they clear the time (small previews skip them).
        let side = max(Canvas.textWidth(p.info.dateLabel, dot: sd), Canvas.textWidth(suffix, dot: sd)) + sd * 8
        guard tw + side * 2 < view.w else { return }
        canvas.text(p.info.dateLabel, x: view.x + sd * 4, y: sy, dot: sd, c, alpha: 0.6)
        if !suffix.isEmpty {
            canvas.text(suffix, x: view.x + view.w - sd * 4 - Canvas.textWidth(suffix, dot: sd), y: sy, dot: sd, c, alpha: 0.6)
        }
    }

    func focusTimer(_ p: Params) {
        if focusStart == nil { focusStart = p.info.now }
        let elapsed = max(0, p.info.now - (focusStart ?? p.info.now))
        let focusLen = 25.0 * 60, breakLen = 5.0 * 60
        let local = elapsed.truncatingRemainder(dividingBy: focusLen + breakLen)
        let sessions = Int(elapsed / (focusLen + breakLen))
        let focusing = local < focusLen
        let remaining = focusing ? focusLen - local : focusLen + breakLen - local
        let progress = focusing ? local / focusLen : (local - focusLen) / breakLen
        let c: RGB = focusing ? RGB(0xFF5A36) : RGB(0x44D62C)
        canvas.clear(c.scaled(0.03))
        let fresh = (focusing ? local : local - focusLen) < 3
        let flash = fresh && Int(p.info.now * 4) % 2 == 0
        let sd = dotSize(fill: 0.45), bd = dotSize(fill: 0.78)
        let label = focusing ? "FOCUS" : "BREAK"
        canvas.text(label, x: sd * 4, y: ((H - sd * 7) / 2).rounded(), dot: sd, c, alpha: flash ? 0.4 : 0.85)
        let rem = Int(remaining.rounded(.up))
        let time = String(format: "%02d:%02d", rem / 60, rem % 60)
        let tx = sd * 4 + Canvas.textWidth("BREAK", dot: sd) + sd * 5
        let tw = canvas.text(time, x: tx, y: ((H - bd * 7) / 2).rounded(), dot: bd, c, style: .led)
        // Rounds done (four dots).
        let rx = W - sd * 4 - sd * 4 * 4
        for i in 0..<4 {
            let done = i < sessions % 4
            canvas.circle(rx + Double(i) * sd * 4 + sd * 1.5, H / 2, sd * 1.3, c, alpha: done ? 0.95 : 0.2)
        }
        let x0 = tx + tw + bd * 3, x1 = rx - sd * 4
        let bh = H * 0.22, by = (H - bh) / 2
        canvas.roundedRect(x0, by, x1 - x0, bh, radius: bh / 2, c, alpha: 0.18)
        canvas.roundedRect(x0, by, (x1 - x0) * (1 - progress), bh, radius: bh / 2, c, alpha: flash ? 0.5 : 1)
    }

    func systemMonitor(_ p: Params, _ t: Double) {
        canvas.clear(RGB(r: 0.01, g: 0.015, b: 0.03))
        let sd = dotSize(fill: 0.48)
        let ty = ((H - sd * 7) / 2).rounded()
        let bh = H * 0.34, by = (H - bh) / 2
        func loadColor(_ v: Double) -> RGB { v < 0.6 ? RGB(0x44D62C) : v < 0.85 ? RGB(0xFFD600) : RGB(0xFF1744) }
        func meter(_ label: String, _ v: Double, _ x0: Double, _ x1: Double) {
            canvas.text(label, x: x0, y: ty, dot: sd, .white, alpha: 0.8)
            let pct = "\(Int((v * 100).rounded()))%"
            let pw = Canvas.textWidth("100%", dot: sd)
            let bx0 = x0 + Canvas.textWidth("MEM", dot: sd) + sd * 3, bx1 = x1 - pw - sd * 3
            canvas.rect(bx0, by, bx1 - bx0, bh, .white, alpha: 0.1)
            let segs = max(4, Int((bx1 - bx0) / (sd * 3)))
            let sw = (bx1 - bx0) / Double(segs)
            for i in 0..<segs {
                let a = clamp01(v * Double(segs) - Double(i))
                if a <= 0 { break }
                canvas.rect(bx0 + Double(i) * sw + 0.5, by, sw - 1, bh, loadColor(Double(i) / Double(segs)), alpha: a)
            }
            canvas.text(pct, x: x1 - Canvas.textWidth(pct, dot: sd), y: ty, dot: sd, loadColor(v))
        }
        let pad = sd * 4
        meter("CPU", p.info.cpu, pad, W * 0.36)
        meter("MEM", p.info.memory, W * 0.36 + pad * 2, W * 0.7)
        // CPU history.
        let hist = p.info.cpuHistory.isEmpty ? [p.info.cpu] : p.info.cpuHistory
        let x0 = W * 0.7 + pad * 2, x1 = W - pad
        let top = H * 0.15, bottom = H * 0.85
        canvas.rect(x0, bottom, x1 - x0, 1, .white, alpha: 0.2)
        let n = hist.count
        var prev: (Double, Double)?
        for (i, v) in hist.enumerated() {
            let x = x0 + (x1 - x0) * (n > 1 ? Double(i) / Double(n - 1) : 1)
            let y = bottom - (bottom - top) * clamp01(v)
            canvas.rect(x - (x1 - x0) / Double(max(1, n)) / 2, y, (x1 - x0) / Double(max(1, n)), bottom - y, RGB(0x00E5FF), alpha: 0.18)
            if let (px, py) = prev { canvas.line(px, py, x, y, width: max(1, H * 0.05), RGB(0x00E5FF)) }
            prev = (x, y)
        }
        if let (lx, ly) = prev { canvas.glow(lx, ly, H * 0.12, RGB(0x00E5FF), 0.6 + 0.4 * sin(t * 4)) }
    }

    /// A firework burst `age` seconds old at (x, y).
    func firework(_ x: Double, _ y: Double, age: Double, _ c: RGB, seed: Int) {
        guard age >= 0, age < 1.4 else { return }
        let n = 16
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi + rand01(seed, 3)
            let sp = H * (0.9 + rand01(seed &* 31 &+ i, 4) * 0.5)
            let px = x + cos(a) * sp * age * 1.6, py = y + sin(a) * sp * age * 0.7 + H * 0.4 * age * age
            canvas.glow(px, py, H * 0.05, c, 1.1 * (1 - age / 1.4))
        }
    }

    func countdown(_ p: Params, _ t: Double) {
        let c = p.color
        canvas.clear(c.scaled(0.025))
        let s = max(0, p.info.secondsToNewYear)
        let celebrating = s > 364.5 * 86_400
        let palette: [RGB] = [RGB(0xFF2BD6), RGB(0x00E5FF), RGB(0xFFD600), RGB(0x44D62C), RGB(0xFF7A00)]
        let every = celebrating ? 0.5 : 2.6
        let k = Int((t / every).rounded(.down))
        for j in (k - 3)...k where j >= 0 {
            firework(rand01(j, 1) * W, H * (0.2 + 0.4 * rand01(j, 2)), age: t - Double(j) * every, palette[j % palette.count].scaled(celebrating ? 1 : 0.4), seed: j)
        }
        var bd = dotSize(fill: 0.72), sd = dotSize(fill: 0.45)
        if celebrating {
            canvas.text("HAPPY NEW YEAR!", centerX: view.x + view.w / 2, centerY: H / 2, dot: bd, palette[Int(t * 3) % palette.count], style: .led)
            return
        }
        let days = Int(s / 86_400), rest = Int(s) % 86_400
        let pieces = [String(format: "%03d", days), "DAYS", String(format: "%02d:%02d:%02d", rest / 3600, (rest / 60) % 60, rest % 60)]
        let until = "UNTIL \(p.info.year + 1)"
        func measure() -> [Double] {
            [Canvas.textWidth(pieces[0], dot: bd), Canvas.textWidth(pieces[1], dot: sd), Canvas.textWidth(pieces[2], dot: bd), Canvas.textWidth(until, dot: sd)]
        }
        var widths = measure()
        if widths.reduce(0, +) + bd * 9 > view.w * 0.96 {
            let k = view.w * 0.96 / (widths.reduce(0, +) + bd * 9)
            bd *= k; sd *= k
            widths = measure()
        }
        let gap = bd * 3
        let total = widths.reduce(0, +) + gap * 3
        var x = (view.x + (view.w - total) / 2).rounded()
        let by = ((H - bd * 7) / 2).rounded(), sy = ((H - sd * 7) / 2).rounded()
        canvas.text(pieces[0], x: x, y: by, dot: bd, c, style: .led); x += widths[0] + gap
        canvas.text(pieces[1], x: x, y: sy, dot: sd, c, alpha: 0.7); x += widths[1] + gap
        canvas.text(pieces[2], x: x, y: by, dot: bd, c, style: .led); x += widths[2] + gap
        canvas.text(until, x: x, y: sy, dot: sd, c, alpha: 0.7)
    }

    func yearProgress(_ p: Params, _ t: Double) {
        let c = p.color
        canvas.clear(c.scaled(0.025))
        let f = clamp01(p.info.yearFraction)
        let bd = dotSize(fill: 0.62)
        let ty = ((H - bd * 7) / 2).rounded()
        let year = "\(p.info.year)"
        let pct = String(format: "%.1f%%", f * 100)
        let yw = canvas.text(year, x: bd * 3, y: ty, dot: bd, c)
        let pw = Canvas.textWidth("100.0%", dot: bd)
        canvas.text(pct, x: W - bd * 3 - Canvas.textWidth(pct, dot: bd), y: ty, dot: bd, c)
        let x0 = bd * 3 + yw + bd * 4, x1 = W - bd * 3 - pw - bd * 4
        let blocks = 20
        let bw = (x1 - x0) / Double(blocks)
        let bh = bd * 7
        let filled = f * Double(blocks)
        for i in 0..<blocks {
            let a = clamp01(filled - Double(i))
            let bx = x0 + Double(i) * bw
            canvas.rect(bx + 1, ty, bw - 2, bh, c, alpha: 0.12)
            if a > 0 {
                let pulse = a < 1 ? 0.55 + 0.45 * sin(t * 3) : 1
                canvas.rect(bx + 1, ty, (bw - 2) * a, bh, c, alpha: pulse)
            }
        }
    }

    func binaryClock(_ p: Params) {
        let c = p.color
        canvas.clear(c.scaled(0.02))
        let (h0, m, s, _) = clockParts(LiveInfo(secondsOfDay: p.info.secondsOfDay, use24Hour: true))
        let digits = [h0 / 10, h0 % 10, m / 10, m % 10, s / 10, s % 10]
        let r = H * 0.095, rowGap = H * 0.23, colGap = H * 0.75, groupGap = H * 1.6
        let totalW = colGap * 3 + groupGap * 2
        let x0 = view.x + (view.w - totalW) / 2
        for (i, d) in digits.enumerated() {
            let x = x0 + Double(i / 2) * (colGap + groupGap) + Double(i % 2) * colGap
            for bit in 0..<4 {
                let on = (d >> (3 - bit)) & 1 == 1
                let y = H / 2 + (Double(bit) - 1.5) * rowGap
                if on { canvas.glow(x, y, r * 1.6, c, 0.4) }
                canvas.circle(x, y, r, c, alpha: on ? 1 : 0.14)
            }
        }
        let sd = dotSize(fill: 0.42)
        let label = String(format: "%02d:%02d:%02d", h0, m, s)
        guard totalW + (Canvas.textWidth(label, dot: sd) + sd * 8) * 2 < view.w else { return }
        canvas.text(label, x: view.x + view.w - sd * 4 - Canvas.textWidth(label, dot: sd), y: ((H - sd * 7) / 2).rounded(), dot: sd, c, alpha: 0.5)
        canvas.text("BINARY", x: view.x + sd * 4, y: ((H - sd * 7) / 2).rounded(), dot: sd, c, alpha: 0.5)
    }
}
