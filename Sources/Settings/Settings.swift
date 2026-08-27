import ServiceManagement
import SwiftUI

/// User preferences, persisted to `UserDefaults` and read live by the
/// wallpaper. Everything defaults to `auto`, where the track's own genre and
/// cadence choose for you; each can be pinned instead.
@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    enum FontChoice: String, CaseIterable, Identifiable {
        case manrope, auto, sans, serif, slab, soft, google
        var id: String { rawValue }

        var title: String {
            switch self {
            case .manrope: return "Manrope"
            case .auto: return "Match the music"
            case .sans: return "Sans — Avenir Next"
            case .serif: return "Serif — Charter"
            case .slab: return "Slab — Rockwell"
            case .soft: return "Soft — SF Rounded"
            case .google: return "Google Font…"
            }
        }
    }

    /// What to fall back to when the GPU should be spared.
    enum PowerBehaviour: String, CaseIterable, Identifiable {
        case full, lightEffects, patterns, colourOnly
        var id: String { rawValue }

        var title: String {
            switch self {
            case .full: return "Keep full effects"
            case .lightEffects: return "Only inexpensive effects"
            case .patterns: return "Drop to line patterns"
            case .colourOnly: return "Colour only"
            }
        }
    }

    /// What to show once a track turns out to have no lyrics.
    enum NoLyricsBehaviour: String, CaseIterable, Identifiable {
        case notice, trackName, nothing
        var id: String { rawValue }

        var title: String {
            switch self {
            case .notice: return "Say so briefly"
            case .trackName: return "Show title and artist"
            case .nothing: return "Show nothing"
            }
        }
    }

    enum BackgroundMode: String, CaseIterable, Identifiable {
        case auto, pattern, shader, colourOnly
        var id: String { rawValue }

        var title: String {
            switch self {
            case .auto: return "Match the music"
            case .pattern: return "Line patterns"
            case .shader: return "GPU effects"
            case .colourOnly: return "Colour only"
            }
        }
    }

    @Published var fontChoice: FontChoice { didSet { store(fontChoice.rawValue, "fontChoice") } }
    @Published var googleFontFamily: String { didSet { store(googleFontFamily, "googleFontFamily") } }
    @Published var backgroundMode: BackgroundMode { didSet { store(backgroundMode.rawValue, "backgroundMode") } }
    /// `nil` means let the track pick within the mode.
    @Published var patternStyle: BackgroundStyle? { didSet { store(patternStyle?.rawValue, "patternStyle") } }
    @Published var shaderStyle: ShaderStyle? { didSet { store(shaderStyle?.rawValue, "shaderStyle") } }
    @Published var useMotionArtwork: Bool { didSet { store(useMotionArtwork, "useMotionArtwork") } }
    /// `nil` means let the track pick.
    @Published var lyricComposition: LyricComposition? { didSet { store(lyricComposition?.rawValue, "lyricComposition") } }
    /// How far Constellation throws its words apart.
    @Published var constellationSpread: Double { didSet { store(constellationSpread, "constellationSpread") } }
    /// How present Echo's repeats are.
    @Published var echoStrength: Double { didSet { store(echoStrength, "echoStrength") } }
    @Published var lyricScale: Double { didSet { store(lyricScale, "lyricScale") } }
    @Published var hasOnboarded: Bool { didSet { store(hasOnboarded, "hasOnboarded") } }
    /// Honour macOS Low Power Mode by easing off the GPU.
    @Published var respectLowPower: Bool { didSet { store(respectLowPower, "respectLowPower") } }
    @Published var onBattery: PowerBehaviour { didSet { store(onBattery.rawValue, "onBattery") } }
    @Published var noLyrics: NoLyricsBehaviour { didSet { store(noLyrics.rawValue, "noLyrics") } }
    /// Registered with the system rather than stored by us -- macOS is the
    /// source of truth, so the toggle reflects what it actually did.
    @Published var launchAtLogin: Bool { didSet { applyLaunchAtLogin() } }
    // Advanced: fine control over how the background is drawn.
    /// Multiplies every animation clock.
    @Published var effectSpeed: Double { didSet { store(effectSpeed, "effectSpeed") } }
    /// Scales how hard beats push the visuals. 0 leaves them ambient.
    @Published var beatResponse: Double { didSet { store(beatResponse, "beatResponse") } }
    /// Strength of the line-pattern layer over the colour field.
    @Published var patternOpacity: Double { didSet { store(patternOpacity, "patternOpacity") } }
    /// How much the backdrop is darkened to keep lyrics readable.
    @Published var scrimStrength: Double { didSet { store(scrimStrength, "scrimStrength") } }
    /// Saturation applied to colours sampled from the artwork.
    @Published var vividness: Double { didSet { store(vividness, "vividness") } }
    /// Softening applied to Apple Music animated covers.
    @Published var motionBlur: Double { didSet { store(motionBlur, "motionBlur") } }

    /// PostScript names of the downloaded Google font, once registered.
    @Published private(set) var googleRegular: String?
    @Published private(set) var googleBold: String?
    @Published private(set) var googleStatus: String?

    private let defaults = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard
        fontChoice = FontChoice(rawValue: d.string(forKey: "fontChoice") ?? "") ?? .manrope
        googleFontFamily = d.string(forKey: "googleFontFamily") ?? ""
        backgroundMode = BackgroundMode(rawValue: d.string(forKey: "backgroundMode") ?? "") ?? .auto
        patternStyle = (d.object(forKey: "patternStyle") as? Int).flatMap(BackgroundStyle.init(rawValue:))
        shaderStyle = (d.string(forKey: "shaderStyle")).flatMap(ShaderStyle.init(rawValue:))
        useMotionArtwork = d.object(forKey: "useMotionArtwork") as? Bool ?? true
        lyricComposition = (d.string(forKey: "lyricComposition")).flatMap(LyricComposition.init(rawValue:))
        constellationSpread = d.object(forKey: "constellationSpread") as? Double ?? 1.0
        echoStrength = d.object(forKey: "echoStrength") as? Double ?? 1.0
        lyricScale = d.object(forKey: "lyricScale") as? Double ?? 1.0
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        respectLowPower = d.object(forKey: "respectLowPower") as? Bool ?? true
        onBattery = PowerBehaviour(rawValue: d.string(forKey: "onBattery") ?? "") ?? .full
        noLyrics = NoLyricsBehaviour(rawValue: d.string(forKey: "noLyrics") ?? "") ?? .notice
        launchAtLogin = SMAppService.mainApp.status == .enabled
        effectSpeed = d.object(forKey: "effectSpeed") as? Double ?? 1.0
        beatResponse = d.object(forKey: "beatResponse") as? Double ?? 1.0
        patternOpacity = d.object(forKey: "patternOpacity") as? Double ?? 0.85
        scrimStrength = d.object(forKey: "scrimStrength") as? Double ?? 1.0
        vividness = d.object(forKey: "vividness") as? Double ?? 1.0
        motionBlur = d.object(forKey: "motionBlur") as? Double ?? 5.0

        if fontChoice == .google, !googleFontFamily.isEmpty {
            Task { await loadGoogleFont(family: googleFontFamily) }
        }
    }

    private func store(_ value: Any?, _ key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    // MARK: - Resolution

    /// The face to set lyrics in, honouring an override or deferring to the
    /// track's own character.
    func face(for mood: TrackMood) -> LyricFace {
        switch fontChoice {
        case .manrope, .auto, .google: return mood.face
        case .sans: return .sans
        case .serif: return .serif
        case .slab: return .slab
        case .soft: return .soft
        }
    }

    /// Lyric type, preferring a downloaded Google font when one is active.
    func lyricFont(size: CGFloat, hero: Bool, mood: TrackMood) -> Font {
        // Manrope is the shipped default, fetched and registered like any
        // other Google family.
        if fontChoice == .manrope, let regular = AppFont.regular {
            return .custom(hero ? (AppFont.bold ?? regular) : regular, fixedSize: size)
        }
        if fontChoice == .google, let regular = googleRegular {
            return .custom(hero ? (googleBold ?? regular) : regular, fixedSize: size)
        }
        return face(for: mood).font(size: size, hero: hero)
    }

    func uiFont(size: CGFloat, bold: Bool = false, mood: TrackMood) -> Font {
        if fontChoice == .manrope, let regular = AppFont.regular {
            return .custom(bold ? (AppFont.bold ?? regular) : regular, fixedSize: size)
        }
        if fontChoice == .google, let regular = googleRegular {
            return .custom(bold ? (googleBold ?? regular) : regular, fixedSize: size)
        }
        return face(for: mood).uiFont(size: size, bold: bold)
    }

    /// Which pattern to draw, if the current mode uses one.
    func resolvedPattern(for mood: TrackMood) -> BackgroundStyle {
        patternStyle ?? mood.background
    }

    /// How to arrange a lyric line, honouring an override or letting the
    /// track choose.
    func resolvedComposition(for mood: TrackMood, seed: Int) -> LyricComposition {
        lyricComposition ?? LyricComposition.matching(mood, seed: seed)
    }

    /// Which GPU effect to run, if the current mode uses one. Calmer effects
    /// are chosen for low-energy tracks so type stays readable.
    func resolvedShader(for mood: TrackMood, seed: Int) -> ShaderStyle {
        let entitled = LicenseManager.shared.isPro
        let sparing = sparesGPU

        if let shaderStyle, entitled || !shaderStyle.isPro {
            // An explicit choice is honoured, except when the machine has
            // asked for restraint and the choice is one of the expensive
            // ones -- then it falls through to a cheap substitute.
            if !sparing || shaderStyle.cost != .heavy { return shaderStyle }
        }

        // Matched, not bucketed. The old version cut the library in half at
        // `energy > 0.6` and picked at random inside the half -- which meant
        // two tracks that genuinely sound alike had no reason to look alike,
        // and a track sitting near the boundary could swing between wildly
        // different looks on a rounding error. Now the track and every effect
        // are described on the same three axes and the nearest one wins.
        var pool = ShaderStyle.allCases
        if sparing {
            let affordable = pool.filter { $0.cost != .heavy }
            if !affordable.isEmpty { pool = affordable }
        }
        if !entitled {
            pool = pool.filter { !$0.isPro }
            if pool.isEmpty { pool = ShaderStyle.free }
        }

        return ShaderStyle.matching(mood.visualCharacter, seed: seed, from: pool)
    }

    /// Whether power conditions call for keeping the GPU load down, even
    /// where effects are still permitted at all.
    var sparesGPU: Bool {
        if respectLowPower, ProcessInfo.processInfo.isLowPowerModeEnabled { return true }
        if PowerSource.isOnBattery, onBattery != .full { return true }
        return false
    }

    /// The effective background mode once power conditions are taken into
    /// account -- GPU shaders are the expensive layer, so they are the first
    /// thing dropped on battery or in Low Power Mode.
    var effectiveBackgroundMode: BackgroundMode {
        let constrained: PowerBehaviour?
        if respectLowPower, ProcessInfo.processInfo.isLowPowerModeEnabled {
            constrained = .patterns
        } else if PowerSource.isOnBattery, onBattery != .full {
            constrained = onBattery
        } else {
            constrained = nil
        }

        guard let constrained else { return backgroundMode }
        switch constrained {
        case .full: return backgroundMode
        // Effects stay on; `resolvedShader` narrows them to the cheap ones.
        case .lightEffects: return backgroundMode
        case .patterns: return backgroundMode == .colourOnly ? .colourOnly : .pattern
        case .colourOnly: return .colourOnly
        }
    }

    /// Restores every advanced control to its shipped value.
    func resetAdvanced() {
        effectSpeed = 1.0
        beatResponse = 1.0
        patternOpacity = 0.85
        scrimStrength = 1.0
        vividness = 1.0
        motionBlur = 5.0
    }

    var advancedIsDefault: Bool {
        effectSpeed == 1.0 && beatResponse == 1.0 && patternOpacity == 0.85
            && scrimStrength == 1.0 && vividness == 1.0 && motionBlur == 5.0
    }

    /// Login items are managed by the system; if registration fails the
    /// toggle is put back so it never claims something untrue.
    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            launchAtLoginError = error.localizedDescription
            let actual = SMAppService.mainApp.status == .enabled
            if actual != launchAtLogin { launchAtLogin = actual }
        }
    }

    @Published var launchAtLoginError: String?

    /// Free for everyone. The paid tier covers our own work -- the advanced
    /// effects and controls -- not Apple's artwork.
    var motionArtworkEnabled: Bool { useMotionArtwork }

    // MARK: - Google Fonts

    func applyGoogleFont(family: String) {
        googleFontFamily = family
        fontChoice = .google
        Task { await loadGoogleFont(family: family) }
    }

    private func loadGoogleFont(family: String) async {
        let trimmed = family.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        googleStatus = "Downloading \(trimmed)…"

        guard let loaded = await GoogleFontsProvider.shared.font(family: trimmed) else {
            googleStatus = "Couldn't find \"\(trimmed)\" on Google Fonts"
            googleRegular = nil
            googleBold = nil
            return
        }
        googleRegular = loaded.regular
        googleBold = loaded.bold
        googleStatus = "Using \(trimmed)"
    }
}
