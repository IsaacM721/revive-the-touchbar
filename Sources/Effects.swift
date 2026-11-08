import Cocoa

/// The Mac side of the renderer. `EffectCore` (plain Swift, see EffectCore.swift and Library*.swift) draws
/// every effect; this owns the bitmap it draws into and lends it the system font for the Matrix glyphs and
/// for Your Text in any language.
final class EffectRenderer {
    let w: Int, h: Int
    let core: EffectCore
    private let pixels: UnsafeMutablePointer<UInt8>
    private let context: CGContext

    /// `layoutWidth` wider than `width` makes a preview: a window onto a full-size bar (see `EffectCore`).
    init(width: Int, height: Int, layoutWidth: Double? = nil) {
        w = max(1, width); h = max(1, height)
        pixels = .allocate(capacity: w * h * 4)
        pixels.initialize(repeating: 255, count: w * h * 4)
        context = CGContext(data: pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        core = EffectCore(width: w, height: h, layoutWidth: layoutWidth, glyphs: EffectRenderer.matrixGlyphs(height: h),
                          rasterizer: EffectRenderer.rasterize)
    }

    deinit { pixels.deallocate() }

    func render(_ p: Params, time: Double) -> CGImage? {
        core.render(p, time: time, into: pixels)
        return context.makeImage()
    }

    /// Matrix rain glyphs (digits and half-width katakana) drawn with the system font, sized to the render height.
    static func matrixGlyphs(height: Int) -> GlyphAtlas {
        let ch = max(6, Int((Double(height) / 3).rounded())), cw = max(4, Int((Double(ch) * 0.68).rounded()))
        let glyphs = Array("0123456789ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄ").map(String.init)
        var atlas = [UInt8](repeating: 0, count: cw * glyphs.count * ch)
        atlas.withUnsafeMutableBytes { raw in
            guard let g = CGContext(data: raw.baseAddress, width: cw * glyphs.count, height: ch, bitsPerComponent: 8,
                                    bytesPerRow: cw * glyphs.count, space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: g, flipped: false)
            let font = NSFont.monospacedSystemFont(ofSize: Double(ch) * 0.92, weight: .semibold)
            for (i, s) in glyphs.enumerated() {
                let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: NSColor.white])
                let size = str.size()
                str.draw(at: NSPoint(x: Double(i * cw) + (Double(cw) - size.width) / 2, y: (Double(ch) - size.height) / 2))
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        return GlyphAtlas(cellW: cw, cellH: ch, count: glyphs.count, mask: atlas)
    }

    /// Your Text in scripts the dot font can't draw (and emoji): bold system font, white on black, as a
    /// coverage mask `height` pixels tall.
    static func rasterize(_ text: String, _ height: Int) -> (mask: [UInt8], width: Int)? {
        guard height > 2 else { return nil }
        let font = NSFont.systemFont(ofSize: CGFloat(height) * 0.78, weight: .bold)
        let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white])
        let size = str.size()
        let width = min(12_000, max(1, Int(size.width.rounded(.up)) + 2))
        var mask = [UInt8](repeating: 0, count: width * height)
        let ok = mask.withUnsafeMutableBytes { raw -> Bool in
            guard let g = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: g, flipped: false)
            str.draw(at: NSPoint(x: 1, y: (CGFloat(height) - size.height) / 2))
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        return ok ? (mask, width) : nil
    }
}
