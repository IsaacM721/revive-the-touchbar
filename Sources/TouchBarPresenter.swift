import Cocoa

extension NSTouchBarItem.Identifier {
    static let rgb = NSTouchBarItem.Identifier("com.isaac.rgbtouchbar.item")
}

/// Puts the effect on the physical Touch Bar as a system-wide modal bar.
final class TouchBarPresenter: NSObject {
    static let barSize = NSSize(width: 1085, height: 30)

    let view = EffectView(renderWidth: 1085, renderHeight: 30, fps: 60, fixedSize: nil, showsBadge: true)
    private let touchBar = NSTouchBar()
    private let container = NSView()
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let openButton = NSButton(title: "", target: nil, action: nil)
    private let keepOnButton = NSButton(title: "", target: nil, action: nil)
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

        configure(openButton, symbol: "slider.horizontal.3", label: NSLocalizedString("Open settings", comment: ""), action: #selector(openTapped))
        configure(keepOnButton, symbol: "cup.and.saucer", label: NSLocalizedString("Keep the Touch Bar on", comment: ""), action: #selector(keepOnTapped))
        configure(closeButton, symbol: "xmark", label: NSLocalizedString("Turn off", comment: ""), action: #selector(closeTapped))

        // The controls sit together at the right end (the left end carries the Free plan's tag). A hidden
        // button drops out of the stack, so the others slide over.
        let controls = NSStackView(views: [openButton, keepOnButton, closeButton])
        controls.orientation = .horizontal
        controls.spacing = 0
        controls.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(controls)

        NSLayoutConstraint.activate([
            widthConstraint,
            container.heightAnchor.constraint(equalToConstant: Self.barSize.height),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            controls.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            controls.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

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

    func setCloseVisible(_ visible: Bool) { closeButton.isHidden = !visible }

    /// The shortcut buttons (open the app, keep the bar on). The close button has its own switch.
    func setButtonsVisible(_ visible: Bool) {
        openButton.isHidden = !visible
        keepOnButton.isHidden = !visible
    }

    /// Filled cup and full white while the bar is being kept on; outline and dimmer while it isn't.
    func setKeepOnActive(_ active: Bool) {
        let label = NSLocalizedString("Keep the Touch Bar on", comment: "")
        keepOnButton.image = NSImage(systemSymbolName: active ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .bold))
        keepOnButton.contentTintColor = active ? .white : NSColor.white.withAlphaComponent(0.6)
        keepOnButton.setAccessibilityValue(active ? "1" : "0")
    }

    @objc private func closeTapped() { onClose?() }
    @objc private func openTapped() { onOpen?() }
    @objc private func keepOnTapped() { onToggleKeepOn?() }

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
        view.stop()
        isPresented = false
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
