import Cocoa
import CoreAudio
import AudioToolbox

/// The two levels the bar's invisible sliders change: the built-in screen's brightness and the output volume.
enum SystemLevel {
    case brightness, volume

    /// 0...1, or nil when this Mac doesn't let us read it.
    var value: Float? {
        switch self {
        case .brightness: return ScreenBrightness.get()
        case .volume: return OutputVolume.get()
        }
    }

    func set(_ v: Float) {
        let v = min(1, max(0, v))
        switch self {
        case .brightness: ScreenBrightness.set(v)
        case .volume: OutputVolume.set(v)
        }
    }
}

/// Built-in display brightness through the private DisplayServices framework (what the brightness keys use).
/// Looked up with `dlsym`, so a macOS that drops it only loses the brightness slider.
enum ScreenBrightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private static let getFn: GetFn? = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: GetFn.self) }
    private static let setFn: SetFn? = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: SetFn.self) }

    /// The laptop's own screen (the one with the Touch Bar), even when an external display is the main one.
    private static var builtIn: CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    static func get() -> Float? {
        guard let getFn, let id = builtIn else { return nil }
        var v: Float = 0
        return getFn(id, &v) == 0 ? v : nil
    }

    static func set(_ v: Float) {
        guard let setFn, let id = builtIn else { return }
        _ = setFn(id, v)
    }
}

/// The default output device's volume through Core Audio.
enum OutputVolume {
    private static var device: AudioObjectID? {
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr, id != 0 else { return nil }
        return id
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    }

    static func get() -> Float? {
        guard let id = device else { return nil }
        var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &v) == noErr else { return nil }
        return isMuted(id) ? 0 : v
    }

    static func set(_ v: Float) {
        guard let id = device else { return }
        var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        var value = Float32(v)
        AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        // Sliding to zero mutes, like the keys; sliding up from mute unmutes.
        var muteAddr = address(kAudioDevicePropertyMute)
        var mute: UInt32 = v <= 0.001 ? 1 : 0
        AudioObjectSetPropertyData(id, &muteAddr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &mute)
    }

    private static func isMuted(_ id: AudioObjectID) -> Bool {
        var addr = address(kAudioDevicePropertyMute)
        var mute: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &mute) == noErr && mute != 0
    }
}
