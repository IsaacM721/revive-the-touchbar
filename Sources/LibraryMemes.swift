import Foundation

// Memes: made to be filmed. The text on the bar stays in English; it's part of the joke.

extension EffectCore {

    /// Text whose letters bob on a wave.
    func wavyText(_ s: String, centerX cx: Double, centerY cy: Double, dot: Double, _ c: RGB, t: Double, amp: Double,
                  shadow: RGB? = nil) {
        let total = Canvas.textWidth(s, dot: dot)
        var pen = (cx - total / 2).rounded()
        for (i, ch) in s.enumerated() {
            let g = String(ch)
            let y = (cy - dot * 3.5 + sin(t * 6 + Double(i) * 0.6) * amp).rounded()
            if let shadow { canvas.text(g, x: pen + dot * 0.8, y: y + dot * 0.8, dot: dot, shadow, alpha: 0.85) }
            let w = canvas.text(g, x: pen, y: y, dot: dot, c)
            pen += w + dot
        }
    }

    private static let chefHat = Sprite([".www.www.", "wwwwwwwww", "wwwwwwwww", ".wwwwwww.", "..wwwww..", "..ggggg..", "..wwwww.."],
                                        ["w": .white, "g": RGB(r: 0.75, g: 0.75, b: 0.8)])

    func cooking(_ t: Double) {
        let hD = H
        let s = t * 1.4
        canvas.shadeSmooth { (x: Double, y: Double) -> RGB in
            let u: Double = x / hD * 0.035, v: Double = y / hD
            let n: Double = 0.5 * sin(u * 80 + s * 2.3 + 1.6 * sin(v * 6 - s * 3.1)) + 0.3 * sin(u * 150 - s * 1.9 + v * 11) + 0.2 * sin(u * 41 + s * 1.1 - v * 4)
            let heat: Double = clamp01(-0.35 + v * 1.05 + n * 0.45)
            return RGB(r: min(1, heat * 2.6) * 0.9 + 0.03, g: clamp01(heat * 2.6 - 0.9) * 0.9 + 0.01, b: clamp01(heat * 3 - 2.2))
        }
        // Embers.
        for i in 0..<Int(W / 14) {
            let period = 1.6 + rand01(i, 1) * 1.4
            let f = fract(t / period + rand01(i, 2))
            let x = rand01(i, 3) * W + sin(t * 2 + Double(i)) * hD * 0.3
            canvas.glow(x, hD * (1 - f * 1.1), hD * 0.05, RGB(r: 1, g: 0.55, b: 0.1), 0.9 * (1 - f))
        }
        var dot = dotSize(fill: 0.72)
        let msg = loop(t, 7) < 3.5 ? "BRO IS COOKING" : "LET HIM COOK"
        let fullW = Canvas.textWidth("BRO IS COOKING", dot: dot) + dot * 0.9 * 9 + dot * 4
        if fullW > view.w * 0.94 { dot *= view.w * 0.94 / fullW }
        let hatDot = dot * 0.9
        let tw = Canvas.textWidth(msg, dot: dot) + hatDot * 9 + dot * 4
        let startX = view.x + (view.w - tw) / 2
        canvas.sprite(EffectCore.chefHat, x: startX, y: (hD - hatDot * 7) / 2 + sin(t * 5) * dot * 0.4, dot: hatDot)
        wavyText(msg, centerX: startX + hatDot * 9 + dot * 4 + Canvas.textWidth(msg, dot: dot) / 2, centerY: hD / 2, dot: dot,
                 RGB(r: 1, g: 0.97, b: 0.85), t: t, amp: dot * 0.45, shadow: RGB(r: 0.25, g: 0.03, b: 0.0))
    }

    func errorScreen(_ t: Double) {
        let hD = H, wD = W
        let messages = ["⚠ FATAL ERROR 0x7B", "TOUCH BAR TOO POWERFUL", "PLEASE RESTART YOUR VIBES"]
        let slot = 2.6
        let k = Int((t / slot).rounded(.down))
        let local = t - Double(k) * slot
        let pulse = 0.5 + 0.5 * sin(t * 5)
        canvas.clear(RGB(r: 0.22 + 0.12 * pulse, g: 0.0, b: 0.02))
        // Blinking border.
        let bw = max(1, hD * 0.07)
        let on = Int(t * 3) % 2 == 0
        let bc: RGB = on ? .white : RGB(0xFF1744)
        canvas.rect(0, 0, wD, bw, bc); canvas.rect(0, hD - bw, wD, bw, bc)
        let msg = messages[k % messages.count]
        let dot = dotSize(fill: 0.6, maxWidth: view.w * 0.9, text: messages[2])
        let cx = view.x + view.w / 2
        let glitch = local < 0.3
        if glitch {
            canvas.text(msg, centerX: cx - dot * 1.5, centerY: hD / 2, dot: dot, RGB(r: 1, g: 0, b: 0.2), alpha: 0.9)
            canvas.text(msg, centerX: cx + dot * 1.5, centerY: hD / 2, dot: dot, RGB(r: 0, g: 1, b: 1), alpha: 0.7)
        }
        canvas.text(msg, centerX: cx, centerY: hD / 2, dot: dot, .white)
        if glitch {
            let frame = Int(t * 30)
            for i in 0..<5 {
                let y0 = Int(rand01(frame &* 7 &+ i, 1) * hD)
                canvas.shiftRows(y0, y0 + 1 + Int(rand01(frame &+ i, 2) * hD * 0.25), by: Int((rand01(frame &+ i, 3) - 0.5) * hD * 1.5))
            }
        }
    }

    func spinner(_ cx: Double, _ cy: Double, radius r: Double, dotR: Double, _ c: RGB, t: Double) {
        for k in 0..<8 {
            let a = Double(k) / 8 * 2 * .pi
            let lit = fract(Double(k) / 8 - t * 1.3)
            canvas.circle(cx + cos(a) * r, cy + sin(a) * r, dotR, c, alpha: 0.15 + 0.85 * pow(lit, 3))
        }
    }

    func loadingForever(_ t: Double) {
        canvas.clear(RGB(r: 0.015, g: 0.015, b: 0.02))
        let cycle = 9.0
        let local = loop(t, cycle)
        let prog = local < 2 ? 0.12 + 0.87 * (1 - pow(1 - local / 2, 3)) : 0.99
        let dropped = local > 8.7
        let c = RGB(0x2979FF)
        spinner(H * 0.7, H / 2, radius: H * 0.28, dotR: H * 0.06, .white, t: t)
        let dot = dotSize(fill: 0.5)
        let ty = ((H - dot * 7) / 2).rounded()
        let dots = String(repeating: ".", count: Int(t * 2.5) % 4)
        let word = local > 3.5 && !dropped ? "ALMOST THERE" : "LOADING"
        canvas.text(word + dots, x: H * 1.3, y: ty, dot: dot, .white)
        let pct = dropped ? "12%" : "\(Int((prog * 100).rounded(.down)))%"
        let pw = Canvas.textWidth("100%", dot: dot)
        let x0 = H * 1.3 + Canvas.textWidth("ALMOST THERE...", dot: dot) + dot * 4, x1 = W - dot * 4 - pw
        let bh = H * 0.28, by = (H - bh) / 2
        canvas.roundedRect(x0, by, x1 - x0, bh, radius: bh / 2, .white, alpha: 0.12)
        let shown = dropped ? 0.12 : prog
        canvas.roundedRect(x0, by, (x1 - x0) * shown, bh, radius: bh / 2, c)
        if local > 2 && !dropped {
            let shimmer = fract(t * 0.8) * (x1 - x0) * shown
            canvas.glow(x0 + shimmer, H / 2, bh, .white, 0.35)
        }
        let flick = local > 5 && !dropped && Int(t * 10) % 7 == 0
        canvas.text(pct, x: W - dot * 3 - Canvas.textWidth(pct, dot: dot), y: ty, dot: dot, dropped ? RGB(0xFF1744) : .white, alpha: flick ? 0.3 : 1)
    }

    func systemUpdate(_ t: Double) {
        canvas.clear(RGB(r: 0.0, g: 0.01, b: 0.03))
        let span = 47.0
        let n = Int((t / span).rounded(.down))
        let pct = Int(fract(t / span) * 100)
        spinner(H * 0.75, H / 2, radius: H * 0.28, dotR: H * 0.055, .white, t: t * 0.8)
        let bd = dotSize(fill: 0.58), sd = dotSize(fill: 0.42)
        let big = "UPDATING \(pct)%"
        canvas.text(big, x: H * 1.5, y: ((H - bd * 7) / 2).rounded(), dot: bd, .white)
        let small1 = "UPDATE \(1 + n % 847) OF 847", small2 = "DO NOT TURN OFF YOUR TOUCH BAR"
        let sy = ((H - sd * 7) / 2).rounded()
        let w2 = Canvas.textWidth(small2, dot: sd)
        canvas.text(small2, x: W - sd * 4 - w2, y: sy, dot: sd, .white, alpha: 0.55)
        canvas.text(small1, x: W - sd * 4 - w2 - sd * 8 - Canvas.textWidth(small1, dot: sd), y: sy, dot: sd, .white, alpha: 0.4)
    }

    func doNotTouch(_ t: Double) {
        let hD = H
        let stripe = hD * 0.55
        let yellow = RGB(r: 1, g: 0.8, b: 0.0)
        canvas.shade { (x: Double, y: Double) -> RGB in
            fract((x + y) / (stripe * 2) - t * 0.35) < 0.5 ? yellow : RGB(r: 0.03, g: 0.03, b: 0.03)
        }
        let dot = dotSize(fill: 0.6)
        let text = "DO NOT TOUCH"
        let tw = Canvas.textWidth(text, dot: dot)
        let pw = tw + dot * 10, ph = hD * 0.84
        let px = view.x + (view.w - pw) / 2, py = (hD - ph) / 2
        canvas.rect(px, py, pw, ph, yellow)
        canvas.rect(px + dot * 0.7, py + dot * 0.7, pw - dot * 1.4, ph - dot * 1.4, RGB(r: 0.03, g: 0.03, b: 0.03))
        let on = loop(t, 1.3) < 1.0
        canvas.text(text, centerX: px + pw / 2, centerY: hD / 2, dot: dot, on ? yellow : RGB(r: 0.4, g: 0.3, b: 0), glow: on ? 0.15 : 0)
    }

    func hacker(_ p: Params, _ t: Double) {
        let c = p.color
        canvas.clear(RGB(r: 0.0, g: 0.012, b: 0.0))
        // Dim hex scrolling behind everything.
        let sd = max(1, dotSize(fill: 0.3))
        let rowsN = max(1, Int(H / (sd * 8)))
        for r in 0..<rowsN {
            let y = Double(r) * sd * 8 + (H - Double(rowsN) * sd * 8) / 2
            let speed = H * (0.6 + Double(r) * 0.4)
            let chunk = sd * 6
            let off = fract(t * speed / chunk) * chunk
            let first = Int((t * speed / chunk).rounded(.down))
            var x = -off, i = 0
            while x < W {
                let v = Int(hash32(UInt32(truncatingIfNeeded: (first + i) &* 131 &+ r)) & 15)
                canvas.text(String(format: "%X", v), x: x, y: y, dot: sd, c, alpha: 0.13)
                x += chunk; i += 1
            }
        }
        let cycle = 11.0
        let local = loop(t, cycle)
        let dot = dotSize(fill: 0.58)
        let ty = ((H - dot * 7) / 2).rounded()
        let x0 = dot * 4
        func plate(_ w: Double) { canvas.rect(x0 - dot * 2, ty - dot * 1.5, w + dot * 4, dot * 10, .black, alpha: 0.85) }
        if local < 2.6 {
            let label = "ACCESSING MAINFRAME"
            let blocks = 12, filled = Int(local / 2.6 * Double(blocks + 1))
            let bar = String(repeating: "█", count: min(blocks, filled)) + String(repeating: "_", count: max(0, blocks - filled))
            plate(Canvas.textWidth(label + "  " + bar, dot: dot))
            let w = canvas.text(label, x: x0, y: ty, dot: dot, c, glow: 0.12)
            canvas.text(bar, x: x0 + w + dot * 4, y: ty, dot: dot, c, alpha: 0.9)
        } else if local < 5 {
            let spin = ["|", "/", "-", "\\"][Int(t * 10) % 4]
            let label = "BYPASSING FIREWALL " + spin
            plate(Canvas.textWidth(label, dot: dot))
            canvas.text(label, x: x0, y: ty, dot: dot, c, glow: 0.12)
        } else if local < 7 {
            let on = Int(local * 6) % 2 == 0
            let label = "ACCESS GRANTED"
            let w = Canvas.textWidth(label, dot: dot)
            canvas.rect(x0 - dot * 2, ty - dot * 1.5, w + dot * 4, dot * 10, c, alpha: on ? 0.95 : 0.25)
            canvas.text(label, x: x0, y: ty, dot: dot, on ? .black : c)
        } else {
            let full = "I'M IN."
            let shown = String(full.prefix(min(full.count, Int((local - 7) * 8))))
            plate(Canvas.textWidth(full, dot: dot) + dot * 6)
            let w = canvas.text(shown, x: x0, y: ty, dot: dot, c, glow: 0.2)
            if Int(t * 2.4) % 2 == 0 { canvas.rect(x0 + w + (shown.isEmpty ? 0 : dot), ty, dot * 5, dot * 7, c) }
        }
    }

    func typing(_ t: Double) {
        canvas.clear(RGB(r: 0.06, g: 0.06, b: 0.07))
        let hD = H
        let dot = dotSize(fill: 0.44)
        let local = loop(t, 8)
        let visible = local < 5.6 ? 1.0 : local < 6 ? (6 - local) / 0.4 : local > 7.6 ? (local - 7.6) / 0.4 : 0
        // Avatar.
        let ar = hD * 0.36
        canvas.circle(ar + dot * 3, hD / 2, ar, RGB(0x9D4DFF))
        canvas.circle(ar + dot * 3 - ar * 0.2, hD / 2 - ar * 0.2, ar * 0.55, RGB(0xFF7A00), alpha: 0.7)
        // Typing bubble with three dots in a wave.
        let bx = ar * 2 + dot * 6, bh = hD * 0.72, bw = bh * 2.3, by = (hD - bh) / 2
        if visible > 0 {
            canvas.roundedRect(bx, by, bw, bh, radius: bh / 2, RGB(r: 0.24, g: 0.24, b: 0.26), alpha: visible)
            for i in 0..<3 {
                let lift = max(0, sin(t * 7 - Double(i) * 0.9)) * bh * 0.16
                let lit = 0.45 + 0.55 * max(0, sin(t * 7 - Double(i) * 0.9))
                canvas.circle(bx + bw * (0.28 + 0.22 * Double(i)), hD / 2 - lift, bh * 0.12, .white, alpha: visible * lit)
            }
        }
        // What you sent, and that it was read.
        let blue = RGB(r: 0.04, g: 0.52, b: 1.0)
        var x = W - dot * 3
        for msg in ["HELLO??", "U UP?"] {
            let tw = Canvas.textWidth(msg, dot: dot)
            let w = tw + dot * 6
            x -= w
            canvas.roundedRect(x, by, w, bh, radius: bh / 2, blue)
            canvas.text(msg, x: x + dot * 3, y: ((hD - dot * 7) / 2).rounded(), dot: dot, .white)
            x -= dot * 3
        }
        let sd = max(1, dotSize(fill: 0.3))
        let read = "READ 2:13 AM"
        canvas.text(read, x: x - Canvas.textWidth(read, dot: sd) - dot * 2, y: ((hD - sd * 7) / 2).rounded(), dot: sd, .white, alpha: 0.45)
    }

    // MARK: Custom

    func marquee(_ p: Params, _ t: Double) {
        canvas.clear()
        let raw = p.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = raw.isEmpty ? "TYPE YOUR TEXT IN SETTINGS" : raw
        let c = raw.isEmpty ? p.color.scaled(0.6) : p.color
        let dot = dotSize(fill: 0.8)
        let speed = H * 3.2
        if PixelFont.canDraw(text) || rasterizer == nil {
            // An LED sign: unlit dots behind, lit letters scrolling past.
            let top = ((H - dot * 7) / 2).rounded()
            var gx = dot / 2
            while gx < W {
                for r in 0..<7 { canvas.circle(gx, top + Double(r) * dot + dot / 2, dot * 0.3, c, alpha: 0.07) }
                gx += dot
            }
            let tw = Canvas.textWidth(text, dot: dot)
            let period = tw + H * 4
            let off = fract(t * speed / period) * period
            var x = (W - off).rounded()
            while x > -period { x -= period }
            while x < W {
                canvas.text(text, x: (x / dot).rounded() * dot, y: top, dot: dot, c, style: .led)
                x += period
            }
        } else if let r = rasterizer {
            let height = Int(H * 0.8)
            if textCache?.key != text + "\(height)", let m = r(text, height) { textCache = (text + "\(height)", m.mask, m.width) }
            guard let cache = textCache else { return }
            let period = Double(cache.width) + H * 4
            let off = fract(t * speed / period) * period
            var x = W - off
            while x > -period { x -= period }
            while x < W {
                canvas.mask(cache.mask, cache.width, height, x: Int(x.rounded()), y: Int((H - Double(height)) / 2), c)
                x += period
            }
        }
    }

    func media(_ p: Params, _ t: Double) {
        guard let clip = p.media, let frame = clip.frame(at: t) else {
            canvas.clear()
            let dot = dotSize(fill: 0.5, maxWidth: view.w * 0.9, text: "CHOOSE A GIF OR VIDEO IN SETTINGS")
            canvas.text("CHOOSE A GIF OR VIDEO IN SETTINGS", centerX: view.x + view.w / 2, centerY: H / 2, dot: dot, .white, alpha: 0.5)
            return
        }
        let mw = clip.width, mh = clip.height, wD = W, hD = H
        canvas.shade { (x: Double, y: Double) -> RGB in
            let sx = min(mw - 1, Int(x / wD * Double(mw))), sy = min(mh - 1, Int(y / hD * Double(mh)))
            let o = (sy * mw + sx) * 3
            return RGB(r: Double(frame[o]) / 255, g: Double(frame[o + 1]) / 255, b: Double(frame[o + 2]) / 255)
        }
    }
}
