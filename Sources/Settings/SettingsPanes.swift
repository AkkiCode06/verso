import SwiftUI

// MARK: - Typeface

/// The sample carries this pane: a full-width line of real lyric type, with
/// the font list filling the space beneath it.
struct TypefacePane: View {
    @ObservedObject private var settings = Settings.shared
    @State private var loaded: [String: String] = [:]
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                PaneHeader(
                    title: "Typeface",
                    subtitle: "Left automatic, the face follows the genre — slab for rock, serif for jazz, rounded for pop."
                )

                Text("Pull me closer")
                    .font(sampleFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)

                ChipRow(
                    items: Settings.FontChoice.allCases,
                    title: shortTitle,
                    selection: $settings.fontChoice
                )

            }
            .padding(.horizontal, 34)
            .padding(.top, 34)

            if settings.fontChoice == .google {
                googleList
                    .padding(.top, 22)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Verso.surface)
    }

    private var googleList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(AppFont.ui(11))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search Google Fonts", text: $search)
                    .textFieldStyle(.plain)
                    .font(AppFont.ui(12))
                    .onSubmit {
                        let typed = search.trimmingCharacters(in: .whitespaces)
                        if !typed.isEmpty { settings.applyGoogleFont(family: typed) }
                    }
                if let status = settings.googleStatus {
                    Text(status)
                        .font(AppFont.ui(10.5))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 10)
            .background(.white.opacity(0.04))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredFamilies, id: \.self) { row($0) }
                }
            }
        }
    }

    private var filteredFamilies: [String] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return GoogleFontsCatalog.allFamilies }
        return GoogleFontsCatalog.allFamilies.filter { $0.lowercased().contains(query) }
    }

    private func row(_ family: String) -> some View {
        let selected = settings.googleFontFamily == family
        return Button {
            settings.applyGoogleFont(family: family)
        } label: {
            HStack {
                // Each row previews in its own face once the file lands.
                Text(family)
                    .font(loaded[family].map { Font.custom($0, fixedSize: 17) } ?? AppFont.ui(17))
                    .foregroundStyle(selected ? .white : .white.opacity(0.72))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(AppFont.ui(10, .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(selected ? .white.opacity(0.08) : .clear)
        }
        .buttonStyle(.plain)
        // Fetched only as a row appears; the catalogue would be tens of
        // megabytes for faces nobody scrolls to.
        .task(id: family) {
            guard loaded[family] == nil else { return }
            guard let font = await GoogleFontsProvider.shared.font(family: family) else { return }
            loaded[family] = font.regular
        }
    }

    private var sampleFont: Font {
        // Manrope and a chosen Google family both come from the same
        // downloaded-and-registered path.
        if settings.fontChoice == .manrope, let regular = AppFont.regular {
            return .custom(AppFont.bold ?? regular, fixedSize: 54)
        }
        if settings.fontChoice == .google, let regular = settings.googleRegular {
            return .custom(regular, fixedSize: 54)
        }
        if settings.fontChoice == .appleMusic {
            return .system(size: 54, weight: .heavy, design: .default)
        }
        let face: LyricFace
        switch settings.fontChoice {
        case .serif: face = .serif
        case .slab: face = .slab
        case .soft: face = .soft
        case .sans, .auto, .google, .manrope, .appleMusic: face = .sans
        }
        return face.font(size: 54, hero: true)
    }

    private func shortTitle(_ choice: Settings.FontChoice) -> String {
        switch choice {
        case .manrope: return "Manrope"
        case .appleMusic: return "Apple Music"
        case .auto: return "Automatic"
        case .sans: return "Sans"
        case .serif: return "Serif"
        case .slab: return "Slab"
        case .soft: return "Soft"
        case .google: return "Google"
        }
    }
}

// MARK: - Background

/// The preview is the pane: it runs full-bleed across the top, with the
/// controls sitting beneath it.
struct BackgroundPane: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var licensing = LicenseManager.shared
    /// Previews measure from when they appeared. Passing absolute time
    /// instead freezes the shader: `timeIntervalSinceReferenceDate` is ~8e8,
    /// where a Float32 uniform steps in units of ~64 seconds, so a second of
    /// real time rounds away to nothing.
    @State private var started = Date()
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Flexible rather than fixed, so the preview claims the whole
            // page when the controls are collapsed.
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(alignment: .topLeading) { previewLabel }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ChipRow(
                        items: Settings.BackgroundMode.allCases,
                        title: \.title,
                        selection: $settings.backgroundMode
                    )
                    styleGrid
                    advanced
                }
                .padding(.horizontal, 34)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
            .frame(maxHeight: showAdvanced ? 330 : 210)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Verso.surface)
    }

    private var previewLabel: some View {
        HStack(spacing: 6) {
            Text(currentStyleName.uppercased())
                .font(AppFont.ui(10, .semibold))
                .tracking(1.1)
            if settings.effectiveBackgroundMode != settings.backgroundMode {
                // Power settings are overriding the choice; say so rather
                // than appearing to ignore it.
                Label("eased for power", systemImage: "battery.25")
                    .font(AppFont.ui(9.5))
                    .foregroundStyle(.orange)
            }
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 34)
        .padding(.top, 26)
    }

    private var preview: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(started)
            ZStack {
                switch settings.backgroundMode {
                case .shader:
                    ShaderBackgroundView(
                        style: previewShader, time: t, flow: t,
                        tintA: Color(hue: 0.74, saturation: 0.62, brightness: 0.85),
                        tintB: Color(hue: 0.55, saturation: 0.66, brightness: 0.72)
                    )
                case .pattern, .auto:
                    LinearGradient(
                        colors: [Color(hue: 0.72, saturation: 0.55, brightness: 0.45),
                                 Color(hue: 0.56, saturation: 0.60, brightness: 0.30)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    FractalBackgroundView(seed: 7, phase: t, style: previewPattern)
                case .colourOnly:
                    LinearGradient(
                        colors: [Color(hue: 0.74, saturation: 0.60, brightness: 0.55),
                                 Color(hue: 0.55, saturation: 0.62, brightness: 0.33)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            }
        }
    }

    /// Styles as a wrapping grid of names, so the whole set is visible at
    /// once rather than hidden inside a menu.
    @ViewBuilder
    private var styleGrid: some View {
        switch settings.backgroundMode {
        case .shader:
            styleWrap(
                names: [("Match the music", nil)] + ShaderStyle.allCases.map { ($0.title, $0) },
                isSelected: { $0 == settings.shaderStyle },
                locked: { _ in false },
                select: { settings.shaderStyle = $0 }
            )
        case .pattern:
            styleWrap(
                names: [("Match the music", nil)] + BackgroundStyle.allCases.map { ($0.title, $0) },
                isSelected: { $0 == settings.patternStyle },
                locked: { _ in false },
                select: { settings.patternStyle = $0 }
            )
        case .auto, .colourOnly:
            Text(settings.backgroundMode == .auto
                 ? "The track's genre and pace choose the look."
                 : "Just the colour field, drawn from the artwork.")
                .font(AppFont.ui(12))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    /// Every knob here feeds the live preview above, so the effect of a
    /// change is visible while dragging.
    @ViewBuilder
    private var advanced: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 13) {
                knob("Speed", "How fast everything moves.",
                     value: $settings.effectSpeed, range: 0.25...2.5, format: multiplier)
                knob("Beat response", "How hard the music pushes the visuals. Zero leaves them ambient.",
                     value: $settings.beatResponse, range: 0...2, format: multiplier)
                knob("Pattern strength", "Weight of the line layer over the colour.",
                     value: $settings.patternOpacity, range: 0...1, format: percent)
                knob("Backdrop shade", "Darkening behind the lyrics. Lower is bolder, harder to read.",
                     value: $settings.scrimStrength, range: 0...1.6, format: percent)
                knob("Colour vividness", "Saturation of the palette taken from the artwork.",
                     value: $settings.vividness, range: 0.3...1.8, format: multiplier)
                knob("Cover softening", "Blur on Apple Music animated covers.",
                     value: $settings.motionBlur, range: 0...24, format: points)

                if !settings.advancedIsDefault {
                    Button("Reset to defaults") { settings.resetAdvanced() }
                        .buttonStyle(.plain)
                        .font(AppFont.ui(11))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 2)
                }
            }
            .padding(.top, 12)
        } label: {
            Text("Advanced")
                .font(AppFont.ui(12, .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.top, 6)
    }

    private func knob(
        _ title: String, _ detail: String,
        value: Binding<Double>, range: ClosedRange<Double>,
        format: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(AppFont.ui(11.5, .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(format(value.wrappedValue))
                    .font(AppFont.ui(10.5).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
            Slider(value: value, in: range).controlSize(.mini)
            Text(detail)
                .font(AppFont.ui(10))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func multiplier(_ v: Double) -> String { String(format: "%.2f×", v) }
    private func percent(_ v: Double) -> String { "\(Int(v * 100))%" }
    private func points(_ v: Double) -> String { "\(Int(v)) pt" }

    private var currentStyleName: String {
        switch settings.backgroundMode {
        case .shader: return previewShader.title
        case .pattern, .auto: return previewPattern.title
        case .colourOnly: return "Colour"
        }
    }

    private var previewShader: ShaderStyle {
        if let chosen = settings.shaderStyle, licensing.isPro || !chosen.isPro { return chosen }
        return licensing.isPro ? .nebula : .aurora
    }

    private var previewPattern: BackgroundStyle {
        settings.patternStyle ?? .constellation
    }
}

// MARK: - Behaviour

struct BehaviourPane: View {
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        ScrollView {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Verso.surface)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 26) {
            PaneHeader(
                title: "Behaviour",
                subtitle: "How hard to work, and what to show when a track has no words."
            )

            setting("Launch at login", "Start Verso when you sign in to this Mac.") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                    if let error = settings.launchAtLoginError {
                        Text(error)
                            .font(AppFont.ui(10.5))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider().opacity(0.15)

            setting("Low Power Mode", "Swap GPU effects for line patterns, which cost far less.") {
                Toggle("", isOn: $settings.respectLowPower)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }

            Divider().opacity(0.15)

            setting("On battery", "How hard to work when unplugged.") {
                ChipRow(
                    items: Settings.PowerBehaviour.allCases,
                    title: \.title,
                    selection: $settings.onBattery
                )
            }

            Divider().opacity(0.15)

            setting("When no lyrics", "Instrumentals, or tracks no source carries.") {
                ChipRow(
                    items: Settings.NoLyricsBehaviour.allCases,
                    title: \.title,
                    selection: $settings.noLyrics
                )
            }

            Divider().opacity(0.15)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    settingLabel("Lyric size", "Relative to the width of your display.")
                    Spacer()
                    Text("\(Int(settings.lyricScale * 100))%")
                        .font(AppFont.ui(12, .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                }
                Slider(value: $settings.lyricScale, in: 0.7...1.5)
                    .controlSize(.small)
                    .frame(maxWidth: 340)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func setting<Content: View>(
        _ title: String, _ detail: String, @ViewBuilder control: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            settingLabel(title, detail)
            control()
        }
    }

    private func settingLabel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppFont.ui(13, .medium))
                .foregroundStyle(.white)
            Text(detail)
                .font(AppFont.ui(11.5))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

// MARK: - Licence

struct LicensePane: View {
    @ObservedObject private var licensing = LicenseManager.shared
    @State private var entry = ""
    @State private var errorText: String?

    /// The same list either way -- framed as what you have, or what you are
    /// missing -- so the difference between the tiers is never ambiguous.
    private let proFeatures: [(String, String, String)] = [
        ("cube.transparent", "8 advanced GPU effects",
         "Kaleidoscope, Fractal, Liquid, Caustics, Nebula, Voronoi, Orbs and Silk."),
        ("play.rectangle.on.rectangle", "Apple Music animated covers",
         "Albums with motion artwork play it full-screen behind the lyrics."),
        ("slider.horizontal.3", "Advanced background controls",
         "Speed, beat response, vividness and shade, tuned to taste."),
        ("infinity", "Every future update",
         "One key, no subscription, no account."),
    ]

    private let freeFeatures: [(String, String)] = [
        ("Word-by-word synced lyrics", "From Apple, NetEase and LRCLIB."),
        ("All 18 line patterns", "Low-poly, constellation, flow field and the rest."),
        ("Three GPU effects", "Plasma, Aurora and Marble."),
        ("Any Google font", "56 curated families, or type any name."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if licensing.isPro { unlocked } else { locked }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Verso.surface)
    }

    // MARK: - Licensed

    private var unlocked: some View {
        VStack(alignment: .leading, spacing: 24) {
            PaneHeader(
                title: "You're on Pro",
                subtitle: licenceSummary
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("EVERYTHING YOU HAVE")
                    .font(AppFont.ui(10, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 8)

                ForEach(Array(proFeatures.enumerated()), id: \.offset) { _, item in
                    featureRow(item.0, item.1, item.2, held: true)
                }
                ForEach(Array(freeFeatures.enumerated()), id: \.offset) { _, item in
                    featureRow("checkmark", item.0, item.1, held: true)
                }
            }

            Button("Remove licence from this Mac") {
                licensing.deactivate()
                entry = ""
            }
            .buttonStyle(.plain)
            .font(AppFont.ui(11.5))
            .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var licenceSummary: String {
        guard let license = licensing.license else { return "" }
        return license.isLifetime
            ? "Lifetime licence, activated \(license.issued.formatted(date: .abbreviated, time: .omitted))."
            : "Valid until \(license.expiry.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—")."
    }

    // MARK: - Free

    private var locked: some View {
        VStack(alignment: .leading, spacing: 24) {
            PaneHeader(
                title: "Free forever.\nPro goes further.",
                subtitle: "Everything below is what a licence adds — nothing you already use is taken away."
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("WHAT YOU'RE MISSING")
                    .font(AppFont.ui(10, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 8)

                ForEach(Array(proFeatures.enumerated()), id: \.offset) { _, item in
                    featureRow(item.0, item.1, item.2, held: false)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("WHAT YOU ALREADY HAVE")
                    .font(AppFont.ui(10, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 8)

                ForEach(Array(freeFeatures.enumerated()), id: \.offset) { _, item in
                    featureRow("checkmark", item.0, item.1, held: true)
                }
            }

            keyField
        }
    }

    private func featureRow(_ symbol: String, _ title: String, _ detail: String, held: Bool) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: held ? "checkmark.circle.fill" : symbol)
                .font(AppFont.ui(13))
                .foregroundStyle(held ? Color.green.opacity(0.85) : .white.opacity(0.4))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppFont.ui(12.5, .medium))
                    .foregroundStyle(held ? .white : .white.opacity(0.75))
                Text(detail)
                    .font(AppFont.ui(11))
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Have a key?")
                .font(AppFont.ui(12, .medium))
                .foregroundStyle(.white.opacity(0.8))

            TextEditor(text: $entry)
                .font(.system(size: 10.5, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(7)
                .frame(maxWidth: 460)
                .frame(height: 74)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.1)))

            HStack(spacing: 12) {
                Button {
                    switch licensing.activate(entry) {
                    case .success: errorText = nil
                    case .failure(let error): errorText = error.localizedDescription
                    }
                } label: {
                    Text("Activate")
                        .font(AppFont.ui(12, .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(.white))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .disabled(entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(AppFont.ui(11))
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// A wrapping row of name chips, shared by the panes that offer a set of
/// named choices. `locked` defaults to nothing being locked, which is what
/// every caller wants while the paywall is disarmed.
@ViewBuilder
fileprivate func styleWrap<T: Equatable>(
    names: [(String, T?)],
    isSelected: @escaping (T?) -> Bool,
    locked: @escaping (T?) -> Bool = { _ in false },
    select: @escaping (T?) -> Void
) -> some View {
    FlowLayout(spacing: 6, lineSpacing: 6, rowAlignment: .leading) {
        ForEach(Array(names.enumerated()), id: \.offset) { _, entry in
            let (title, value) = entry
            let selected = isSelected(value)
            let isLocked = locked(value)
            Button { select(value) } label: {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                    if isLocked {
                        Image(systemName: "lock.fill").font(AppFont.ui(8))
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5.5)
                .background(Capsule().fill(selected ? .white : .white.opacity(0.09)))
                .foregroundStyle(selected ? .black : .white.opacity(isLocked ? 0.4 : 0.75))
            }
            .buttonStyle(.plain)
        }
    }
}
