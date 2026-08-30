import Combine
import Foundation

/// Owns the fetched lyric lines for the current track. Deliberately does not
/// track the active line/word itself -- the view derives those every frame
/// from `NowPlayingMonitor.playbackTime()`, which keeps the highlight smooth
/// instead of quantised to a publisher's tick rate.
@MainActor
final class LyricsViewModel: ObservableObject {
    /// Shared so the wallpaper and the controls panel -- which live in
    /// separate windows -- read the same lyrics instead of each fetching
    /// their own copy.
    static let shared = LyricsViewModel()

    @Published var lines: [LyricsFetcher.Line] = [] {
        didSet { dynamics = MusicDynamics(lines: lines) }
    }
    /// Untimed lyrics, shown as a static block when no timed source has the
    /// track.
    @Published var plainLines: [String] = []
    @Published var isLoading = false
    @Published var notFound = false
    /// When the miss was reported, so the notice can retire itself instead of
    /// sitting on the wallpaper for the rest of the song.
    private(set) var notFoundAt: Date?
    /// Timing precision and source of the current lyrics, for the controls.
    @Published var provenance: LyricsFetcher.Provenance?

    /// Rebuilt whenever lyrics change; drives the reactive background.
    private(set) var dynamics = MusicDynamics(lines: [])

    private var cancellables: Set<AnyCancellable> = []
    private var lastKey: String?

    private init() {
        NowPlayingMonitor.shared.$current
            .removeDuplicates()
            .sink { [weak self] track in self?.handleTrackChange(track) }
            .store(in: &cancellables)
        handleTrackChange(NowPlayingMonitor.shared.current)
    }

    /// How densely the track is sung -- the closest proxy to tempo available
    /// without the audio, and the main input to the mood read.
    var wordsPerSecond: Double {
        guard let first = lines.first, let last = lines.last else { return 0 }
        let span = last.end - first.start
        guard span > 1 else { return 0 }
        let totalWords = lines.reduce(0) { $0 + $1.words.count }
        return Double(totalWords) / span
    }

    /// Index of the line currently being sung, if any.
    func activeLineIndex(at time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        var result: Int?
        for (index, line) in lines.enumerated() {
            if line.start <= time { result = index } else { break }
        }
        return result
    }

    /// Index of the word currently being sung within `line`, if any.
    func activeWordIndex(in line: LyricsFetcher.Line, at time: TimeInterval) -> Int? {
        guard !line.words.isEmpty else { return nil }
        for (index, word) in line.words.enumerated() where time >= word.start && time < word.end {
            return index
        }
        return nil
    }

    private func handleTrackChange(_ track: NowPlayingMonitor.Track?) {
        guard let track else {
            lastKey = nil
            lines = []
            plainLines = []
            provenance = nil
            notFound = false
            notFoundAt = nil
            isLoading = false
            return
        }
        let key = "\(track.title)|\(track.artist)"
        guard key != lastKey else { return }
        lastKey = key
        lines = []
        plainLines = []
        provenance = nil
        notFound = false
        notFoundAt = nil
        isLoading = true

        Task {
            let result = await LyricsFetcher.shared.lyrics(
                title: track.title, artist: track.artist,
                album: track.album, duration: track.duration
            )
            guard key == self.lastKey else { return }
            self.isLoading = false
            switch result {
            case .synced(let synced, let provenance) where !synced.isEmpty:
                self.lines = synced
                self.provenance = provenance
            case .plain(let plain, let provenance) where !plain.isEmpty:
                self.plainLines = plain
                self.provenance = provenance
            default:
                self.notFound = true
                self.notFoundAt = Date()
            }
        }
    }
}
