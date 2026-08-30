import SwiftUI

/// How a lyric line is composed on the screen.
///
/// The Lyric Speaker does not set every line the same way. It re-composes
/// around the words themselves: sometimes a web of connected fragments,
/// sometimes one phrase echoed at half a dozen sizes, sometimes an editorial
/// spread mixing two typefaces in a single line. These are those three
/// behaviours, plus the original scattered setting.
///
/// Each is a *layout* rather than a new renderer -- the timing, karaoke fill
/// and held-note emphasis all still come from `ScatteredLyricText`, so a line
/// stays in sync however it happens to be arranged.
enum LyricComposition: String, CaseIterable, Identifiable {
    case scattered, constellation, echo, editorial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scattered: return "Scattered"
        case .constellation: return "Constellation"
        case .echo: return "Echo"
        case .editorial: return "Editorial"
        }
    }

    var detail: String {
        switch self {
        case .scattered: return "Words set loose across the line."
        case .constellation: return "Fragments linked by hairlines, like a star chart."
        case .echo: return "The phrase repeated at many sizes, some inverted."
        case .editorial: return "Two typefaces in one line, set like a spread."
        }
    }

    /// Which composition suits a track, when the choice is left automatic.
    ///
    /// Deliberately coarse: the composition changes the *reading* of a line,
    /// so switching on something as jittery as per-line word count would be
    /// restless. Energy and how played-by-hand the music is are stable for a
    /// whole track, which is the right granularity for this.
    static func matching(_ mood: TrackMood, seed: Int) -> LyricComposition {
        // Dense, mechanical music suits the linked web; sparse organic music
        // suits the echo; everything in between gets the editorial setting,
        // with scattered as the general-purpose fallback.
        if mood.energy > 0.68 && mood.organic < 0.45 { return .constellation }
        if mood.energy < 0.38 && mood.organic > 0.62 { return .echo }
        return abs(seed) % 2 == 0 ? .editorial : .scattered
    }
}

// MARK: - Assembled line

/// One lyric line, arranged by its composition.
///
/// The wallpaper and the settings preview both render through this, so a
/// preview cannot quietly drift from what actually appears on screen.
struct LyricLineView: View {
    let words: [LyricsFetcher.Word]
    let time: TimeInterval
    var baseSize: CGFloat = 44
    var mood: TrackMood = .neutral
    var composition: LyricComposition = .scattered
    var seed: Int = 0
    /// How present the line is, 0...1. Echo fades its repeats in with it.
    var presence: Double = 1

    var body: some View {
        ZStack {
            // Echo lays repeats of the whole phrase behind the live line, so
            // it has to sit under the words rather than beside them.
            if composition == .echo {
                EchoBackdrop(
                    text: words.map(\.text).joined(separator: " "),
                    font: { Settings.shared.lyricFont(size: $0, hero: false, mood: mood) },
                    baseSize: baseSize,
                    seed: seed,
                    presence: presence
                )
            }
            ScatteredLyricText(
                words: words,
                time: time,
                baseSize: baseSize,
                style: .forLine(seed),
                mood: mood,
                composition: composition,
                seed: seed
            )
        }
    }
}

// MARK: - Constellation

/// Where each word landed, collected from the layout so the linking lines
/// can be drawn between real positions rather than guessed ones.
struct WordAnchorKey: PreferenceKey {
    static let defaultValue: [Int: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Int: Anchor<CGRect>],
                       nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// The hairline web drawn between words.
///
/// SwiftUI will not tell you where a laid-out child ended up, so each word
/// publishes its bounds through a preference and the lines are drawn in an
/// overlay once every position is known. That is why this is a separate pass
/// rather than something the layout itself could do.
struct ConstellationLines: View {
    let anchors: [Int: Anchor<CGRect>]
    /// Vertical scatter applied to each word after layout, which the anchors
    /// do not include.
    let offsets: [Int: CGFloat]
    let count: Int
    /// Index of the word currently being sung, so its links can be lit.
    let activeIndex: Int?
    let seed: Int

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let centres = (0..<count).compactMap { index -> (Int, CGPoint)? in
                    guard let anchor = anchors[index] else { return nil }
                    let rect = proxy[anchor]
                    guard rect.width > 0 else { return nil }
                    return (index, CGPoint(x: rect.midX, y: rect.midY + (offsets[index] ?? 0)))
                }
                guard centres.count > 1 else { return }
                let position = Dictionary(uniqueKeysWithValues: centres)

                for (index, point) in centres {
                    // The backbone: every word linked to the next.
                    if let next = position[index + 1] {
                        stroke(&context, from: point, to: next,
                               lit: index == activeIndex || index + 1 == activeIndex,
                               size: size)
                    }
                    // Plus a longer chord every few words, which is what turns
                    // a chain into a web. The stride is derived from the seed
                    // so a line always draws the same figure.
                    let reach = 2 + (abs(seed &+ index) % 3)
                    if let far = position[index + reach] {
                        stroke(&context, from: point, to: far,
                               lit: index == activeIndex, size: size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Draws one link, overshooting both ends so the web reads as a fragment
    /// of something larger rather than a closed shape.
    private func stroke(_ context: inout GraphicsContext,
                        from: CGPoint, to: CGPoint, lit: Bool, size: CGSize) {
        let dx = to.x - from.x, dy = to.y - from.y
        let length = max((dx * dx + dy * dy).squareRoot(), 1)
        let overshoot: CGFloat = 26
        let ux = dx / length, uy = dy / length

        var path = Path()
        path.move(to: CGPoint(x: from.x - ux * overshoot, y: from.y - uy * overshoot))
        path.addLine(to: CGPoint(x: to.x + ux * overshoot, y: to.y + uy * overshoot))

        context.stroke(
            path,
            with: .color(.white.opacity(lit ? 0.42 : 0.16)),
            lineWidth: lit ? 1.1 : 0.7
        )
    }
}

// MARK: - Echo

/// The phrase repeated behind itself at descending sizes, a few copies
/// inverted.
///
/// The inversion is the detail that makes it read as the Lyric Speaker
/// rather than as a drop shadow: on the real display the repeats are mirrored
/// through the horizontal, so the line appears reflected in the glass.
struct EchoBackdrop: View {
    let text: String
    let font: (CGFloat) -> Font
    let baseSize: CGFloat
    let seed: Int
    /// Rises as the line is sung, so the echoes arrive with the vocal.
    let presence: Double

    private struct Ghost {
        var scale: CGFloat
        var dx: CGFloat
        var dy: CGFloat
        var angle: Double
        var opacity: Double
        var flipped: Bool
    }

    /// Fixed rather than random: a line must set the same way every frame,
    /// and `TimelineView` rebuilds this view continuously.
    private var ghosts: [Ghost] {
        // Every repeat sits well under the live line and well away from the
        // centre. The first pass had them at full size and a fifth opacity,
        // which made them read as five competing lines rather than as an
        // echo of one -- the live lyric was the hardest thing on screen to
        // find. Nothing here is legible enough to be mistaken for the line
        // being sung.
        let variants: [Ghost] = [
            .init(scale: 0.85, dx: -0.30, dy: -0.62, angle: -2.0, opacity: 0.055, flipped: true),
            .init(scale: 0.42, dx: 0.46, dy: -0.44, angle: 1.5, opacity: 0.085, flipped: false),
            .init(scale: 0.30, dx: -0.50, dy: 0.48, angle: -1.0, opacity: 0.10, flipped: false),
            .init(scale: 0.60, dx: 0.34, dy: 0.66, angle: 2.5, opacity: 0.065, flipped: true),
            .init(scale: 0.22, dx: 0.10, dy: -0.78, angle: 0.0, opacity: 0.12, flipped: false),
        ]
        // The seed rotates which variant leads, so two lines in a row do not
        // arrange themselves identically.
        let offset = abs(seed) % variants.count
        return Array(variants[offset...] + variants[..<offset])
    }

    var body: some View {
        ZStack {
            ForEach(Array(ghosts.enumerated()), id: \.offset) { _, ghost in
                Text(text)
                    .font(font(baseSize * ghost.scale))
                    .foregroundStyle(.white.opacity(ghost.opacity * presence * Settings.shared.echoStrength))
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(ghost.angle))
                    .scaleEffect(x: 1, y: ghost.flipped ? -1 : 1)
                    .offset(x: baseSize * ghost.dx * 3.2, y: baseSize * ghost.dy * 1.5)
            }
        }
        .allowsHitTesting(false)
    }
}
