import Cocoa

extension Notification.Name {
    /// Asks the Touch Bar to play the brightness and volume demo (the settings window's "Show me" button).
    static let showSlideTip = Notification.Name("com.isaac.rgbtouchbar.showSlideTip")
}

/// Invisible sliders over the lighting: slide sideways on the left half for screen brightness, on the right half
/// for volume (the same sides as those keys on the keyboard). Taps do nothing, so nothing changes by accident.
/// While sliding, a small plate shows the level. The first few times the bar comes on, the plates play a short
/// demo ("Slide for volume" with the level moving) until both sliders have been used.
final class SlideControlView: NSView {
    private let left = LevelPlate(level: .brightness)
    private let right = LevelPlate(level: .volume)

    /// Width at the right end taken by the bar's buttons; the two zones share what's left of it.
    var reservedRight: () -> CGFloat = { 0 }
    /// Where brightness ends and volume begins: the middle of the free space.
    private var split: CGFloat { max(100, bounds.width - reservedRight() - 12) / 2 }
    /// A slide across one zone covers the whole range.
    private var pointsForFullRange: CGFloat { max(180, split) }
    /// Sideways movement needed before a slide starts, so taps and rests are ignored.
    private let threshold: CGFloat = 8

    private var touchStartX: CGFloat = 0
    private var lastX: CGFloat = 0
    private var active: LevelPlate?
    private var value: Float = 0
    private var tipTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        allowedTouchTypes = [.direct]
        wantsRestingTouches = false
        for plate in [left, right] {
            plate.translatesAutoresizingMaskIntoConstraints = false
            plate.alphaValue = 0
            addSubview(plate)
        }
        // Each plate sits in the middle of its half (the right one shifted left, clear of the buttons). See layout().
        leftCenter = left.centerXAnchor.constraint(equalTo: leadingAnchor)
        rightCenter = right.centerXAnchor.constraint(equalTo: leadingAnchor)
        NSLayoutConstraint.activate([
            leftCenter, rightCenter,
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private var leftCenter: NSLayoutConstraint!
    private var rightCenter: NSLayoutConstraint!

    required init?(coder: NSCoder) { fatalError("not supported") }

    override func layout() {
        super.layout()
        leftCenter.constant = split * 0.5
        rightCenter.constant = split * 1.5
        for p in [left, right] { p.maxWidth = split - 16 }
    }

    // MARK: Touches

    override func touchesBegan(with event: NSEvent) {
        guard let t = event.touches(matching: .began, in: self).first else { return }
        let x = t.location(in: self).x
        touchStartX = x
        lastX = x
        active = nil
    }

    override func touchesMoved(with event: NSEvent) {
        guard let t = event.touches(matching: .moved, in: self).first else { return }
        let x = t.location(in: self).x
        if active == nil {
            guard abs(x - touchStartX) >= threshold else { return }
            let plate = touchStartX < split ? left : right
            guard let current = plate.level.value else { return }   // this Mac can't change it
            stopTip()
            active = plate
            value = current
            plate.showLabel(false)
            plate.setFill(current)
            plate.fade(in: true)
            SlideControlView.markUsed(plate.level)
        }
        guard let plate = active else { return }
        value = min(1, max(0, value + Float((x - lastX) / pointsForFullRange)))
        lastX = x
        plate.level.set(value)
        plate.setFill(value)
    }

    override func touchesEnded(with event: NSEvent) { finish() }
    override func touchesCancelled(with event: NSEvent) { finish() }

    private func finish() {
        guard let plate = active else { return }
        active = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard self?.active !== plate else { return }
            plate.fade(in: false)
        }
    }

    // MARK: The tip

    private static let usedKey: [SystemLevel: String] = [.brightness: "usedBrightnessSlide", .volume: "usedVolumeSlide"]
    private static let tipCountKey = "slideTipShownCount"
    private static let maxAutomaticTips = 3

    private static func markUsed(_ level: SystemLevel) {
        UserDefaults.standard.set(true, forKey: usedKey[level]!)
    }

    /// Show the tip on its own until both sliders have been used, at most a few times.
    static var wantsAutomaticTip: Bool {
        let d = UserDefaults.standard
        let usedBoth = d.bool(forKey: usedKey[.brightness]!) && d.bool(forKey: usedKey[.volume]!)
        return !usedBoth && d.integer(forKey: tipCountKey) < maxAutomaticTips
    }

    /// Plays the demo on both halves for a few seconds. `animated: false` shows a still (snapshots, reduced motion).
    func showTip(automatic: Bool = false, animated: Bool = true) {
        if automatic {
            let d = UserDefaults.standard
            d.set(d.integer(forKey: Self.tipCountKey) + 1, forKey: Self.tipCountKey)
        }
        stopTip()
        let plates = [left, right].filter { $0.level.value != nil }
        for p in plates { p.showLabel(true); p.setFill(0.35); p.fade(in: true) }
        let moves = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let start = CACurrentMediaTime()
        if moves {
            tipTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
                let t = CACurrentMediaTime() - start
                // An eased sweep up and back, like a finger sliding right then left.
                let f = Float(0.5 - 0.5 * cos(t * .pi / 1.2))
                for p in plates { p.setFill(0.15 + 0.7 * f) }
                if t > 6 { self?.stopTip() }
            }
        } else if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.stopTip() }
        }
    }

    func stopTip() {
        let wasRunning = tipTimer != nil || left.isShowingLabel || right.isShowingLabel
        tipTimer?.invalidate()
        tipTimer = nil
        guard wasRunning else { return }
        for p in [left, right] where p !== active { p.fade(in: false) }
        for p in [left, right] { p.showLabel(false) }
    }

    /// For `--snapshot-bar`: the plate as it looks mid-slide.
    func previewLevel(_ level: SystemLevel, _ v: Float) {
        let p = level == .brightness ? left : right
        p.showLabel(false)
        p.setFill(v)
        p.alphaValue = 1
    }
}

/// The readout: a dark plate (so it reads over any color) with the level's symbol, an optional hint, and a track.
final class LevelPlate: NSView {
    let level: SystemLevel
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let track = CALayer()
    private let fill = CALayer()
    private var fraction: Float = 0
    private(set) var isShowingLabel = false
    private var labelWidth: NSLayoutConstraint!
    private var trailing: NSLayoutConstraint!
    /// The plate never grows past its zone; a long translation truncates instead.
    var maxWidth: CGFloat = 300 { didSet { applyWidths() } }
    /// The track is shorter while the hint text is showing, so both fit side by side.
    private var trackWidth: CGFloat { isShowingLabel ? 70 : 120 }

    init(level: SystemLevel) {
        self.level = level
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        icon.contentTintColor = .white
        icon.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = level == .brightness ? NSLocalizedString("Slide for brightness", comment: "")
                                                 : NSLocalizedString("Slide for volume", comment: "")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        track.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
        fill.backgroundColor = NSColor.white.cgColor
        track.addSublayer(fill)
        layer?.addSublayer(track)
        addSubview(icon)
        addSubview(label)
        labelWidth = label.widthAnchor.constraint(lessThanOrEqualToConstant: 0)
        trailing = trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 0)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 24),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            labelWidth,
            trailing,   // room for the track after the label
        ])
        applyWidths()
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    func showLabel(_ on: Bool) {
        isShowingLabel = on
        label.isHidden = !on
        applyWidths()
    }

    private func applyWidths() {
        let fixed = 10 + 18 + 6 + 8 + trackWidth + 12
        labelWidth.constant = isShowingLabel ? max(0, maxWidth - fixed) : 0
        trailing.constant = 8 + trackWidth + 12
        needsLayout = true
    }

    func setFill(_ v: Float) {
        fraction = v
        updateIcon()
        needsLayout = true
    }

    func fade(in visible: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = visible ? 0.15 : 0.3
            animator().alphaValue = visible ? 1 : 0
        }
    }

    private func updateIcon() {
        let name: String
        switch level {
        case .brightness: name = fraction < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .volume:
            name = fraction <= 0.001 ? "speaker.slash.fill" : fraction < 0.34 ? "speaker.wave.1.fill"
                : fraction < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        }
        icon.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .bold))
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = cornerRadius(fraction: 1, height: bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        track.frame = CGRect(x: bounds.width - 12 - trackWidth, y: (bounds.height - 4) / 2, width: trackWidth, height: 4)
        track.cornerRadius = 2
        fill.frame = CGRect(x: 0, y: 0, width: trackWidth * CGFloat(fraction), height: 4)
        fill.cornerRadius = 2
        CATransaction.commit()
    }
}
