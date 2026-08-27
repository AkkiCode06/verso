import Foundation

/// Fetches *timestamped* lyrics from lrclib.net -- a free, unauthenticated,
/// community-run database. Plain (untimed) lyrics are rejected outright: an
/// unsynced wall of text has no place in a live display.
///
/// Two synced formats are offered. `lyricsfile` (YAML) is preferred because
/// each line carries an explicit end time and instrumental breaks are marked
/// with a lone note glyph; the classic `syncedLyrics` LRC blob is the
/// fallback, where a line's end has to be inferred from the next line.
///
/// Neither format carries word-level timing -- LRCLIB simply does not
/// publish it, and no free source does (Spotify's needs auth, Musixmatch's
/// needs a paid key). Word timings below are therefore derived by splitting
/// each line's window across its words, weighted by length. It tracks the
/// vocal closely but it is an approximation, not true syllable sync.
final class LyricsFetcher {
    static let shared = LyricsFetcher()

    struct Word {
        var text: String
        var start: TimeInterval
        var end: TimeInterval
    }

    struct Line {
        var start: TimeInterval
        var end: TimeInterval
        var text: String
        var words: [Word]
        var isInstrumental: Bool
    }

    /// How precisely the lyrics are timed, and where they came from -- shown
    /// on the controls so it is clear whether the highlight is tracking each
    /// word or just the line.
    struct Provenance: Equatable {
        var precision: String
        var source: String

        var label: String { "\(precision) · \(source)" }
    }

    /// Synced lyrics when a timed source has the track; otherwise the plain
    /// text, shown as a static block rather than nothing at all.
    enum Result {
        case synced([Line], Provenance)
        case plain([String], Provenance)
    }

    private var cache: [String: Result] = [:]

    func lyrics(title: String, artist: String, album: String? = nil, duration: Double) async -> Result? {
        let cacheKey = "\(title)|\(artist)"
        if let cached = cache[cacheKey] { return cached }

        // First choice: Lyrics+ / KPoe, which serves syllable-level timing
        // sourced from Apple Music itself -- the same lyrics Music.app shows.
        if let hit = await KPoeLyricsProvider.lines(
            title: title, artist: artist, album: album, duration: duration
        ) {
            let result = Result.synced(hit.lines, Provenance(precision: "Word-by-word", source: hit.source))
            cache[cacheKey] = result
            return result
        }

        // Then NetEase's "yrc" karaoke format, which carries real per-word
        // timing. LRCLIB below is line-level only, so its word timings have
        // to be inferred.
        if let wordLevel = await NetEaseLyricsProvider.wordLevelLines(
            title: title, artist: artist, duration: duration
        ) {
            let result = Result.synced(wordLevel, Provenance(precision: "Word-by-word", source: "NetEase"))
            cache[cacheKey] = result
            return result
        }

        let primaryArtist = artist
            .components(separatedBy: CharacterSet(charactersIn: "&,"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? artist

        var plainFallback: [String] = []

        for candidate in Set([artist, primaryArtist]) {
            guard let payload = await fetch(title: title, artist: candidate) else { continue }

            var lines: [Line] = []
            if let file = payload.lyricsfile, !file.isEmpty {
                lines = Self.parseLyricsFile(file)
            }
            if lines.isEmpty, let lrc = payload.syncedLyrics, !lrc.isEmpty {
                lines = Self.parseLRC(lrc, trackDuration: duration)
            }
            if !lines.isEmpty {
                let result = Result.synced(lines, Provenance(precision: "Line synced", source: "LRCLIB"))
                cache[cacheKey] = result
                return result
            }
            if plainFallback.isEmpty, let plain = payload.plainLyrics, !plain.isEmpty {
                plainFallback = plain
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }

        guard !plainFallback.isEmpty else { return nil }
        let result = Result.plain(plainFallback, Provenance(precision: "Not synced", source: "LRCLIB"))
        cache[cacheKey] = result
        return result
    }

    private func fetch(title: String, artist: String) async -> Response? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        guard let url = components?.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("Wavelength v0.1 (macOS now-playing lyrics)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            return nil
        }
    }

    private struct Response: Decodable {
        var syncedLyrics: String?
        var lyricsfile: String?
        var plainLyrics: String?
    }

    // MARK: - lyricsfile (YAML) parsing

    /// The schema is small and rigidly generated, so a line scanner beats
    /// pulling in a YAML dependency:
    ///   lines:
    ///   - text: I've been tryna call
    ///     start_ms: 27160
    ///     end_ms: 29960
    private static func parseLyricsFile(_ yaml: String) -> [Line] {
        var entries: [(start: Double, end: Double, text: String)] = []
        var pendingText: String?
        var pendingStart: Double?
        var pendingEnd: Double?
        var insideLines = false

        func flush() {
            defer { pendingText = nil; pendingStart = nil; pendingEnd = nil }
            guard let text = pendingText, let start = pendingStart else { return }
            entries.append((start, pendingEnd ?? start + 4, text))
        }

        for rawLine in yaml.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = String(rawLine).trimmingCharacters(in: .whitespaces)
            if trimmed == "lines:" { insideLines = true; continue }
            guard insideLines else { continue }

            if trimmed.hasPrefix("- text:") {
                flush()
                pendingText = unquote(String(trimmed.dropFirst("- text:".count)).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("text:"), pendingText == nil {
                pendingText = unquote(String(trimmed.dropFirst("text:".count)).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("start_ms:") {
                pendingStart = Double(trimmed.dropFirst("start_ms:".count).trimmingCharacters(in: .whitespaces)).map { $0 / 1000 }
            } else if trimmed.hasPrefix("end_ms:") {
                pendingEnd = Double(trimmed.dropFirst("end_ms:".count).trimmingCharacters(in: .whitespaces)).map { $0 / 1000 }
            }
        }
        flush()
        return entries.map { makeLine(text: $0.text, start: $0.start, end: $0.end) }
    }

    private static func unquote(_ value: String) -> String {
        var result = value
        for quote in ["'", "\""] where result.hasPrefix(quote) && result.hasSuffix(quote) && result.count >= 2 {
            result = String(result.dropFirst().dropLast())
            result = result.replacingOccurrences(of: quote + quote, with: quote)
            break
        }
        return result
    }

    // MARK: - LRC parsing (fallback)

    private static func parseLRC(_ text: String, trackDuration: Double) -> [Line] {
        let pattern = #"\[(\d{2}):(\d{2})[.:](\d{2,3})\]\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var parsed: [(time: TimeInterval, text: String)] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(rawLine)
            guard let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
                  let minuteRange = Range(match.range(at: 1), in: s),
                  let secondRange = Range(match.range(at: 2), in: s),
                  let fractionRange = Range(match.range(at: 3), in: s),
                  let textRange = Range(match.range(at: 4), in: s),
                  let minutes = Double(s[minuteRange]),
                  let seconds = Double(s[secondRange]),
                  let fraction = Double(s[fractionRange])
            else { continue }
            let divisor = s[fractionRange].count == 3 ? 1000.0 : 100.0
            parsed.append((minutes * 60 + seconds + fraction / divisor,
                           s[textRange].trimmingCharacters(in: .whitespaces)))
        }
        guard !parsed.isEmpty else { return [] }
        parsed.sort { $0.time < $1.time }

        return parsed.enumerated().map { index, entry in
            let end: TimeInterval
            if index + 1 < parsed.count {
                end = parsed[index + 1].time
            } else if trackDuration > entry.time {
                end = trackDuration
            } else {
                end = entry.time + 4
            }
            return makeLine(text: entry.text, start: entry.time, end: end)
        }
    }

    // MARK: - Shared line construction

    private static func makeLine(text: String, start: Double, end: Double) -> Line {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        // A lone note glyph marks an instrumental break rather than a lyric.
        let instrumental = cleaned.isEmpty || cleaned.allSatisfy { "♪♫•·-–—".contains($0) || $0.isWhitespace }
        return Line(
            start: start,
            end: end,
            text: instrumental ? "" : cleaned,
            words: instrumental ? [] : distributeWords(in: cleaned, from: start, to: end),
            isInstrumental: instrumental
        )
    }

    /// Splits a line's window across its words proportionally to their length,
    /// so longer words hold emphasis longer -- far more natural than an even
    /// split. The window is trimmed slightly because a sung line normally
    /// finishes before the next one begins.
    private static func distributeWords(in text: String, from start: TimeInterval, to end: TimeInterval) -> [Word] {
        let tokens = text.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return [] }

        let window = max(end - start, 0.3)
        let usable = min(window, max(Double(tokens.count) * 0.42, window * 0.88))
        let weights = tokens.map { Double($0.count) + 1.5 }
        let totalWeight = weights.reduce(0, +)

        var words: [Word] = []
        var cursor = start
        for (token, weight) in zip(tokens, weights) {
            let slice = usable * (weight / totalWeight)
            words.append(Word(text: token, start: cursor, end: cursor + slice))
            cursor += slice
        }
        return words
    }
}
