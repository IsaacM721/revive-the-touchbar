import SwiftUI
import AppKit

/// A rotary knob styled like the hardware on a synthesizer: knurled skirt, brushed-metal cap,
/// a glowing pointer, and an LED scale that lights up to the current value.
/// There are no borders anywhere; every edge comes from gradients and shadow.
///
/// Drag up or to the right to turn it up (hold ⌥ for fine control), double-click to reset.
/// The ends of the travel are detents, with a haptic tick on a trackpad.
struct SynthKnob: View {
    @Binding var value: Double            // 0...1
    var size: CGFloat = 96
    var accent = Color(red: 0, green: 0.9, blue: 1)
    var resetValue = 1.0

    @State private var dragStart: Double?
    @State private var atDetent = false

    private let startAngle = -135.0, sweep = 270.0, ledCount = 11
    private var angle: Angle { .degrees(startAngle + sweep * value) }

    var body: some View {
        ZStack {
            leds

            KnobFace(size: size, accent: accent, pointer: angle)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(drag)
        .simultaneousGesture(TapGesture(count: 2).onEnded { value = resetValue })
        .accessibilityElement()
        .accessibilityLabel("Corner radius")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.1)
            case .decrement: value = max(0, value - 0.1)
            @unknown default: break
            }
        }
    }

    // MARK: Pieces

    private var leds: some View {
        ForEach(0..<ledCount, id: \.self) { i in
            let f = Double(i) / Double(ledCount - 1)
            let lit = value >= f - 0.001
            Circle()
                .fill(lit ? accent : Color.white.opacity(0.13))
                .frame(width: size * 0.05, height: size * 0.05)
                .shadow(color: lit ? accent.opacity(0.9) : .clear, radius: 4)
                .frame(width: size, height: size, alignment: .top)
                .rotationEffect(.degrees(startAngle + sweep * f))
        }
    }

    // MARK: Interaction

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let start = dragStart ?? value
                dragStart = start
                let fine = NSEvent.modifierFlags.contains(.option) ? 0.25 : 1.0
                var v = start + Double(g.translation.width - g.translation.height) / 220 * fine
                v = min(1, max(0, v))
                if v > 0.97 { v = 1 } else if v < 0.03 { v = 0 }     // detents at both ends
                let onDetent = v == 0 || v == 1
                if onDetent && !atDetent {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                atDetent = onDetent
                value = v
            }
            .onEnded { _ in dragStart = nil }
    }
}

// MARK: - Shared look

/// The physical part of a knob: knurled skirt, brushed-metal cap, glowing pointer.
/// `pointer` is the rotation from straight up. No borders; edges come from gradients and shadow.
struct KnobFace: View {
    var size: CGFloat
    var accent: Color
    var pointer: Angle

    var body: some View {
        let skirt = size * 0.74, cap = size * 0.5
        ZStack {
            // Knurled skirt with a soft, fixed light from the top left.
            Circle()
                .fill(AngularGradient(gradient: Gradient(stops: Self.knurl), center: .center))
                .frame(width: skirt, height: skirt)
                .overlay(Circle().fill(RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .center,
                                                      startRadius: skirt * 0.28, endRadius: skirt * 0.5)))
                .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.16), .clear],
                                                      startPoint: .topLeading, endPoint: .center)))
                .shadow(color: .black.opacity(0.75), radius: size * 0.09, y: size * 0.07)

            // Brushed-metal cap.
            Circle()
                .fill(AngularGradient(gradient: Gradient(stops: Self.brushed), center: .center))
                .frame(width: cap, height: cap)
                .overlay(Circle().fill(RadialGradient(colors: [.white.opacity(0.28), .clear, .black.opacity(0.35)],
                                                      center: UnitPoint(x: 0.4, y: 0.32),
                                                      startRadius: 0, endRadius: cap * 0.62)))
                .shadow(color: .black.opacity(0.55), radius: size * 0.04, y: size * 0.03)

            // Pointer.
            Capsule()
                .fill(accent)
                .frame(width: max(3, size * 0.04), height: cap * 0.3)
                .shadow(color: accent.opacity(0.95), radius: 4)
                .padding(.top, cap * 0.08)
                .frame(width: cap, height: cap, alignment: .top)
                .rotationEffect(pointer)
        }
    }

    /// 72 ridges around the skirt.
    private static let knurl: [Gradient.Stop] = {
        let n = 144
        return (0...n).map { i in
            .init(color: Color(white: i % 2 == 0 ? 0.09 : 0.24), location: Double(i) / Double(n))
        }
    }()

    private static let brushed: [Gradient.Stop] = {
        let shades: [Double] = [0.86, 0.42, 0.78, 0.33, 0.86, 0.42, 0.78, 0.33, 0.86]
        return shades.enumerated().map { i, w in
            .init(color: Color(white: w), location: Double(i) / Double(shades.count - 1))
        }
    }()
}

// MARK: - Direction knob

/// An endless dial for direction. The pointer points the way the light flows:
/// 0° is left to right (horizontal), 90° is top to bottom (vertical), and so on around.
/// It clicks onto every 45°, with a haptic tick on a trackpad and the matching LED lighting up.
struct AngleKnob: View {
    @Binding var degrees: Double          // 0..<360
    var size: CGFloat = 96
    var accent = Color(red: 0, green: 0.9, blue: 1)
    var resetDegrees = 0.0

    @State private var lastTouch: Double?
    @State private var travelled = 0.0
    @State private var startDegrees = 0.0
    @State private var snapped: Double?

    private static func wrap(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * 45
                let lit = abs(degrees - a) < 0.5
                Circle()
                    .fill(lit ? accent : Color.white.opacity(0.13))
                    .frame(width: size * 0.05, height: size * 0.05)
                    .shadow(color: lit ? accent.opacity(0.9) : .clear, radius: 4)
                    .frame(width: size, height: size, alignment: .top)
                    .rotationEffect(.degrees(a + 90))
            }
            KnobFace(size: size, accent: accent, pointer: .degrees(degrees + 90))
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(drag)
        .simultaneousGesture(TapGesture(count: 2).onEnded { degrees = resetDegrees })
        .accessibilityElement()
        .accessibilityLabel("Direction")
        .accessibilityValue("\(Int(degrees)) degrees")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: degrees = Self.wrap(degrees + 15)
            case .decrement: degrees = Self.wrap(degrees - 15)
            @unknown default: break
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let now = atan2(Double(g.location.y) - Double(size) / 2, Double(g.location.x) - Double(size) / 2) * 180 / .pi
                if let last = lastTouch {
                    var d = now - last
                    if d > 180 { d -= 360 } else if d < -180 { d += 360 }
                    travelled += d * (NSEvent.modifierFlags.contains(.option) ? 0.25 : 1)
                } else {
                    startDegrees = degrees
                    travelled = 0
                }
                lastTouch = now

                var v = Self.wrap(startDegrees + travelled)
                let nearest = (v / 45).rounded() * 45
                if abs(v - nearest) < 4 {
                    v = Self.wrap(nearest)
                    if snapped != v {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    }
                    snapped = v
                } else {
                    snapped = nil
                }
                degrees = v
            }
            .onEnded { _ in lastTouch = nil }
    }
}
