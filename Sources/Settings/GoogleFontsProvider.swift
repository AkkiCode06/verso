import AppKit
import CoreText

/// Downloads a family from Google Fonts and registers it for this process.
///
/// Two details make this work without an API key or an install:
///
/// - Google's `css2` endpoint serves WOFF2 to modern browsers, which CoreText
///   cannot register. Asking with an old user agent makes it fall back to
///   plain TTF, which CoreText handles.
/// - `CTFontManagerRegisterFontsForURL` with `.process` scope makes the font
///   available to this app alone -- no admin prompt, and nothing is added to
///   the user's installed fonts.
actor GoogleFontsProvider {
    static let shared = GoogleFontsProvider()

    struct LoadedFont {
        var regular: String
        var bold: String?
    }

    private var loaded: [String: LoadedFont] = [:]

    private var cacheDirectory: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Verso/Fonts")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    func font(family: String) async -> LoadedFont? {
        if let hit = loaded[family] { return hit }

        guard let urls = await ttfURLs(family: family), !urls.isEmpty else { return nil }

        var regularName: String?
        var boldName: String?
        for (index, url) in urls.prefix(2).enumerated() {
            guard let name = await install(url: url, family: family, index: index) else { continue }
            if index == 0 { regularName = name } else { boldName = name }
        }

        guard let regularName else { return nil }
        let result = LoadedFont(regular: regularName, bold: boldName)
        loaded[family] = result
        return result
    }

    /// Asks Google for regular and bold cuts, in TTF.
    private func ttfURLs(family: String) async -> [URL]? {
        let encoded = family.replacingOccurrences(of: " ", with: "+")
        guard let url = URL(string: "https://fonts.googleapis.com/css2?family=\(encoded):wght@400;700") else {
            return nil
        }
        var request = URLRequest(url: url)
        // Deliberately archaic: a modern agent gets WOFF2 back, which
        // CoreText cannot use.
        request.setValue("Mozilla/4.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let css = String(data: data, encoding: .utf8)
            else { return nil }

            guard let regex = try? NSRegularExpression(pattern: #"https://[^)]+?\.ttf"#) else { return nil }
            let range = NSRange(css.startIndex..., in: css)

            // The sheet repeats each weight once per unicode subset; one URL
            // per distinct file is enough.
            var seen: [URL] = []
            for match in regex.matches(in: css, range: range) {
                guard let matchRange = Range(match.range, in: css),
                      let candidate = URL(string: String(css[matchRange]))
                else { continue }
                if !seen.contains(candidate) { seen.append(candidate) }
            }
            return seen
        } catch {
            return nil
        }
    }

    private func install(url: URL, family: String, index: Int) async -> String? {
        let destination = cacheDirectory
            .appendingPathComponent("\(family.replacingOccurrences(of: " ", with: "-"))-\(index).ttf")

        if !FileManager.default.fileExists(atPath: destination.path) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count > 1000
                else { return nil }
                try data.write(to: destination)
            } catch {
                return nil
            }
        }
        return register(destination)
    }

    /// Registers the file and reports the PostScript name SwiftUI needs.
    private func register(_ url: URL) -> String? {
        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        // An "already registered" failure is fine -- the name still resolves.
        if !registered, error != nil {
            _ = error?.takeRetainedValue()
        }
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let first = descriptors.first,
              let name = CTFontDescriptorCopyAttribute(first, kCTFontNameAttribute) as? String
        else { return nil }
        // Confirm AppKit can actually instantiate it before handing the name on.
        return NSFont(name: name, size: 12) != nil ? name : nil
    }
}
