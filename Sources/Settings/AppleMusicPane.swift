import SwiftUI

/// Everything to do with Apple Music's animated album covers.
///
/// This is the one background Verso does not generate. When an album ships an
/// animated cover, the app steps out of the way entirely and shows the artist's
/// own art direction — so it earns a pane of its own rather than a checkbox
/// buried under Background.
struct AppleMusicPane: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var nowPlaying = NowPlayingMonitor.shared

    private var motion: MotionArtworkProvider.Motion? { nowPlaying.motionArtwork }
    private var track: NowPlayingMonitor.Track? { nowPlaying.current }

    private var currentIsExcluded: Bool {
        settings.excludesMotion(artist: track?.artist, album: track?.album)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaneHeader(
                    title: "Apple Music",
                    subtitle: "Some albums ship an animated cover. Verso can hand the whole background over to it."
                )

                preview
                masterToggle

                if settings.useMotionArtwork {
                    placement
                    readability
                    exclusions
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Verso.surface)
    }

    // MARK: - Preview

    /// The real player, at the real placement, so the crop can be judged
    /// rather than guessed at. Falls back to explaining why there is nothing
    /// to show, which is the more common case.
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Verso.surfaceCard)

            if let motion, settings.useMotionArtwork, !currentIsExcluded {
                MotionArtworkView(url: motion.square, placement: settings.motionPlacement)
                    .blur(radius: settings.motionBlur)
                    .overlay(Color.black.opacity(0.40 * settings.scrimStrength))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomLeading) {
                        Text(track.map { "\($0.title) — \($0.artist)" } ?? "")
                            .font(AppFont.ui(11, .medium))
                            .foregroundStyle(Verso.cream.opacity(0.85))
                            .padding(12)
                    }
            } else {
                VStack(spacing: 7) {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 19, weight: .light))
                        .foregroundStyle(Verso.cream.opacity(0.35))
                    Text(statusText)
                        .font(AppFont.ui(12))
                        .foregroundStyle(Verso.cream.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(height: 190)
    }

    private var statusSymbol: String {
        if !settings.useMotionArtwork { return "square.slash" }
        if currentIsExcluded { return "hand.raised" }
        if track == nil { return "pause.circle" }
        return "sparkles.rectangle.stack"
    }

    private var statusText: String {
        if !settings.useMotionArtwork {
            return "Animated covers are off. Verso will always draw its own background."
        }
        if currentIsExcluded {
            return "This album is on your exclusion list, so Verso is drawing its own background instead."
        }
        if track == nil {
            return "Nothing is playing. Start a track to see whether its album has an animated cover."
        }
        return "This album has no animated cover — most don't. Verso is drawing its own background instead."
    }

    // MARK: - Sections

    private var masterToggle: some View {
        Toggle(isOn: $settings.useMotionArtwork) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Use animated album covers")
                    .font(AppFont.ui(12.5, .medium))
                    .foregroundStyle(Verso.cream.opacity(0.92))
                Text("When an album has one, it replaces every generated effect. Lyrics keep their timing and composition on top.")
                    .font(AppFont.ui(11))
                    .foregroundStyle(Verso.cream.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .tint(Verso.violet)
    }

    private var placement: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Placement",
                         "Covers are square and screens are wide, so something has to give.")
            ForEach(Settings.MotionPlacement.allCases) { option in
                Button {
                    settings.motionPlacement = option
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: settings.motionPlacement == option
                              ? "largecircle.fill.circle" : "circle")
                            .font(AppFont.ui(12.5))
                            .foregroundStyle(settings.motionPlacement == option
                                             ? Verso.violet : Verso.cream.opacity(0.30))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.title)
                                .font(AppFont.ui(12, settings.motionPlacement == option ? .semibold : .regular))
                                .foregroundStyle(Verso.cream.opacity(0.9))
                            Text(option.detail)
                                .font(AppFont.ui(10.5))
                                .foregroundStyle(Verso.cream.opacity(0.42))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(settings.motionPlacement == option
                                  ? Verso.violet.opacity(0.12) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var readability: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Readability",
                         "A cover is art, not a backdrop, so lyrics need help surviving a bright frame.")
            knob("Blur", "Softens fine detail so it stops competing with the type.",
                 value: $settings.motionBlur, range: 0...20,
                 format: { String(format: "%.0f pt", $0) })
            knob("Darkening", "How far the frame is dimmed behind the words.",
                 value: $settings.scrimStrength, range: 0...1.6,
                 format: { String(format: "%.2f×", $0) })
        }
    }

    private var exclusions: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Exclusions",
                         "Some covers are too busy, too bright, or just wrong behind lyrics. Excluded albums fall back to a generated background.")

            if let track, !(track.album ?? "").isEmpty {
                Button {
                    settings.setMotionExcluded(!currentIsExcluded,
                                               artist: track.artist, album: track.album)
                } label: {
                    Label(currentIsExcluded ? "Allow this album again" : "Exclude this album",
                          systemImage: currentIsExcluded ? "arrow.uturn.backward" : "hand.raised")
                        .font(AppFont.ui(11.5, .medium))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Verso.violet.opacity(0.20)))
                        .foregroundStyle(Verso.cream.opacity(0.9))
                }
                .buttonStyle(.plain)

                Text(track.album ?? "")
                    .font(AppFont.ui(10.5))
                    .foregroundStyle(Verso.cream.opacity(0.40))
            } else {
                Text("Play something to exclude its album.")
                    .font(AppFont.ui(11))
                    .foregroundStyle(Verso.cream.opacity(0.40))
            }

            if settings.motionExclusions.isEmpty {
                Text("Nothing excluded.")
                    .font(AppFont.ui(11))
                    .foregroundStyle(Verso.cream.opacity(0.30))
                    .padding(.top, 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(settings.motionExclusions, id: \.self) { key in
                        HStack(spacing: 8) {
                            Text(readable(key))
                                .font(AppFont.ui(11))
                                .foregroundStyle(Verso.cream.opacity(0.68))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                settings.motionExclusions.removeAll { $0 == key }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(Verso.cream.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        Divider().overlay(Verso.cream.opacity(0.06))
                    }
                }
                .background(RoundedRectangle(cornerRadius: 7).fill(Verso.surfaceCard))
                .padding(.top, 2)
            }
        }
    }

    /// Keys are stored lowercased `artist|album`; this puts them back into
    /// something a person can recognise in a list.
    private func readable(_ key: String) -> String {
        let parts = key.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return key }
        let artist = parts[0].capitalized, album = parts[1].capitalized
        return album.isEmpty ? artist : "\(album) — \(artist)"
    }

    // MARK: - Pieces

    private func sectionTitle(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppFont.ui(12, .semibold))
                .foregroundStyle(Verso.cream.opacity(0.88))
            Text(detail)
                .font(AppFont.ui(11))
                .foregroundStyle(Verso.cream.opacity(0.45))
                .frame(maxWidth: 470, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
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
                    .foregroundStyle(Verso.cream.opacity(0.82))
                Spacer()
                Text(format(value.wrappedValue))
                    .font(AppFont.ui(11).monospacedDigit())
                    .foregroundStyle(Verso.cream.opacity(0.48))
            }
            Slider(value: value, in: range)
                .controlSize(.small)
                .tint(Verso.violet)
            Text(detail)
                .font(AppFont.ui(10.5))
                .foregroundStyle(Verso.cream.opacity(0.38))
        }
    }
}
