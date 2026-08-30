import SwiftUI

/// Verso's colours, sampled from the wordmark rather than invented alongside
/// it. The icon runs peach at the top through violet to a near-black plum;
/// these are those stops, plus the green from the flower that forms the "o".
///
/// Kept in one place so the settings window, the walkthrough and anything
/// added later cannot drift into their own approximations of the brand.
enum Verso {
    // Gradient stops, top to bottom of the icon.
    static let blush = Color(hex: 0xFDD3C9)
    static let orchid = Color(hex: 0xD78FE8)
    static let violet = Color(hex: 0xC36BFA)
    static let grape = Color(hex: 0x9D4DD7)
    static let plum = Color(hex: 0x6D329C)
    static let ink = Color(hex: 0x3E1860)
    static let midnight = Color(hex: 0x240940)

    /// The petal colour of the mark.
    static let cream = Color(hex: 0xF1EFE8)
    /// The flower's own green. Used sparingly -- it is the accent, not a
    /// second brand colour.
    static let leaf = Color(hex: 0x00BF63)

    // MARK: - Surfaces

    /// Deepest surface, for window backgrounds. Not pure black: the icon's
    /// darkest stop is a plum, and true black next to it reads as a hole.
    static let surface = Color(hex: 0x14061F)
    /// One step up, for the sidebar.
    static let surfaceRaised = Color(hex: 0x1C0A2B)
    /// Cards and controls sitting on `surface`.
    static let surfaceCard = Color(hex: 0x24103A)

    /// The icon's own gradient, for headers and selected states.
    static let brandGradient = LinearGradient(
        colors: [blush, orchid, violet, grape, ink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// A shorter run of it, for small fills where the full sweep would read
    /// as noise.
    static let accentGradient = LinearGradient(
        colors: [violet, grape],
        startPoint: .leading, endPoint: .trailing
    )
}

extension Color {
    /// 0xRRGGBB.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
