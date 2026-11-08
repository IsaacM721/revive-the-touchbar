import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Your GIF or Video: imports a file, keeps a copy in Application Support (so it survives the original
/// moving), and decodes it into frames that fill the bar.
final class MediaLibrary: ObservableObject {
    static let shared = MediaLibrary()

    @Published private(set) var clip: MediaClip?
    @Published private(set) var name: String?
    @Published private(set) var busy = false
    /// Already localized.
    @Published var error: String?

    /// Frames are stored at the Touch Bar's own size; every view samples them to fit.
    static let frameW = 1085, frameH = 30
    private static let maxFrames = 240

    private var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Revive the Touchbar", isDirectory: true)
    }

    private var stored: URL? {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .first { $0.lastPathComponent.hasPrefix("media.") }
    }

    private init() {
        if let url = stored { load(url, name: UserDefaults.standard.string(forKey: "mediaName")) }
    }

    /// Asks for a file.
    func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif, .png, .jpeg, .heic, .webP, .image, .movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = NSLocalizedString("Choose a GIF, an image, or a short video for your Touch Bar.", comment: "")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(url)
    }

    func importFile(_ url: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        if let old = stored { try? fm.removeItem(at: old) }
        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension.lowercased()
        let dest = folder.appendingPathComponent("media." + ext)
        do {
            try fm.copyItem(at: url, to: dest)
        } catch {
            self.error = NSLocalizedString("That file couldn't be opened. Try a GIF, PNG, JPEG, or MP4.", comment: "")
            return
        }
        UserDefaults.standard.set(url.lastPathComponent, forKey: "mediaName")
        load(dest, name: url.lastPathComponent)
    }

    func remove() {
        if let old = stored { try? FileManager.default.removeItem(at: old) }
        UserDefaults.standard.removeObject(forKey: "mediaName")
        clip = nil; name = nil; error = nil
    }

    private func load(_ url: URL, name: String?) {
        busy = true; error = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let clip = Self.decodeImages(url) ?? Self.decodeVideo(url)
            DispatchQueue.main.async {
                self.busy = false
                if let clip {
                    self.clip = clip
                    self.name = name
                } else {
                    self.error = NSLocalizedString("That file couldn't be opened. Try a GIF, PNG, JPEG, or MP4.", comment: "")
                }
            }
        }
    }

    /// GIF, APNG, animated WebP or HEIC, or a still image.
    private static func decodeImages(_ url: URL) -> MediaClip? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(src)
        guard count > 0 else { return nil }
        let step = max(1, (count + maxFrames - 1) / maxFrames)
        var frames: [[UInt8]] = [], delays: [Double] = []
        for i in stride(from: 0, to: count, by: step) {
            guard let img = CGImageSourceCreateImageAtIndex(src, i, nil), let px = fill(img) else { continue }
            frames.append(px)
            delays.append(delay(src, i) * Double(step))
        }
        return frames.isEmpty ? nil : MediaClip(width: frameW, height: frameH, frames: frames, delays: delays)
    }

    private static func delay(_ src: CGImageSource, _ i: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [String: Any] else { return 0.1 }
        let kinds: [(CFString, CFString, CFString)] = [
            (kCGImagePropertyGIFDictionary, kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyGIFDelayTime),
            (kCGImagePropertyPNGDictionary, kCGImagePropertyAPNGUnclampedDelayTime, kCGImagePropertyAPNGDelayTime),
            (kCGImagePropertyWebPDictionary, kCGImagePropertyWebPUnclampedDelayTime, kCGImagePropertyWebPDelayTime),
        ]
        for (dict, unclamped, clamped) in kinds {
            guard let d = props[dict as String] as? [String: Any] else { continue }
            if let v = d[unclamped as String] as? Double, v > 0.011 { return v }
            if let v = d[clamped as String] as? Double, v > 0.011 { return v }
        }
        return 0.1
    }

    /// Up to 12 seconds of a video, at up to 20 frames a second.
    private static func decodeVideo(_ url: URL) -> MediaClip? {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else { return nil }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
        gen.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
        gen.maximumSize = CGSize(width: 1600, height: 1600)
        let length = min(duration, 12)
        let fps = min(20, Double(maxFrames) / length)
        var frames: [[UInt8]] = []
        var t = 0.0
        while t < length {
            if let img = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil), let px = fill(img) {
                frames.append(px)
            }
            t += 1 / fps
        }
        guard !frames.isEmpty else { return nil }
        return MediaClip(width: frameW, height: frameH, frames: frames, delays: Array(repeating: 1 / fps, count: frames.count))
    }

    /// Scales an image to fill the bar (cropping what doesn't fit, centered) and returns RGB bytes.
    private static func fill(_ img: CGImage) -> [UInt8]? {
        let w = frameW, h = frameH
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let ok = rgba.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.interpolationQuality = .high
            let iw = CGFloat(img.width), ih = CGFloat(img.height)
            guard iw > 0, ih > 0 else { return false }
            let scale = max(CGFloat(w) / iw, CGFloat(h) / ih)
            let dw = iw * scale, dh = ih * scale
            ctx.draw(img, in: CGRect(x: (CGFloat(w) - dw) / 2, y: (CGFloat(h) - dh) / 2, width: dw, height: dh))
            return true
        }
        guard ok else { return nil }
        var out = [UInt8](repeating: 0, count: w * h * 3)
        for i in 0..<(w * h) {
            out[i * 3] = rgba[i * 4]; out[i * 3 + 1] = rgba[i * 4 + 1]; out[i * 3 + 2] = rgba[i * 4 + 2]
        }
        return out
    }
}
