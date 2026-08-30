import SwiftUI

/// A read of a track's "vibe", used to pick typography, the generative
/// background, and how fast everything moves -- calm, drifting visuals for a
/// ballad; fast, angular ones for a club track.
///
/// This is derived from metadata and lyric cadence rather than audio DSP:
/// macOS gives no access to another app's audio stream, and Apple Music
/// reports `bpm` as 0 for streamed tracks (verified). The signals that *are*
/// available -- genre, how densely words are sung, and how saturated the
/// cover is -- separate a ballad from a banger perfectly well in practice.
/// The Lyric Speaker switches between four faces of Morisawa's Role
/// super-family depending on the music. Role itself is a commercial licence
/// and cannot be shipped here, so each role is carried by a real named
/// typeface rather than the system default:
///
/// - Role Sans  -> Avenir Next Condensed. Geometric and condensed, which is
///   what gives the display its poster weight.
/// - Role Serif -> Charter, drawn by Matthew Carter -- the same designer who
///   worked on Role with Morisawa, so it is the closest relative available.
/// - Role Slab  -> Rockwell, a genuine slab rather than a serif standing in
///   for one.
/// - Role Soft  -> SF Rounded. No named rounded family ships with macOS, so
///   this is the one role still served by a system face.
enum LyricFace: Equatable {
    case sans, serif, slab, soft

    /// Lyric type. `hero` picks the heavy cut used for emphasised words.
    func font(size: CGFloat, hero: Bool) -> Font {
        switch self {
        case .sans:
            return .custom(hero ? "AvenirNextCondensed-Heavy" : "AvenirNextCondensed-Medium", fixedSize: size)
        case .serif:
            return .custom(hero ? "Charter-Black" : "Charter-Roman", fixedSize: size)
        case .slab:
            return .custom(hero ? "Rockwell-Bold" : "Rockwell-Regular", fixedSize: size)
        case .soft:
            return .system(size: size, weight: hero ? .heavy : .medium, design: .rounded)
        }
    }

    /// The face's opposite number, for compositions that deliberately set
    /// two voices against each other in a single line.
    var contrasting: LyricFace {
        switch self {
        case .sans: return .serif
        case .serif: return .sans
        case .slab: return .soft
        case .soft: return .slab
        }
    }

    /// Interface text -- track title, timings, status.
    func uiFont(size: CGFloat, bold: Bool = false) -> Font {
        switch self {
        case .sans:
            return .custom(bold ? "AvenirNextCondensed-Bold" : "AvenirNextCondensed-Medium", fixedSize: size)
        case .serif:
            return .custom(bold ? "Charter-Bold" : "Charter-Roman", fixedSize: size)
        case .slab:
            return .custom(bold ? "Rockwell-Bold" : "Rockwell-Regular", fixedSize: size)
        case .soft:
            return .system(size: size, weight: bold ? .bold : .medium, design: .rounded)
        }
    }

    /// The Lyric Speaker's own genre mapping: slab for rock and powerful
    /// acoustic, serif for emotional and classical, soft for gentle and
    /// upbeat, sans as the default.
    static func forGenre(_ genre: String?) -> LyricFace {
        let text = (genre ?? "").lowercased()
        if text.containsAny("rock", "metal", "punk", "grunge", "alternative") { return .slab }
        if text.containsAny("jazz", "blues", "classical", "opera", "orchestral") { return .serif }
        if text.containsAny("ambient", "chill", "acoustic", "folk", "country", "singer") { return .serif }
        if text.containsAny("pop", "k-pop", "r&b", "soul", "funk", "disco") { return .soft }
        return .sans
    }
}

struct TrackMood: Equatable {
    /// 0 = still, 1 = frantic.
    var energy: Double
    var face: LyricFace
    var background: BackgroundStyle
    /// Multiplier on background animation speed.
    var motionRate: Double
    /// Multiplier on rotation and wave amplitude in the lyric layout.
    var intensity: Double
    /// 0 = machine-made and geometric, 1 = played and organic. Energy alone
    /// cannot tell a techno track from a bluegrass one at the same tempo;
    /// this is the axis that can.
    var organic: Double = 0.5

    static let neutral = TrackMood(
        energy: 0.5, face: .sans, background: .constellation,
        motionRate: 1.0, intensity: 1.0, organic: 0.5
    )

    /// The track expressed on the same three axes the effects declare, so
    /// the two can be compared directly.
    var visualCharacter: ShaderStyle.Character {
        // Density is not read off the music -- it is a readability budget.
        // A busy effect under a fast lyric is unreadable, so the allowance
        // grows with energy but never reaches the top of the scale.
        ShaderStyle.Character(
            energy: energy,
            density: 0.25 + energy * 0.45,
            organic: organic
        )
    }

    static func derive(
        genre: String?,
        wordsPerSecond: Double,
        artworkSaturation: Double,
        seed: Int
    ) -> TrackMood {
        let genreText = (genre ?? "").lowercased()

        // Genre sets a coarse energy baseline; the typographic voice comes
        // from the same mapping the controls use, so both agree.
        let genreEnergy: Double
        if genreText.containsAny("electronic", "dance", "house", "techno", "edm", "drum", "dubstep", "trance") {
            genreEnergy = 0.90
        } else if genreText.containsAny("rock", "metal", "punk", "grunge", "alternative") {
            genreEnergy = 0.85
        } else if genreText.containsAny("hip", "rap", "trap", "grime", "drill") {
            genreEnergy = 0.80
        } else if genreText.containsAny("pop", "k-pop") {
            genreEnergy = 0.65
        } else if genreText.containsAny("r&b", "soul", "funk", "disco") {
            genreEnergy = 0.55
        } else if genreText.containsAny("jazz", "blues", "classical", "opera", "orchestral") {
            genreEnergy = 0.20
        } else if genreText.containsAny("ambient", "chill", "acoustic", "folk", "country", "singer") {
            genreEnergy = 0.25
        } else {
            genreEnergy = 0.50
        }
        let face = LyricFace.forGenre(genre)

        // How played-by-hand the music is. Sequenced genres sit low, acoustic
        // and orchestral ones high, and everything sung over a live band in
        // between.
        let organic: Double
        if genreText.containsAny("electronic", "dance", "house", "techno", "edm", "drum", "dubstep", "trance") {
            organic = 0.12
        } else if genreText.containsAny("hip", "rap", "trap", "grime", "drill") {
            organic = 0.30
        } else if genreText.containsAny("rock", "metal", "punk", "grunge", "alternative") {
            organic = 0.45
        } else if genreText.containsAny("pop", "k-pop") {
            organic = 0.52
        } else if genreText.containsAny("r&b", "soul", "funk", "disco") {
            organic = 0.68
        } else if genreText.containsAny("jazz", "blues", "classical", "opera", "orchestral") {
            organic = 0.88
        } else if genreText.containsAny("ambient", "chill", "acoustic", "folk", "country", "singer") {
            organic = 0.92
        } else {
            organic = 0.50
        }

        // Lyric cadence sharpens it: ~0.8 words/sec is a ballad, ~3.4 is a
        // fast rap verse. This is the closest thing to a tempo reading we can
        // get without the audio.
        let cadence = wordsPerSecond > 0
            ? min(max((wordsPerSecond - 0.8) / 2.6, 0), 1)
            : genreEnergy
        let energy = min(max(genreEnergy * 0.55 + cadence * 0.45, 0), 1)

        // Angular, busy patterns for high energy; slow organic ones for low.
        // The seed picks within the tier, so each track keeps its own look.
        let pool: [BackgroundStyle]
        if energy > 0.72 {
            pool = BackgroundStyle.energetic
        } else if energy > 0.45 {
            pool = BackgroundStyle.mid
        } else {
            pool = BackgroundStyle.calm
        }
        let background = pool[abs(seed) % pool.count]

        return TrackMood(
            energy: energy,
            face: face,
            background: background,
            motionRate: 0.45 + energy * 1.25,
            intensity: 0.25 + energy * 1.30 + artworkSaturation * 0.20,
            // A vivid cover nudges the read a little more organic; a washed
            // out one, a little more clinical.
            organic: min(max(organic + (artworkSaturation - 0.5) * 0.16, 0), 1)
        )
    }
}

private extension String {
    func containsAny(_ needles: String...) -> Bool {
        needles.contains { contains($0) }
    }
}
