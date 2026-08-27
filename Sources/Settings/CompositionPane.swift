import SwiftUI

/// Picking how lyrics are arranged, with the arrangement running live above
/// the controls.
///
/// The preview is not a mock-up: it renders through `LyricLineView`, the same
/// view the wallpaper uses, against a real shader background. A still image
/// would be useless here -- every one of these compositions is defined by how
/// it behaves as a line is sung, so the preview has to be playing.
struct CompositionPane: View {
    @ObservedObject private var settings = Settings.shared
    /// Relative, not absolute: a Float32 shader uniform loses all precision
    /// at `timeIntervalSinceReferenceDate` scale and the preview freezes.
    @State private var started = Date()
    @State private var sample = 0
    @State private var showAdvanced = false

    /// Written for the purpose rather than lifted from a record -- a settings
    /// pane is not the place to ship someone's lyrics.
    private static let samples: [[String]] = [
        ["Hold", "the", "light", "a", "little", "longer"],
        ["Everything", "moves", "when", "you", "do"],
        ["Say", "it", "once", "and", "mean", "it"],
    ]

    /// The phrase laid out on a timeline, then looped. Timings are uneven on
    /// purpose: the emphasis logic keys off how long a word is *held*, so a
    /// perfectly even sample would never show a hero word at all.
    private static func line(_ index: Int) -> [LyricsFetcher.Word] {
        let words = samples[index % samples.count]
        var cursor: TimeInterval = 0.35
        return words.enumerated().map { position, text in
            // Every third word is drawn out, which is what promotes it.
            let held = position % 3 == 2
            let duration: TimeInterval = held ? 0.92 : 0.40
            let word = LyricsFetcher.Word(text: text, start: cursor, end: cursor + duration)
            cursor += duration + 0.06
            return word
        }
    }

    private var words: [LyricsFetcher.Word] { Self.line(sample) }
    private var loopLength: TimeInterval { (words.last?.end ?? 3) + 1.4 }

    private var active: LyricComposition? { settings.lyricComposition }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.04, green: 0.04, blue: 0.055))
    }

    // MARK: - Preview

    private var preview: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(started)
            let looped = elapsed.truncatingRemainder(dividingBy: loopLength)
            // What the wallpaper would choose right now, so "Match the music"
            // shows a real answer rather than a placeholder.
            let composition = active ?? LyricComposition.matching(previewMood, seed: sample)

            ZStack {
                ShaderBackgroundView(
                    style: .ribbons,
                    time: elapsed, flow: elapsed,
                    tintA: Color(hue: 0.62, saturation: 0.55, brightness: 0.72),
                    tintB: Color(hue: 0.86, saturation: 0.45, brightness: 0.48)
                )
                Color.black.opacity(0.34)

                LyricLineView(
                    words: words,
                    time: looped,
                    baseSize: 38,
                    mood: previewMood,
                    composition: composition,
                    seed: sample,
                    presence: fade(at: looped)
                )
                .opacity(fade(at: looped))
                .padding(.horizontal, 30)

                VStack {
                    HStack {
                        Spacer()
                        Text(composition.title.uppercased())
                            .font(AppFont.ui(9.5, .semibold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.4)))
                    }
                    Spacer()
                }
                .padding(14)
            }
            .frame(height: 268)
            .clipped()
        }
    }

    /// Fades the line in at the top of the loop and out at the end, so the
    /// sample restarts rather than cutting.
    private func fade(at t: TimeInterval) -> Double {
        let inn = Easing.smoothstep(t / 0.4)
        let out = 1 - Easing.smoothstep((t - (loopLength - 0.9)) / 0.6)
        return min(inn, max(out, 0))
    }

    /// A mid-energy, mid-organic track, so automatic selection lands
    /// somewhere representative rather than at an extreme.
    private var previewMood: TrackMood {
        TrackMood(
            energy: 0.55, face: Settings.shared.face(for: .neutral),
            background: .constellation, motionRate: 1.0, intensity: 1.0, organic: 0.55
        )
    }

    // MARK: - Controls

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PaneHeader(
                    title: "Composition",
                    subtitle: "How a line is arranged on the screen. Timing and emphasis are the same throughout — only the arrangement changes."
                )

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(LyricComposition.allCases) { option in
                        row(option)
                    }
                    matchRow
                }

                advanced

                HStack(spacing: 10) {
                    Button {
                        sample = (sample + 1) % Self.samples.count
                        started = Date()
                    } label: {
                        Label("Try another phrase", systemImage: "arrow.triangle.2.circlepath")
                            .font(AppFont.ui(11.5, .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.1)))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        started = Date()
                    } label: {
                        Label("Replay", systemImage: "gobackward")
                            .font(AppFont.ui(11.5, .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.1)))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 26)
            .padding(.bottom, 30)
        }
    }

    /// Per-composition controls, shown only for the composition they affect
    /// so the pane does not fill with knobs that currently do nothing.
    @ViewBuilder
    private var advanced: some View {
        let shown = active ?? LyricComposition.matching(previewMood, seed: sample)
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 13) {
                if shown == .constellation {
                    knob("Scatter", "How far apart the linked words are thrown. Short lines are tightened automatically.",
                         value: $settings.constellationSpread, range: 0.3...1.8,
                         format: { String(format: "%.2f×", $0) })
                }
                if shown == .echo {
                    knob("Echo strength", "How present the repeats are behind the live line.",
                         value: $settings.echoStrength, range: 0...1.6,
                         format: { String(format: "%.2f×", $0) })
                }
                if shown != .constellation && shown != .echo {
                    Text("Scattered and Editorial take their character from the lyric itself — how long each word is held — so there is nothing here to tune.")
                        .font(AppFont.ui(11))
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Reset composition settings") {
                    settings.constellationSpread = 1.0
                    settings.echoStrength = 1.0
                }
                .buttonStyle(.plain)
                .font(AppFont.ui(11))
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 10)
        } label: {
            Text("Advanced")
                .font(AppFont.ui(12, .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .tint(.white.opacity(0.6))
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
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Text(format(value.wrappedValue))
                    .font(AppFont.ui(11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
            Slider(value: value, in: range)
                .controlSize(.small)
                .tint(.white.opacity(0.75))
            Text(detail)
                .font(AppFont.ui(10.5))
                .foregroundStyle(.white.opacity(0.38))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var matchRow: some View {
        selectable(
            title: "Match the music",
            detail: "Dense mechanical tracks get Constellation, sparse organic ones Echo.",
            selected: active == nil
        ) { settings.lyricComposition = nil }
    }

    private func row(_ option: LyricComposition) -> some View {
        selectable(
            title: option.title,
            detail: option.detail,
            selected: active == option
        ) { settings.lyricComposition = option }
    }

    /// A full-width row rather than a chip: each composition needs a line of
    /// explanation, and chips leave nowhere to put it.
    private func selectable(
        title: String, detail: String, selected: Bool, choose: @escaping () -> Void
    ) -> some View {
        Button(action: choose) {
            HStack(spacing: 11) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(AppFont.ui(13))
                    .foregroundStyle(selected ? .white : .white.opacity(0.32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.ui(12.5, selected ? .semibold : .regular))
                        .foregroundStyle(.white.opacity(selected ? 1 : 0.82))
                    Text(detail)
                        .font(AppFont.ui(11))
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? .white.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
