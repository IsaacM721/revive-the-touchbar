import Cocoa

extension NSTouchBarItem.Identifier {
    static let lightingToggle = NSTouchBarItem.Identifier("com.isaac.rgbtouchbar.toggle")
}

/// A button in the system Control Strip, the native part of the Touch Bar, that turns the lighting on and off.
/// It stays there while the app runs, so the lighting can be switched back on without opening anything. While
/// our bar is showing, the system also keeps it in the corner it reserves, so it can be switched off the same way.
final class ControlStripItem: NSObject {
    static let identifier = NSTouchBarItem.Identifier.lightingToggle

    /// `DFRElementSetControlStripPresenceForIdentifier(identifier, present)`, from the private DFRFoundation framework.
    /// Looked up at run time: if a macOS drops it the item is still added, just not pinned, and nothing crashes.
    private static let setPresence: (@convention(c) (NSString, Bool) -> Void)? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY),
              let symbol = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") else { return nil }
        return unsafeBitCast(symbol, to: (@convention(c) (NSString, Bool) -> Void).self)
    }()

    private let item = NSCustomTouchBarItem(identifier: ControlStripItem.identifier)
    private let button = NSButton(title: "", target: nil, action: nil)
    private(set) var isInstalled = false
    var onTap: (() -> Void)?

    override init() {
        super.init()
        let label = NSLocalizedString("Turn lighting on or off", comment: "")
        button.target = self
        button.action = #selector(tapped)
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel(label)
        item.view = button
        item.customizationLabel = label
        setLightingOn(false)
    }

    /// Filled pill and accent color while the lighting is on; outline pill while it's off. The pill matches the menu bar icon.
    func setLightingOn(_ on: Bool) {
        let label = NSLocalizedString("Turn lighting on or off", comment: "")
        button.image = NSImage(systemSymbolName: on ? "capsule.fill" : "capsule", accessibilityDescription: label)
        button.bezelColor = on ? .controlAccentColor : nil
        button.setAccessibilityValue(on ? "1" : "0")
    }

    /// Adds the button to the Control Strip. Returns false (and does nothing) if this macOS has no such entry point.
    @discardableResult
    func install() -> Bool {
        if isInstalled { return true }
        guard NSTouchBarItem.responds(to: #selector(NSTouchBarItem.addSystemTrayItem(_:))) else {
            NSLog("Revive the Touchbar: this macOS has no Control Strip entry point, so the Control Strip button isn't shown.")
            return false
        }
        NSTouchBarItem.addSystemTrayItem(item)
        Self.setPresence?(Self.identifier.rawValue as NSString, true)
        isInstalled = true
        return true
    }

    /// Puts the button back on the strip. Showing our modal bar and then closing it can take the button off the
    /// strip, so this runs after every dismiss. It does nothing if the button was never installed or was removed.
    func refresh() {
        guard isInstalled, NSTouchBarItem.responds(to: #selector(NSTouchBarItem.addSystemTrayItem(_:))) else { return }
        if NSTouchBarItem.responds(to: #selector(NSTouchBarItem.removeSystemTrayItem(_:))) { NSTouchBarItem.removeSystemTrayItem(item) }
        NSTouchBarItem.addSystemTrayItem(item)
        Self.setPresence?(Self.identifier.rawValue as NSString, true)
    }

    func remove() {
        guard isInstalled else { return }
        Self.setPresence?(Self.identifier.rawValue as NSString, false)
        if NSTouchBarItem.responds(to: #selector(NSTouchBarItem.removeSystemTrayItem(_:))) {
            NSTouchBarItem.removeSystemTrayItem(item)
        }
        isInstalled = false
    }

    @objc private func tapped() { onTap?() }
}
