import SwiftUI

/// GPU background effects, evaluated per pixel in Metal. These do what the
/// Canvas styles cannot -- raymarched geometry, escape-time fractals,
/// metaball fields -- and cost roughly the same because the work happens on
/// the GPU rather than in a per-frame draw list.
enum ShaderStyle: String, CaseIterable, Identifiable {
    // Flat 2D fields.
    case plasma, kaleido, aurora, fractal, liquid, warp
    case nebula, voronoi, orbs, silk
    // Raymarched: a signed-distance field walked step by step per pixel.
    case waves, helix
    // Closed-form 3D: a plane or sphere solved analytically, so the depth is
    // real but nothing is marched.
    case ripple, mirror
    case wormhole, rings, vortex
    case orbit, bubbles
    case galaxy
    case strata, clouds, curtains, ribbons, prism

    var id: String { rawValue }

    /// Rough per-pixel expense, used to keep the wallpaper cheap when the
    /// machine cannot afford it. `heavy` means the effect marches a ray or
    /// runs a deep escape-time loop for every pixel of every frame; on an
    /// integrated GPU driving a Retina display that is the difference
    /// between idling and running the fans.
    enum Cost { case light, medium, heavy }

    var cost: Cost {
        switch self {
        case .plasma, .aurora, .silk,
             .ripple, .mirror,
             .wormhole, .rings, .vortex,
             .orbit, .strata, .curtains, .ribbons, .prism:
            return .light
        case .kaleido, .liquid, .warp, .voronoi, .orbs,
             .bubbles, .galaxy, .clouds:
            return .medium
        case .fractal, .nebula, .waves, .helix:
            return .heavy
        }
    }

    var functionName: String {
        switch self {
        case .plasma: return "wlPlasma"
        case .kaleido: return "wlKaleido"
        case .aurora: return "wlAurora"
        case .fractal: return "wlFractal"
        case .liquid: return "wlLiquid"
        case .warp: return "wlWarp"
        case .nebula: return "wlNebula"
        case .voronoi: return "wlVoronoi"
        case .orbs: return "wlOrbs"
        case .silk: return "wlSilk"
        case .waves: return "wlWaves"
        case .helix: return "wlHelix"
        case .ripple: return "wlRipple"
        case .mirror: return "wlMirror"
        case .wormhole: return "wlWormhole"
        case .rings: return "wlRings"
        case .vortex: return "wlVortex"
        case .orbit: return "wlOrbit"
        case .bubbles: return "wlBubbles"
        case .galaxy: return "wlGalaxy"
        case .strata: return "wlStrata"
        case .clouds: return "wlClouds"
        case .curtains: return "wlCurtains"
        case .ribbons: return "wlRibbons"
        case .prism: return "wlPrism"
        }
    }

    var title: String {
        switch self {
        case .plasma: return "Plasma"
        case .kaleido: return "Kaleidoscope"
        case .aurora: return "Aurora"
        case .fractal: return "Fractal"
        case .liquid: return "Liquid"
        case .warp: return "Marble"
        case .nebula: return "Nebula"
        case .voronoi: return "Voronoi"
        case .orbs: return "Orbs"
        case .silk: return "Silk"
        case .waves: return "Waves"
        case .helix: return "Helix"
        case .ripple: return "Ripple"
        case .mirror: return "Mirror"
        case .wormhole: return "Wormhole"
        case .rings: return "Rings"
        case .vortex: return "Vortex"
        case .orbit: return "Orbit"
        case .bubbles: return "Bubbles"
        case .galaxy: return "Galaxy"
        case .strata: return "Strata"
        case .clouds: return "Clouds"
        case .curtains: return "Curtains"
        case .ribbons: return "Ribbons"
        case .prism: return "Prism"
        }
    }

    /// Everything is free while the paywall is disarmed; the split is kept
    /// so re-arming it needs no change here.
    var isPro: Bool {
        switch self {
        case .plasma, .aurora, .warp: return false
        default: return true
        }
    }

    static var free: [ShaderStyle] { allCases.filter { !$0.isPro } }

    /// Effects cheap enough to leave running on battery or a low-power Mac.
    static var economical: [ShaderStyle] { allCases.filter { $0.cost == .light } }

    /// Where an effect sits, so a track can be *matched* to one instead of
    /// drawn out of a bucket.
    struct Character {
        /// 0 = still, 1 = frantic.
        var energy: Double
        /// 0 = open and sparse, 1 = busy. Busy effects fight the lyrics, so
        /// this is the axis that protects readability.
        var density: Double
        /// 0 = geometric and hard-edged, 1 = organic and flowing. This is
        /// what separates a techno track from a folk one when both happen to
        /// sit at the same energy.
        var organic: Double
    }

    var character: Character {
        switch self {
        case .plasma:   return .init(energy: 0.30, density: 0.35, organic: 0.85)
        case .kaleido:  return .init(energy: 0.75, density: 0.80, organic: 0.30)
        case .aurora:   return .init(energy: 0.25, density: 0.30, organic: 0.95)
        case .fractal:  return .init(energy: 0.85, density: 0.95, organic: 0.20)
        case .liquid:   return .init(energy: 0.45, density: 0.50, organic: 0.90)
        case .warp:     return .init(energy: 0.35, density: 0.55, organic: 0.80)
        case .nebula:   return .init(energy: 0.42, density: 0.70, organic: 0.80)
        case .voronoi:  return .init(energy: 0.65, density: 0.70, organic: 0.25)
        case .orbs:     return .init(energy: 0.40, density: 0.40, organic: 0.75)
        case .silk:     return .init(energy: 0.20, density: 0.30, organic: 0.90)
        case .waves:    return .init(energy: 0.45, density: 0.45, organic: 0.85)
        case .helix:    return .init(energy: 0.70, density: 0.50, organic: 0.35)
        case .ripple:   return .init(energy: 0.35, density: 0.45, organic: 0.95)
        case .mirror:   return .init(energy: 0.30, density: 0.35, organic: 0.70)
        case .wormhole: return .init(energy: 0.80, density: 0.70, organic: 0.30)
        case .rings:    return .init(energy: 0.55, density: 0.35, organic: 0.45)
        case .vortex:   return .init(energy: 0.70, density: 0.55, organic: 0.55)
        case .orbit:    return .init(energy: 0.50, density: 0.30, organic: 0.50)
        case .bubbles:  return .init(energy: 0.35, density: 0.40, organic: 0.80)
        case .galaxy:   return .init(energy: 0.40, density: 0.60, organic: 0.75)
        case .strata:   return .init(energy: 0.20, density: 0.45, organic: 0.55)
        case .clouds:   return .init(energy: 0.25, density: 0.55, organic: 0.90)
        case .curtains: return .init(energy: 0.45, density: 0.50, organic: 0.85)
        case .ribbons:  return .init(energy: 0.40, density: 0.40, organic: 0.70)
        case .prism:    return .init(energy: 0.60, density: 0.50, organic: 0.40)
        }
    }

    /// Squared distance from a track's character to this effect's, lower
    /// being a better fit. Energy leads, because it is the axis a listener
    /// notices first; organic follows, because it is what separates two
    /// effects that happen to move at the same speed.
    func fit(to target: Character) -> Double {
        let c = character
        let dEnergy = (c.energy - target.energy) * (c.energy - target.energy) * 1.00
        let dOrganic = (c.organic - target.organic) * (c.organic - target.organic) * 0.75
        let dDensity = (c.density - target.density) * (c.density - target.density) * 0.45
        return dEnergy + dOrganic + dDensity
    }

    /// How many of the best-fitting effects a track chooses between.
    ///
    /// Sweeping the plausible mood space showed why this cannot be 1: taking
    /// only the nearest effect meant 20 of 25 could never be selected at all,
    /// because a handful of them sit nearest to every point real music
    /// occupies. Four is where coverage reaches 24 of 25 while every
    /// candidate is still a genuinely close match.
    private static let candidatePoolSize = 4

    /// The effect that best suits a track, chosen from the closest few.
    static func matching(_ target: Character, seed: Int, from pool: [ShaderStyle]) -> ShaderStyle {
        guard !pool.isEmpty else { return .plasma }
        let ranked = pool.sorted { $0.fit(to: target) < $1.fit(to: target) }
        let candidates = Array(ranked.prefix(candidatePoolSize))
        let index = Int(stableNoise(seed) * Double(candidates.count)) % candidates.count
        return candidates[index]
    }

    /// A stable [0,1) from a track seed.
    ///
    /// Deliberately not `Hasher`: Swift seeds that randomly per process, so
    /// it would deal every track a new effect on each launch. The seed is
    /// folded in *first* and the result avalanched at the end -- FNV mixes
    /// forward only, so a seed folded in last barely reaches the high bits
    /// sampled here. Measured: without the avalanche, seeds 1 and 1337
    /// differed by 0.0001 and the seed was effectively ignored.
    private static func stableNoise(_ seed: Int) -> Double {
        var h: UInt64 = 1469598103934665603
        var s = UInt64(bitPattern: Int64(seed))
        for _ in 0..<8 {
            h = (h ^ (s & 0xFF)) &* 1099511628211
            s >>= 8
        }
        for byte in "wavelength".utf8 { h = (h ^ UInt64(byte)) &* 1099511628211 }
        // splitmix64 finalizer.
        h ^= h >> 30; h = h &* 0xBF58476D1CE4E5B9
        h ^= h >> 27; h = h &* 0x94D049BB133111EB
        h ^= h >> 31
        return Double(h >> 40) / Double(1 << 24)
    }

    /// Calm enough to sit under a full line of lyrics.
    static let calm: [ShaderStyle] = [.plasma, .aurora, .liquid, .warp, .nebula, .orbs, .silk, .waves, .ripple, .mirror, .rings, .orbit, .bubbles, .galaxy, .strata, .clouds, .curtains, .ribbons]
    static let intense: [ShaderStyle] = [.kaleido, .fractal, .voronoi, .helix, .wormhole, .vortex, .prism]
}

struct ShaderBackgroundView: View {
    let style: ShaderStyle
    /// Steady accumulated phase from `VisualClock`.
    let time: Double
    /// Beat-accelerated phase. The effects advect along this, so a hit surges
    /// the fluid forward instead of merely brightening it.
    let flow: Double
    let tintA: Color
    let tintB: Color
    /// Beats brighten and bloom the effect. Only intensity is passed through
    /// -- `time` stays a clean accumulated phase, since scaling it by a
    /// changing rate would make the pattern jump rather than react.
    var reactivity: MusicDynamics.Reactivity = .idle

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Rectangle()
                .colorEffect(
                    ShaderLibrary[dynamicMember: style.functionName](
                        .float2(size.width, size.height),
                        .float(Float(time)),
                        .float(Float(flow)),
                        .color(tintA),
                        .color(tintB),
                        .float(Float(reactivity.pulse)),
                        .float(Float(reactivity.swell))
                    )
                )
        }
        .ignoresSafeArea()
        .drawingGroup()
    }
}
