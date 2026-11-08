import Cocoa

extension NSTouchBarItem.Identifier {
    static let rgb = NSTouchBarItem.Identifier("com.isaac.rgbtouchbar.item")
}

/// Puts the effect on the physical Touch Bar as a system-wide modal bar.
final class TouchBarPresenter: NSObject {
    static let barSize = NSSize(width: 1085, height: 30)

    let view = EffectView(renderWidth: 1085, renderHeight: 30, fps: 60, fixedSize: nil, showsBadge: true)
    /// Invisible brightness (left half) and volume (right half) sliders over the lighting.
    let sliders = SlideControlView()
    private var slidersEnabled = true
    private let touchBar = NSTouchBar()
    private let container = NSView()
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let openButton = NSButton(title: "", target: nil, action: nil)
    private let keepOnButton = NSButton(title: "", target: nil, action: nil)
    private let fnButton = NSButton(title: "", target: nil, action: nil)
    /// F1–F12 row shown in place of the lighting, plus the button that brings the lighting back.
    private let fnKeys = NSStackView()
    private let lightingButton = NSButton(title: "", target: nil, action: nil)
    private var controls = NSStackView()
    private(set) var showingFunctionKeys = false
    private let widthConstraint: NSLayoutConstraint
    private(set) var isPresented = false
    var onClose: (() -> Void)?
    /// Tapped the button that opens the app's settings window.
    var onOpen: (() -> Void)?
    /// Tapped the button that keeps the Touch Bar (and the display) on while nobody is at the keyboard.
    var onToggleKeepOn: (() -> Void)?
    /// The bar was closed and the system has had a moment to settle.
    var onDismissed: (() -> Void)?
    /// A Control Strip button to keep showing, in the corner the system reserves, while this bar is up.
    var trayItemIdentifier: NSTouchBarItem.Identifier?

    override init() {
        widthConstraint = container.widthAnchor.constraint(equalToConstant: Self.barSize.width)
        super.init()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        sliders.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sliders)   // above the lighting, below the buttons

        configure(openButton, symbol: "slider.horizontal.3", label: NSLocalizedString("Open settings", comment: ""), action: #selector(openTapped))
        configure(keepOnButton, symbol: "cup.and.saucer", label: NSLocalizedString("Keep the Touch Bar on", comment: ""), action: #selector(keepOnTapped))
        configure(closeButton, symbol: "xmark", label: NSLocalizedString("Turn off", comment: ""), action: #selector(closeTapped))
        configure(fnButton, symbol: "fn", label: NSLocalizedString("Show function keys", comment: ""), action: #selector(fnTapped))
        if fnButton.image == nil { fnButton.title = "fn"; fnButton.imagePosition = .noImage; fnButton.font = .boldSystemFont(ofSize: 13) }
        configure(lightingButton, symbol: "sparkles", label: NSLocalizedString("Show the lighting", comment: ""), action: #selector(fnTapped))
        lightingButton.isHidden = true

        // The controls sit together at the right end (the left end carries the Free plan's tag). A hidden
        // button drops out of the stack, so the others slide over.
        controls = NSStackView(views: [fnButton, openButton, keepOnButton, closeButton])
        controls.orientation = .horizontal
        controls.spacing = 0
        controls.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(controls)

        // Function keys: the standard gray Touch Bar keys, sharing the width evenly. Hidden until asked for.
        for n in 1...12 {
            let key = NSButton(title: "F\(n)", target: self, action: #selector(functionKeyTapped(_:)))
            key.tag = n
            key.font = .systemFont(ofSize: 15)
            key.setAccessibilityLabel("F\(n)")
            fnKeys.addArrangedSubview(key)
        }
        fnKeys.orientation = .horizontal
        fnKeys.distribution = .fillEqually
        fnKeys.spacing = 6
        fnKeys.isHidden = true
        fnKeys.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(fnKeys)
        container.addSubview(lightingButton)

        NSLayoutConstraint.activate([
            widthConstraint,
            container.heightAnchor.constraint(equalToConstant: Self.barSize.height),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            sliders.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sliders.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sliders.topAnchor.constraint(equalTo: container.topAnchor),
            sliders.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            controls.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            controls.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            // The lighting button lands where the fn button was, so the same spot toggles back.
            lightingButton.trailingAnchor.constraint(equalTo: controls.leadingAnchor, constant: 44),
            lightingButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            fnKeys.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            fnKeys.trailingAnchor.constraint(equalTo: lightingButton.leadingAnchor, constant: -8),
            fnKeys.topAnchor.constraint(equalTo: container.topAnchor),
            fnKeys.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        sliders.reservedRight = { [weak self] in
            guard let self, !self.controls.isHidden, self.controls.frame.width > 0 else { return 0 }
            return self.container.bounds.width - self.controls.frame.minX
        }

        let item = NSCustomTouchBarItem(identifier: .rgb)
        item.view = container
        touchBar.defaultItemIdentifiers = [.rgb]
        touchBar.templateItems = [item]
    }

    /// A bare symbol button for the bar: no oval or background, and a soft shadow so it reads over any color.
    private func configure(_ button: NSButton, symbol: String, label: String, action: Selector) {
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.setAccessibilityLabel(label)
        button.wantsLayer = true
        button.shadow = {
            let sh = NSShadow()
            sh.shadowColor = NSColor.black.withAlphaComponent(0.65)
            sh.shadowBlurRadius = 3
            sh.shadowOffset = .zero
            return sh
        }()
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .bold))
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    /// For `--snapshot-bar`: the bar's own view, laid out at the width the system gives a modal Touch Bar.
    func previewContainer(width: CGFloat) -> NSView {
        widthConstraint.constant = width
        view.start()
        return container
    }

    func setCloseVisible(_ visible: Bool) { closeButton.isHidden = !visible; sliders.needsLayout = true }

    /// The shortcut buttons (open the app, keep the bar on). The close button has its own switch.
    func setButtonsVisible(_ visible: Bool) {
        fnButton.isHidden = !visible
        openButton.isHidden = !visible
        keepOnButton.isHidden = !visible
        sliders.needsLayout = true
    }

    /// Filled cup and full white while the bar is being kept on; outline and dimmer while it isn't.
    func setKeepOnActive(_ active: Bool) {
        let label = NSLocalizedString("Keep the Touch Bar on", comment: "")
        keepOnButton.image = NSImage(systemSymbolName: active ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .bold))
        keepOnButton.contentTintColor = active ? .white : NSColor.white.withAlphaComponent(0.6)
        keepOnButton.setAccessibilityValue(active ? "1" : "0")
    }

    func setSlidersEnabled(_ on: Bool) {
        slidersEnabled = on
        sliders.isHidden = !on || showingFunctionKeys
        if !on { sliders.stopTip() }
    }

    /// Plays the "slide here" demo on the bar (from settings, or on its own for new users).
    func showSlideTip(automatic: Bool = false) {
        guard isPresented, slidersEnabled, !showingFunctionKeys else { return }
        sliders.showTip(automatic: automatic)
    }

    @objc private func closeTapped() { onClose?() }
    @objc private func openTapped() { onOpen?() }
    @objc private func keepOnTapped() { onToggleKeepOn?() }
    @objc private func fnTapped() { setShowingFunctionKeys(!showingFunctionKeys) }
    @objc private func functionKeyTapped(_ sender: NSButton) { FunctionKeys.press(sender.tag) }

    /// Swaps the lighting for F1–F12 (the effect pauses to save battery) or back.
    func setShowingFunctionKeys(_ on: Bool, askPermission: Bool = true) {
        showingFunctionKeys = on
        if on, askPermission { FunctionKeys.ensureAccess(prompt: true) }
        fnKeys.isHidden = !on
        lightingButton.isHidden = !on
        view.isHidden = on
        sliders.isHidden = on || !slidersEnabled
        if on { sliders.stopTip() }
        controls.isHidden = on
        if on { view.stop() } else if isPresented { view.start() }
    }

    func present() {
        if NSTouchBar.responds(to: #selector(NSTouchBar.presentSystemModalTouchBar(_:placement:systemTrayItemIdentifier:))) {
            view.start()
            NSTouchBar.presentSystemModalTouchBar(touchBar, placement: 1, systemTrayItemIdentifier: trayItemIdentifier)
        } else if NSTouchBar.responds(to: #selector(NSTouchBar.presentSystemModalFunctionBar(_:systemTrayItemIdentifier:))) {
            view.start()
            NSTouchBar.presentSystemModalFunctionBar(touchBar, systemTrayItemIdentifier: trayItemIdentifier)
        } else {
            // This macOS has neither entry point (Apple changed or removed them). Calling a missing class method
            // would crash the app on launch, so stay a normal app with a Dock icon and settings, and say why.
            NSLog("Revive the Touchbar: this macOS has no system-modal Touch Bar API, so the lighting can't be shown.")
            return
        }
        isPresented = true
        if showingFunctionKeys { view.stop() }   // put back on wake while showing F keys: keep them
        if SlideControlView.wantsAutomaticTip {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.showSlideTip(automatic: true) }
        }
        // The system only gives modal bars part of the strip (the right ~80pt is reserved), and
        // anything wider gets clipped, squaring off the pill's right end. Fit to what we're given.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.fitToAvailableWidth() }
        if let path = ProcessInfo.processInfo.environment["RGBTB_DEBUG"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.dumpGeometry(to: path) }
        }
    }

    func dismiss() {
        if NSTouchBar.responds(to: #selector(NSTouchBar.dismissSystemModalTouchBar(_:))) {
            NSTouchBar.dismissSystemModalTouchBar(touchBar)
        } else if NSTouchBar.responds(to: #selector(NSTouchBar.dismissSystemModalFunctionBar(_:))) {
            NSTouchBar.dismissSystemModalFunctionBar(touchBar)
        }
        isPresented = false
        setShowingFunctionKeys(false)   // the next time the bar comes on, it shows the lighting
        sliders.stopTip()
        view.stop()
        // Give the system a moment to finish closing the bar, then let the app restore anything it took away.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.isPresented else { return }
            self.onDismissed?()
        }
    }

    private func fitToAvailableWidth() {
        guard let available = container.window?.frame.width, available > 100,
              abs(available - widthConstraint.constant) > 0.5 else { return }
        widthConstraint.constant = available
    }

    /// Debug aid: writes the view hierarchy the Touch Bar server gave us.
    private func dumpGeometry(to path: String) {
        var out = ""
        var v: NSView? = container
        while let x = v {
            out += "\(type(of: x)) frame=\(x.frame) bounds=\(x.bounds)\n"
            v = x.superview
        }
        if let w = container.window {
            out += "window \(type(of: w)) frame=\(w.frame) contentView=\(String(describing: w.contentView?.frame))\n"
        }
        out += "screens: \(NSScreen.screens.map { $0.frame })\n"
        try? out.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
