import Compression
import Foundation

/// Lyrics from the Lyrics+ / KPoe community nodes, which aggregate
/// syllable-level karaoke lyrics -- including Apple Music's own, the same
/// ones Music.app shows. Free, no key.
///
/// Preferred over NetEase because it returns `"type": "Word"` with a
/// `syllabus` array per line: real per-syllable timing sourced from Apple,
/// so the highlight matches what the user hears in their own app.
enum KPoeLyricsProvider {
    /// Mirrors are tried in order; community nodes come and go.
    private static let hosts = [
        "https://lyricsplus.prjktla.workers.dev",
        "https://lyricsplus.binimum.org",
        "https://lyricsplus.prjktla.my.id",
    ]

    static func lines(
        title: String, artist: String, album: String?, duration: Double
    ) async -> (lines: [LyricsFetcher.Line], source: String)? {
        for host in hosts {
            guard let payload = await fetch(host: host, title: title, artist: artist, album: album, duration: duration),
                  let entries = payload.lyrics, !entries.isEmpty
            else { continue }

            let lines = entries.compactMap { convert($0) }.filter { !$0.words.isEmpty }
            guard !lines.isEmpty else { continue }

            // The node reports which upstream it pulled from, e.g. "Apple" or
            // "Lyrics+ (via Apple with QQ)"; keep just the leading name.
            let raw = payload.metadata?.source ?? "Lyrics+"
            let source = raw.components(separatedBy: " (").first ?? raw
            return (lines, source)
        }
        return nil
    }

    // MARK: - Fetch

    private static func fetch(
        host: String, title: String, artist: String, album: String?, duration: Double
    ) async -> Response? {
        var components = URLComponents(string: "\(host)/v2/lyrics/get")
        var query = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "artist", value: artist),
        ]
        if duration > 0 { query.append(URLQueryItem(name: "duration", value: String(Int(duration)))) }
        if let album, !album.isEmpty { query.append(URLQueryItem(name: "album", value: album)) }
        components?.queryItems = query
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Wavelength/0.1 (macOS now-playing lyrics)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            // 429 carries a short cooldown; treat as a miss so the caller
            // falls through to the next source rather than stalling.
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            // These nodes serve a gzip body under `content-type:
            // application/json` with no `Content-Encoding` header, so
            // URLSession leaves it compressed. Inflate it ourselves.
            let payload = gunzipIfNeeded(data)
            return try JSONDecoder().decode(Response.self, from: payload)
        } catch {
            return nil
        }
    }

    // MARK: - Conversion

    private static func convert(_ entry: Entry) -> LyricsFetcher.Line? {
        let start = entry.time / 1000
        let end = (entry.time + max(entry.duration, 1)) / 1000
        let text = entry.text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        var words: [LyricsFetcher.Word] = []
        if let syllabus = entry.syllabus, !syllabus.isEmpty {
            words = mergeSyllables(syllabus)
        }
        guard !words.isEmpty else { return nil }

        return LyricsFetcher.Line(
            start: start, end: end, text: text, words: words, isInstrumental: false
        )
    }

    /// A syllable is not a word: "con", "trol", "la" arrive as three entries
    /// and would be laid out as three separate chunks. Syllables are joined
    /// back into words -- a trailing space marks a word boundary -- while the
    /// word keeps the first syllable's start and the last one's end.
    private static func mergeSyllables(_ syllabus: [Syllable]) -> [LyricsFetcher.Word] {
        var words: [LyricsFetcher.Word] = []
        var buffer = ""
        var wordStart: Double?
        var wordEnd: Double = 0

        func flush() {
            let trimmed = buffer.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, let begin = wordStart {
                words.append(LyricsFetcher.Word(text: trimmed, start: begin, end: max(wordEnd, begin + 0.06)))
            }
            buffer = ""
            wordStart = nil
            wordEnd = 0
        }

        for syllable in syllabus {
            let start = syllable.time / 1000
            let end = (syllable.time + max(syllable.duration, 1)) / 1000
            if wordStart == nil { wordStart = start }
            wordEnd = max(wordEnd, end)
            buffer += syllable.text
            if syllable.text.hasSuffix(" ") { flush() }
        }
        flush()
        return words
    }

    // MARK: - gzip

    private static func gunzipIfNeeded(_ data: Data) -> Data {
        guard data.count > 18, data[data.startIndex] == 0x1f, data[data.startIndex + 1] == 0x8b else {
            return data
        }
        // Step over the gzip header, including any optional fields the
        // flag byte announces, to reach the raw DEFLATE stream.
        var index = data.startIndex + 10
        let flags = data[data.startIndex + 3]
        if flags & 0x04 != 0, index + 1 < data.endIndex {
            let extraLength = Int(data[index]) | Int(data[index + 1]) << 8
            index += 2 + extraLength
        }
        if flags & 0x08 != 0 {
            while index < data.endIndex, data[index] != 0 { index += 1 }
            index += 1
        }
        if flags & 0x10 != 0 {
            while index < data.endIndex, data[index] != 0 { index += 1 }
            index += 1
        }
        if flags & 0x02 != 0 { index += 2 }
        guard index < data.endIndex else { return data }

        return inflate(data.subdata(in: index..<data.endIndex)) ?? data
    }

    /// Apple's COMPRESSION_ZLIB is raw DEFLATE, which is exactly what sits
    /// inside a gzip container once the header is skipped.
    private static func inflate(_ input: Data) -> Data? {
        let bufferSize = 64 * 1024
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destination.deallocate() }

        var stream = compression_stream(
            dst_ptr: destination, dst_size: bufferSize,
            src_ptr: destination, src_size: 0, state: nil
        )
        guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK
        else { return nil }
        defer { compression_stream_destroy(&stream) }

        return input.withUnsafeBytes { raw -> Data? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            stream.src_ptr = base
            stream.src_size = input.count

            var output = Data()
            var status = COMPRESSION_STATUS_OK
            repeat {
                stream.dst_ptr = destination
                stream.dst_size = bufferSize
                status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    output.append(destination, count: bufferSize - stream.dst_size)
                default:
                    return nil
                }
            } while status == COMPRESSION_STATUS_OK
            return output
        }
    }

    // MARK: - Payload

    private struct Response: Decodable {
        var type: String?
        var lyrics: [Entry]?
        var metadata: Metadata?
    }

    private struct Metadata: Decodable {
        var source: String?
    }

    private struct Entry: Decodable {
        var time: Double
        var duration: Double
        var text: String
        var syllabus: [Syllable]?
    }

    private struct Syllable: Decodable {
        var time: Double
        var duration: Double
        var text: String
    }
}
