import AppKit

/// Now-playing state from Apple Music's public AppleScript dictionary.
/// Track changes arrive as distributed notifications; playback position is
/// re-anchored on a slow timer and extrapolated from the clock in between,
/// so word-level lyric sync stays fluid without firing an Apple event on
/// every frame.
final class NowPlayingMonitor: ObservableObject {
    static let shared = NowPlayingMonitor()

    struct Track: Equatable {
        var title: String
        var artist: String
        var duration: Double
        var genre: String?
        var album: String?

        static func == (lhs: Track, rhs: Track) -> Bool {
            lhs.title == rhs.title && lhs.artist == rhs.artist
        }
    }

    @Published private(set) var current: Track? {
        didSet {
            if current == nil {
                if idleSince == nil { idleSince = Date() }
            } else {
                idleSince = nil
            }
        }
    }
    /// When playback stopped, so the "nothing playing" notice can fade out
    /// rather than sitting on the wallpaper indefinitely.
    @Published private(set) var idleSince: Date?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var isPlaying = false
    /// Apple Music's animated cover, for the minority of albums that have one.
    @Published private(set) var motionArtwork: MotionArtworkProvider.Motion?

    private let musicBundleID = "com.apple.Music"
    private let scriptQueue = DispatchQueue(label: "com.akki.wavelength.applescript")
    private var compiledScripts: [String: NSAppleScript] = [:]
    private var anchor: (position: TimeInterval, at: Date)?
    private var syncTimer: Timer?

    private init() {
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleChange),
            name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil
        )
        refresh()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.resyncPosition()
        }
    }

    /// Nudges lyrics slightly ahead of the raw clock. An Apple event only
    /// tells us where Music *was*, and the audio itself is buffered a little
    /// behind that, so a small lead lands the highlight on the beat instead
    /// of just after it.
    private static let syncLead: TimeInterval = 0.16

    /// Smoothly extrapolated playback position, safe to call every frame.
    @MainActor
    func playbackTime() -> TimeInterval {
        guard let anchor else { return 0 }
        guard isPlaying else { return anchor.position }
        return anchor.position + Date().timeIntervalSince(anchor.at) + Self.syncLead
    }

    /// Executes a position query and returns the value together with the
    /// instant it most likely refers to.
    ///
    /// A round-trip runs ~160ms. Stamping the anchor when the call *returns*
    /// therefore back-dates playback by that much and drags every lyric late;
    /// Music actually sampled the value somewhere inside the call, so the
    /// midpoint is the better estimate.
    private func sampledPosition() -> (position: TimeInterval, at: Date)? {
        let startedAt = Date()
        guard let position = doubleResult("tell application \"Music\" to player position") else { return nil }
        let midpoint = startedAt.addingTimeInterval(Date().timeIntervalSince(startedAt) / 2)
        return (position, midpoint)
    }

    @objc private func handleChange() {
        refresh()
    }

    func refresh() {
        scriptQueue.async { [weak self] in
            guard let self else { return }
            guard self.isMusicRunning(),
                  self.boolResult("tell application \"Music\" to player state is playing") == true,
                  let title = self.stringResult("tell application \"Music\" to name of current track"),
                  !title.isEmpty
            else {
                DispatchQueue.main.async {
                    self.current = nil
                    self.artwork = nil
                    self.isPlaying = false
                    self.anchor = nil
                }
                return
            }

            let artist = self.stringResult("tell application \"Music\" to artist of current track") ?? ""
            let duration = self.doubleResult("tell application \"Music\" to duration of current track") ?? 0
            let genre = self.stringResult("tell application \"Music\" to genre of current track")
            let album = self.stringResult("tell application \"Music\" to album of current track")
            let sample = self.sampledPosition()
            let track = Track(title: title, artist: artist, duration: duration, genre: genre, album: album)

            DispatchQueue.main.async {
                let isNewTrack = self.current != track
                self.current = track
                self.isPlaying = true
                if let sample { self.anchor = (sample.position, sample.at) }
                if isNewTrack {
                    self.artwork = nil
                    self.motionArtwork = nil
                    self.loadArtwork(for: track)
                    self.loadMotionArtwork(for: track)
                }
            }
        }
    }

    /// Music's own artwork is the authority -- it is the exact cover for the
    /// exact edition playing. A catalogue search is only a fallback, and a
    /// fuzzy one: "Songs from the Big Chair" and its Super Deluxe reissue are
    /// different covers for the same song title.
    private func loadArtwork(for track: Track) {
        scriptQueue.async { [weak self] in
            guard let self else { return }
            let local = self.musicArtwork()
            DispatchQueue.main.async {
                guard self.current == track else { return }
                if let local {
                    self.artwork = local
                    return
                }
                Task { @MainActor in
                    let remote = await ArtworkProvider.shared.artwork(
                        title: track.title, artist: track.artist,
                        album: track.album, duration: track.duration
                    )
                    guard self.current == track else { return }
                    self.artwork = remote
                }
            }
        }
    }

    private func loadMotionArtwork(for track: Track) {
        Task { @MainActor in
            let motion = await MotionArtworkProvider.shared.motion(
                album: track.album, artist: track.artist, title: track.title
            )
            guard self.current == track else { return }
            self.motionArtwork = motion
        }
    }

    /// Reads the cover straight out of Music. Availability varies -- a track
    /// streamed moments ago may report no artwork until it caches -- so the
    /// count is checked before asking for the bytes.
    private func musicArtwork() -> NSImage? {
        let count = execute("tell application \"Music\" to count of artworks of current track")?.int32Value ?? 0
        guard count > 0 else { return nil }

        for property in ["data", "raw data"] {
            guard let descriptor = execute("tell application \"Music\" to get \(property) of artwork 1 of current track") else { continue }
            let data = descriptor.data
            if !data.isEmpty, let image = NSImage(data: data) { return image }
        }
        return nil
    }

    private func resyncPosition() {
        scriptQueue.async { [weak self] in
            guard let self else { return }
            guard self.boolResult("tell application \"Music\" to player state is playing") == true else {
                DispatchQueue.main.async { self.isPlaying = false }
                return
            }
            guard let sample = self.sampledPosition() else { return }
            DispatchQueue.main.async {
                self.isPlaying = true
                self.anchor = (sample.position, sample.at)
            }
        }
    }

    // MARK: - Transport

    func playPause() {
        command("tell application \"Music\" to playpause")
    }

    func nextTrack() {
        command("tell application \"Music\" to next track")
    }

    func previousTrack() {
        command("tell application \"Music\" to previous track")
    }

    func seek(to seconds: TimeInterval) {
        // Anchor optimistically so the lyric highlight jumps immediately
        // rather than waiting for the next resync tick.
        anchor = (seconds, Date())
        scriptQueue.async { [weak self] in
            guard let self else { return }
            // Not cached: the source differs on every call, so caching it
            // would grow the script table without bound.
            _ = NSAppleScript(source: "tell application \"Music\" to set player position to \(Int(seconds))")?
                .executeAndReturnError(nil)
            self.resyncPosition()
        }
    }

    private func command(_ source: String) {
        scriptQueue.async { [weak self] in
            guard let self else { return }
            _ = self.execute(source)
            self.refresh()
        }
    }

    private func isMusicRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == musicBundleID }
    }

    /// Compiled scripts are cached because compiling on every poll is far
    /// more expensive than executing. Confined to `scriptQueue`.
    private func execute(_ source: String) -> NSAppleEventDescriptor? {
        let script: NSAppleScript
        if let cached = compiledScripts[source] {
            script = cached
        } else {
            guard let fresh = NSAppleScript(source: source) else { return nil }
            compiledScripts[source] = fresh
            script = fresh
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        return errorInfo == nil ? result : nil
    }

    private func stringResult(_ source: String) -> String? { execute(source)?.stringValue }
    private func boolResult(_ source: String) -> Bool? { execute(source)?.booleanValue }
    private func doubleResult(_ source: String) -> Double? { execute(source)?.doubleValue }
}
