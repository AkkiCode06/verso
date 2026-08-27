import SwiftUI

/// The menu bar dropdown: what's playing, transport, and a way into the rest.
/// Everything configurable lives in the settings window instead, so this stays
/// something you can read at a glance.
struct MenuBarView: View {
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @ObservedObject private var lyrics = LyricsViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nowPlayingCard
            transport
                .padding(.top, 12)
                .padding(.bottom, 4)

            Divider().padding(.vertical, 8)

            menuItem("Settings…", symbol: "slider.horizontal.3") {
                SettingsWindowController.shared.present()
            }
            menuItem("Guide", symbol: "sparkles.rectangle.stack") {
                OnboardingWindowController.shared.present()
            }

            Divider().padding(.vertical, 8)

            menuItem("Quit Wavelength", symbol: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 268)
    }

    // MARK: - Now playing

    private var nowPlayingCard: some View {
        HStack(spacing: 10) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlaying.current?.title ?? "Nothing playing")
                    .font(AppFont.ui(12.5, .semibold))
                    .lineLimit(1)
                Text(nowPlaying.current?.artist ?? "Play something in Music")
                    .font(AppFont.ui(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let provenance = lyrics.provenance {
                    Text(provenance.label)
                        .font(AppFont.ui(9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let artwork = nowPlaying.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "music.note")
                        .font(AppFont.ui(14))
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var transport: some View {
        HStack(spacing: 22) {
            Spacer()
            transportButton("backward.fill", 13) { nowPlaying.previousTrack() }
            transportButton(nowPlaying.isPlaying ? "pause.fill" : "play.fill", 17) { nowPlaying.playPause() }
            transportButton("forward.fill", 13) { nowPlaying.nextTrack() }
            Spacer()
        }
    }

    private func transportButton(_ symbol: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .frame(width: size * 2, height: size * 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menu rows

    private func menuItem(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(AppFont.ui(11))
                    .frame(width: 15)
                Text(title).font(AppFont.ui(12))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
