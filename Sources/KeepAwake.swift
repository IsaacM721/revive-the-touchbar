import Foundation
import IOKit.pwr_mgt

/// Keeps the display, and with it the Touch Bar, from dimming or sleeping when nobody is at the keyboard.
/// Same power assertion as `caffeinate -d`: it's released the moment `set(false)` is called or the app quits.
final class KeepAwake {
    static let shared = KeepAwake()
    private var assertion: IOPMAssertionID = 0
    private(set) var isHolding = false

    func set(_ on: Bool) {
        if on, !isHolding {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Revive the Touchbar keeps the Touch Bar on" as CFString,
                &assertion)
            isHolding = result == kIOReturnSuccess
            if !isHolding { NSLog("Revive the Touchbar: couldn't keep the display awake (IOKit error \(result)).") }
        } else if !on, isHolding {
            IOPMAssertionRelease(assertion)
            assertion = 0
            isHolding = false
        }
    }
}
