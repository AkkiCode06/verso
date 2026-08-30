import Foundation

/// How busy the music is *right now*, derived from the lyric timeline.
///
/// macOS exposes no audio stream from another app, so there is no spectrum to
/// analyse. What we do have is word-accurate timing, and vocal phrasing
/// tracks a song's shape closely: dense verses, sparse breakdowns, and the
/// moment vocals return after a long instrumental. Driving the visuals from
/// that makes the background move *with* the track rather than on a timer,
/// without pretending to be a spectrum visualiser.
struct MusicDynamics {
    struct Reactivity {
        /// Slow-moving fullness, from local word density.
        var swell: Double
        /// Fast transient from recent word onsets.
        var pulse: Double

        var combined: Double { min(swell * 0.45 + pulse * 0.55, 1) }

        static let idle = Reactivity(swell: 0.35, pulse: 0)
    }

    private let onsets: [TimeInterval]
    /// Moments where vocals resume after a long instrumental stretch -- the
    /// closest thing to a "drop" the lyric timeline can tell us about.
    private let returns: [TimeInterval]
    /// Seconds per beat, inferred once per track. Zero when unknown.
    private let beatPeriod: TimeInterval

    /// Density never falls to nothing, so an instrumental passage keeps
    /// drifting instead of stalling until the next word.
    private static let restingSwell = 0.40

    init(lines: [LyricsFetcher.Line]) {
        let sorted = lines.flatMap { $0.words.map(\.start) }.sorted()
        onsets = sorted

        var detected: [TimeInterval] = []
        for (index, onset) in sorted.enumerated() where index > 0 {
            if onset - sorted[index - 1] > 5.0 { detected.append(onset) }
        }
        returns = detected
        beatPeriod = Self.inferBeatPeriod(from: sorted)
    }

    /// Recovers a beat period from the sung timeline.
    ///
    /// Music's own `bpm` property would be the obvious source, but Apple
    /// Music reports 0 for streamed tracks -- the case that matters. Sung
    /// words, though, land on or near the beat far more often than not, so
    /// the *median* gap between onsets sits at some simple fraction of the
    /// beat. Folding that into the range nearly all popular music occupies
    /// recovers a period good enough to keep time by. The median is what
    /// makes it robust: held notes and long rests are outliers, and they
    /// move a mean but not a middle.
    ///
    /// The point of a period, as opposed to the onsets themselves, is that
    /// it keeps ticking where the lyrics say nothing -- intros, solos,
    /// breakdowns and run-outs.
    private static func inferBeatPeriod(from onsets: [TimeInterval]) -> TimeInterval {
        guard onsets.count >= 8 else { return 0 }
        var gaps = zip(onsets.dropFirst(), onsets)
            .map { $0 - $1 }
            .filter { $0 > 0.08 && $0 < 2.0 }
        guard gaps.count >= 6 else { return 0 }
        gaps.sort()

        var period = gaps[gaps.count / 2]
        // Fold by octaves into 70-170bpm. A median that came out as a half
        // or double beat lands on the real one.
        while period < 0.353 { period *= 2 }
        while period > 0.857 { period /= 2 }
        return period
    }

    func reactivity(at time: TimeInterval) -> Reactivity {
        guard !onsets.isEmpty else { return .idle }
        let boost = returnBoost(at: time)
        // Whichever is stronger: the words being sung, or the beat carrying
        // on underneath them. The handoff is silent -- as a phrase ends the
        // sung pulse decays and the metronome is simply what is left.
        let carried = max(pulse(at: time), metronome(at: time))
        return Reactivity(
            swell: min(max(swell(at: time), Self.restingSwell) + boost * 0.4, 1),
            pulse: min(carried + boost * 0.6, 1)
        )
    }

    /// A steady heartbeat at the inferred tempo, at roughly half the weight
    /// of a real sung onset so the vocal still leads where there is one.
    private func metronome(at time: TimeInterval) -> Double {
        guard beatPeriod > 0 else { return 0 }
        let sinceBeat = time.truncatingRemainder(dividingBy: beatPeriod)
        return exp(-sinceBeat / (beatPeriod * 0.45)) * 0.5
    }

    /// Recent word onsets, weighted by recency. The decay is deliberately
    /// unhurried: a sharp envelope makes the colour field twitch, where a
    /// long one makes it swell and settle.
    private func pulse(at time: TimeInterval) -> Double {
        var index = firstIndex(after: time) - 1
        var total = 0.0
        var counted = 0
        while index >= 0, counted < 6 {
            let age = time - onsets[index]
            if age > 2.4 { break }
            total += exp(-age / 0.62)
            index -= 1
            counted += 1
        }
        return min(total, 1)
    }

    /// Word density in a +/-3s window.
    private func swell(at time: TimeInterval) -> Double {
        let lower = firstIndex(after: time - 3)
        let upper = firstIndex(after: time + 3)
        return min(Double(max(upper - lower, 0)) / 14.0, 1)
    }

    /// Decaying kick when the vocal comes back after silence.
    private func returnBoost(at time: TimeInterval) -> Double {
        var best = 0.0
        for moment in returns {
            guard time >= moment, time - moment < 2.5 else { continue }
            best = max(best, 1 - (time - moment) / 2.5)
        }
        return best
    }

    /// Index of the first onset strictly after `time`.
    private func firstIndex(after time: TimeInterval) -> Int {
        var low = 0
        var high = onsets.count
        while low < high {
            let mid = (low + high) / 2
            if onsets[mid] <= time { low = mid + 1 } else { high = mid }
        }
        return low
    }
}
