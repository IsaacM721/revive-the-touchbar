import Cocoa
import SwiftUI

// The plain-Swift model (RGB, Effect, Params) lives in Model.swift. These are the AppKit and SwiftUI bits.

extension RGB {
    init(_ c: NSColor) {
        let s = c.usingColorSpace(.sRGB) ?? c
        self.init(r: Double(s.redComponent), g: Double(s.greenComponent), b: Double(s.blueComponent))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
}

extension Effect {
    var isFree: Bool { Settings.freeEffects.contains(self) }
}

/// The person's language code as the drop feed and effect text use it ("en", "es", "pt", "fr", "hi", "zh").
var appLanguage: String {
    Bundle.main.preferredLocalizations.first.map { String($0.prefix(2)) } ?? "en"
}

// MARK: - Presets

/// A saved look: every tunable, under a name.
struct Preset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var effect: String
    var speed: Double
    var brightness: Double
    var width: Double
    var color: String
    var corner: Double
    var angle: Double
    /// Added with the library update; older presets decode without them.
    var drop: String?
    var text: String?
}

// MARK: - Settings

final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }
    @Published var effect: Effect { didSet { d.set(effect.rawValue, forKey: "effect") } }
    /// Animation speed multiplier.
    @Published var speed: Double { didSet { d.set(speed, forKey: "speed") } }
    @Published var brightness: Double { didSet { d.set(brightness, forKey: "brightness") } }
    /// How many rainbows fit across the bar for Rainbow Wave (small = stretched out).
    @Published var width: Double { didSet { d.set(width, forKey: "width") } }
    @Published var color: RGB { didSet { d.set(color.hex, forKey: "color") } }
    @Published var showClose: Bool { didSet { d.set(showClose, forKey: "showClose") } }
    /// The shortcut buttons on the Touch Bar (open the app, keep the bar on).
    @Published var showButtons: Bool { didSet { d.set(showButtons, forKey: "showButtons") } }
    /// A button in the system Control Strip that turns the lighting on and off.
    @Published var showStripButton: Bool { didSet { d.set(showStripButton, forKey: "showStripButton") } }
    /// Stops the display from dimming or sleeping while the lighting is on, so the Touch Bar stays lit with nobody there.
    @Published var keepOn: Bool { didSet { d.set(keepOn, forKey: "keepOn") } }
    /// Also show the app in the Dock (and the app switcher). The menu bar icon is always there.
    @Published var showInDock: Bool { didSet { d.set(showInDock, forKey: "showInDock") } }
    /// 0 = square corners, 1 = full pill.
    @Published var cornerFraction: Double { didSet { d.set(cornerFraction, forKey: "cornerFraction") } }
    /// Direction of flow in degrees (0 = horizontal, left to right).
    @Published var angle: Double { didSet { d.set(angle, forKey: "angle") } }
    /// Words for Your Text.
    @Published var text: String { didSet { d.set(text, forKey: "text") } }
    /// The animation drop that's playing, or "" when a built-in effect is.
    @Published var dropID: String { didSet { d.set(dropID, forKey: "dropID") } }
    /// The library shelf the settings window shows ("drops" or an `EffectCategory` raw value).
    @Published var shelf: String { didSet { d.set(shelf, forKey: "shelf") } }

    /// Saved looks, newest last.
    @Published var presets: [Preset] {
        didSet { d.set(try? JSONEncoder().encode(presets), forKey: "presets") }
    }

    private init() {
        presets = (d.data(forKey: "presets").flatMap { try? JSONDecoder().decode([Preset].self, from: $0) }) ?? []
        enabled = d.object(forKey: "enabled") as? Bool ?? true
        effect = Effect(rawValue: d.string(forKey: "effect") ?? "") ?? .rainbowWave
        speed = d.object(forKey: "speed") as? Double ?? 1
        brightness = d.object(forKey: "brightness") as? Double ?? 1
        width = d.object(forKey: "width") as? Double ?? 0.4
        color = RGB(hex: d.string(forKey: "color") ?? "") ?? RGB(hex: "44D62C")!
        showClose = d.object(forKey: "showClose") as? Bool ?? true
        showButtons = d.object(forKey: "showButtons") as? Bool ?? true
        showStripButton = d.object(forKey: "showStripButton") as? Bool ?? true
        keepOn = d.object(forKey: "keepOn") as? Bool ?? false   // off until chosen: it costs battery
        showInDock = d.object(forKey: "showInDock") as? Bool ?? true
        cornerFraction = d.object(forKey: "cornerFraction") as? Double ?? 1
        angle = d.object(forKey: "angle") as? Double ?? 90
        text = d.string(forKey: "text") ?? ""
        dropID = d.string(forKey: "dropID") ?? ""
        shelf = d.string(forKey: "shelf") ?? EffectCategory.ambient.rawValue
    }

    /// Plays a built-in effect.
    func select(_ e: Effect) {
        dropID = ""
        effect = e
    }

    /// Plays an animation drop.
    func select(drop: SceneSpec) { dropID = drop.id }

    /// Saves the current look. A preset with the same name is replaced.
    func savePreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let p = Preset(name: trimmed, effect: effect.rawValue, speed: speed, brightness: brightness, width: width,
                       color: color.hex, corner: cornerFraction, angle: angle, drop: dropID.isEmpty ? nil : dropID,
                       text: effect.usesText ? text : nil)
        if let i = presets.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            var replaced = p
            replaced.id = presets[i].id
            presets[i] = replaced
        } else {
            presets.append(p)
        }
    }

    func apply(_ p: Preset) {
        effect = Effect(rawValue: p.effect) ?? effect
        dropID = p.drop ?? ""
        speed = p.speed; brightness = p.brightness; width = p.width
        color = RGB(hex: p.color) ?? color
        cornerFraction = p.corner; angle = p.angle
        if let t = p.text { text = t }
    }

    func deletePreset(_ p: Preset) { presets.removeAll { $0.id == p.id } }

    /// The preset whose values match the current look, if any (used to highlight it).
    var activePreset: Preset? {
        presets.first { $0.effect == effect.rawValue && ($0.drop ?? "") == dropID && $0.speed == speed && $0.brightness == brightness
            && $0.width == width && $0.color == color.hex && $0.corner == cornerFraction && $0.angle == angle }
    }

    /// The free plan: these effects, in green, with these settings, nothing adjustable, and a small
    /// "Revive" tag on the bar. Drops, Your Text, and Your GIF are Pro.
    static let freeEffects = Effect.free
    private var fullAccess: Bool { LicenseManager.shared.status.hasFullAccess }
    var effectiveEffect: Effect { fullAccess || Self.freeEffects.contains(effect) ? effect : .spectrumCycle }
    var effectiveSpeed: Double { fullAccess ? speed : 1.2 }
    var effectiveBrightness: Double { fullAccess ? brightness : 0.8 }
    var effectiveCorner: Double { fullAccess ? cornerFraction : 0 }          // Square
    var effectiveColor: RGB { fullAccess ? color : RGB(hex: "44D62C")! }     // Toxic Green
    var effectiveWidth: Double { fullAccess ? width : 0.4 }
    /// The drop that's playing, if one is picked, it has downloaded, and the plan includes drops.
    var effectiveScene: SceneSpec? {
        guard fullAccess, !dropID.isEmpty else { return nil }
        return DropFeed.shared.drops.first { $0.id == dropID }
    }

    /// Everyone gets a vertical flow; only an admin license can aim the light.
    var effectiveAngle: Double { LicenseManager.shared.isAdmin ? angle : 90 }

    var params: Params {
        var p = Params(effect: effectiveEffect, brightness: effectiveBrightness, width: effectiveWidth, color: effectiveColor, angle: effectiveAngle)
        p.text = text
        p.info = LiveInfoSource.shared.current
        p.media = MediaLibrary.shared.clip
        p.scene = effectiveScene
        return p
    }
}
