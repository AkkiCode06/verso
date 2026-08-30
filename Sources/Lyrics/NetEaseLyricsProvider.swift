import Foundation

/// NetEase Cloud Music publishes a word-level karaoke format ("yrc") that is
/// reachable with no API key. Each line carries per-word start times and
/// durations, e.g.
///
///   [32820,4800](32820,540,0)Maybe (33360,120,0)you (33480,180,0)can ...
///
/// i.e. `[lineStartMs,lineDurationMs]` followed by `(wordStartMs,wordDurationMs,0)word`
/// repeated. This is genuine syllable-accurate timing rather than the
/// derived-from-line-length approximation LRCLIB forces.
///
/// Availability is best for tracks in NetEase's catalogue; when a match is
/// not confident, callers fall back to LRCLIB's line-level data.
enum NetEaseLyricsProvider {
    /// Longest a single sung word is allowed to hold. Real sustains top out
    /// around 3s; anything beyond is bad data, not singing.
    private static let maxWordDuration: Double = 5.0

    static func wordLevelLines(title: String, artist: String, duration: Double) async -> [LyricsFetcher.Line]? {
        guard let songID = await songID(title: title, artist: artist, duration: duration),
              let yrc = await yrcLyric(id: songID)
        else { return nil }
        let lines = parseYRC(yrc)
        return lines.isEmpty ? nil : lines
    }

    // MARK: - Search

    private static func songID(title: String, artist: String, duration: Double) async -> Int? {
        var components = URLComponents(string: "https://music.163.com/api/search/get")
        components?.queryItems = [
            URLQueryItem(name: "s", value: "\(title) \(artist)"),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "8"),
        ]
        guard let url = components?.url, let data = await get(url) else { return nil }
        guard let payload = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let songs = payload.result?.songs
        else { return nil }

        let wantedTitle = normalize(title)
        let wantedArtist = normalize(artist)

        // Search returns many editions of a popular track -- radio edits,
        // live cuts, remixes -- all with matching titles and artists. Taking
        // the first acceptable hit picks the wrong edit often enough to
        // matter, and a wrong edit means every word timestamp drifts. So
        // score every candidate and keep the best, weighting runtime most
        // heavily since it is the signal that actually separates editions.
        struct Candidate {
            var id: Int
            var score: Int
            var durationDelta: Double
        }

        var best: Candidate?
        for song in songs {
            guard matches(normalize(song.name), wantedTitle) else { continue }

            let artistMatches = song.artists?.contains { candidate in
                matches(normalize(candidate.name), wantedArtist)
            } ?? false

            let delta = duration > 0 && (song.duration ?? 0) > 0
                ? abs(Double(song.duration ?? 0) / 1000 - duration)
                : Double.greatestFiniteMagnitude

            var score = 0
            if delta < 2 { score += 5 } else if delta < 5 { score += 4 }
            if artistMatches { score += 2 }
            guard score > 0 else { continue }

            let candidate = Candidate(id: song.id, score: score, durationDelta: delta)
            if let current = best {
                let better = candidate.score > current.score
                    || (candidate.score == current.score && candidate.durationDelta < current.durationDelta)
                if better { best = candidate }
            } else {
                best = candidate
            }
        }
        return best?.id
    }

    private static func matches(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a == b || a.contains(b) || b.contains(a)
    }

    private static func normalize(_ value: String) -> String {
        var text = value.lowercased()
        for pattern in [#"\([^)]*\)"#, #"\[[^\]]*\]"#, #"feat\..*"#, #"ft\..*"#] {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return text.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }

    // MARK: - Lyric fetch

    private static func yrcLyric(id: Int) async -> String? {
        guard let url = URL(string: "https://music.163.com/api/song/lyric?id=\(id)&lv=1&kv=1&tv=-1&yv=1"),
              let data = await get(url),
              let payload = try? JSONDecoder().decode(LyricResponse.self, from: data)
        else { return nil }
        let yrc = payload.yrc?.lyric
        return (yrc?.isEmpty == false) ? yrc : nil
    }

    private static func get(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 12
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return data
        } catch {
            return nil
        }
    }

    // MARK: - yrc parsing

    private static func parseYRC(_ yrc: String) -> [LyricsFetcher.Line] {
        guard let headerRegex = try? NSRegularExpression(pattern: #"^\[(\d+),(\d+)\]"#),
              let wordRegex = try? NSRegularExpression(pattern: #"\((\d+),(\d+),\d+\)([^(]*)"#)
        else { return [] }

        var lines: [LyricsFetcher.Line] = []
        for rawLine in yrc.split(separator: "\n") {
            let s = String(rawLine)
            let fullRange = NSRange(s.startIndex..., in: s)
            guard let header = headerRegex.firstMatch(in: s, range: fullRange),
                  let startRange = Range(header.range(at: 1), in: s),
                  let durationRange = Range(header.range(at: 2), in: s),
                  let startMs = Double(s[startRange]),
                  let durationMs = Double(s[durationRange])
            else { continue }

            var words: [LyricsFetcher.Word] = []
            var fullText = ""

            wordRegex.enumerateMatches(in: s, range: fullRange) { match, _, _ in
                guard let match,
                      let wordStartRange = Range(match.range(at: 1), in: s),
                      let wordDurationRange = Range(match.range(at: 2), in: s),
                      let textRange = Range(match.range(at: 3), in: s),
                      let wordStart = Double(s[wordStartRange]),
                      let wordDuration = Double(s[wordDurationRange])
                else { return }

                let piece = String(s[textRange])
                fullText += piece
                let trimmed = piece.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }

                // yrc occasionally parks a huge duration on a trailing token
                // (a lone "!" carrying 30+ seconds across an instrumental).
                // Left alone that pins the word at full emphasis and glow, so
                // cap what any single word can hold.
                let start = wordStart / 1000
                let end = start + min(max(wordDuration / 1000, 0.06), maxWordDuration)

                // Bare punctuation is its own token in yrc; fold it into the
                // preceding word so it does not float as a separate chip. Its
                // timing is not meaningful, so the word's own end stands.
                if trimmed.allSatisfy({ !$0.isLetter && !$0.isNumber }), var previous = words.popLast() {
                    previous.text += trimmed
                    words.append(previous)
                    return
                }
                words.append(LyricsFetcher.Word(text: trimmed, start: start, end: end))
            }

            let cleaned = fullText.trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty, !isCredits(cleaned) else { continue }

            lines.append(LyricsFetcher.Line(
                start: startMs / 1000,
                end: (startMs + durationMs) / 1000,
                text: cleaned,
                words: words,
                isInstrumental: words.isEmpty
            ))
        }
        return lines
    }

    /// NetEase prefixes most tracks with production credits in Chinese; they
    /// are timed like lyrics but are not lyrics.
    private static let creditMarkers = [
        "制作人", "作词", "作曲", "编曲", "混音", "录音", "母带",
        "出品", "发行", "监制", "吉他", "贝斯", "鼓", "键盘", "和声", "制作",
    ]

    private static func isCredits(_ text: String) -> Bool {
        creditMarkers.contains { text.contains($0) }
    }

    // MARK: - Payloads

    private struct SearchResponse: Decodable {
        struct Result: Decodable { var songs: [Song]? }
        var result: Result?
    }

    private struct Song: Decodable {
        struct Artist: Decodable { var name: String }
        var id: Int
        var name: String
        var artists: [Artist]?
        var duration: Int?
    }

    private struct LyricResponse: Decodable {
        struct Lyric: Decodable { var lyric: String? }
        var yrc: Lyric?
    }
}
