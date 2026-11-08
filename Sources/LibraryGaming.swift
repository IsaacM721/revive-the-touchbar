import Foundation

// Gaming: HUD pieces and tiny games. Everything is scripted on a loop, so it always "plays well".

extension EffectCore {

    private static let heart = Sprite([".##.##.", "#w#####", "#######", ".#####.", "..###..", "...#..."],
                                      ["#": RGB(0xFF1744), "w": RGB(r: 1, g: 0.75, b: 0.8)])

    /// Local time within a repeating cycle, never negative.
    func loop(_ t: Double, _ period: Double) -> Double {
        let l = t.truncatingRemainder(dividingBy: period)
        return l < 0 ? l + period : l
    }

    func healthBar(_ t: Double) {
        canvas.clear(RGB(r: 0.02, g: 0.01, b: 0.015))
        let cycle = 10.0
        let hits: [(at: Double, dmg: Double)] = [(0.8, 18), (1.9, 25), (2.7, 12), (3.9, 22), (5.0, 11)]
        let healAt = 6.6, healFor = 1.4
        func hp(_ tt: Double) -> Double {
            let l = loop(tt, cycle)
            var v = 100.0
            for h in hits where l >= h.at { v -= h.dmg }
            if l >= healAt { v += (100 - v) * smoothstep(0, 1, (l - healAt) / healFor) }
            return v
        }
        let local = loop(t, cycle)
        let now = hp(t)
        let ghost = local >= healAt ? now : max(now, hp(t - 0.6))
        let sinceHit = hits.filter { local >= $0.at }.last.map { local - $0.at } ?? 99
        let shake = sinceHit < 0.25 ? sin(sinceHit * 90) * H * 0.07 * (1 - sinceHit / 0.25) : 0
        let dot = dotSize(fill: 0.5)
        let ty = ((H - dot * 7) / 2).rounded()

        // Heart, beating faster when low.
        let beat = now < 30 ? 1 + 0.15 * max(0, sin(t * 18)) : 1 + 0.05 * max(0, sin(t * 7))
        let hd = dot * 0.95 * beat
        canvas.sprite(EffectCore.heart, x: dot * 3 + shake - (hd - dot) * 3.5, y: (H - hd * 6) / 2, dot: hd)
        canvas.text("HP", x: dot * 3 + dot * 9 + shake, y: ty, dot: dot, .white)

        let x0 = dot * 3 + dot * 27 + shake
        let label = "\(Int(now.rounded()))/100"
        let lw = Canvas.textWidth("100/100", dot: dot)
        let x1 = W - dot * 4 - lw + shake
        let bh = H * 0.5, by = (H - bh) / 2
        canvas.rect(x0 - 1, by - 1, x1 - x0 + 2, bh + 2, RGB(r: 0.35, g: 0.35, b: 0.4))
        canvas.rect(x0, by, x1 - x0, bh, RGB(r: 0.08, g: 0.06, b: 0.08))
        let fillColor: RGB = now > 50 ? RGB(0x44D62C) : now > 25 ? RGB(0xFFD600) : RGB(0xFF1744)
        let low = now <= 25 && Int(t * 4) % 2 == 0
        canvas.rect(x0, by, (x1 - x0) * ghost / 100, bh, RGB(r: 1, g: 0.92, b: 0.6), alpha: 0.85)
        canvas.rect(x0, by, (x1 - x0) * now / 100, bh, fillColor, alpha: low ? 0.6 : 1)
        canvas.rect(x0, by, (x1 - x0) * now / 100, bh * 0.3, .white, alpha: 0.25)
        for s in 1..<10 { canvas.rect(x0 + (x1 - x0) * Double(s) / 10 - 0.5, by, 1, bh, .black, alpha: 0.45) }
        canvas.text(label, x: W - dot * 3 - Canvas.textWidth(label, dot: dot) + shake, y: ty, dot: dot, .white)

        if sinceHit < 0.9, let h = hits.filter({ local >= $0.at }).last {
            let fx = x0 + (x1 - x0) * now / 100
            canvas.text("-\(Int(h.dmg))", centerX: fx + dot * 6, centerY: H / 2 - sinceHit * H * 0.5, dot: dot, RGB(0xFF1744), alpha: 1 - sinceHit / 0.9)
            canvas.rect(0, 0, W, H, RGB(0xFF1744), alpha: max(0, 0.3 * (1 - sinceHit / 0.3)), additive: true)
        }
        if local >= healAt && local < healAt + healFor + 0.6 {
            let a = local - healAt
            canvas.text("+\(Int(100 - hp(healAt * 0.999 + floor(t / cycle) * cycle)))", centerX: x0 + (x1 - x0) * 0.55, centerY: H / 2 - a * H * 0.35, dot: dot, RGB(0x69F0AE), alpha: clamp01(1 - (a - healFor) / 0.6))
            for i in 0..<10 {
                let sx = x0 + (x1 - x0) * rand01(i, 3) * now / 100
                canvas.glow(sx, H * (1 - fract(a * 0.8 + rand01(i, 4))), H * 0.08, RGB(0x69F0AE), 0.7)
            }
        }
    }

    func xpBar(_ t: Double) {
        canvas.clear(RGB(r: 0.015, g: 0.015, b: 0.03))
        let cycle = 6.5
        let gains: [(at: Double, xp: Double)] = [(0.5, 120), (1.3, 80), (2.0, 150), (2.8, 90), (3.5, 200), (4.2, 160)]
        let maxXP = 800.0
        let local = loop(t, cycle)
        let level = 12 + Int((t / cycle).rounded(.down)) % 88
        var xp = 0.0
        for g in gains where local >= g.at { xp += g.xp * smoothstep(0, 1, (local - g.at) / 0.35) }
        let leveled = local >= 4.2 + 0.35
        let gold = RGB(0xFFD600)
        let dot = dotSize(fill: 0.5)
        let ty = ((H - dot * 7) / 2).rounded()
        let lv = "LV \(level)"
        canvas.text(lv, x: dot * 3, y: ty, dot: dot, gold, glow: 0.15)
        let x0 = dot * 3 + Canvas.textWidth("LV 99", dot: dot) + dot * 4
        let right = "\(Int(xp.rounded()))/800 XP"
        let x1 = W - dot * 7 - Canvas.textWidth("800/800 XP", dot: dot)
        let bh = H * 0.36, by = (H - bh) / 2
        canvas.roundedRect(x0 - 1, by - 1, x1 - x0 + 2, bh + 2, radius: bh / 2 + 1, RGB(r: 0.3, g: 0.3, b: 0.38))
        canvas.roundedRect(x0, by, x1 - x0, bh, radius: bh / 2, RGB(r: 0.05, g: 0.05, b: 0.1))
        let fw = (x1 - x0) * min(1, xp / maxXP)
        let flash = leveled && Int(local * 8) % 2 == 0
        if fw > 1 {
            let fill0 = RGB(0x00E5FF), fill1 = RGB(0x69F0AE)
            for sx in stride(from: 0.0, to: fw, by: 2) {
                let c = flash ? gold : fill0.mixed(with: fill1, sx / (x1 - x0))
                canvas.rect(x0 + sx, by, min(2, fw - sx), bh, c)
            }
            // A shine that sweeps along the fill.
            let shine = fract(t * 0.6) * (x1 - x0)
            if shine < fw { canvas.glow(x0 + shine, by + bh / 2, bh, .white, 0.5) }
        }
        canvas.text(right, x: W - dot * 3 - Canvas.textWidth(right, dot: dot), y: ty, dot: dot, .white, alpha: 0.9)
        for g in gains where local >= g.at && local < g.at + 1.0 {
            let a = local - g.at
            let fx = x0 + (x1 - x0) * min(1, xp / maxXP)
            canvas.text("+\(Int(g.xp)) XP", centerX: fx, centerY: H / 2 - a * H * 0.5, dot: max(1, dot * 0.75), RGB(0x69F0AE), alpha: 1 - a)
        }
        if leveled {
            let a = local - 4.55
            for i in 0..<24 {
                let sx = x0 + rand01(i, 5) * (x1 - x0)
                canvas.glow(sx, H * (1 - fract(a * 0.9 + rand01(i, 6))), H * 0.07, gold, 0.9 * (1 - a / 2))
            }
            let d2 = dotSize(fill: 0.72)
            canvas.text("LEVEL UP!", centerX: (x0 + x1) / 2 + 1, centerY: H / 2 + 1, dot: d2, .black, alpha: 0.8)
            canvas.text("LEVEL UP!", centerX: (x0 + x1) / 2, centerY: H / 2, dot: d2, flash ? .white : gold, glow: 0.3)
        }
    }

    func coinRush(_ t: Double) {
        let hD = H
        canvas.shade { (_: Double, y: Double) -> RGB in
            let v: Double = y / hD
            return RGB(r: 0.03 + 0.03 * v, g: 0.02 + 0.02 * v, b: 0.1 + 0.05 * v)
        }
        let gold = RGB(r: 1, g: 0.8, b: 0.15), rim = RGB(r: 0.8, g: 0.5, b: 0.05)
        let dot = dotSize(fill: 0.55)
        let r = H * 0.3
        let counterW = Canvas.textWidth("×000", dot: dot) + r * 2 + dot * 6
        let target = W - counterW
        let interval = 0.32, speed = H * 7
        let travel = (target + r * 2) / speed
        // Coins that have already arrived.
        let collected = max(0, Int(((t - travel) / interval).rounded(.down)) + 1)
        let first = max(0, Int(((t - travel) / interval).rounded(.up)))
        let last = Int((t / interval).rounded(.down))
        if first <= last {
            for j in first...last {
                let age = t - Double(j) * interval
                let x = age * speed - r * 2
                let y = hD / 2 + sin(x * 0.018 + Double(j)) * hD * 0.12
                let wf = max(0.12, abs(cos(t * 5 + Double(j) * 0.7)))
                canvas.ellipse(x, y, r * wf, r, rim)
                canvas.ellipse(x, y, r * wf * 0.78, r * 0.78, gold)
                canvas.ellipse(x - r * wf * 0.25, y - r * 0.3, r * wf * 0.2, r * 0.18, .white, alpha: 0.7)
            }
        }
        // The counter, with a pop when a coin lands.
        let since = t - (Double(collected - 1) * interval + travel)
        let pop = collected > 0 && since < 0.2 ? 1 - since / 0.2 : 0
        let cx = target + r * 1.5
        canvas.ellipse(cx, hD / 2, r * (1 + pop * 0.25), r * (1 + pop * 0.25), rim)
        canvas.ellipse(cx, hD / 2, r * 0.78 * (1 + pop * 0.25), r * 0.78 * (1 + pop * 0.25), gold)
        if pop > 0 { canvas.glow(cx, hD / 2, r * 2, gold, pop) }
        canvas.text(String(format: "×%03d", collected % 1000), x: cx + r * 1.6, y: ((hD - dot * 7) / 2).rounded(), dot: dot, .white)
    }

    func wantedLevel(_ t: Double) {
        canvas.clear(RGB(r: 0.02, g: 0.02, b: 0.04))
        let cycle = 11.0
        let local = loop(t, cycle)
        let level = min(5, 1 + Int(local / 1.5))
        let maxed = local > 7.5
        // Police lights: red on the left, blue on the right, double flash.
        let ph = fract(t / 0.5)
        let red = (ph < 0.08 || (ph > 0.14 && ph < 0.22)) ? 1.0 : 0.0
        let blue = (ph > 0.5 && ph < 0.58) || (ph > 0.64 && ph < 0.72) ? 1.0 : 0.0
        canvas.glow(W * 0.06, H / 2, H * 1.6, RGB(r: 1, g: 0.05, b: 0.1), 0.9 * red)
        canvas.glow(W * 0.94, H / 2, H * 1.6, RGB(r: 0.1, g: 0.3, b: 1), 0.9 * blue)
        canvas.glow(W * 0.3, H / 2, H * 1.2, RGB(r: 1, g: 0.05, b: 0.1), 0.35 * red)
        canvas.glow(W * 0.7, H / 2, H * 1.2, RGB(r: 0.1, g: 0.3, b: 1), 0.35 * blue)
        let dot = dotSize(fill: 0.75)
        let starW = Canvas.textWidth("★", dot: dot)
        let gap = dot * 2
        let label = "WANTED"
        let ld = dotSize(fill: 0.5)
        let total = Canvas.textWidth(label, dot: ld) + dot * 4 + 5 * starW + 4 * gap
        var x = (view.x + (view.w - total) / 2).rounded()
        canvas.text(label, x: x, y: ((H - ld * 7) / 2).rounded(), dot: ld, .white, alpha: 0.75)
        x += Canvas.textWidth(label, dot: ld) + dot * 4
        let sy = ((H - dot * 7) / 2).rounded()
        for i in 0..<5 {
            let lit = i < level
            let fresh = lit && i == level - 1 && fract(local / 1.5) < 0.4 && !maxed
            let blink = (fresh || maxed) && Int(t * 6) % 2 == 0
            if lit {
                canvas.text("★", x: x, y: sy, dot: dot, blink ? RGB(r: 1, g: 1, b: 1) : RGB(r: 1, g: 0.85, b: 0.3), alpha: blink ? 0.55 : 1, glow: 0.25)
            } else {
                canvas.text("★", x: x, y: sy, dot: dot, .white, alpha: 0.13)
            }
            x += starW + gap
        }
    }

    private static let runnerFrames: [Sprite] = {
        let top = ["..hhhh..", ".hhhhhhh", "..ssse..", "..ssss..", ".bbbbbb.", "s.bbbb.s", "..bbbb.."]
        let pal: [Character: RGB] = ["h": RGB(0xFF1744), "s": RGB(r: 1, g: 0.8, b: 0.6), "e": RGB(r: 0.05, g: 0.05, b: 0.1),
                                     "b": RGB(0x2979FF), "l": RGB(r: 0.25, g: 0.2, b: 0.3)]
        return [
            Sprite(top + ["..l..l..", ".l....l.", "l......l"], pal),
            Sprite(top + ["...ll...", "...ll...", "..l.l..."], pal),
            Sprite(top + ["..llll..", ".l....l.", "........"], pal),
        ]
    }()

    private static let crate = Sprite(["dddddd", "dcdccd", "dccdcd", "dcdccd", "dccdcd", "dddddd"],
                                      ["d": RGB(r: 0.4, g: 0.22, b: 0.08), "c": RGB(r: 0.78, g: 0.5, b: 0.22)])

    func pixelRunner(_ t: Double) {
        let hD = H, wD = W
        let ground = (hD * 0.84).rounded()
        canvas.shade { (x: Double, y: Double) -> RGB in
            let v: Double = y / hD
            let band: Double = (v * 5).rounded(.down) / 5
            var c = RGB(r: 0.2 + 0.6 * band, g: 0.12 + 0.25 * band, b: 0.4 - 0.05 * band)
            let hill: Double = hD * (0.35 + 0.3 * noise1((x + t * hD * 0.6) / hD * 0.25, 13))
            if y > ground - hill * 0.5 { c = RGB(r: 0.25, g: 0.12, b: 0.35) }
            return c
        }
        // Ground: a strip with dashes that scroll at running speed.
        let speed = hD * 5.5
        let s = t * speed
        canvas.rect(0, ground, wD, hD - ground, RGB(r: 0.18, g: 0.55, b: 0.2))
        canvas.rect(0, ground, wD, max(1, hD * 0.05), RGB(r: 0.45, g: 0.85, b: 0.35))
        var dx = -fract(s / (hD * 0.8)) * hD * 0.8
        while dx < wD { canvas.rect(dx, ground + (hD - ground) * 0.55, hD * 0.25, max(1, hD * 0.04), RGB(r: 0.1, g: 0.35, b: 0.12)); dx += hD * 0.8 }

        // Crates along the track at uneven gaps (cached so the course repeats).
        let crateDot = hD * 0.07, crateW = crateDot * 6
        let course: [Double] = cached("runner\(Int(hD))") {
            var xs: [Double] = [], x = hD * 12
            for j in 0..<400 { xs.append(x); x += hD * (6 + rand01(j, 81) * 9) }
            return xs
        }
        let lap = course.last! + hD * 10
        let sl = s.truncatingRemainder(dividingBy: lap)
        let dot = hD / 12.5
        let rx = wD * 0.16, rw = dot * 8
        let jumpLen = speed * 0.6, jumpH = hD * 0.5
        var lift = 0.0
        for cx in course {
            let screen = cx - sl + rx
            if screen > wD + crateW { break }
            if screen < -crateW * 4 { continue }
            canvas.sprite(EffectCore.crate, x: screen, y: ground - crateW, dot: crateDot)
            let d = sl - (cx + crateW / 2 - rw / 2)
            if abs(d) < jumpLen / 2 { lift = max(lift, jumpH * (1 - pow(2 * d / jumpLen, 2))) }
        }
        let frame = lift > 0.5 ? 2 : Int(t * 10) % 2
        canvas.sprite(EffectCore.runnerFrames[frame], x: rx, y: ground - dot * 10 - lift, dot: dot)
        let sd = max(1, (hD / 16).rounded())
        let score = String(format: "%05d", Int(s / hD * 10) % 100000)
        canvas.text(score, x: wD - sd * 3 - Canvas.textWidth(score, dot: sd), y: sd * 1.5, dot: sd, .white, alpha: 0.9)
    }

    func shooterHUD(_ t: Double) {
        let hD = H, wD = W
        canvas.shade { (x: Double, y: Double) -> RGB in
            let e: Double = min(1, min(x, wD - x) / (wD * 0.2)) * 0.6 + 0.4
            return RGB(r: 0.02 * e, g: 0.04 * e, b: 0.045 * e)
        }
        let cycle = 9.0
        let local = loop(t, cycle)
        let bursts: [(Double, Double, Int)] = [(0.3, 1.2, 6), (2.0, 2.9, 6), (3.6, 4.8, 8), (5.4, 6.2, 5)]
        var ammo = 30, firing = false, lastShot = -9.0
        for (a, b, n) in bursts {
            if local >= a {
                let fired = min(n, Int((min(local, b) - a) / ((b - a) / Double(n))) + 1)
                ammo -= fired
                if local < b { firing = true; lastShot = a + Double(fired - 1) * (b - a) / Double(n) }
                else { lastShot = max(lastShot, a + Double(n - 1) * (b - a) / Double(n)) }
            }
        }
        let reloading = local >= 6.6 && local < 8.2
        if local >= 8.2 { ammo = 30 }
        let reserve = local >= 8.2 ? 65 : 90
        let sinceShot = local - lastShot
        let cx = wD / 2, cy = hD / 2
        let u = max(1, hD / 15)
        let spread = u * (2 + (firing ? 2.5 * exp(-sinceShot * 8) + 1 : 0))
        let arm = u * 3.5
        let green = RGB(0x69F0AE)
        canvas.line(cx - spread - arm, cy, cx - spread, cy, width: u * 0.8, green)
        canvas.line(cx + spread, cy, cx + spread + arm, cy, width: u * 0.8, green)
        canvas.line(cx, cy - spread - arm, cx, cy - spread, width: u * 0.8, green)
        canvas.line(cx, cy + spread, cx, cy + spread + arm, width: u * 0.8, green)
        canvas.circle(cx, cy, u * 0.6, green)
        if firing && sinceShot < 0.08 { canvas.glow(cx, cy, hD * 0.5, RGB(r: 1, g: 0.8, b: 0.4), 0.35) }
        if firing && Int(local * 7) % 3 == 0 && sinceShot < 0.15 {
            canvas.text("×", centerX: cx, centerY: cy, dot: u * 1.4, .white, alpha: 0.9)
        }
        let dot = dotSize(fill: 0.5)
        let ty = ((hD - dot * 7) / 2).rounded()
        canvas.text("♥ 100", x: dot * 3, y: ty, dot: dot, green)
        for (start, name) in [(1.2, "YOU ⌖ BOT_07"), (4.9, "YOU ⌖ BOT_12")] where local >= start && local < start + 2 {
            let a = clamp01((start + 2 - local) / 0.5)
            canvas.text(name, x: cx + hD * 1.4, y: ty, dot: max(1, dot * 0.8), .white, alpha: a * 0.85)
        }
        let ammoText = reloading ? "RELOADING…" : "\(ammo) / \(reserve)"
        let ac: RGB = ammo <= 5 && !reloading ? RGB(0xFF5252) : .white
        canvas.text(ammoText, x: wD - dot * 3 - Canvas.textWidth(ammoText, dot: dot), y: ty, dot: dot, ac,
                    alpha: reloading ? 0.5 + 0.5 * sin(local * 12) : 1)
    }

    func bossFight(_ t: Double) {
        let hD = H, wD = W
        let cycle = 16.0
        let local = loop(t, cycle)
        let pulse = 0.5 + 0.5 * sin(t * 1.5)
        canvas.shade { (_: Double, y: Double) -> RGB in
            let v: Double = y / hD
            return RGB(r: 0.08 + 0.05 * pulse * (1 - v), g: 0.0, b: 0.02)
        }
        // Scripted hits: 20 hits over 13 s.
        func hp(_ l: Double) -> Double {
            var v = 100.0
            for i in 0..<20 {
                let at = 0.6 + Double(i) * 0.62 + rand01(i, 91) * 0.3
                if l >= at { v -= 3 + rand01(i, 92) * 3.4 }
            }
            return max(0, v)
        }
        let now = hp(local), ghost = max(now, hp(local - 0.5))
        let dead = local > 13.6
        let enraged = now < 50 && !dead
        let dot = dotSize(fill: 0.46)
        let name = enraged ? "TOUCH BAR KING · ENRAGED" : "TOUCH BAR KING"
        let nameW = Canvas.textWidth("TOUCH BAR KING · ENRAGED", dot: dot)
        let ty = ((hD - dot * 7) / 2).rounded()
        canvas.text(name, x: dot * 3, y: ty, dot: dot, enraged ? RGB(0xFF5252) : RGB(r: 1, g: 0.85, b: 0.5))
        let x0 = dot * 3 + nameW + dot * 4, x1 = wD - dot * 3
        let bh = hD * 0.34, by = (hD - bh) / 2
        canvas.rect(x0 - 2, by - 2, x1 - x0 + 4, bh + 4, RGB(r: 0.75, g: 0.6, b: 0.25))
        canvas.rect(x0 - 1, by - 1, x1 - x0 + 2, bh + 2, .black)
        let fillC: RGB = enraged ? RGB(0x9D4DFF) : RGB(0xFF1744)
        canvas.rect(x0, by, (x1 - x0) * ghost / 100, bh, RGB(r: 1, g: 0.85, b: 0.3))
        canvas.rect(x0, by, (x1 - x0) * now / 100, bh, fillC)
        canvas.rect(x0, by, (x1 - x0) * now / 100, bh * 0.3, .white, alpha: 0.22)
        if ghost > now + 0.1 { canvas.rect(x0 + (x1 - x0) * now / 100 - 1, by, 2, bh, .white) }
        if dead {
            let a = local - 13.6
            let gold = RGB(0xFFD600)
            for i in 0..<30 {
                canvas.glow(x0 + rand01(i, 7) * (x1 - x0), hD * (1 - fract(a * 0.7 + rand01(i, 8))), hD * 0.08, gold, 0.9)
            }
            let d2 = dotSize(fill: 0.72)
            canvas.text("VICTORY", centerX: (x0 + x1) / 2, centerY: hD / 2, dot: d2, gold, glow: 0.3)
        }
    }
}
