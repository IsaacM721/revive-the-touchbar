import Foundation

// effectlab: renders effects with the app's own renderer, off the Mac. Used to check new effects and to
// make the website's clips. Build and run with tools/effectlab/run.sh.
//
//   effectlab list                                   ids, one per line (with category)
//   effectlab still <id|all> <dir> [w h t]           one PPM per effect
//   effectlab raw <id> <w> <h> <fps> <seconds> [start] [badge|-] [layoutWidth]   raw RGB24 frames on stdout (pipe to ffmpeg)
//   effectlab drop <drops.json> <id> <w> <h> <fps> <seconds>     same, for an animation drop
//   effectlab drops <drops.json>                                  checks every drop decodes; lists ids
//   effectlab loop <id|drop:ID> <w> <h> <fps> <seconds> <fade> <layoutWidth|0> [drops.json]   seamless loop, raw RGB24
//   effectlab bench [w h]                                         milliseconds per frame for every effect
//   effectlab manifest                                            the library as JSON (website gallery)
//   effectlab reel <id,id,...> <w> <h> <fps> <secondsEach> <fade>   showreel, raw RGB24

setvbuf(stdout, nil, _IOFBF, 1 << 20)
let args = CommandLine.arguments

/// Colors the website shows each effect in (the app uses whatever you pick).
func showcaseColor(_ e: Effect) -> RGB {
    switch e {
    case .breathing: return RGB(0x9D4DFF)
    case .heartbeat: return RGB(0xFF1744)
    case .scanner: return RGB(0xFF1744)
    case .solid: return RGB(0x2979FF)
    case .clock, .binaryClock: return RGB(0x00E5FF)
    case .countdown: return RGB(0xFF2BD6)
    case .yearProgress: return RGB(0xFF7A00)
    case .marquee: return RGB(0xFF2BD6)
    default: return RGB(0x44D62C)
    }
}

/// A stand-in for someone's GIF: chunky, low-resolution plasma, like a GIF made for the Touch Bar.
let demoClip: MediaClip = {
    let core = EffectCore(width: 136, height: 4)
    var frames: [[UInt8]] = []
    var px = [UInt8](repeating: 255, count: 136 * 4 * 4)
    for k in 0..<40 {
        let t = Double(k) / 8
        px.withUnsafeMutableBufferPointer { core.render(Params(effect: .plasma, brightness: 1, width: 0.4, color: .white, angle: 90), time: t, into: $0.baseAddress!) }
        var rgb = [UInt8](repeating: 0, count: 136 * 4 * 3)
        for i in 0..<(136 * 4) { rgb[i * 3] = px[i * 4]; rgb[i * 3 + 1] = px[i * 4 + 1]; rgb[i * 3 + 2] = px[i * 4 + 2] }
        frames.append(rgb)
    }
    return MediaClip(width: 136, height: 4, frames: frames, delays: Array(repeating: 0.125, count: frames.count))
}()

func params(_ e: Effect, t: Double, badge: Bool = false) -> Params {
    var p = Params(effect: e, brightness: 1, width: 0.4, color: showcaseColor(e), angle: 90)
    p.text = "HELLO FROM MY TOUCH BAR ♥"
    var info = LiveInfo()
    info.secondsOfDay += t
    info.secondsToNewYear -= t
    info.now = 1_790_000_000 + t
    info.cpuHistory = (0..<60).map { i in 0.25 + 0.5 * noise1(Double(i) * 0.35 + t * 0.9, 7) }
    info.cpu = info.cpuHistory.last ?? 0.3
    p.info = info
    p.badge = badge
    if e == .media { p.media = demoClip }
    return p
}

func ppm(_ core: EffectCore, _ px: [UInt8]) -> Data {
    var d = Data("P6\n\(core.w) \(core.h)\n255\n".utf8)
    d.reserveCapacity(d.count + core.w * core.h * 3)
    for i in 0..<(core.w * core.h) { d.append(px[i * 4]); d.append(px[i * 4 + 1]); d.append(px[i * 4 + 2]) }
    return d
}

func effect(_ id: String) -> Effect {
    guard let e = Effect(rawValue: id) else { FileHandle.standardError.write("unknown effect \(id)\n".data(using: .utf8)!); exit(2) }
    return e
}

func rawFrames(_ core: EffectCore, fps: Double, seconds: Double, start: Double, make: (Double) -> Params) {
    var px = [UInt8](repeating: 255, count: core.w * core.h * 4)
    var rgb = [UInt8](repeating: 0, count: core.w * core.h * 3)
    let n = Int((fps * seconds).rounded())
    for f in 0..<n {
        let t = start + Double(f) / fps
        px.withUnsafeMutableBufferPointer { core.render(make(t), time: t, into: $0.baseAddress!) }
        for i in 0..<(core.w * core.h) { rgb[i * 3] = px[i * 4]; rgb[i * 3 + 1] = px[i * 4 + 1]; rgb[i * 3 + 2] = px[i * 4 + 2] }
        rgb.withUnsafeBufferPointer { _ = fwrite($0.baseAddress!, 1, $0.count, stdout) }
    }
    fflush(stdout)
}

switch args.count > 1 ? args[1] : "" {
case "list":
    for e in Effect.allCases { print(e.rawValue, e.category.rawValue, e.title, separator: "\t") }

case "manifest":
    // The library as JSON, for the website's gallery.
    let items: [[String: Any]] = Effect.allCases.map {
        ["id": $0.rawValue, "category": $0.category.rawValue, "title": $0.title, "blurb": $0.blurb,
         "free": Effect.free.contains($0), "new": $0.isNew, "live": $0.isLive]
    }
    let data = try! JSONSerialization.data(withJSONObject: ["categories": EffectCategory.allCases.map { ["id": $0.rawValue, "title": $0.title] }, "effects": items], options: [.prettyPrinted, .sortedKeys])
    print(String(data: data, encoding: .utf8)!)

case "reel":
    // A showreel: several effects in a row, crossfading, looping back to the first.
    //   reel <id,id,...> <w> <h> <fps> <secondsEach> <fade>
    let ids = args[2].split(separator: ",").map { effect(String($0)) }
    let w = Int(args[3])!, h = Int(args[4])!, fps = Double(args[5])!, each = Double(args[6])!, fade = Double(args[7])!
    let n = Int((fps * each).rounded()), f = Int((fps * fade).rounded())
    var segments: [[[UInt8]]] = []
    var px = [UInt8](repeating: 255, count: w * h * 4)
    for e in ids {
        let core = EffectCore(width: w, height: h)
        var seg: [[UInt8]] = []
        for k in 0..<(n + f) {
            let t = 2 + Double(k) / fps
            px.withUnsafeMutableBufferPointer { core.render(params(e, t: t), time: t, into: $0.baseAddress!) }
            var rgb = [UInt8](repeating: 0, count: w * h * 3)
            for i in 0..<(w * h) { rgb[i * 3] = px[i * 4]; rgb[i * 3 + 1] = px[i * 4 + 1]; rgb[i * 3 + 2] = px[i * 4 + 2] }
            seg.append(rgb)
        }
        segments.append(seg)
    }
    // Segment i plays frames f..<n+f; its last f frames blend into the first f frames of segment i+1.
    for (i, seg) in segments.enumerated() {
        let next = segments[(i + 1) % segments.count]
        for k in f..<(n + f) {
            var out = seg[k]
            let j = k - n
            if j >= 0 {
                let a = Double(j + 1) / Double(f + 1), y = next[j]
                for q in 0..<out.count { out[q] = UInt8((Double(out[q]) * (1 - a) + Double(y[q]) * a).rounded()) }
            }
            out.withUnsafeBufferPointer { _ = fwrite($0.baseAddress!, 1, $0.count, stdout) }
        }
    }
    fflush(stdout)

case "still":
    let which = args[2], dir = args[3]
    let w = args.count > 4 ? Int(args[4])! : 1085, h = args.count > 5 ? Int(args[5])! : 30
    let t = args.count > 6 ? Double(args[6])! : 2.3
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let list = which == "all" ? Effect.allCases : [effect(which)]
    for e in list {
        let core = EffectCore(width: w, height: h)
        var px = [UInt8](repeating: 255, count: w * h * 4)
        px.withUnsafeMutableBufferPointer { core.render(params(e, t: t), time: t, into: $0.baseAddress!) }
        try! ppm(core, px).write(to: URL(fileURLWithPath: "\(dir)/\(e.rawValue).ppm"))
    }

case "raw":
    let e = effect(args[2])
    let w = Int(args[3])!, h = Int(args[4])!, fps = Double(args[5])!, seconds = Double(args[6])!
    let start = args.count > 7 ? Double(args[7])! : 1
    let badge = args.count > 8 && args[8] == "badge"
    // Optional: lay out for a wider bar and show a window onto it (how previews work).
    let layout = args.count > 9 ? Double(args[9]) : nil
    let core = EffectCore(width: w, height: h, layoutWidth: layout)
    rawFrames(core, fps: fps, seconds: seconds, start: start) { params(e, t: $0, badge: badge) }

case "drop":
    let data = try! Data(contentsOf: URL(fileURLWithPath: args[2]))
    let all = try! JSONDecoder().decode([SceneSpec].self, from: data)
    guard let spec = all.first(where: { $0.id == args[3] }) else { FileHandle.standardError.write("no drop \(args[3])\n".data(using: .utf8)!); exit(2) }
    let w = Int(args[4])!, h = Int(args[5])!, fps = Double(args[6])!, seconds = Double(args[7])!
    let layout = args.count > 8 ? Double(args[8]) : nil
    let core = EffectCore(width: w, height: h, layoutWidth: layout)
    rawFrames(core, fps: fps, seconds: seconds, start: 1) { t in var p = params(.solid, t: t); p.scene = spec; return p }

case "loop":
    // A seamless loop: renders `seconds + fade` and crossfades the tail into the head.
    //   loop <effect id | drop:ID> <w> <h> <fps> <seconds> <fade> <layoutWidth|0> [drops.json]
    let id = args[2]
    let w = Int(args[3])!, h = Int(args[4])!, fps = Double(args[5])!, seconds = Double(args[6])!, fade = Double(args[7])!
    let layout = Double(args[8]).flatMap { $0 > 0 ? $0 : nil }
    var scene: SceneSpec?
    var e = Effect.solid
    if id.hasPrefix("drop:") {
        let all = try! JSONDecoder().decode([SceneSpec].self, from: Data(contentsOf: URL(fileURLWithPath: args[9])))
        scene = all.first { $0.id == String(id.dropFirst(5)) }
        if scene == nil { FileHandle.standardError.write("no drop \(id)\n".data(using: .utf8)!); exit(2) }
    } else { e = effect(id) }
    let core = EffectCore(width: w, height: h, layoutWidth: layout)
    let n = Int((fps * seconds).rounded()), f = Int((fps * fade).rounded())
    var frames: [[UInt8]] = []
    var px = [UInt8](repeating: 255, count: w * h * 4)
    for k in 0..<(n + f) {
        let t = 1.5 + Double(k) / fps
        var p = params(e, t: t)
        p.scene = scene
        px.withUnsafeMutableBufferPointer { core.render(p, time: t, into: $0.baseAddress!) }
        var rgb = [UInt8](repeating: 0, count: w * h * 3)
        for i in 0..<(w * h) { rgb[i * 3] = px[i * 4]; rgb[i * 3 + 1] = px[i * 4 + 1]; rgb[i * 3 + 2] = px[i * 4 + 2] }
        frames.append(rgb)
    }
    for k in 0..<n {
        var out: [UInt8]
        if k < n - f || f == 0 {
            out = frames[k + f]
        } else {
            let j = k - (n - f), a = Double(j + 1) / Double(f + 1)
            let x = frames[k + f], y = frames[j]
            out = [UInt8](repeating: 0, count: x.count)
            for i in 0..<x.count { out[i] = UInt8((Double(x[i]) * (1 - a) + Double(y[i]) * a).rounded()) }
        }
        out.withUnsafeBufferPointer { _ = fwrite($0.baseAddress!, 1, $0.count, stdout) }
    }
    fflush(stdout)

case "bench":
    // Milliseconds per frame at Touch Bar size, for every effect.
    let w = args.count > 2 ? Int(args[2])! : 1004, h = args.count > 3 ? Int(args[3])! : 30
    var px = [UInt8](repeating: 255, count: w * h * 4)
    for e in Effect.allCases {
        let core = EffectCore(width: w, height: h)
        let n = 90
        let start = Date()
        for f in 0..<n {
            let t = 1 + Double(f) / 60
            px.withUnsafeMutableBufferPointer { core.render(params(e, t: t), time: t, into: $0.baseAddress!) }
        }
        print(String(format: "%-16@ %6.2f ms", e.rawValue as NSString, Date().timeIntervalSince(start) * 1000 / Double(n)))
    }

case "drops":
    let data = try! Data(contentsOf: URL(fileURLWithPath: args[2]))
    let all = try! JSONDecoder().decode([SceneSpec].self, from: data)
    for d in all { print(d.id, d.shelf.rawValue, d.name, separator: "\t") }

default:
    print("usage: effectlab list | still <id|all> <dir> [w h t] | raw <id> w h fps seconds [start] [badge] | drop <drops.json> <id> w h fps seconds | drops <drops.json>")
    exit(2)
}
