import Cocoa

/// Layer-backed pill that plays the current effect. Used for the Touch Bar itself and for
/// every preview in the settings window.
final class EffectView: NSView {
    private var renderer: EffectRenderer
    private let fps: Double
    private let fixedSize: NSSize?
    private let followsWindow: Bool
    private var timer: Timer?
    private var phase = 1.0
    private var lastTick = CACurrentMediaTime()
    private var occlusionObserver: NSObjectProtocol?

    /// When set, plays this effect instead of the selected one (settings-window cards).
    var overrideEffect: Effect?
    /// When set, plays this animation drop instead (settings-window cards).
    var overrideScene: SceneSpec?
    /// Shows the free plan's "Revive" tag when the plan calls for it (the Touch Bar and the live preview).
    var showsBadge: Bool
    /// For small previews: lay effects out as on a bar this many times wider than tall (the Touch Bar is
    /// about 33.5) and show the interesting part at full size, instead of squeezing the whole bar in.
    private let layoutAspect: Double?

    init(renderWidth: Int, renderHeight: Int, fps: Double, fixedSize: NSSize? = nil,
         overrideEffect: Effect? = nil, overrideScene: SceneSpec? = nil, followsWindow: Bool = false, showsBadge: Bool = false,
         layoutAspect: Double? = nil) {
        renderer = EffectRenderer(width: renderWidth, height: renderHeight, layoutWidth: layoutAspect.map { $0 * Double(renderHeight) })
        self.layoutAspect = layoutAspect
        self.fps = fps
        self.fixedSize = fixedSize
        self.overrideEffect = overrideEffect
        self.overrideScene = overrideScene
        self.followsWindow = followsWindow
        self.showsBadge = showsBadge
        super.init(frame: NSRect(origin: .zero, size: fixedSize ?? NSSize(width: renderWidth, height: renderHeight)))
        wantsLayer = true
        layer?.contentsGravity = .resize
        layer?.magnificationFilter = .linear
        layer?.masksToBounds = true
        tick()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    override var intrinsicContentSize: NSSize {
        fixedSize ?? NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func layout() {
        super.layout()
        fitRenderer()
        applyCorner()
    }

    /// Keeps the rendered image in the same proportions as the view, so text and pixel art never stretch.
    private func fitRenderer() {
        guard bounds.width > 1, bounds.height > 1 else { return }
        let want = max(8, Int((bounds.width / bounds.height * CGFloat(renderer.h)).rounded()))
        if abs(want - renderer.w) > 2 {
            renderer = EffectRenderer(width: want, height: renderer.h, layoutWidth: layoutAspect.map { $0 * Double(renderer.h) })
        }
    }

    private func applyCorner() {
        layer?.cornerRadius = cornerRadius(fraction: Settings.shared.effectiveCorner, height: bounds.height)
    }

    func start() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1 / fps, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // Previews only animate while their window is actually visible.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard followsWindow else { return }
        if let o = occlusionObserver { NotificationCenter.default.removeObserver(o); occlusionObserver = nil }
        guard let window else { stop(); return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self, weak window] _ in
            guard let self, let window else { return }
            window.occlusionState.contains(.visible) ? self.start() : self.stop()
        }
        if window.occlusionState.contains(.visible) { start() }
    }

    /// What to draw this frame.
    private var params: Params {
        var p = Settings.shared.params
        if let e = overrideEffect { p.effect = e; p.scene = nil }
        if let s = overrideScene { p.scene = s }
        p.badge = showsBadge && !LicenseManager.shared.status.hasFullAccess
        return p
    }

    func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.25)
        lastTick = now
        phase += dt * Settings.shared.effectiveSpeed
        guard let image = renderer.render(params, time: phase) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = image
        applyCorner()
        CATransaction.commit()
    }

    /// Renders the pill over black (the Touch Bar's own background) to a PNG. Used by `--snapshot`.
    func writePNG(to path: String, at time: Double) {
        layout()
        guard let image = renderer.render(params, time: time) else { return }
        layer?.contents = image
        let w = Int(bounds.width), h = Int(bounds.height)
        guard let layer, let out = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        out.setFillColor(NSColor.black.cgColor)
        out.fill(CGRect(x: 0, y: 0, width: w, height: h))
        layer.render(in: out)
        guard let final = out.makeImage() else { return }
        try? NSBitmapImageRep(cgImage: final).representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: path))
    }
}
