import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @ObservedObject private var lyricsVM = LyricsViewModel.shared
    @ObservedObject private var hover = HoverState.shared
    @ObservedObject private var settings = Settings.shared
    @State private var palette: [SIMD3<Double>] = ColorExtractor.fallbackHSBPalette
    @State private var currentLayer: BackgroundLayer = .generated(pattern: nil)
    @State private var previousLayer: BackgroundLayer?
    @State private var layerChangedAt = Date.distantPast

    private static let backgroundFadeDuration: TimeInterval = 0.75
    /// How long the "no lyrics" notice stays up, and how long it takes to go.
    private static let noticeHoldDuration: TimeInterval = 4.0
    private static let noticeFadeDuration: TimeInterval = 1.0
    private static let idleHoldDuration: TimeInterval = 5.0

    /// What the background should be right now. Changing any input -- the
    /// album gaining motion art, a settings change, the track's mood -- makes
    /// this differ from `currentLayer` and starts a crossfade.
    enum BackgroundLayer: Equatable {
        case motion(URL)
        case shader(ShaderStyle)
        /// `nil` pattern means colour field only.
        case generated(pattern: BackgroundStyle?)
    }

    private var desiredLayer: BackgroundLayer {
        if let motion = nowPlaying.motionArtwork, settings.motionArtworkEnabled {
            return .motion(motion.square)
        }
        let mood = self.mood
        let mode = settings.effectiveBackgroundMode
        if mode == .shader || (mode == .auto && mood.energy > 0.72) {
            return .shader(settings.resolvedShader(for: mood, seed: trackSeed))
        }
        if mode == .colourOnly { return .generated(pattern: nil) }
        return .generated(pattern: settings.resolvedPattern(for: mood))
    }

    private var trackSeed: Int {
        let key = (nowPlaying.current?.title ?? "") + (nowPlaying.current?.artist ?? "")
        var value: UInt64 = 1469598103934665603
        for byte in key.utf8 {
            value = (value ^ UInt64(byte)) &* 1099511628211
        }
        return Int(value % 100_000)
    }

    private var artworkSaturation: Double {
        guard !palette.isEmpty else { return 0.5 }
        return palette.map(\.y).reduce(0, +) / Double(palette.count)
    }

    private var mood: TrackMood {
        TrackMood.derive(
            genre: nowPlaying.current?.genre,
            wordsPerSecond: lyricsVM.wordsPerSecond,
            artworkSaturation: artworkSaturation,
            seed: trackSeed
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let baseSize = min(max(geometry.size.width * 0.046, 38), 124) * settings.lyricScale
            let mood = self.mood

            // One timeline drives the gradient, the pattern and the lyrics so
            // they share a frame clock instead of each running their own.
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let playbackTime = nowPlaying.playbackTime()

                // The pattern layer runs at a fixed rate and takes no input
                // from the music; the musical response lives in the colour
                // field, where beats swell the blobs.
                let speed = settings.effectSpeed
                let patternPhase = VisualClock.pattern.advance(to: now, rate: speed)
                let colourPhase = VisualClock.gradient.advance(to: now, rate: speed)
                // Beat response scales the envelope, so 0 leaves the visuals
                // purely ambient without disabling the animation itself.
                let raw = lyricsVM.dynamics.reactivity(at: playbackTime)
                let reactivity = MusicDynamics.Reactivity(
                    swell: raw.swell * settings.beatResponse,
                    pulse: raw.pulse * settings.beatResponse
                )
                // Beats lean on the fluid rather than kicking it. The range
                // is narrow on purpose -- at the old 3.7x the effect visibly
                // lunged on every hit -- and `VisualClock` eases the rate
                // toward this target over a couple of seconds, so the change
                // arrives as a gathering rather than a jolt.
                let flowPhase = VisualClock.flow.advance(
                    to: now,
                    rate: speed * (1.0 + 0.34 * reactivity.pulse + 0.22 * reactivity.swell)
                )

                // Background switches are crossfaded from a timestamp
                // rather than a SwiftUI transition: this view is rebuilt
                // every frame by TimelineView, which discards transition
                // state, so a `.transition` here would simply cut.
                let fade = Easing.smoothstep(
                    Date().timeIntervalSince(layerChangedAt) / Self.backgroundFadeDuration
                )

                ZStack {
                    // `compositingGroup` flattens each layer with its own
                    // scrim before the fade opacity is applied; without it
                    // the two scrims blend through each other and the screen
                    // visibly lightens mid-transition.
                    if let outgoing = previousLayer, fade < 1 {
                        backgroundLayer(
                            outgoing, colourPhase: colourPhase, patternPhase: patternPhase,
                            flowPhase: flowPhase, reactivity: reactivity, size: geometry.size
                        )
                        .compositingGroup()
                        .opacity(1 - fade)
                    }

                    backgroundLayer(
                        currentLayer, colourPhase: colourPhase, patternPhase: patternPhase,
                        flowPhase: flowPhase, reactivity: reactivity, size: geometry.size
                    )
                    .compositingGroup()
                    .opacity(previousLayer == nil ? 1 : fade)

                    lyricsSection(
                        time: playbackTime,
                        baseSize: baseSize,
                        maxWidth: geometry.size.width * 0.80,
                        mood: mood
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
                    .blur(radius: hover.isActive ? 22 : 0)
                    .opacity(hover.isActive ? 0.3 : 1)
                    .animation(.easeOut(duration: 0.3), value: hover.isActive)
                }
            }
        }
        .onChange(of: nowPlaying.artwork) { _, artwork in updatePalette(artwork) }
        .onChange(of: desiredLayer) { previous, next in
            // Hold the old layer alive just long enough to fade it out.
            previousLayer = previous
            currentLayer = next
            layerChangedAt = Date()
        }
        .onAppear {
            updatePalette(nowPlaying.artwork)
            currentLayer = desiredLayer
        }
    }

    /// Renders one background layer. Each carries its own scrim so the two
    /// sides of a crossfade stay legible throughout the blend.
    @ViewBuilder
    private func backgroundLayer(
        _ layer: BackgroundLayer, colourPhase: Double, patternPhase: Double,
        flowPhase: Double, reactivity: MusicDynamics.Reactivity, size: CGSize
    ) -> some View {
        switch layer {
        case .motion(let url):
            ZStack {
                // The album brought its own art direction, so nothing of ours
                // is drawn over it -- just enough softening and shade that
                // the words stay readable on a bright frame.
                MotionArtworkView(url: url)
                    .ignoresSafeArea()
                    // Only softened enough to stop fine detail fighting the
                    // type -- the footage should still be recognisable.
                    .blur(radius: settings.motionBlur)
                    // A fixed overscan, purely to keep the blur from showing
                    // the frame edge. It used to breathe with the beat; that
                    // twitched the whole picture on every hit.
                    .scaleEffect(1.04)
                Color.black.opacity(0.40 * settings.scrimStrength).ignoresSafeArea()
                RadialGradient(
                    colors: [.black.opacity(0.5), .black.opacity(0.16), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.55
                )
                .ignoresSafeArea()
            }

        case .shader(let style):
            ZStack {
                ShaderBackgroundView(
                    style: style,
                    time: colourPhase,
                    flow: flowPhase,
                    tintA: paletteColour(0),
                    tintB: paletteColour(4),
                    reactivity: reactivity
                )
                scrim
            }

        case .generated(let pattern):
            ZStack {
                AnimatedGradientView(
                    palette: palette,
                    time: colourPhase,
                    reactivity: reactivity
                )
                if let pattern {
                    FractalBackgroundView(
                        seed: trackSeed,
                        phase: patternPhase,
                        style: pattern
                    )
                    .opacity(settings.patternOpacity)
                }
                scrim
            }
        }
    }

    private var scrim: some View {
        let strength = settings.scrimStrength
        return LinearGradient(
            colors: [
                .black.opacity(0.34 * strength),
                .black.opacity(0.12 * strength),
                .black.opacity(0.50 * strength),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func paletteColour(_ index: Int) -> Color {
        guard palette.indices.contains(index) else { return .purple }
        let hsb = palette[index]
        return Color(
            hue: hsb.x,
            saturation: min(hsb.y * 1.2 * settings.vividness, 1),
            brightness: min(hsb.z * 1.15 + 0.1, 1)
        )
    }

    private func updatePalette(_ artwork: NSImage?) {
        guard let artwork else {
            withAnimation(.easeInOut(duration: 0.9)) {
                palette = ColorExtractor.fallbackHSBPalette
            }
            return
        }
        Task.detached(priority: .userInitiated) {
            let extracted = ColorExtractor.extractPalette(from: artwork)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.9)) {
                    self.palette = extracted
                }
                DesktopWallpaperController.shared.currentPalette = extracted
            }
        }
    }

    @ViewBuilder
    private func lyricsSection(time: TimeInterval, baseSize: CGFloat, maxWidth: CGFloat, mood: TrackMood) -> some View {
        if nowPlaying.current == nil {
            // Say so, then leave the background to itself rather than
            // parking a notice on the desktop for hours.
            if let since = nowPlaying.idleSince {
                let age = Date().timeIntervalSince(since)
                let presence = 1 - Easing.smoothstep(
                    (age - Self.idleHoldDuration) / Self.noticeFadeDuration
                )
                if presence > 0.01 {
                    placeholder("Nothing playing", size: baseSize * 0.42)
                        .opacity(presence)
                }
            }
        } else if lyricsVM.isLoading {
            ProgressView().controlSize(.large).tint(.white)
        } else if !lyricsVM.plainLines.isEmpty {
            // No timed source has this track, so the words are shown as a
            // static block instead of nothing at all.
            plainLyrics(baseSize: baseSize, maxWidth: maxWidth, mood: mood)
        } else if lyricsVM.notFound || lyricsVM.lines.isEmpty {
            // Say so briefly, then get out of the way -- an instrumental
            // should not carry a permanent error notice on the wallpaper.
            switch settings.noLyrics {
            case .nothing:
                Color.clear
            case .trackName:
                VStack(spacing: baseSize * 0.12) {
                    Text(nowPlaying.current?.title ?? "")
                        .font(settings.lyricFont(size: baseSize * 0.5, hero: true, mood: mood))
                    Text(nowPlaying.current?.artist ?? "")
                        .font(settings.uiFont(size: baseSize * 0.26, mood: mood))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 2)
            case .notice:
                if let reportedAt = lyricsVM.notFoundAt {
                    let age = Date().timeIntervalSince(reportedAt)
                    let presence = 1 - Easing.smoothstep(
                        (age - Self.noticeHoldDuration) / Self.noticeFadeDuration
                    )
                    if presence > 0.01 {
                        placeholder("No lyrics found", size: baseSize * 0.34)
                            .opacity(presence)
                    }
                }
            }
        } else {
            currentLine(time: time, baseSize: baseSize, maxWidth: maxWidth, mood: mood)
        }
    }

    private func plainLyrics(baseSize: CGFloat, maxWidth: CGFloat, mood: TrackMood) -> some View {
        VStack(spacing: baseSize * 0.10) {
            ForEach(Array(lyricsVM.plainLines.prefix(14).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(settings.lyricFont(size: baseSize * 0.26, hero: false, mood: mood))
                    .foregroundStyle(.white.opacity(line.isEmpty ? 0 : 0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: maxWidth)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }

    /// Only the line being sung is shown -- no previous/next context.
    @ViewBuilder
    private func currentLine(time: TimeInterval, baseSize: CGFloat, maxWidth: CGFloat, mood: TrackMood) -> some View {
        let lines = lyricsVM.lines
        let index = lyricsVM.activeLineIndex(at: time) ?? 0

        if lines.indices.contains(index), !lines[index].words.isEmpty {
            // The fade is computed from playback time rather than a SwiftUI
            // transition: this view is rebuilt every frame by TimelineView,
            // which discards transition state and made line changes snap.
            let line = lines[index]
            let appear = Easing.smoothstep((time - line.start) / 0.26)
            let fadeOut = 1 - Easing.smoothstep((time - (line.end - 0.18)) / 0.18)
            let presence = min(appear, max(fadeOut, 0))

            LyricLineView(
                words: line.words,
                time: time,
                baseSize: baseSize,
                mood: mood,
                composition: settings.resolvedComposition(for: mood, seed: index),
                seed: index,
                presence: presence
            )
            .frame(maxWidth: maxWidth)
            .opacity(presence)
            .scaleEffect(0.985 + 0.015 * presence)
            .offset(y: (1 - appear) * 12)
        } else {
            Color.clear
        }
    }

    private func placeholder(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(settings.uiFont(size: size, mood: mood))
            .foregroundStyle(.white.opacity(0.5))
    }
}
