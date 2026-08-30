import SwiftUI

/// How much a child may grow beyond its natural size. The layout reserves
/// that room up front, so a word swelling never lands on its neighbours.
struct PeakScaleKey: LayoutValueKey {
    static let defaultValue: CGFloat = 1
}

extension View {
    func peakScale(_ value: CGFloat) -> some View {
        layoutValue(key: PeakScaleKey.self, value: value)
    }
}

/// Wraps children into rows, aligned leading / centre / trailing. Row-level
/// alignment is what lets consecutive lyric lines sit differently on the
/// canvas instead of all stacking down the middle.
struct FlowLayout: Layout {
    enum RowAlignment { case leading, center, trailing }

    var spacing: CGFloat = 12
    var lineSpacing: CGFloat = 10
    var rowAlignment: RowAlignment = .center

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var result: [Row] = []
        var current = Row()
        for (index, subview) in subviews.enumerated() {
            let natural = subview.sizeThatFits(.unspecified)
            // `scaleEffect` grows a view outside its layout box, so without
            // reserving the peak size here an enlarged word simply overlaps
            // whatever sits next to it.
            let peak = subview[PeakScaleKey.self]
            let size = CGSize(width: natural.width * peak, height: natural.height * peak)
            let projected = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if projected > maxWidth, !current.items.isEmpty {
                result.append(current)
                current = Row()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty { result.append(current) }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let laid = rows(for: subviews, maxWidth: maxWidth)
        let height = laid.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(laid.count - 1, 0))
        let width = laid.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let laid = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in laid {
            var x: CGFloat
            switch rowAlignment {
            case .leading: x = bounds.minX
            case .center: x = bounds.midX - row.width / 2
            case .trailing: x = bounds.maxX - row.width
            }
            for item in row.items {
                // Centred inside its reserved slot, so growth expands into
                // that reserved room rather than over the next word.
                subviews[item.index].place(
                    at: CGPoint(x: x + item.size.width / 2, y: y + row.height / 2),
                    anchor: .center,
                    proposal: .unspecified
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }
}

/// A dragged-out word, set glyph by glyph. Each letter lights and swells as
/// the sweep reaches it, so a held syllable visibly grows across its own
/// length rather than inflating all at once.
private struct HeldWordText: View {
    let label: String
    let font: Font
    /// Needed to reserve room for each glyph's growth.
    let pointSize: CGFloat
    let progress: Double
    let sustain: Double
    let glow: Double

    /// Peak growth of a single letter. Kept small: the clearance it needs
    /// shows up as letter-spacing, and too much of it makes a held word read
    /// as a different typeface from the rest of the line.
    private static let letterScale: CGFloat = 0.07

    var body: some View {
        let characters = Array(label)
        HStack(spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                let reach = progress * Double(characters.count) - Double(index)
                let lit = Easing.smoothstep(reach)
                Text(String(character))
                    .font(font)
                    .foregroundStyle(.white.opacity(0.28 + 0.72 * lit))
                    // Each glyph swells about its own centre, so it needs
                    // half its growth as clearance on either side -- without
                    // this the letters of a held word ride over each other.
                    .padding(.horizontal, pointSize * 0.02)
                    .scaleEffect(1 + Self.letterScale * lit * sustain, anchor: .bottom)
                    .shadow(color: .white.opacity(0.55 * glow * lit), radius: 6 + 18 * glow * lit)
            }
        }
    }
}

enum Easing {
    /// Classic 3x²-2x³ ease, clamped. Used wherever motion is driven from a
    /// time value instead of a SwiftUI animation.
    static func smoothstep(_ x: Double) -> Double {
        let clamped = min(max(x, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}

/// How a single lyric line is set. Cycling these between lines gives the
/// restless, re-composing quality of the Lyric Speaker display rather than a
/// fixed centred block.
struct LyricLineStyle {
    var rowAlignment: FlowLayout.RowAlignment
    /// Amplitude of the undulating baseline, as a fraction of base size.
    var wave: CGFloat
    var rotationSpread: Double
    /// 0 = every word the same size, 1 = strong large/small contrast.
    var sizeContrast: CGFloat
    var uppercaseHeroes: Bool

    static func forLine(_ index: Int) -> LyricLineStyle {
        switch abs(index) % 5 {
        case 0:
            return .init(rowAlignment: .center, wave: 0.00, rotationSpread: 1.3, sizeContrast: 0.9, uppercaseHeroes: true)
        case 1:
            return .init(rowAlignment: .leading, wave: 0.09, rotationSpread: 0.5, sizeContrast: 0.45, uppercaseHeroes: false)
        case 2:
            return .init(rowAlignment: .center, wave: 0.15, rotationSpread: 2.1, sizeContrast: 1.0, uppercaseHeroes: true)
        case 3:
            return .init(rowAlignment: .trailing, wave: -0.10, rotationSpread: 0.9, sizeContrast: 0.6, uppercaseHeroes: false)
        default:
            return .init(rowAlignment: .center, wave: 0.06, rotationSpread: 0.0, sizeContrast: 0.25, uppercaseHeroes: true)
        }
    }
}

/// A lyric line as a typographic collage. Static per-word variation supplies
/// the texture; the word currently being sung is always rendered decisively
/// larger and brighter than any idle word, so the eye tracks the vocal.
struct ScatteredLyricText: View {
    let words: [LyricsFetcher.Word]
    /// Current playback position. Emphasis is interpolated from this every
    /// frame rather than toggled on an index, which is what keeps words
    /// swelling smoothly instead of snapping between states.
    let time: TimeInterval
    var baseSize: CGFloat = 44
    var style: LyricLineStyle = .forLine(0)
    /// Supplies the typeface voice and how animated the layout feels.
    var mood: TrackMood = .neutral
    /// How the line is arranged. Timing and emphasis are unaffected -- only
    /// the arrangement changes.
    var composition: LyricComposition = .scattered
    /// Stable per line, so a composition draws the same figure each frame.
    var seed: Int = 0

    /// Peak growth of the word being sung.
    private let peakScale: CGFloat = 1.07

    /// Grammatical filler. However long a singer leans on "the", it is not
    /// the word carrying the line, so it never takes the display weight.
    private static let functionWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "so", "if", "as", "of", "to", "in",
        "on", "at", "by", "for", "with", "from", "up", "out", "is", "am", "are",
        "was", "were", "be", "been", "do", "did", "it", "its", "i", "im", "you",
        "youre", "me", "my", "we", "he", "she", "they", "them", "this", "that",
        "there", "here", "just", "got", "gonna", "wanna",
    ]

    /// Mean sung length across the line, the yardstick a word is measured
    /// against -- a fast rap line and a ballad have very different norms.
    private var averageWordDuration: Double {
        let durations = visibleWords.map { $0.end - $0.start }.filter { $0 > 0.01 }
        guard !durations.isEmpty else { return 0.3 }
        return durations.reduce(0, +) / Double(durations.count)
    }

    /// 0 when a word is sung at the line's usual pace, rising as it is held
    /// longer. This is what decides which words carry the weight: the ones
    /// the singer actually leans on.
    private func drag(_ word: LyricsFetcher.Word) -> Double {
        let cleaned = word.text.lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        guard cleaned.count > 2, !Self.functionWords.contains(cleaned) else { return 0 }

        let duration = word.end - word.start
        let average = averageWordDuration
        guard average > 0.01 else { return 0 }
        // 1.15x the line's average is where a word starts reading as held.
        return Easing.smoothstep((duration / average - 1.15) / 0.85)
    }

    /// How much line there is to work with, 0...1.
    ///
    /// A three-word line has nothing to make a figure out of: at the full
    /// spread those few words are simply flung into opposite corners with
    /// nothing between them, which is what made short lines look broken
    /// rather than composed. Scatter and row spacing both scale by this.
    private var fullness: Double {
        min(Double(visibleWords.count) / 7.0, 1.0)
    }

    /// Tokens that would render as nothing are dropped: they are invisible
    /// but still occupy a slot, which shows up as an unexplained gap in the
    /// middle of a line.
    private var visibleWords: [LyricsFetcher.Word] {
        words.filter { word in
            word.text.contains { $0.isLetter || $0.isNumber }
        }
    }

    var body: some View {
        // Gaps come from a fixed inset on each word (below), not from
        // reserving a share of its width -- proportional reservation made a
        // wide word claim a wide margin and a narrow one almost none, so the
        // spacing visibly changed from word to word.
        FlowLayout(
            spacing: baseSize * (composition == .constellation ? 0.06 : 0.02),
            // The web needs vertical room to scatter into; without it the
            // words collide with the rows above and below. Short lines get
            // less of it -- see `fullness`.
            lineSpacing: baseSize * (composition == .constellation
                                     ? 0.34 + 0.96 * CGFloat(fullness) : 0.30),
            rowAlignment: style.rowAlignment
        ) {
            ForEach(Array(visibleWords.enumerated()), id: \.offset) { index, word in
                wordView(index: index, word: word)
            }
        }
        .overlayPreferenceValue(WordAnchorKey.self) { anchors in
            if composition == .constellation {
                ConstellationLines(
                    anchors: anchors,
                    offsets: scatterOffsets,
                    count: visibleWords.count,
                    activeIndex: activeWordIndex,
                    seed: seed
                )
            }
        }
    }

    /// One word, set and lit.
    ///
    /// Kept as its own builder rather than inline in the layout: with the
    /// composition branches folded in, the single expression exceeded what
    /// the type-checker will solve in reasonable time.
    @ViewBuilder
    private func wordView(index: Int, word: LyricsFetcher.Word) -> some View {
        let metrics = metrics(index: index, word: word)
        let heat = emphasis(for: word)
        let fill = fillProgress(for: word)
        let glow = glowAmount(for: word, heat: heat)
        let held = sustain(for: word)
        let label = metrics.uppercased ? word.text.uppercased() : word.text
        // Editorial sets two voices in one line the way a magazine spread
        // does; every other composition keeps to a single face.
        let font: Font = metrics.alternateFace
            ? mood.face.contrasting.font(size: metrics.size, hero: metrics.isHero)
            : Settings.shared.lyricFont(size: metrics.size, hero: metrics.isHero, mood: mood)

        Group {
            if held > 0.02 {
                // A held note is set letter by letter so each glyph swells in
                // turn as the syllable is dragged out -- the word appears to
                // be sung louder as it goes.
                HeldWordText(
                    label: label, font: font, pointSize: metrics.size,
                    progress: fill, sustain: held, glow: glow
                )
            } else {
                // Karaoke fill: a dim word underneath, with the lit copy
                // revealed left-to-right in step with the word's own timing.
                // Typography stays fixed and only scale moves -- swapping
                // weight mid-word re-renders and pops.
                ZStack {
                    Text(label).font(font).foregroundStyle(.white.opacity(0.28))
                    Text(label).font(font).foregroundStyle(.white)
                        .mask(sweepMask(progress: fill))
                }
            }
        }
        // A constant inset, so every gap is the same width whatever the words
        // on either side happen to be.
        .padding(.horizontal, baseSize * 0.10)
        // Captured before the transforms below. `.offset` moves what is drawn
        // but not the layout frame, so an anchor read after it still reports
        // the un-scattered position -- which is exactly why the web came out
        // as one horizontal rule through the line.
        .anchorPreference(key: WordAnchorKey.self, value: .bounds) { anchor in
            composition == .constellation ? [index: anchor] : [:]
        }
        .rotationEffect(.degrees(metrics.rotation))
        .offset(y: metrics.waveOffset)
        .scaleEffect(1 + (peakScale - 1) * CGFloat(heat) + 0.03 * CGFloat(glow))
        .shadow(color: .white.opacity(0.45 * glow * fill), radius: 10 + 22 * glow)
        .shadow(color: .black.opacity(0.28 + 0.24 * heat), radius: 7 + 12 * heat, y: 2)
        .zIndex(heat > 0.05 ? 1 : 0)
    }

    /// The vertical scatter each word is drawn at, so the web can add it back
    /// to the layout frame it reads from.
    private var scatterOffsets: [Int: CGFloat] {
        guard composition == .constellation else { return [:] }
        return Dictionary(uniqueKeysWithValues: visibleWords.enumerated().map { index, word in
            (index, metrics(index: index, word: word).waveOffset)
        })
    }

    /// The word being sung, for lighting its links in the web.
    private var activeWordIndex: Int? {
        visibleWords.firstIndex { time >= $0.start && time <= $0.end }
    }

    /// How far the lit fill has swept across a word: 0 before it is sung,
    /// reaching 1 as it finishes and staying there, so a line accumulates
    /// rather than flickering back to dim behind the vocal.
    private func fillProgress(for word: LyricsFetcher.Word) -> Double {
        let duration = max(word.end - word.start, 0.001)
        return min(max((time - word.start) / duration, 0), 1)
    }

    /// Left-to-right reveal with a softened leading edge, so the fill reads
    /// as a sweep rather than a hard wipe.
    private func sweepMask(progress: Double) -> some View {
        let clamped = min(max(progress, 0), 1)
        let feather = 0.12
        return LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: max(clamped - feather, 0)),
                .init(color: .clear, location: clamped),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// How dragged-out a syllable is. Ordinary ones run ~0.2-0.4s; anything
    /// past ~0.45s is being held.
    private func sustain(for word: LyricsFetcher.Word) -> Double {
        Easing.smoothstep(((word.end - word.start) - 0.45) / 0.85)
    }

    /// Bloom for sustained syllables. NetEase's yrc timing gives each word a
    /// real duration, so a held note ("controllaaa") is simply a word with a
    /// long window -- the glow rises as the hold continues and fades with the
    /// word, showing the drag the way Apple Music does.
    private func glowAmount(for word: LyricsFetcher.Word, heat: Double) -> Double {
        let duration = word.end - word.start
        let sustain = sustain(for: word)
        guard sustain > 0.01, heat > 0.01 else { return 0 }

        // Swell in over the first part of the hold rather than snapping on.
        let progress = min(max((time - word.start) / max(duration, 0.001), 0), 1)
        let swell = Easing.smoothstep(progress / 0.45)
        return heat * sustain * swell
    }

    /// A continuous 0...1 envelope: rises just before the word lands, holds
    /// while it is sung, then decays. Continuous interpolation is what
    /// removes the frame-to-frame jumping.
    private func emphasis(for word: LyricsFetcher.Word) -> Double {
        let leadIn: TimeInterval = 0.10
        let decay: TimeInterval = 0.30

        if time < word.start - leadIn { return 0 }
        if time < word.start {
            return Easing.smoothstep((time - (word.start - leadIn)) / leadIn)
        }
        if time <= word.end { return 1 }
        let elapsed = (time - word.end) / decay
        return elapsed >= 1 ? 0 : 1 - Easing.smoothstep(elapsed)
    }

    private struct WordMetrics {
        var size: CGFloat
        var isHero: Bool
        var rotation: Double
        var waveOffset: CGFloat
        var uppercased: Bool
        /// Set this word in the contrasting typeface (editorial only).
        var alternateFace: Bool
    }

    /// Derived from the word itself so a lyric always sets the same way
    /// rather than reshuffling on every redraw.
    private func metrics(index: Int, word: LyricsFetcher.Word) -> WordMetrics {
        var value: UInt64 = 1469598103934665603
        for byte in word.text.utf8 {
            value = (value ^ UInt64(byte)) &* 1099511628211
        }
        value = value ^ UInt64(index &* 2654435761)

        // How hard the singer leans on this word decides the weight; the hash
        // only supplies a little size jitter so the line is not mechanical.
        let held = drag(word)
        let isHero = held > 0.25
        let jitter = CGFloat(Int(value / 100) % 5) / 5.0

        // Idle sizes stay well below baseSize; the active word's scale takes
        // it clearly past all of them. A longer-held word sits larger still.
        var size = isHero
            ? baseSize * (0.58 + 0.30 * style.sizeContrast * CGFloat(held) + 0.05 * jitter)
            : baseSize * (0.52 + 0.06 * jitter)

        // Editorial widens the range hard: a spread gets its character from
        // real size contrast, not from a gentle wobble around one size.
        var alternate = false
        if composition == .editorial {
            size *= isHero ? 1.28 : (0.72 + 0.34 * jitter)
            // Roughly every third word takes the second face. Driven by the
            // word's own hash, so the pairing is fixed for a given lyric.
            alternate = !isHero && (value / 10_000) % 3 == 0
        }

        var offset = sin(Double(index) * 0.85) * style.wave * baseSize * CGFloat(mood.intensity)

        if composition == .constellation {
            // The web needs the words at genuinely different heights. On a
            // single baseline every link comes out horizontal and collinear,
            // and the whole figure reads as a rule struck through the line
            // rather than as a constellation.
            let spread = CGFloat(Int(value / 7) % 100) / 100.0 - 0.5
            let reach = CGFloat(0.30 + 0.70 * fullness) * CGFloat(Settings.shared.constellationSpread)
            offset += (spread * baseSize * 2.1 + CGFloat(sin(Double(index) * 2.3)) * baseSize * 0.42) * reach
            // Satellites shrink well back so the held words carry the figure,
            // the way the small linked fragments do on the real display.
            size *= isHero ? 1.18 : 0.60
        }

        return WordMetrics(
            size: max(size, 11),
            isHero: isHero,
            rotation: Double(Int(value / 1000) % 9 - 4) * 0.35 * style.rotationSpread * mood.intensity,
            waveOffset: offset,
            uppercased: isHero && style.uppercaseHeroes,
            alternateFace: alternate
        )
    }
}
