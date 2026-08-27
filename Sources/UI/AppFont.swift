import SwiftUI

/// Manrope, used for every piece of interface text and as the default lyric
/// face. It is fetched from Google Fonts once and registered for this process
/// only, exactly like a user-chosen family -- so nothing is installed on the
/// system and there is no licensing baggage in the bundle.
///
/// Until it arrives, calls fall back to the system font at the same size, so
/// the first frames after launch are laid out sensibly rather than blank.
@MainActor
enum AppFont {
    private(set) static var regular: String?
    private(set) static var bold: String?

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let wantsBold: Bool
        switch weight {
        case .semibold, .bold, .heavy, .black: wantsBold = true
        default: wantsBold = false
        }
        if let name = wantsBold ? (bold ?? regular) : regular {
            return .custom(name, fixedSize: size)
        }
        return .system(size: size, weight: weight)
    }

    /// Display type -- the headings that carry the settings and onboarding.
    static func display(_ size: CGFloat) -> Font {
        if let name = bold ?? regular { return .custom(name, fixedSize: size) }
        return .system(size: size, weight: .bold)
    }

    static func preload() {
        Task {
            guard let font = await GoogleFontsProvider.shared.font(family: "Manrope") else { return }
            regular = font.regular
            bold = font.bold
            // Nudge the interface so already-rendered text picks up the face.
            NotificationCenter.default.post(name: .appFontLoaded, object: nil)
        }
    }
}

extension Notification.Name {
    static let appFontLoaded = Notification.Name("WavelengthAppFontLoaded")
}

/// Redraws its content once Manrope finishes downloading.
struct AppFontScope<Content: View>: View {
    @State private var revision = 0
    @ViewBuilder var content: Content

    var body: some View {
        content
            .id(revision)
            .onReceive(NotificationCenter.default.publisher(for: .appFontLoaded)) { _ in
                revision += 1
            }
    }
}
