import Foundation

/// Finds Apple Music's animated album art for the current track, when the
/// album has any.
///
/// The motion assets live behind `api.music.apple.com`, which needs a signed
/// developer token. But the *public* album page on music.apple.com embeds the
/// same data in its serialized payload -- `videoArtwork.dictionary
/// .motionDetailSquare.video` -- pointing at an HLS playlist on
/// mvod.itunes.apple.com that serves without authentication. That is the
/// route used here: catalogue lookup for the album page, then the stream URL
/// out of the page.
///
/// Only a minority of albums have motion artwork, so a miss is the normal
/// case and simply leaves the generated colour field in place.
actor MotionArtworkProvider {
    static let shared = MotionArtworkProvider()

    struct Motion: Equatable {
        var square: URL
        var tall: URL?
    }

    /// Albums without motion art are cached as `.some(nil)` so a miss is not
    /// looked up again on every track change within the same album.
    private var cache: [String: Motion?] = [:]

    func motion(album: String?, artist: String, title: String) async -> Motion? {
        let key = "\(album ?? title)|\(artist)"
        if let cached = cache[key] { return cached }

        let result = await lookup(album: album, artist: artist, title: title)
        cache[key] = result
        return result
    }

    private func lookup(album: String?, artist: String, title: String) async -> Motion? {
        guard let pageURL = await albumPageURL(album: album, artist: artist, title: title),
              let html = await fetchText(pageURL)
        else { return nil }

        // The payload escapes slashes; normalise before matching.
        let text = html.replacingOccurrences(of: "\\u002F", with: "/")
        guard let square = videoURL(in: text, key: "motionDetailSquare") else { return nil }
        return Motion(square: square, tall: videoURL(in: text, key: "motionDetailTall"))
    }

    /// Pulls the HLS URL that follows a given motion-artwork key. A scoped
    /// scan beats decoding the page's very large JSON blob.
    private func videoURL(in text: String, key: String) -> URL? {
        guard let keyRange = text.range(of: "\"\(key)\"") else { return nil }
        let window = text[keyRange.upperBound...].prefix(2500)
        guard let match = window.range(of: #""video"\s*:\s*"[^"]+\.m3u8""#, options: .regularExpression)
        else { return nil }

        let fragment = window[match]
        guard let start = fragment.range(of: "http") else { return nil }
        let raw = fragment[start.lowerBound...].dropLast()
        return URL(string: String(raw))
    }

    private func albumPageURL(album: String?, artist: String, title: String) async -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        // Album entity gives `collectionViewUrl` directly; falling back to the
        // song entity still carries the parent album's page.
        let term = album.map { "\(artist) \($0)" } ?? "\(artist) \(title)"
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: album == nil ? "song" : "album"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components?.url,
              let data = await fetchData(url),
              let payload = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let link = payload.results.first?.collectionViewUrl
        else { return nil }
        return URL(string: link)
    }

    private func fetchText(_ url: URL) async -> String? {
        guard let data = await fetchData(url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func fetchData(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private struct SearchResponse: Decodable {
        struct Result: Decodable { var collectionViewUrl: String? }
        var results: [Result]
    }
}
