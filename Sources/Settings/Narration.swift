import Foundation

/// The first-run narration, and what the screen does under it.
///
/// The walkthrough is the product demonstrating itself: the spoken lines are
/// rendered by the same view that renders lyrics, over the same backgrounds,
/// with the same word-by-word timing. Nothing here is a mock-up of Verso -- it
/// *is* Verso, reading a script instead of a song.
enum Narration {
    /// What is drawn behind a line. The walkthrough moves through all three
    /// kinds Verso offers, because "which of these do you want" is the only
    /// real choice the app asks anyone to make.
    enum Backdrop: Equatable {
        case shader(ShaderStyle)
        case pattern(BackgroundStyle)
        case colourOnly
        /// The whole library at once; nothing else is drawn behind it.
        case library
    }

    struct Line {
        var text: String
        /// Seconds into the recording where this line begins.
        var start: TimeInterval
        /// How long it is spoken for.
        var duration: TimeInterval
        var backdrop: Backdrop
        var composition: LyricComposition = .scattered

        var end: TimeInterval { start + duration }
        var showsLibrary: Bool { backdrop == .library }
    }

    /// Measured from the shipped recording, not estimated.
    ///
    /// Every start and end below came from running the voiceover through
    /// silence detection and reading off where speech actually begins and
    /// ends. Twelve detected segments, twelve lines. That is worth more than
    /// a careful guess: a speaker's pauses are never uniform, and hand-timing
    /// against a waveform by ear is the sort of thing that ends up half a
    /// second out on the lines nobody re-checked.
    static let script: [Line] = [
        .init(text: "Hey! Thanks for downloading Verso.",
              start: 0.00, duration: 2.20, backdrop: .shader(.aurora)),

        .init(text: "Verso turns your desktop into the music you're playing.",
              start: 3.88, duration: 2.71, backdrop: .shader(.silk)),

        // Rings arrive one after another, which reads as pulse -- the right
        // thing behind a line about being in time.
        .init(text: "Every word, in time, exactly as it's sung.",
              start: 8.27, duration: 2.75, backdrop: .shader(.rings)),

        .init(text: "This one's my favourite. It's called Curtains.",
              start: 12.72, duration: 2.57, backdrop: .shader(.curtains)),

        // Spoken over the library rather than instead of it, so the claim and
        // the evidence are on screen together.
        .init(text: "But it doesn't have to be yours. There are plenty to pick from.",
              start: 17.05, duration: 2.86, backdrop: .library),

        // Long enough to fill the frame: constellation shrinks its satellite
        // words hard, so a three-word line reads as almost nothing.
        .init(text: "Do you want something cinematic, with real depth to it?",
              start: 21.63, duration: 2.81, backdrop: .shader(.wormhole),
              composition: .constellation),

        .init(text: "Or something quieter, just lines and slow movement?",
              start: 26.10, duration: 2.73, backdrop: .pattern(.contours)),

        .init(text: "Or nothing but colour, so it stays out of your way.",
              start: 30.35, duration: 2.66, backdrop: .colourOnly,
              composition: .echo),

        .init(text: "Leave it automatic, and every track picks its own.",
              start: 34.77, duration: 2.58, backdrop: .shader(.orbit)),

        .init(text: "Or pin the one you love, and never think about it again.",
              start: 39.00, duration: 2.97, backdrop: .pattern(.constellation),
              composition: .editorial),

        .init(text: "That's it. Go play something.",
              start: 43.61, duration: 1.62, backdrop: .shader(.plasma)),

        // Bookends the opening on Aurora.
        .init(text: "Welcome to Verso.",
              start: 46.84, duration: 1.36, backdrop: .shader(.aurora)),
    ]

    /// Where the last word lands. This is what a recording is compared
    /// against, so it must not include the tail.
    static var spoken: TimeInterval { script.last?.end ?? 0 }

    /// The whole walkthrough, including a moment after the last line.
    static var length: TimeInterval { spoken + 2.0 }

    /// Rescales every cue to fit a recording of a different length.
    ///
    /// Only fires when the recording actually differs from the one these
    /// timings were measured against -- otherwise it would take exact,
    /// measured values and stretch them by a percent or two for no reason.
    /// It exists so a re-recorded voiceover stays roughly in sync without
    /// anyone re-measuring by hand; a fresh silence-detection pass is still
    /// the better answer for a keeper.
    static func retimed(toDuration audioLength: TimeInterval) -> [Line] {
        guard audioLength > 1, spoken > 1 else { return script }
        let factor = audioLength / spoken
        guard abs(factor - 1) > 0.02 else { return script }
        return script.map {
            Line(text: $0.text, start: $0.start * factor, duration: $0.duration * factor,
                 backdrop: $0.backdrop, composition: $0.composition)
        }
    }

    /// Splits a line into words carrying their own start and end.
    ///
    /// Real lyrics arrive with per-word timings from the provider; a narration
    /// script has none, so each word takes a share of the line proportional to
    /// its length. Longer words genuinely do take longer to say, which makes
    /// this a far better approximation than dividing the line evenly, and it
    /// is close enough that the sweep tracks the voice.
    static func words(in line: Line) -> [LyricsFetcher.Word] {
        let tokens = line.text.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return [] }

        let weights = tokens.map { Double($0.count) + 1.4 }   // +1.4 for the gap after
        let total = weights.reduce(0, +)

        var cursor = line.start
        return zip(tokens, weights).map { token, weight in
            let span = line.duration * (weight / total)
            let word = LyricsFetcher.Word(text: token, start: cursor, end: cursor + span * 0.82)
            cursor += span
            return word
        }
    }
}
