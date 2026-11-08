import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let license = LicenseManager.shared
    private let bar = TouchBarPresenter()
    private let strip = ControlStripItem()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    /// Lighting runs only while it's switched on and the trial or a license is active.
    private var shouldLight: Bool { settings.enabled }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = Self.menuBarIcon()
        statusItem.button?.setAccessibilityLabel("Revive the Touchbar")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        NSApp.mainMenu = buildMainMenu()

        // Dock icon on or off, from the settings window. Switching back to menu-bar-only would hide the
        // settings window along with the app, so bring it back to the front.
        settings.$showInDock.dropFirst().removeDuplicates().sink { [weak self] show in
            NSApp.setActivationPolicy(show ? .regular : .accessory)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                self?.window?.makeKeyAndOrderFront(nil)
            }
        }.store(in: &cancellables)

        bar.onClose = { [weak self] in self?.settings.enabled = false }
        bar.onOpen = { [weak self] in self?.showSettings() }
        bar.onToggleKeepOn = { [weak self] in self?.settings.keepOn.toggle() }

        // The Control Strip button goes in before the first present, so the bar can keep it in view. Tapping it
        // switches the lighting, which is how it comes back on after the bar has been closed.
        strip.onTap = { [weak self] in self?.settings.enabled.toggle() }
        bar.onDismissed = { [weak self] in self?.strip.refresh() }
        settings.$showStripButton.removeDuplicates().sink { [weak self] show in
            guard let self else { return }
            let installed = show && self.strip.install()
            if !show { self.strip.remove() }
            self.bar.trayItemIdentifier = installed ? ControlStripItem.identifier : nil
            if self.bar.isPresented { self.bar.dismiss(); self.bar.present() }   // the tray item is chosen at present time
        }.store(in: &cancellables)
        settings.$enabled.sink { [weak self] in self?.strip.setLightingOn($0) }.store(in: &cancellables)

        // Fires immediately with the stored values, so this also does the first present.
        settings.$enabled
            .removeDuplicates()
            .sink { [weak self] on in
                guard let bar = self?.bar else { return }
                on ? bar.present() : bar.dismiss()
            }.store(in: &cancellables)
        settings.$showClose.sink { [weak self] in self?.bar.setCloseVisible($0) }.store(in: &cancellables)
        settings.$showButtons.sink { [weak self] in self?.bar.setButtonsVisible($0) }.store(in: &cancellables)
        settings.$keepOn.sink { [weak self] in self?.bar.setKeepOnActive($0) }.store(in: &cancellables)
        // The display only stays awake while the lighting is on too, so turning the bar off lets the Mac sleep as usual.
        Publishers.CombineLatest(settings.$enabled, settings.$keepOn)
            .map { $0 && $1 }
            .removeDuplicates()
            .sink { KeepAwake.shared.set($0) }
            .store(in: &cancellables)

        // The trial just ended: open settings once so the plans can be seen (no modal alert). The free plan keeps running.
        license.$status.removeDuplicates().sink { [weak self] status in
            if Config.chargingEnabled, status == .free, !UserDefaults.standard.bool(forKey: "didShowTrialEnd") { self?.showSettings() }
        }.store(in: &cancellables)

        // The system drops modal Touch Bars across sleep, so put ours back on wake.
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.shouldLight else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.bar.present() }
            }
        }

        DropFeed.shared.refresh()
        _ = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in DropFeed.shared.refresh() }

        if !UserDefaults.standard.bool(forKey: "didShowSettings") {
            UserDefaults.standard.set(true, forKey: "didShowSettings")
            Telemetry.ping("first_launch")
            showSettings()
        }
    }

    /// Clicking the Dock icon (or opening the app again from Finder) brings the settings window up.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    /// Right-click on the Dock icon: switch the lighting without opening anything.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: NSLocalizedString("Lighting", comment: ""), action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = settings.enabled ? .on : .off
        menu.addItem(toggle)
        return menu
    }

    /// The menus in the menu bar while the app is in front. The Edit menu also gives text fields their
    /// ⌘C / ⌘V / ⌘A, even when the app runs from the menu bar only.
    private func buildMainMenu() -> NSMenu {
        func L(_ s: String) -> String { NSLocalizedString(s, comment: "") }
        func item(_ title: String, _ action: Selector?, _ key: String = "", _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            return i
        }
        let main = NSMenu()
        func add(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let menu = NSMenu(title: title)
            items.forEach { menu.addItem($0) }
            let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            holder.submenu = menu
            main.addItem(holder)
            return menu
        }
        let settingsItem = item(L("Settings…"), #selector(showSettings), ",")
        settingsItem.target = self
        _ = add("Revive the Touchbar", [
            item(L("About Revive the Touchbar"), #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            settingsItem,
            .separator(),
            item(L("Hide Revive the Touchbar"), #selector(NSApplication.hide(_:)), "h"),
            item(L("Hide Others"), #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item(L("Show All"), #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item(L("Quit Revive the Touchbar"), #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = add(L("Edit"), [
            item(L("Undo"), Selector(("undo:")), "z"),
            item(L("Redo"), Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item(L("Cut"), #selector(NSText.cut(_:)), "x"),
            item(L("Copy"), #selector(NSText.copy(_:)), "c"),
            item(L("Paste"), #selector(NSText.paste(_:)), "v"),
            item(L("Select All"), #selector(NSText.selectAll(_:)), "a"),
        ])
        NSApp.windowsMenu = add(L("Window"), [
            item(L("Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"),
            item(L("Close"), #selector(NSWindow.performClose(_:)), "w"),
        ])
        return main
    }

    /// `revive://activate?key=...`, opened from the website.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { license.handle(url: url) }
        showSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if bar.isPresented { bar.dismiss() }
        strip.remove()
    }

    /// A small pill, drawn as a template image so the menu bar tints it for light, dark, and highlighted states.
    private static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 12), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 2.5), xRadius: 3.5, yRadius: 3.5).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: Settings window

    @objc func showSettings() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Revive the Touchbar"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 660, height: 800))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Menu (rebuilt each time it opens so it always reflects the current state)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func L(_ s: String) -> String { NSLocalizedString(s, comment: "") }

        let open = NSMenuItem(title: L("Open Revive the Touchbar…"), action: #selector(showSettings), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let toggle = NSMenuItem(title: L("Lighting"), action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = settings.enabled ? .on : .off
        toggle.isEnabled = true
        menu.addItem(toggle)

        let keepOn = NSMenuItem(title: L("Keep the Touch Bar on"), action: #selector(toggleKeepOn), keyEquivalent: "")
        keepOn.target = self
        keepOn.state = settings.keepOn ? .on : .off
        menu.addItem(keepOn)

        let presets = NSMenuItem(title: L("Presets"), action: nil, keyEquivalent: "")
        let presetMenu = NSMenu()
        if settings.presets.isEmpty {
            let none = NSMenuItem(title: L("No Presets Yet"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            presetMenu.addItem(none)
        }
        for p in settings.presets {
            let item = NSMenuItem(title: p.name, action: #selector(pickPreset(_:)), keyEquivalent: "")
            item.isEnabled = license.status.hasFullAccess
            item.target = self
            item.representedObject = p.id.uuidString
            item.state = settings.activePreset == p ? .on : .off
            presetMenu.addItem(item)
        }
        presets.submenu = presetMenu
        menu.addItem(presets)

        // The library, one submenu per shelf, plus the drops.
        let full = license.status.hasFullAccess
        let playingScene = settings.effectiveScene
        let lockImage = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: L("Locked. Unlock everything with a plan."))
        let drops = DropFeed.shared.drops
        if !drops.isEmpty {
            let dropsItem = NSMenuItem(title: L("Drops"), action: nil, keyEquivalent: "")
            let dropMenu = NSMenu()
            for d in drops {
                let item = NSMenuItem(title: d.localizedName(appLanguage), action: #selector(pickDrop(_:)), keyEquivalent: "")
                item.target = self
                item.isEnabled = full
                if !full { item.image = lockImage }
                item.representedObject = d.id
                item.state = playingScene?.id == d.id ? .on : .off
                dropMenu.addItem(item)
            }
            dropsItem.submenu = dropMenu
            menu.addItem(dropsItem)
        }
        for category in EffectCategory.allCases {
            let shelf = NSMenuItem(title: L(category.title), action: nil, keyEquivalent: "")
            let shelfMenu = NSMenu()
            for e in Effect.inCategory(category) {
                let locked = !full && !e.isFree
                let item = NSMenuItem(title: L(e.title), action: #selector(pickEffect(_:)), keyEquivalent: "")
                item.target = self
                item.isEnabled = !locked
                if locked { item.image = lockImage }
                item.representedObject = e.rawValue
                item.state = playingScene == nil && settings.effectiveEffect == e ? .on : .off
                shelfMenu.addItem(item)
            }
            shelf.submenu = shelfMenu
            if playingScene == nil && settings.effectiveEffect.category == category { shelf.state = .on }
            menu.addItem(shelf)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L("Quit Revive the Touchbar"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func toggleEnabled() { settings.enabled.toggle() }

    @objc private func toggleKeepOn() { settings.keepOn.toggle() }

    @objc private func pickEffect(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let e = Effect(rawValue: raw) else { return }
        settings.select(e)
        settings.enabled = true
    }

    @objc private func pickDrop(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let d = DropFeed.shared.drops.first(where: { $0.id == id }) else { return }
        settings.select(drop: d)
        settings.enabled = true
    }

    @objc private func pickPreset(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let p = settings.presets.first(where: { $0.id.uuidString == id }) else { return }
        settings.apply(p)
        settings.enabled = true
    }
}

// MARK: - Entry point and debugging helpers

/// The value after a flag, if any.
private func argument(after flag: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: flag), i + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[i + 1]
}

/// Optional "light" or "dark" after the output path.
private func appearanceArgument(after flag: String) -> NSAppearance? {
    guard let i = CommandLine.arguments.firstIndex(of: flag), i + 2 < CommandLine.arguments.count else { return nil }
    switch CommandLine.arguments[i + 2] {
    case "light": return NSAppearance(named: .aqua)
    case "dark": return NSAppearance(named: .darkAqua)
    default: return nil
    }
}

/// Optional "top" or "tuning" after the appearance argument.
private func partArgument(after flag: String) -> SnapshotPart? {
    guard let i = CommandLine.arguments.firstIndex(of: flag), i + 3 < CommandLine.arguments.count else { return nil }
    switch CommandLine.arguments[i + 3] {
    case "top": return .top
    case "tuning": return .tuning
    default: return nil
    }
}

private func captureWindow(_ number: Int, to out: String, after delay: Double = 2.5) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-l", "\(number)", "-o", out]
        try? p.run(); p.waitUntilExit()
        exit(0)
    }
}

// `--snapshot <dir>` renders every effect to a PNG in <dir> and exits.
if let dir = argument(after: "--snapshot") {
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    for e in Effect.allCases {
        let view = EffectView(renderWidth: 1085, renderHeight: 30, fps: 60, overrideEffect: e)
        view.writePNG(to: "\(dir)/\(e.rawValue).png", at: 2.3)
    }
    exit(0)
}

// `--frames <dir> <effect> <count> <fps> <speedup>` renders animation frames of one effect (for demo GIFs).
if let i = CommandLine.arguments.firstIndex(of: "--frames"), i + 5 < CommandLine.arguments.count {
    let args = Array(CommandLine.arguments[(i + 1)...(i + 5)])
    let dir = args[0]
    guard let effect = Effect(rawValue: args[1]), let count = Int(args[2]), let fps = Double(args[3]), let speed = Double(args[4]) else { exit(2) }
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let view = EffectView(renderWidth: 1085, renderHeight: 30, fps: 60, overrideEffect: effect)
    for n in 0..<count {
        view.writePNG(to: String(format: "%@/%@_%03d.png", dir, effect.rawValue, n), at: 1.0 + Double(n) / fps * speed)
    }
    exit(0)
}

// `--snapshot-knob <file.png>` renders the knobs.
if let out = argument(after: "--snapshot-knob") {
    let row = HStack(spacing: 36) {
        ForEach([0.0, 0.5, 1.0], id: \.self) { SynthKnob(value: .constant($0), size: 120) }
        AngleKnob(degrees: .constant(0), size: 120)
        AngleKnob(degrees: .constant(90), size: 120)
        AngleKnob(degrees: .constant(45), size: 120)
    }
    .padding(44)
    .background(Color(red: 0.04, green: 0.04, blue: 0.07))
    MainActor.assumeIsolated {
        let renderer = ImageRenderer(content: row)
        renderer.scale = 2
        if let tiff = renderer.nsImage?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
        }
    }
    exit(0)
}

// `--snapshot-ui-tall <file.png> [light|dark]` captures the whole settings window, taller than the screen.
if let out = argument(after: "--snapshot-ui-tall") {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let frame = NSRect(x: 40, y: -1200, width: 660, height: 2000)
    let win = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
    win.contentView = NSHostingView(rootView: SettingsView(part: partArgument(after: "--snapshot-ui-tall")))
    win.appearance = appearanceArgument(after: "--snapshot-ui-tall")
    win.isReleasedWhenClosed = false
    win.setFrame(frame, display: true)
    win.orderFrontRegardless()
    captureWindow(win.windowNumber, to: out)
    app.run()
}

// `--snapshot-bar <file.png> [keepon] [nobuttons]` captures the Touch Bar's own view: the effect with its controls, 1004pt wide on black.
if let out = argument(after: "--snapshot-bar") {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let flags = CommandLine.arguments
    let p = TouchBarPresenter()
    p.setKeepOnActive(flags.contains("keepon"))
    p.setButtonsVisible(!flags.contains("nobuttons"))
    let frame = NSRect(x: 40, y: 100, width: 1004, height: 30)
    let win = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
    win.backgroundColor = .black
    win.isReleasedWhenClosed = false
    let host = NSView(frame: NSRect(origin: .zero, size: frame.size))
    win.contentView = host
    let bar = p.previewContainer(width: 1004)
    host.addSubview(bar)
    NSLayoutConstraint.activate([
        bar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
        bar.topAnchor.constraint(equalTo: host.topAnchor),
    ])
    win.orderFrontRegardless()
    captureWindow(win.windowNumber, to: out, after: 2.5)
    app.run()
}

// `--snapshot-ui <file.png>` opens the settings window, captures it, and exits.
if let out = argument(after: "--snapshot-ui") {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let d = AppDelegate()
    app.delegate = d
    d.showSettings()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        captureWindow(app.windows.first { $0.title == "Revive the Touchbar" }?.windowNumber ?? 0, to: out, after: 2)
    }
    app.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Info.plist keeps LSUIElement so the app never flashes into the Dock when that's switched off.
app.setActivationPolicy(Settings.shared.showInDock ? .regular : .accessory)
app.run()
