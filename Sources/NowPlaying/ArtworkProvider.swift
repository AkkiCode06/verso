import AppKit

/// Apple Music's AppleScript bridge reports `count of artworks == 0` for
/// streamed catalog tracks -- cover art simply is not exposed there (it is
/// DRM'd content, not a file tag). Apple's public iTunes Search API does
/// serve the same cover, unauthenticated, so we look the track up by
/// artist + title and pull the image from there.
actor ArtworkProvider {
    static let shared = ArtworkProvider()

    private var cache: [String: NSImage] = [:]

    func artwork(title: String, artist: String, album: String?, duration: Double) async -> NSImage? {
        let key = "\(title)|\(artist)|\(album ?? "")"
        if let hit = cache[key] { return hit }

        // Apple Music artist fields often chain collaborators ("A & B, C");
        // the search index matches far better on the primary artist alone.
        let primaryArtist = artist
            .components(separatedBy: CharacterSet(charactersIn: "&,"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? artist

        for term in ["\(primaryArtist) \(title)", title] {
            if let image = await search(term: term, title: title, artist: artist, album: album, duration: duration) {
                cache[key] = image
                return image
            }
        }
        return nil
    }

    private func search(term: String, title: String, artist: String, album: String?, duration: Double) async -> NSImage? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "12"),
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let payload = try JSONDecoder().decode(SearchResponse.self, from: data)
            guard let best = bestMatch(in: payload.results, title: title, artist: artist, album: album, duration: duration),
                  let thumb = best.artworkUrl100
            else { return nil }

            // The same path serves larger renditions; 600px is plenty for
            // both the gradient sampling and the on-screen capsule.
            let large = thumb.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            guard let imageURL = URL(string: large) else { return nil }
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            return NSImage(data: imageData)
        } catch {
            return nil
        }
    }

    /// Taking the first hit picks the wrong cover constantly: a catalogue
    /// carries the single, the album, remasters and deluxe reissues under the
    /// same title, each with different art. Album name and runtime are what
    /// actually identify the edition.
    private func bestMatch(
        in results: [Result], title: String, artist: String, album: String?, duration: Double
    ) -> Result? {
        let wantedTitle = normalize(title)
        let wantedArtist = normalize(artist)
        let wantedAlbum = album.map(normalize) ?? ""

        var best: (result: Result, score: Int, delta: Double)?
        for candidate in results {
            guard matches(normalize(candidate.trackName ?? ""), wantedTitle) else { continue }

            var score = 0
            if !wantedAlbum.isEmpty, matches(normalize(candidate.collectionName ?? ""), wantedAlbum) {
                score += 4
            }
            let delta = duration > 0 && (candidate.trackTimeMillis ?? 0) > 0
                ? abs(Double(candidate.trackTimeMillis ?? 0) / 1000 - duration)
                : Double.greatestFiniteMagnitude
            if delta < 2 { score += 4 } else if delta < 5 { score += 2 }
            if matches(normalize(candidate.artistName ?? ""), wantedArtist) { score += 2 }

            if let current = best {
                if score > current.score || (score == current.score && delta < current.delta) {
                    best = (candidate, score, delta)
                }
            } else {
                best = (candidate, score, delta)
            }
        }
        return best?.result
    }

    private func matches(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a == b || a.contains(b) || b.contains(a)
    }

    private func normalize(_ value: String) -> String {
        var text = value.lowercased()
        for pattern in [#"\([^)]*\)"#, #"\[[^\]]*\]"#, #"feat\..*"#, #"ft\..*"#] {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return text.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }

    private struct SearchResponse: Decodable {
        var results: [Result]
    }

    struct Result: Decodable {
        var artworkUrl100: String?
        var trackName: String?
        var artistName: String?
        var collectionName: String?
        var trackTimeMillis: Int?
    }
}
