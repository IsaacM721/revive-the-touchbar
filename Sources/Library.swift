import Foundation

// The effect library beyond the original ten. Each effect is a method that draws one frame into
// `canvas` as a pure function of time `t` (seconds, already scaled by the Speed control). Sizes are
// relative to the bar height `H`, so effects look the same on the Touch Bar (about 1004 x 30), in the
// settings cards, and in the website's clips.

extension EffectCore {
    func drawLibrary(_ p: Params, _ t: Double) {
        switch p.effect {
        // Ambient
        case .aurora: aurora(t)
        case .rain: rain(t)
        case .aquarium: aquarium(t)
        case .galaxy: galaxy(t)
        case .fireflies: fireflies(t)
        case .sunset: sunset(t)
        case .lavaLamp: lavaLamp(t)
        case .snowfall: snowfall(t)
        // Retro
        case .plasma: plasma(t)
        case .bouncingLogo: bouncingLogo(t)
        case .terminal: terminal(p, t)
        case .paddleBall: paddleBall(t)
        case .loadingBar: loadingBar(p, t)
        case .snake: snake(t)
        case .synthwave: synthwave(t)
        case .equalizer: equalizer(t)
        case .vhs: vhs(t)
        // Gaming
        case .healthBar: healthBar(t)
        case .xpBar: xpBar(t)
        case .coinRush: coinRush(t)
        case .wantedLevel: wantedLevel(t)
        case .pixelRunner: pixelRunner(t)
        case .shooterHUD: shooterHUD(t)
        case .bossFight: bossFight(t)
        // Productivity
        case .clock: clock(p)
        case .focusTimer: focusTimer(p)
        case .systemMonitor: systemMonitor(p, t)
        case .countdown: countdown(p, t)
        case .yearProgress: yearProgress(p, t)
        case .binaryClock: binaryClock(p)
        // Memes
        case .cooking: cooking(t)
        case .fatalError: errorScreen(t)
        case .loadingForever: loadingForever(t)
        case .systemUpdate: systemUpdate(t)
        case .doNotTouch: doNotTouch(t)
        case .hacker: hacker(p, t)
        case .typing: typing(t)
        // Custom
        case .marquee: marquee(p, t)
        case .media: media(p, t)
        default: canvas.clear()
        }
    }

    // MARK: Shared helpers

    /// Dot size for text `rows` dots tall that should fill about `fill` of the bar height, never so wide
    /// that `chars` characters overflow `maxWidth`.
    func dotSize(fill: Double = 0.7, maxWidth: Double? = nil, text: String? = nil) -> Double {
        var d = H * fill / Double(PixelFont.rows)
        if let text, let maxWidth {
            let dots = Double(PixelFont.width(text))
            if dots * d > maxWidth { d = maxWidth / dots }
        }
        return d >= 2 ? d.rounded(.down) : max(0.8, d)
    }

    /// 0...1 position for something bouncing between two walls, crossing once per unit of `p`.
    /// Also returns how many walls it has hit.
    func bounce(_ p: Double) -> (pos: Double, hits: Int) {
        let n = Int(p.rounded(.down)), f = p - Double(n)
        return (n % 2 == 0 ? f : 1 - f, n)
    }

    /// A cached value per effect (paths, layouts) keyed by name.
    func cached<T>(_ key: String, _ make: () -> T) -> T {
        if let v = cache[key] as? T { return v }
        let v = make()
        cache[key] = v
        return v
    }
}
