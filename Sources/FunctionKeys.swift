import Cocoa

/// Sends F1–F12 to the frontmost app, as if the physical keys were pressed.
/// Posting key events needs the Accessibility permission; the first tap asks for it.
enum FunctionKeys {
    /// Virtual key codes for F1...F12 (Carbon kVK_F1...kVK_F12).
    static let codes: [CGKeyCode] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    /// True when the app may post key events. With `prompt`, macOS shows its permission request if it's missing.
    @discardableResult
    static func ensureAccess(prompt: Bool) -> Bool {
        if CGPreflightPostEventAccess() { return true }
        // The request can wait on the system's permission dialog, so keep it off the main thread.
        if prompt { DispatchQueue.global(qos: .userInitiated).async { CGRequestPostEventAccess() } }
        return false
    }

    /// Presses and releases F`number` (1...12). Returns false when permission is missing.
    @discardableResult
    static func press(_ number: Int) -> Bool {
        guard (1...12).contains(number), ensureAccess(prompt: true) else { return false }
        let code = codes[number - 1]
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
            // Real F keys carry the function-key flag; some apps check for it.
            e.flags = .maskSecondaryFn
            e.post(tap: .cghidEventTap)
        }
        return true
    }
}
