import Foundation

/// Families offered in the picker.
///
/// Google's full catalogue listing needs an API key, and enumerating ~1,800
/// families would be unusable to scroll anyway. This is a hand-picked set
/// that suits lyric display -- strong display faces, readable text faces, and
/// a few oddities -- grouped so the list can be skimmed. Any family Google
/// hosts still works if typed by name.
enum GoogleFontsCatalog {
    struct Group: Identifiable {
        var id: String { name }
        var name: String
        var families: [String]
    }

    static let groups: [Group] = [
        Group(name: "Display", families: [
            "Anton", "Bebas Neue", "Archivo Black", "Alfa Slab One", "Righteous",
            "Bungee", "Passion One", "Titan One", "Staatliches", "Chivo",
            "Fjalla One", "Oswald", "Teko", "Rampart One", "Monoton",
        ]),
        Group(name: "Sans", families: [
            "Inter", "Montserrat", "Poppins", "Raleway", "Work Sans",
            "DM Sans", "Manrope", "Outfit", "Figtree", "Sora",
            "Space Grotesk", "Rubik", "Nunito", "Barlow", "Lexend",
        ]),
        Group(name: "Serif", families: [
            "Playfair Display", "Lora", "Merriweather", "Cormorant Garamond",
            "Libre Baskerville", "EB Garamond", "Spectral", "Bitter",
            "Crimson Text", "Source Serif 4", "Zilla Slab", "Roboto Slab",
        ]),
        Group(name: "Handwriting", families: [
            "Caveat", "Dancing Script", "Pacifico", "Satisfy",
            "Shadows Into Light", "Kalam", "Sacramento", "Amatic SC",
        ]),
        Group(name: "Mono", families: [
            "JetBrains Mono", "Space Mono", "IBM Plex Mono", "Fira Code",
            "Roboto Mono", "Source Code Pro",
        ]),
    ]

    static var allFamilies: [String] { groups.flatMap(\.families) }
}
