import SwiftUI

/// Transport controls that fade in over the centre of the wallpaper, in the
/// same place the lyrics occupy. Deliberately chrome-free: no card, no
/// border, no material -- just artwork, type and controls floating on the
/// gradient, with a soft edgeless scrim for legibility.
struct MediaControlsView: View {
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @ObservedObject private var hover = HoverState.shared
    @ObservedObject private var lyrics = LyricsViewModel.shared

    /// Same face the lyrics use, so the panel speaks in the track's voice.
    private var mood: TrackMood {
        TrackMood.derive(genre: nowPlaying.current?.genre,
                         wordsPerSecond: lyrics.wordsPerSecond,
                         artworkSaturation: 0.5, seed: 0)
    }

    var body: some View {
        // No scrim layer: a radial gradient here gets clipped to the window's
        // bounds and reads as a grey rectangle floating on the wallpaper.
        // Per-element shadows carry legibility instead.
        VStack(spacing: 13) {
            if let artwork = nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.55), radius: 20, y: 7)
            }

            VStack(spacing: 3) {
                Text(nowPlaying.current?.title ?? "Nothing playing")
                    .font(Settings.shared.uiFont(size: 19, bold: true, mood: mood))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.current?.artist ?? "")
                    .font(Settings.shared.uiFont(size: 13, mood: mood))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)

                // How precisely the lyrics on screen are timed, and where
                // they came from.
                if let provenance = lyrics.provenance {
                    Text(provenance.label)
                        .font(Settings.shared.uiFont(size: 10, mood: mood))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
            .shadow(color: .black.opacity(0.6), radius: 7, y: 1)

            scrubber
                .frame(width: 290)
                .padding(.top, 2)

            transport
        }
        .padding(.horizontal, 24)
        .opacity(hover.isActive ? 1 : 0)
        .scaleEffect(hover.isActive ? 1 : 0.97)
        .animation(.easeOut(duration: 0.28), value: hover.isActive)
    }

    private var scrubber: some View {
        // 5Hz is ample for a progress bar and far cheaper than redrawing
        // every display frame.
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            let duration = max(nowPlaying.current?.duration ?? 1, 1)
            let elapsed = min(nowPlaying.playbackTime(), duration)

            VStack(spacing: 8) {
                MinimalScrubber(
                    progress: elapsed / duration,
                    onSeek: { fraction in nowPlaying.seek(to: fraction * duration) }
                )
                HStack {
                    Text(timestamp(elapsed))
                    Spacer()
                    Text(timestamp(duration))
                }
                .font(Settings.shared.uiFont(size: 11, mood: mood).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
            }
            .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
        }
    }

    private var transport: some View {
        HStack(spacing: 26) {
            controlButton("backward.fill", size: 17) { nowPlaying.previousTrack() }
            controlButton(nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 23) { nowPlaying.playPause() }
            controlButton("forward.fill", size: 17) { nowPlaying.nextTrack() }
        }
        .shadow(color: .black.opacity(0.5), radius: 10, y: 2)
    }

    private func controlButton(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size * 2.1, height: size * 2.1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func timestamp(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// A hairline progress bar with no slider chrome -- tap or drag anywhere on
/// it to seek.
private struct MinimalScrubber: View {
    let progress: Double
    var onSeek: (Double) -> Void

    @State private var dragFraction: Double?

    var body: some View {
        GeometryReader { geometry in
            let fraction = min(max(dragFraction ?? progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.24))
                    .frame(height: 4)
                Capsule()
                    .fill(.white.opacity(0.92))
                    .frame(width: geometry.size.width * fraction, height: 4)
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .offset(x: geometry.size.width * fraction - 5)
                    .opacity(dragFraction == nil ? 0.85 : 1)
            }
            .frame(height: 22)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragFraction = min(max(value.location.x / geometry.size.width, 0), 1)
                    }
                    .onEnded { value in
                        let target = min(max(value.location.x / geometry.size.width, 0), 1)
                        dragFraction = nil
                        onSeek(target)
                    }
            )
        }
        .frame(height: 22)
    }
}
