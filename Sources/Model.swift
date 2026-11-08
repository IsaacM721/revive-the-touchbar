import Foundation

// Everything here is plain Swift (Foundation only), so the renderer can also be built and tested
// off the Mac. See tools/effectlab. AppKit and SwiftUI extensions live in Settings.swift.

// MARK: - Color

struct RGB: Equatable {
    var r: Double, g: Double, b: Double

    static let white = RGB(r: 1, g: 1, b: 1)
    static let black = RGB(r: 0, g: 0, b: 0)

    static func hsv(_ h: Double, _ s: Double, _ v: Double) -> RGB {
        let hh = (h - h.rounded(.down)) * 6
        let i = Int(hh) % 6
        let f = hh - hh.rounded(.down)
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch i {
        case 0: return RGB(r: v, g: t, b: p)
        case 1: return RGB(r: q, g: v, b: p)
        case 2: return RGB(r: p, g: v, b: t)
        case 3: return RGB(r: p, g: q, b: v)
        case 4: return RGB(r: t, g: p, b: v)
        default: return RGB(r: v, g: p, b: q)
        }
    }

    func scaled(_ k: Double) -> RGB { RGB(r: r * k, g: g * k, b: b * k) }

    func mixed(with o: RGB, _ t: Double) -> RGB {
        RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    func adding(_ o: RGB) -> RGB { RGB(r: r + o.r, g: g + o.g, b: b + o.b) }

    /// Perceived brightness, 0...1.
    var luma: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    var hex: String {
        String(format: "%02X%02X%02X", Int(r * 255 + 0.5), Int(g * 255 + 0.5), Int(b * 255 + 0.5))
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    init?(hex raw: String) {
        let hex = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        guard hex.count == 6, let n = UInt32(hex, radix: 16) else { return nil }
        self.init(r: Double((n >> 16) & 255) / 255, g: Double((n >> 8) & 255) / 255, b: Double(n & 255) / 255)
    }

    /// For literals in effect code: `RGB(0xFF7A00)`.
    init(_ n: UInt32) {
        self.init(r: Double((n >> 16) & 255) / 255, g: Double((n >> 8) & 255) / 255, b: Double(n & 255) / 255)
    }
}

// MARK: - Library

/// Shelves in the effect library. The settings window and the website group effects by these.
enum EffectCategory: String, CaseIterable, Identifiable {
    case ambient, retro, gaming, productivity, memes, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ambient: "Ambient"
        case .retro: "Retro"
        case .gaming: "Gaming"
        case .productivity: "Productivity"
        case .memes: "Memes"
        case .custom: "Custom"
        }
    }

    /// SF Symbol for the category picker.
    var symbol: String {
        switch self {
        case .ambient: "moon.stars"
        case .retro: "tv"
        case .gaming: "gamecontroller"
        case .productivity: "timer"
        case .memes: "face.smiling"
        case .custom: "paintbrush"
        }
    }
}

/// Every built-in effect. Raw values are stored in settings and presets, so never rename one.
enum Effect: String, CaseIterable, Identifiable {
    // Ambient
    case rainbowWave, spectrumCycle, breathing, neonBreath, heartbeat, inferno, starfield, solid
    case aurora, rain, aquarium, galaxy, fireflies, sunset, lavaLamp, snowfall
    // Retro
    case matrix, scanner, plasma, bouncingLogo, terminal, paddleBall, loadingBar, snake, synthwave, equalizer, vhs
    // Gaming
    case healthBar, xpBar, coinRush, wantedLevel, pixelRunner, shooterHUD, bossFight
    // Productivity
    case clock, focusTimer, systemMonitor, countdown, yearProgress, binaryClock
    // Memes
    case cooking, fatalError, loadingForever, systemUpdate, doNotTouch, hacker, typing
    // Custom
    case marquee, media

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rainbowWave: "Rainbow Wave"
        case .spectrumCycle: "Spectrum Cycle"
        case .breathing: "Breathing"
        case .neonBreath: "Neon Breath"
        case .heartbeat: "Heartbeat"
        case .inferno: "Inferno"
        case .starfield: "Starfield"
        case .solid: "Solid"
        case .aurora: "Aurora"
        case .rain: "Rain"
        case .aquarium: "Aquarium"
        case .galaxy: "Galaxy"
        case .fireflies: "Fireflies"
        case .sunset: "Sunset"
        case .lavaLamp: "Lava Lamp"
        case .snowfall: "Snowfall"
        case .matrix: "Matrix"
        case .scanner: "Scanner"
        case .plasma: "Plasma"
        case .bouncingLogo: "Bouncing Logo"
        case .terminal: "Retro Terminal"
        case .paddleBall: "Paddle Ball"
        case .loadingBar: "Loading Bar"
        case .snake: "Snake"
        case .synthwave: "Synthwave"
        case .equalizer: "Equalizer"
        case .vhs: "VHS Tape"
        case .healthBar: "Health Bar"
        case .xpBar: "XP Bar"
        case .coinRush: "Coin Rush"
        case .wantedLevel: "Wanted Level"
        case .pixelRunner: "Pixel Runner"
        case .shooterHUD: "Shooter HUD"
        case .bossFight: "Boss Fight"
        case .clock: "Clock"
        case .focusTimer: "Focus Timer"
        case .systemMonitor: "System Monitor"
        case .countdown: "New Year Countdown"
        case .yearProgress: "Year Progress"
        case .binaryClock: "Binary Clock"
        case .cooking: "Bro Is Cooking"
        case .fatalError: "Fatal Error"
        case .loadingForever: "Loading Forever"
        case .systemUpdate: "System Update"
        case .doNotTouch: "Do Not Touch"
        case .hacker: "I'm In"
        case .typing: "Someone Is Typing"
        case .marquee: "Your Text"
        case .media: "Your GIF or Video"
        }
    }

    var blurb: String {
        switch self {
        case .rainbowWave: "The classic. A slow, stretched spectrum wave."
        case .spectrumCycle: "The whole bar drifts through every color."
        case .breathing: "Smooth inhale, exhale. One color of your choice."
        case .neonBreath: "Breath pulses ripple out from the center, white-hot at the peak."
        case .heartbeat: "Thump-thump shockwaves blast out from the middle."
        case .inferno: "Flickering flames climbing up the bar."
        case .starfield: "Random colored stars twinkle on and off."
        case .solid: "A single steady color."
        case .aurora: "Northern lights ripple across the bar."
        case .rain: "A soft storm streaks across the bar."
        case .aquarium: "Little fish swim by while bubbles drift up."
        case .galaxy: "A slow nebula drifts past a field of stars."
        case .fireflies: "Warm lights float and blink in the dark."
        case .sunset: "The sun sinks into a glowing sea."
        case .lavaLamp: "Blobs of color melt into each other."
        case .snowfall: "Quiet snow drifts down."
        case .matrix: "Green code rains down on a black screen."
        case .scanner: "A glowing comet with a trail sweeps side to side."
        case .plasma: "Old-school demo colors, melting forever."
        case .bouncingLogo: "It will hit the corner. Eventually."
        case .terminal: "A green screen types its way through boot-up."
        case .paddleBall: "Two paddles, one ball, no winner."
        case .loadingBar: "A chunky progress bar that always finishes."
        case .snake: "The classic snake eats its way across the bar."
        case .synthwave: "A neon grid races toward an 80s sunset."
        case .equalizer: "Bouncing bars, like a stereo from 1989."
        case .vhs: "Tracking lines, glitches, and a play button."
        case .healthBar: "Take damage, heal up, repeat."
        case .xpBar: "Earn XP and level up, over and over."
        case .coinRush: "Spinning coins roll in and the counter climbs."
        case .wantedLevel: "Five stars and flashing lights. Good luck."
        case .pixelRunner: "A tiny hero runs and jumps forever."
        case .shooterHUD: "Crosshair, ammo count, and a kill feed."
        case .bossFight: "A giant health bar that takes forever to drain."
        case .clock: "The time, in big glowing digits."
        case .focusTimer: "25 minutes of focus, then a 5-minute break."
        case .systemMonitor: "Live CPU and memory use on your Mac."
        case .countdown: "Days, hours, and seconds until the new year."
        case .yearProgress: "How much of the year is already gone."
        case .binaryClock: "The time, for people who read binary."
        case .cooking: "Let him cook. Flames included."
        case .fatalError: "A very serious error that means nothing."
        case .loadingForever: "Stuck at 99, then back to 12. Classic."
        case .systemUpdate: "Installing update 1 of 847. Do not turn off your Touch Bar."
        case .doNotTouch: "Hazard stripes for the one strip you shouldn't touch."
        case .hacker: "Access granted. You are now a hacker."
        case .typing: "Three dots that never turn into a message."
        case .marquee: "Your own words, scrolling in lights."
        case .media: "Play a GIF, an image, or a short video on the bar."
        }
    }

    var category: EffectCategory {
        switch self {
        case .rainbowWave, .spectrumCycle, .breathing, .neonBreath, .heartbeat, .inferno, .starfield, .solid,
             .aurora, .rain, .aquarium, .galaxy, .fireflies, .sunset, .lavaLamp, .snowfall: .ambient
        case .matrix, .scanner, .plasma, .bouncingLogo, .terminal, .paddleBall, .loadingBar, .snake, .synthwave, .equalizer, .vhs: .retro
        case .healthBar, .xpBar, .coinRush, .wantedLevel, .pixelRunner, .shooterHUD, .bossFight: .gaming
        case .clock, .focusTimer, .systemMonitor, .countdown, .yearProgress, .binaryClock: .productivity
        case .cooking, .fatalError, .loadingForever, .systemUpdate, .doNotTouch, .hacker, .typing: .memes
        case .marquee, .media: .custom
        }
    }

    static func inCategory(_ c: EffectCategory) -> [Effect] { allCases.filter { $0.category == c } }

    /// On the free plan (after the trial) these keep working, in green, with fixed settings.
    static let free: [Effect] = [.spectrumCycle, .matrix, .clock, .rain, .bouncingLogo, .doNotTouch]

    /// Effects added in the library update (shown with a "New" tag for a while).
    var isNew: Bool {
        ![.rainbowWave, .spectrumCycle, .breathing, .neonBreath, .heartbeat, .inferno, .starfield, .solid, .matrix, .scanner].contains(self)
    }

    /// Tinted by the color you pick.
    var usesColor: Bool {
        [.breathing, .heartbeat, .scanner, .matrix, .solid, .terminal, .loadingBar, .clock, .binaryClock,
         .countdown, .yearProgress, .hacker, .marquee].contains(self)
    }
    var usesWidth: Bool { self == .rainbowWave }
    /// Effects that flow along a direction you can aim (most have none).
    var usesAngle: Bool { [.rainbowWave, .spectrumCycle, .neonBreath, .heartbeat, .scanner].contains(self) }
    /// Uses the text you type (Your Text).
    var usesText: Bool { self == .marquee }
    /// Where the interesting part is, 0 (left end) to 1 (right end). Small previews show a window onto
    /// the full-size bar centered here, rather than squeezing the whole bar into a card.
    var previewFocus: Double {
        switch self {
        case .typing, .vhs, .healthBar, .xpBar, .loadingForever, .pixelRunner, .bossFight, .focusTimer, .systemUpdate,
             .hacker, .terminal, .loadingBar, .systemMonitor, .yearProgress: 0
        case .coinRush: 1
        default: 0.5
        }
    }

    /// Shows the actual time or live system numbers.
    var isLive: Bool { [.clock, .focusTimer, .systemMonitor, .countdown, .yearProgress, .binaryClock].contains(self) }
}

/// Corner radius for a bar `height` tall. `fraction` runs from 0 (square) to 1 (full pill, where the
/// radius is half the height).
func cornerRadius(fraction: Double, height: CGFloat) -> CGFloat {
    height * 0.5 * CGFloat(fraction)
}

// MARK: - Frame inputs

/// Real-world numbers some effects show (time, CPU). The app fills this once a second.
struct LiveInfo {
    /// Local wall-clock time, seconds since midnight.
    var secondsOfDay: Double = 34_860          // 9:41
    /// Seconds until the next local new year.
    var secondsToNewYear: Double = 8_395_975  // 97 days, 4:12:55
    /// 0...1 of the current year already passed.
    var yearFraction: Double = 0.734
    /// The current year, for Year Progress.
    var year: Int = 2026
    /// Wall clock, seconds since 1970 (the Focus Timer counts from when it was picked).
    var now: Double = 1_790_000_000
    /// "SAT 26 SEP", already in the person's language when the dot font can draw it.
    var dateLabel = "SAT 26 SEP"
    /// 0...1 CPU use across all cores, and memory in use.
    var cpu: Double = 0.34
    var memory: Double = 0.62
    /// Recent CPU samples, oldest first, one a second.
    var cpuHistory: [Double] = []
    var use24Hour = false
}

/// Frames of a GIF, image, or video, already scaled to fill a bar. Pixels are RGB, 3 bytes each.
final class MediaClip {
    let width: Int, height: Int
    let frames: [[UInt8]]
    /// Seconds each frame stays up.
    let delays: [Double]
    let duration: Double

    init(width: Int, height: Int, frames: [[UInt8]], delays: [Double]) {
        self.width = width; self.height = height; self.frames = frames
        self.delays = delays.map { max(0.02, $0) }
        duration = max(0.02, self.delays.reduce(0, +))
    }

    func frame(at t: Double) -> [UInt8]? {
        guard !frames.isEmpty else { return nil }
        guard frames.count > 1 else { return frames[0] }
        var x = t.truncatingRemainder(dividingBy: duration)
        if x < 0 { x += duration }
        for (i, d) in delays.enumerated() {
            if x < d { return frames[i] }
            x -= d
        }
        return frames[frames.count - 1]
    }
}

/// Everything the renderer needs for one frame (speed is applied to the animation clock, not here).
struct Params {
    var effect: Effect
    var brightness: Double
    var width: Double
    var color: RGB
    /// Direction of flow in degrees: 0 = left to right (horizontal), 90 = top to bottom (vertical).
    var angle: Double
    /// Words for Your Text.
    var text: String = ""
    var info = LiveInfo()
    var media: MediaClip? = nil
    /// A downloaded animation (an "animation drop"). When set, it plays instead of `effect`.
    var scene: SceneSpec? = nil
    /// The free plan's small "Revive" tag at the left end of the bar.
    var badge = false
}
