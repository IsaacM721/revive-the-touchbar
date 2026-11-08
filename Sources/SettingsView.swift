import SwiftUI
import ServiceManagement

/// The signature: knob LEDs and pointers glow cyan. Everything else uses the system accent color.
let knobAccent = Color(red: 0, green: 0.9, blue: 1)

/// Localizes a string that lives in a variable (SwiftUI only localizes string literals on its own).
func loc(_ s: String) -> LocalizedStringKey { LocalizedStringKey(s) }
func fmt(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: Locale.current, arguments: args)
}

private let swatches: [(String, String)] = [
    ("Toxic Green", "44D62C"), ("Cyan", "00E5FF"), ("Electric Blue", "2979FF"), ("Purple", "9D4DFF"),
    ("Magenta", "FF2BD6"), ("Red", "FF1744"), ("Orange", "FF7A00"), ("White", "FFFFFF"),
]

struct EffectPreview: NSViewRepresentable {
    var effect: Effect?
    var scene: SceneSpec? = nil
    var renderWidth = 240
    var renderHeight = 24
    var fps = 30.0
    var showsBadge = false
    /// Cards show a full-size window onto the bar (see `EffectView.layoutAspect`); the live preview doesn't.
    var layoutAspect: Double? = 33.5

    func makeNSView(context: Context) -> EffectView {
        EffectView(renderWidth: renderWidth, renderHeight: renderHeight, fps: fps, overrideEffect: effect, overrideScene: scene,
                   followsWindow: true, showsBadge: showsBadge, layoutAspect: layoutAspect)
    }

    func updateNSView(_ view: EffectView, context: Context) {
        view.overrideEffect = effect
        view.overrideScene = scene
    }
}

private struct Panel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
    }
}

/// Which part of the window to show. Only used to capture website screenshots; `nil` means everything.
enum SnapshotPart { case top, tuning }

struct SettingsView: View {
    var part: SnapshotPart? = nil
    private func show(_ p: SnapshotPart) -> Bool { part == nil || part == p }
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var license = LicenseManager.shared
    @ObservedObject private var sponsors = SponsorFeed.shared
    @ObservedObject private var drops = DropFeed.shared
    @ObservedObject private var media = MediaLibrary.shared
    @AppStorage("didWelcome") private var didWelcome = false

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var naming = false
    @State private var presetName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if show(.top) {
                    header
                    if Config.chargingEnabled { statusBanner }
                    if !didWelcome && part == nil { welcome }
                    livePreview
                    presetsSection
                    librarySection
                }
                if show(.tuning) {
                    tuningSection
                    generalSection
                }
                if part == nil {
                    if license.status.showsAds, let sponsor = sponsors.current { sponsorCard(sponsor) }
                    footer
                }
            }
            .padding(28)
        }
        .frame(minWidth: 600, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .onAppear {
            sponsors.refresh()
            drops.refresh()
        }
    }

    private var fullAccess: Bool { license.status.hasFullAccess }

    // MARK: Header and status

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 40, height: 40)
            Text("Revive the Touchbar").font(.title2.weight(.semibold))
            Spacer()
            Toggle(isOn: $s.enabled) { Text("Lighting") }
                .toggleStyle(.switch)
        }
    }

    @ViewBuilder private var statusBanner: some View {
        switch license.status {
        case .trial(let days):
            HStack(spacing: 10) {
                Image(systemName: "clock").foregroundStyle(.secondary)
                Text(days == 1 ? NSLocalizedString("Free trial: 1 day left", comment: "") : fmt("Free trial: %d days left", days))
                Spacer()
            }
            .modifier(Panel())
        case .licensed(let plan, _):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc(plan == .lifetime ? "Lifetime license" : plan == .yearly ? "Pro Yearly plan" : "Monthly plan"))
                    if license.isLaunchGift {
                        Text("A launch gift. Thanks for being here early.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Deactivate This Mac") { license.signOut() }
            }
            .modifier(Panel())
        case .free:
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(.secondary)
                Text("Free plan")
                Spacer()
            }
            .modifier(Panel())
        }
    }

    /// First launch only: a few quick picks from different shelves, so the first thing you do is play.
    private var welcome: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Touch Bar is back.").font(.headline)
                Text(loc(license.status.isTrial
                         ? "Pick something to start. The whole library is yours during the trial, and new drops arrive every week."
                         : "Pick something to start. The whole library is yours, and new drops arrive every week."))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ForEach([Effect.rainbowWave, .cooking, .clock, .aquarium]) { e in
                        Button(loc(e.title)) {
                            s.select(e)
                            s.shelf = e.category.rawValue
                            didWelcome = true
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Button { didWelcome = true } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Close"))
        }
        .modifier(Panel())
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The whole bar, in its real proportions.
            EffectPreview(effect: nil, renderWidth: 1004, renderHeight: 30, fps: 45, showsBadge: true, layoutAspect: nil)
                .aspectRatio(1004 / 30, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 14)
            Text(loc(s.enabled ? "Live preview matches your Touch Bar." : "Paused. Your Touch Bar is back to normal."))
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Presets").font(.headline)
                Spacer()
                Button { presetName = ""; naming = true } label: { Label("Save Current Look", systemImage: "plus") }
                    .disabled(!fullAccess)
                    .popover(isPresented: $naming, arrowEdge: .bottom) { namePopover }
            }
            if !fullAccess {
                lockedNote("Presets are part of a paid plan.")
            } else if s.presets.isEmpty {
                Text("Save a look to bring it back with one click.").font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(s.presets) { p in
                        let active = s.activePreset == p
                        Button { s.apply(p) } label: {
                            Text(p.name).lineLimit(1).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(active ? .accentColor : nil)
                        .overlay(alignment: .trailing) { if active { Image(systemName: "checkmark").font(.caption2.bold()).padding(.trailing, 8) } }
                        .contextMenu { Button("Delete", role: .destructive) { s.deletePreset(p) } }
                        .accessibilityLabel(Text(p.name))
                        .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var namePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name").font(.headline)
            TextField("My look", text: $presetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onSubmit(commitPreset)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { naming = false }
                Button("Save", action: commitPreset)
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }

    private func commitPreset() {
        s.savePreset(named: presetName)
        naming = false
    }

    // MARK: Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Library").font(.headline)
                Spacer()
                Text(fmt("%d animations", Effect.allCases.count + drops.drops.count)).font(.caption).foregroundStyle(.secondary)
            }
            shelfPicker
            if s.shelf == "drops" {
                dropsShelf
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Effect.inCategory(EffectCategory(rawValue: s.shelf) ?? .ambient)) { effectCard($0) }
                }
            }
        }
    }

    private var shelfPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                shelfChip("drops", title: "Drops", symbol: "sparkles")
                ForEach(EffectCategory.allCases) { c in shelfChip(c.rawValue, title: c.title, symbol: c.symbol) }
            }
            .padding(.vertical, 2)
        }
    }

    private func shelfChip(_ id: String, title: String, symbol: String) -> some View {
        let selected = s.shelf == id
        return Button { s.shelf = id } label: {
            Label(loc(title), systemImage: symbol)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(Capsule().fill(selected ? Color.accentColor : Color(nsColor: .controlBackgroundColor)))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(selected ? 0 : 0.1)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var dropsShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New animations every week. They download on their own and are part of Pro.")
                .font(.callout).foregroundStyle(.secondary)
            if drops.drops.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading drops…").foregroundStyle(.secondary)
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(drops.drops) { dropCard($0) }
                }
            }
        }
    }

    private func effectCard(_ e: Effect) -> some View {
        let selected = s.effectiveScene == nil && s.effectiveEffect == e
        let locked = !fullAccess && !e.isFree
        return Button { if !locked { s.select(e) } } label: {
            card(preview: EffectPreview(effect: e), title: Text(loc(e.title)), blurb: Text(loc(e.blurb)),
                 locked: locked, tag: !locked && !fullAccess ? "Free" : nil, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(locked ? Text("Locked. Unlock everything with a plan.") : Text(""))
    }

    private func dropCard(_ d: SceneSpec) -> some View {
        let selected = s.effectiveScene?.id == d.id
        let locked = !fullAccess
        return Button { if !locked { s.select(drop: d) } } label: {
            card(preview: EffectPreview(effect: nil, scene: d), title: Text(verbatim: d.localizedName(appLanguage)),
                 blurb: Text(verbatim: d.localizedBlurb(appLanguage) ?? ""), locked: locked,
                 tag: !locked && drops.isNew(d) ? "New" : nil, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(locked ? Text("Locked. Unlock everything with a plan.") : Text(""))
    }

    private func card(preview: EffectPreview, title: Text, blurb: Text, locked: Bool, tag: String?, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            preview.frame(height: 24).opacity(locked ? 0.55 : 1)
            HStack(spacing: 6) {
                title.font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                } else if let tag {
                    Text(loc(tag)).font(.caption2.weight(.semibold)).foregroundStyle(Color.accentColor)
                }
            }
            blurb.font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.07), lineWidth: selected ? 2.5 : 1))
        .contentShape(Rectangle())
    }

    // MARK: Tuning

    private var tuningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tuning").font(.headline)
            if !fullAccess { lockedTuning } else {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    cornerKnob
                    if s.effect.usesAngle && license.isAdmin { directionKnob }
                }
                .frame(maxWidth: .infinity)
                slider("Speed", value: $s.speed, range: 0.25...4, label: String(format: "%.2g×", s.speed))
                slider("Brightness", value: $s.brightness, range: 0.1...1, label: "\(Int(s.brightness * 100))%")
                if s.effectiveScene == nil && s.effect.usesWidth {
                    slider("Color Spread", value: $s.width, range: 0.15...3,
                           label: NSLocalizedString(s.width < 0.6 ? "Stretched" : s.width < 1.5 ? "Normal" : "Tight", comment: ""))
                }
                if s.effectiveScene == nil && s.effect.usesText { textRow }
                if s.effectiveScene == nil && s.effect == .media { mediaRow }
                if s.effectiveScene == nil && s.effect.usesColor { colorRow }
            }
            .modifier(Panel())
            }
        }
    }

    /// Shown on the free plan instead of the controls: what it is locked to, and how to unlock the rest.
    private var lockedTuning: some View {
        VStack(alignment: .leading, spacing: 14) {
            lockedNote("Tuning is part of a paid plan. The free plan uses these settings.")
            VStack(spacing: 10) {
                lockedRow("Corner Radius", NSLocalizedString("Square", comment: ""))
                lockedRow("Speed", "1.2×")
                lockedRow("Brightness", "80%")
                lockedRow("Color", NSLocalizedString("Toxic Green", comment: ""))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(Panel())
    }

    private func lockedRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(loc(title)).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func lockedNote(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
            Text(loc(text)).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(loc(title)).font(.subheadline.weight(.medium))
                Spacer()
                Text(label).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range).accessibilityLabel(Text(loc(title)))
        }
    }

    private var cornerKnob: some View {
        let label = s.cornerFraction >= 0.999 ? NSLocalizedString("Full pill", comment: "")
            : s.cornerFraction <= 0.001 ? NSLocalizedString("Square", comment: "")
            : fmt("Rounded %d%%", Int(s.cornerFraction * 100))
        return knobColumn(title: "Corner Radius", value: label,
                          hint: "Drag up or right to round the bar. Hold ⌥ for fine control, double-click to reset.") {
            SynthKnob(value: $s.cornerFraction, size: 104, accent: knobAccent)
        }
    }

    private var directionKnob: some View {
        let d = Int(s.angle.rounded())
        let name: String
        switch d {
        case 0: name = NSLocalizedString("Horizontal →", comment: "")
        case 180: name = NSLocalizedString("Horizontal ←", comment: "")
        case 90: name = NSLocalizedString("Vertical ↓", comment: "")
        case 270: name = NSLocalizedString("Vertical ↑", comment: "")
        default: name = "\(d)°"
        }
        return knobColumn(title: "Direction", value: name,
                          hint: "Turn to aim the light. It clicks at every 45°. Double-click for horizontal.") {
            AngleKnob(degrees: $s.angle, size: 104, accent: knobAccent)
        }
    }

    private func knobColumn<K: View>(title: String, value: String, hint: String, @ViewBuilder knob: () -> K) -> some View {
        VStack(spacing: 10) {
            knob()
            Text(loc(title)).font(.subheadline.weight(.medium))
            Text(value).font(.subheadline.monospaced()).foregroundStyle(Color.accentColor)
            Text(loc(hint)).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var textRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your Text").font(.subheadline.weight(.medium))
            TextField("Type something", text: $s.text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: s.text) { value in if value.count > 120 { s.text = String(value.prefix(120)) } }
            Text("Letters, numbers, and punctuation show as an LED sign. Other scripts and emoji use the system font.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var mediaRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your GIF or Video").font(.subheadline.weight(.medium))
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle").foregroundStyle(.secondary)
                Text(verbatim: media.name ?? NSLocalizedString("No file yet", comment: ""))
                    .lineLimit(1).truncationMode(.middle).foregroundStyle(media.name == nil ? Color.secondary : Color.primary)
                if media.busy { ProgressView().controlSize(.small) }
                Spacer()
                if media.name != nil { Button("Remove") { media.remove() } }
                Button("Choose File…") { media.choose() }
            }
            if let error = media.error {
                Text(error).font(.caption).foregroundStyle(.red)
            } else {
                Text("GIFs, images, and videos up to 12 seconds. They fill the bar, so wide images look best.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color").font(.subheadline.weight(.medium))
            HStack(spacing: 10) {
                ForEach(swatches, id: \.1) { name, hex in
                    let rgb = RGB(hex: hex)!
                    Button { s.color = rgb } label: {
                        Circle().fill(rgb.color).frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(Color.primary, lineWidth: s.color == rgb ? 2.5 : 0).padding(-3))
                            .shadow(color: rgb.color.opacity(0.5), radius: 4)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString(name, comment: ""))
                    .accessibilityLabel(Text(loc(name)))
                    .accessibilityAddTraits(s.color == rgb ? .isSelected : [])
                }
                ColorPicker("Color", selection: Binding(get: { s.color.color }, set: { s.color = RGB(NSColor($0)) }),
                            supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }

    // MARK: General, sponsor, footer

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("General").font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show a close button on the Touch Bar", isOn: $s.showClose)
                Toggle("Show shortcut buttons on the Touch Bar", isOn: $s.showButtons)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Slide on the Touch Bar to change brightness and volume", isOn: $s.slideControls)
                    Text("Slide sideways over the lighting: the left half sets screen brightness, the right half sets volume.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if s.slideControls {
                        Button("Show me on the Touch Bar") {
                            NotificationCenter.default.post(name: .showSlideTip, object: nil)
                        }
                        .disabled(!s.enabled)
                    }
                }
                Toggle("Add a lighting button to the Control Strip", isOn: $s.showStripButton)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Keep the Touch Bar on while you are away", isOn: $s.keepOn)
                    Text("Stops the display from sleeping while the lighting is on. Uses more battery.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Show icon in the Dock", isOn: $s.showInDock)
                Toggle("Open at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch { NSSound.beep() }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(Panel())
        }
    }

    private func sponsorCard(_ sponsor: Sponsor) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sponsored").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(sponsor.title).font(.subheadline.weight(.semibold))
                Text(sponsor.text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let url = URL(string: sponsor.url) {
                Button(sponsor.cta ?? NSLocalizedString("Learn More", comment: "")) { NSWorkspace.shared.open(url) }
            }
        }
        .modifier(Panel())
        .accessibilityElement(children: .contain)
    }

    private var footer: some View {
        HStack {
            Text("Closing this window keeps the effect running. Find Revive the Touchbar in the menu bar.")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
