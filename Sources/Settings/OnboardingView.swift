import AVFoundation
import AppKit
import SwiftUI

/// First run, played rather than read.
///
/// There is no form here and nothing to configure. A voice introduces the app
/// while its own lyric engine sets the words on screen, over its own effects,
/// with its own word-by-word timing. By the end you have watched Verso do the
/// thing it does, which is a better introduction than a page describing it.
///
/// Everything the old walkthrough asked for -- typeface, background, licence --
/// already defaults to *match the music*, so there was nothing here worth
/// stopping a first-time user to ask.
struct OnboardingView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var narrator = Narrator()
    /// Relative, not absolute -- a Float32 shader uniform loses all precision
    /// at `timeIntervalSinceReferenceDate` scale and the effect freezes.
    @State private var started = Date()
    @State private var finished = false
    @State private var currentBackground: Narration.Backdrop = .shader(.aurora)
    @State private var previousBackground: Narration.Backdrop?
    @State private var backgroundChangedAt = Date.distantPast

    private static let backgroundFade: TimeInterval = 1.1
    var onFinish: () -> Void

    private var lines: [Narration.Line] { narrator.lines }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(started)
            // The recording is the clock when there is one, so the words track
            // the voice even if a frame is dropped or the audio starts late.
            let t = narrator.isPlaying ? narrator.currentTime : elapsed
            let line = lines.last { t >= $0.start - 0.45 }
            let ending = t > (lines.last?.end ?? 0) + 4.6

            ZStack {
                background(elapsed: elapsed)

                if let line, !ending {
                    LyricLineView(
                        words: Narration.words(in: line),
                        time: t,
                        baseSize: 40,
                        mood: mood(for: line),
                        composition: line.composition,
                        seed: index(of: line),
                        presence: presence(of: line, at: t)
                    )
                    .opacity(presence(of: line, at: t))
                    .padding(.horizontal, 56)
                    .id(index(of: line))
                }

                controls(at: t)
            }
            .onChange(of: ending) { _, done in
                if done { complete(after: 0.5) }
            }
            .onChange(of: line?.backdrop) { _, next in
                guard let next, next != currentBackground else { return }
                previousBackground = currentBackground
                currentBackground = next
                backgroundChangedAt = Date()
            }
        }
        .frame(width: 940, height: 600)
        .background(.black)
        .colorScheme(.dark)
        .onAppear { narrator.start() }
        .onDisappear { narrator.stop() }
    }

    // MARK: - Background

    /// Crossfades from a timestamp rather than a SwiftUI transition.
    ///
    /// `TimelineView(.animation)` rebuilds this view every frame and discards
    /// transition state along the way, so `.transition(.opacity)` never got to
    /// run and each change landed as a hard cut. Holding the outgoing style
    /// alive and fading between the two by hand is what actually works here --
    /// the same approach the wallpaper uses for the same reason.
    @ViewBuilder
    private func background(elapsed: TimeInterval) -> some View {
        let fade = Easing.smoothstep(
            Date().timeIntervalSince(backgroundChangedAt) / Self.backgroundFade
        )
        ZStack {
            if let outgoing = previousBackground, fade < 1 {
                effect(outgoing, elapsed: elapsed).opacity(1 - fade)
            }
            effect(currentBackground, elapsed: elapsed)
                .opacity(previousBackground == nil ? 1 : fade)
        }
        .overlay(Color.black.opacity(0.20))
        .ignoresSafeArea()
    }

    /// Draws whichever of the three kinds a cue asked for. The walkthrough
    /// moves through all of them so the choice Verso offers is shown rather
    /// than described.
    @ViewBuilder
    private func effect(_ backdrop: Narration.Backdrop, elapsed: TimeInterval) -> some View {
        switch backdrop {
        case .shader(let style):
            ShaderBackgroundView(
                style: style,
                time: elapsed, flow: elapsed,
                tintA: Color(hue: 0.74, saturation: 0.55, brightness: 0.80),
                tintB: Color(hue: 0.88, saturation: 0.40, brightness: 0.42)
            )
        case .pattern(let style):
            ZStack {
                AnimatedGradientView(palette: Self.palette, time: elapsed * 0.5)
                FractalBackgroundView(seed: 7, phase: elapsed, style: style)
            }
        case .colourOnly:
            AnimatedGradientView(palette: Self.palette, time: elapsed * 0.5)
        case .library:
            // The grid *is* the background here -- no effect behind it, since
            // forty-three tiles over a running shader is two animations
            // competing. The heavier scrim is what keeps the line readable
            // over something this busy.
            ZStack {
                Color.black
                EffectLibraryGrid(time: elapsed)
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 66)
                Color.black.opacity(0.34)
            }
        }
    }

    /// Fixed, so the walkthrough holds one colour identity across all three
    /// background kinds. Hue, saturation, brightness.
    private static let palette: [SIMD3<Double>] = [
        SIMD3(0.74, 0.58, 0.82),
        SIMD3(0.80, 0.50, 0.66),
        SIMD3(0.88, 0.44, 0.50),
        SIMD3(0.68, 0.52, 0.60),
    ]

    private func mood(for line: Narration.Line) -> TrackMood {
        TrackMood(energy: 0.5, face: settings.face(for: .neutral),
                  background: .constellation, motionRate: 1, intensity: 1, organic: 0.6)
    }

    private func index(of line: Narration.Line) -> Int {
        lines.firstIndex { $0.start == line.start } ?? 0
    }

    /// Fades a line in as it starts and out as the next one arrives.
    ///
    /// The closing line is held far longer and faded far slower: nothing
    /// follows it, so there is no reason to clear it quickly, and letting
    /// "Welcome to Verso." sit for a moment is what makes the walkthrough end
    /// rather than simply stop.
    private func presence(of line: Narration.Line, at t: TimeInterval) -> Double {
        let isLast = index(of: line) == lines.count - 1
        let appear = Easing.smoothstep((t - (line.start - 0.35)) / 0.45)
        let hold: TimeInterval = isLast ? 2.6 : 0.30
        let fade: TimeInterval = isLast ? 1.9 : 0.55
        let leave = 1 - Easing.smoothstep((t - (line.end + hold)) / fade)
        return min(appear, max(leave, 0))
    }

    // MARK: - Chrome

    @ViewBuilder
    private func controls(at t: TimeInterval) -> some View {
        VStack {
            // A hairline of progress rather than a counter, so the walkthrough
            // has a visible end without turning into a loading bar.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.10))
                    Rectangle().fill(.white.opacity(0.55))
                        .frame(width: geo.size.width * min(t / max(narrator.length, 1), 1))
                }
            }
            .frame(height: 2)

            Spacer()

            HStack {
                Button(narrator.isMuted ? "Sound on" : "Mute") {
                    narrator.toggleMute()
                }
                .buttonStyle(.plain)
                .font(AppFont.ui(12))
                .foregroundStyle(.white.opacity(0.45))

                Spacer()

                // Always available. A voiceover you cannot escape is a good way
                // to make someone quit an app thirty seconds after installing it.
                Button("Skip") { complete(after: 0) }
                    .buttonStyle(.plain)
                    .font(AppFont.ui(12.5, .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 22)
        }
    }

    private func complete(after delay: TimeInterval) {
        guard !finished else { return }
        finished = true
        narrator.stop()
        settings.hasOnboarded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { onFinish() }
    }
}

// MARK: - Narrator

/// Plays the voiceover and reports where it is.
///
/// The recording is optional on purpose. If `onboarding.m4a` is absent the
/// walkthrough still runs, silently, on its written timings -- so a build
/// without the audio is degraded rather than broken, and the visuals can be
/// worked on without waiting for a recording.
@Observable
final class Narrator {
    private var player: AVAudioPlayer?
    private(set) var lines: [Narration.Line] = Narration.script
    private(set) var isMuted = false

    var isPlaying: Bool { player?.isPlaying ?? false }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var length: TimeInterval { player?.duration ?? Narration.length }

    func start() {
        guard let url = Bundle.main.url(forResource: "onboarding", withExtension: "m4a")
                     ?? Bundle.main.url(forResource: "onboarding", withExtension: "mp3")
        else { return }

        player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        // The script's written timings are an estimate; the recording is the
        // truth. Rescaling to its real length keeps the words on the voice.
        if let duration = player?.duration, duration > 1 {
            lines = Narration.retimed(toDuration: duration)
        }
        player?.play()
    }

    func toggleMute() {
        isMuted.toggle()
        player?.volume = isMuted ? 0 : 1
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

/// Presents the onboarding as a standalone window, since this is an accessory
/// app with no ordinary window of its own.
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func presentIfNeeded() {
        guard !Settings.shared.hasOnboarded else { return }
        present()
    }

    func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Regular for the duration, so the walkthrough can take focus and play
        // sound as a foreground app rather than an accessory nobody activated.
        NSApp.setActivationPolicy(.regular)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        // Created in code, so it would otherwise be released on close while
        // this controller still holds it -- an over-release crash.
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: OnboardingView { [weak self] in self?.close() })
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func close() {
        // Deferred: called from inside this window's own hosting view, so
        // tearing it down synchronously would free it mid-event.
        DispatchQueue.main.async { [weak self] in
            self?.window?.orderOut(nil)
            self?.window?.contentView = nil
            self?.window = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
