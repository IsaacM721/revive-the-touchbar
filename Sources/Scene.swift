import Foundation

// Animation drops: animations described as data (JSON), downloaded from the website, so new ones can
// ship every week without an app update. A scene is a background plus a stack of layers drawn in order.
// The format is small on purpose: it is easy to write by hand, easy to review, and easy for a model to
// generate from a description later. Everything is clamped, so a bad file can't hurt performance.
//
// Example (see docs/drops.json for more):
//   { "id": "skill-issue", "name": "Skill Issue", "category": "memes",
//     "background": ["#1a0005"],
//     "layers": [ { "type": "stripes", "colors": ["#ff1744", "#220008"], "width": 0.5, "speed": 0.4 },
//                 { "type": "text", "text": "SKILL ISSUE", "motion": "blink", "color": "#ffffff", "plate": "#000000" } ] }

struct SceneSpec: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var blurb: String?
    /// One of the library shelves (`EffectCategory` raw values). Defaults to memes.
    var category: String?
    var author: String?
    /// When it was published, "YYYY-MM-DD". Newest drops show first with a "New" tag.
    var added: String?
    /// Name and blurb in other languages: {"es": {"name": "...", "blurb": "..."}}.
    var i18n: [String: [String: String]]?
    /// One color (solid) or several (a vertical gradient, top to bottom).
    var background: [String]?
    /// Where small previews should look, 0 (left end) to 1 (right end). Defaults to the middle.
    var focus: Double?
    var layers: [SceneLayer]

    func localizedName(_ lang: String) -> String { i18n?[lang]?["name"] ?? name }
    func localizedBlurb(_ lang: String) -> String? { i18n?[lang]?["blurb"] ?? blurb }
    var shelf: EffectCategory { EffectCategory(rawValue: category ?? "") ?? .memes }
}

struct SceneLayer: Codable, Equatable {
    /// gradient, stripes, noise, particles, text, sprite, bars, scanlines, pulse
    var type: String
    var color: String?
    var colors: [String]?
    var speed: Double?
    var alpha: Double?
    // text
    var text: String?
    /// Several messages shown in turn, `every` seconds each.
    var texts: [String]?
    var every: Double?
    /// scroll, center, wave, blink, typewriter
    var motion: String?
    /// Height as a fraction of the bar (text and sprites).
    var size: Double?
    /// block or led
    var style: String?
    var glow: Double?
    /// Horizontal anchor 0...1 for centered text and sprites.
    var x: Double?
    /// A dark plate behind text so it reads over busy layers.
    var plate: String?
    // particles
    /// rise, fall, drift, twinkle, confetti
    var kind: String?
    var count: Int?
    // sprite
    var pixels: [String]?
    var palette: [String: String]?
    // stripes, gradient
    var width: Double?
    var direction: String?
    // bars
    var bars: Int?
}

extension EffectCore {
    func drawScene(_ s: SceneSpec, _ p: Params, _ t: Double) {
        let bg = (s.background ?? ["#000000"]).prefix(4).compactMap { RGB(hex: $0) }
        if bg.count <= 1 {
            canvas.clear(bg.first ?? .black)
        } else {
            let hD = H
            canvas.shade { (_: Double, y: Double) -> RGB in EffectCore.ramp(bg, y / hD) }
        }
        for (i, layer) in s.layers.prefix(8).enumerated() { drawLayer(layer, index: i, p, t) }
    }

    /// Picks a color along a list, blending between neighbors. `f` is 0...1.
    static func ramp(_ colors: [RGB], _ f: Double) -> RGB {
        guard colors.count > 1 else { return colors.first ?? .black }
        let x = clamp01(f) * Double(colors.count - 1)
        let i = min(colors.count - 2, Int(x))
        return colors[i].mixed(with: colors[i + 1], x - Double(i))
    }

    private func drawLayer(_ l: SceneLayer, index: Int, _ p: Params, _ t: Double) {
        let colors = (l.colors ?? l.color.map { [$0] } ?? []).prefix(8).compactMap { RGB(hex: $0) }
        let main = colors.first ?? p.color
        let speed = min(20, max(-20, l.speed ?? 1))
        let alpha = clamp01(l.alpha ?? 1)
        let salt = UInt32(index &* 977 &+ 13)
        let hD = H, wD = W
        switch l.type {

        case "gradient":
            let cs = colors.isEmpty ? [RGB(0xFF2BD6), RGB(0x00E5FF)] : colors
            let loopCs = cs + [cs[0]]
            let vertical = l.direction == "vertical"
            let span = max(0.2, l.width ?? 1) * wD
            for y in 0..<h {
                for x in 0..<w {
                    let f: Double = vertical ? (Double(y) + 0.5) / hD : fract((Double(x) + 0.5 + canvas.ox) / span - t * speed * 0.08)
                    canvas.blend(x, y, vertical ? EffectCore.ramp(cs, f) : EffectCore.ramp(loopCs, f), alpha)
                }
            }

        case "stripes":
            let a = colors.first ?? RGB(0xFFD600), b = colors.count > 1 ? colors[1] : .black
            let sw = hD * min(3, max(0.1, l.width ?? 0.5))
            let slant = l.direction == "vertical" ? 0.0 : 1.0
            canvas.overlay { (x: Double, y: Double) -> RGB? in
                fract((x + y * slant) / (sw * 2) - t * speed * 0.3) < 0.5 ? a : b
            }

        case "noise":
            let cs = colors.count >= 2 ? colors : [RGB(r: 0.02, g: 0.01, b: 0.08), RGB(0x9D4DFF), RGB(0x00E5FF)]
            let scale = min(4, max(0.1, l.width ?? 1))
            canvas.overlay { (x: Double, y: Double) -> RGB? in
                let n: Double = fbm(x / hD * 0.3 / scale - t * speed * 0.05, y / hD / scale + t * speed * 0.03, octaves: 4, salt)
                return EffectCore.ramp(cs, smoothstep(0.25, 0.8, n))
            }

        case "particles":
            let kind = l.kind ?? "drift"
            let n = min(300, max(1, l.count ?? Int(wD / 12)))
            let size = min(0.5, max(0.02, l.size ?? 0.08)) * hD
            let cs = colors.isEmpty ? [RGB.white] : colors
            for i in 0..<n {
                let c = cs[Int(rand01(i, salt &+ 1) * Double(cs.count)) % cs.count]
                let r = size * (0.5 + rand01(i, salt &+ 2))
                let ph = rand01(i, salt &+ 3)
                let bx = rand01(i, salt &+ 4) * wD
                let sp = (0.5 + rand01(i, salt &+ 5)) * speed
                switch kind {
                case "rise", "fall":
                    let f = fract(ph + t * sp * 0.35)
                    let y = kind == "rise" ? hD * (1.1 - f * 1.2) : hD * (-0.1 + f * 1.2)
                    let x = bx + sin(t * 2 * sp + Double(i)) * hD * 0.15
                    canvas.glow(x, y, r, c, alpha * (kind == "rise" ? 1 - f : 1))
                case "confetti":
                    let f = fract(ph + t * sp * 0.4)
                    let y = hD * (-0.1 + f * 1.2), x = bx + sin(t * 3 * sp + Double(i)) * hD * 0.2
                    let wob = abs(sin(t * 6 * sp + Double(i)))
                    canvas.rect(x, y, r * 1.6 * max(0.2, wob), r * 0.9, c, alpha: alpha)
                case "twinkle":
                    let tw = pow(max(0, sin(t * sp * 2 + ph * 6.28)), 3)
                    canvas.glow(bx, rand01(i, salt &+ 6) * hD, r, c, alpha * tw)
                default:
                    let x = fract(bx / wD + t * sp * 0.02) * wD
                    let y = hD * rand01(i, salt &+ 6) + sin(t * sp + Double(i)) * hD * 0.1
                    canvas.glow(x, y, r, c, alpha * (0.5 + 0.5 * sin(t * 2 + Double(i))))
                }
            }

        case "text":
            let messages = (l.texts ?? [l.text ?? ""]).prefix(12).map { String($0.prefix(120)) }
            guard !messages.isEmpty else { return }
            let every = max(0.5, l.every ?? 3)
            let k = Int((t / every).rounded(.down))
            let local = t - Double(k) * every
            let msg = messages[k % messages.count]
            let motion = l.motion ?? "center"
            let style: Canvas.TextStyle = l.style == "led" ? .led : .block
            var dot = dotSize(fill: min(0.95, max(0.25, l.size ?? 0.66)))
            if motion != "scroll" { dot = min(dot, dotSize(fill: 0.95, maxWidth: view.w * 0.94, text: msg)) }
            let tw = Canvas.textWidth(msg, dot: dot)
            // Placed on the visible part of the bar (all of it on the Touch Bar, the window in previews).
            let cx = min(view.x + view.w - tw / 2, max(view.x + tw / 2, view.x + view.w * clamp01(l.x ?? 0.5)))
            let glow = min(1, max(0, l.glow ?? 0))
            if let plateHex = l.plate, let pc = RGB(hex: plateHex), motion != "scroll" {
                canvas.rect(cx - tw / 2 - dot * 3, (hD - dot * 10) / 2, tw + dot * 6, dot * 10, pc, alpha: 0.85)
            }
            let top = ((hD - dot * 7) / 2).rounded()
            switch motion {
            case "scroll":
                let period = tw + hD * 4
                var x = wD - fract(t * speed * hD * 3 / period) * period
                while x > -period { x -= period }
                while x < wD { canvas.text(msg, x: x.rounded(), y: top, dot: dot, main, style: style, alpha: alpha, glow: glow); x += period }
            case "wave":
                wavyText(msg, centerX: cx, centerY: hD / 2, dot: dot, main, t: t * speed, amp: dot * 0.5)
            case "blink":
                let on = fract(t * speed * 0.8) < 0.7
                canvas.text(msg, centerX: cx, centerY: hD / 2, dot: dot, main, style: style, alpha: on ? alpha : alpha * 0.25, glow: glow)
            case "typewriter":
                let shown = String(msg.prefix(Int(local * 14 * speed)))
                let x = (cx - tw / 2).rounded()
                let w = canvas.text(shown, x: x, y: top, dot: dot, main, style: style, alpha: alpha, glow: glow)
                if Int(t * 2.4) % 2 == 0 { canvas.rect(x + w + (shown.isEmpty ? 0 : dot), top, dot * 5, dot * 7, main, alpha: alpha) }
            default:
                // Rainbow text when several colors are given.
                if colors.count > 1 {
                    var pen = (cx - tw / 2).rounded()
                    for (i, ch) in msg.enumerated() {
                        let c = EffectCore.ramp(colors + [colors[0]], fract(Double(i) * 0.08 - t * speed * 0.3))
                        pen += canvas.text(String(ch), x: pen, y: top, dot: dot, c, style: style, alpha: alpha, glow: glow) + dot
                    }
                } else {
                    canvas.text(msg, centerX: cx, centerY: hD / 2, dot: dot, main, style: style, alpha: alpha, glow: glow)
                }
            }

        case "sprite":
            let rows = (l.pixels ?? []).prefix(16).map { String($0.prefix(32)) }
            guard !rows.isEmpty else { return }
            var pal: [Character: RGB] = [:]
            for (k, v) in l.palette ?? [:] { if let ch = k.first, let c = RGB(hex: v) { pal[ch] = c } }
            if pal.isEmpty { pal["#"] = main }
            let sprite = Sprite(rows, pal)
            let dot = hD * min(1, max(0.2, l.size ?? 0.7)) / Double(max(1, sprite.h))
            let sw = Double(sprite.w) * dot, sh = Double(sprite.h) * dot
            switch l.motion ?? "center" {
            case "walk":
                let span = wD + sw * 2
                let x = fract(rand01(index, salt) + t * speed * hD * 2 / span) * span - sw
                canvas.sprite(sprite, x: x, y: (hD - sh) / 2 + sin(t * 8 * speed) * dot * 0.5, dot: dot, alpha: alpha)
            case "bounce":
                let b = bounce(t * speed * 0.15)
                canvas.sprite(sprite, x: view.x + b.pos * (view.w - sw), y: (hD - sh) / 2 - abs(sin(t * 5 * speed)) * (hD - sh) / 2, dot: dot, flip: b.hits % 2 == 1, alpha: alpha)
            default:
                let cx = view.x + view.w * clamp01(l.x ?? 0.5)
                canvas.sprite(sprite, x: (cx - sw / 2).rounded(), y: (hD - sh) / 2 + sin(t * 3 * speed) * dot * 0.6, dot: dot, alpha: alpha)
            }

        case "bars":
            let n = min(128, max(4, l.bars ?? Int(wD / (hD * 0.7))))
            let bw = wD / Double(n)
            let cs = colors.isEmpty ? [RGB(0x44D62C), RGB(0xFFD600), RGB(0xFF1744)] : colors
            for i in 0..<n {
                let lv = clamp01(0.1 + 0.8 * pow(noise1(t * speed * 3 + Double(i) * 0.6, salt), 1.4) + exp(-fract(t * speed / 0.5) * 5) * 0.4 * (1 - Double(i) / Double(n)))
                let bh = hD * lv
                canvas.rect(Double(i) * bw + bw * 0.12, hD - bh, bw * 0.76, bh, EffectCore.ramp(cs, lv), alpha: alpha)
            }

        case "scanlines":
            let k = 1 - 0.35 * alpha
            canvas.multiply { (_: Double, y: Double) -> Double in Int(y) % 2 == 0 ? 1 : k }

        case "pulse":
            let k = 1 - 0.5 * alpha * (0.5 + 0.5 * sin(t * speed * 4))
            canvas.multiply { (_: Double, _: Double) -> Double in k }

        default:
            break
        }
    }
}
