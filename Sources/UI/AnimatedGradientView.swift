import SwiftUI

/// The colour field, built the way Apple Music builds its animated artwork
/// background: a handful of large, very soft colour blobs drawn from the
/// cover, each drifting along its own slow path, blurred together so they
/// read as pigment suspended in water rather than distinct shapes.
///
/// The earlier version pushed mesh control points around per beat, which is
/// what made it look frantic -- a beat physically relocated the colour. Here
/// a beat only makes the existing blobs **swell and brighten**; it never
/// moves them, and never changes which colour is where. Motion stays slow and
/// continuous, so the music reads as breathing through the field instead of
/// snapping it to a new state.
struct AnimatedGradientView: View {
    /// Base palette as 3x3 hue/saturation/brightness triples.
    let palette: [SIMD3<Double>]
    /// Accumulated phase from `VisualClock`.
    let time: Double
    var reactivity: MusicDynamics.Reactivity = .idle

    /// Corners and centre of the sampled grid -- spread across the artwork,
    /// so the blobs carry genuinely different colours.
    private let sampleIndices = [0, 2, 4, 6, 8]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                baseColor
                ZStack {
                    ForEach(sampleIndices.indices, id: \.self) { slot in
                        blob(slot: slot, size: size)
                    }
                }
                // Diffuses the blobs into one another. Scaled up first so the
                // blur's soft edge falls outside the screen instead of
                // darkening the border.
                .blur(radius: min(size.width, size.height) * 0.075)
                .scaleEffect(1.2)
            }
            // Flattens the whole stack into one GPU pass -- several large
            // blurred gradients composited every frame is otherwise costly.
            .drawingGroup()
        }
        .ignoresSafeArea()
    }

    // MARK: - Layers

    private var baseColor: Color {
        guard !palette.isEmpty else { return .black }
        let average = palette.reduce(SIMD3<Double>(0, 0, 0), +) / Double(palette.count)
        // Held back so the blobs above stay the brightest thing on screen.
        return Color(
            hue: average.x,
            saturation: min(average.y * 1.1, 1),
            brightness: max(average.z * 0.45, 0.06)
        )
    }

    private func blob(slot: Int, size: CGSize) -> some View {
        let spec = specification(slot: slot)
        let shortest = min(size.width, size.height)
        let turn = 2 * Double.pi

        // Different periods on each axis trace a Lissajous path, so blobs
        // wander without ever retracing the same loop.
        let angleX = time / spec.periodX * turn + spec.phase
        let angleY = time / spec.periodY * turn + spec.phase * 1.3
        let x = size.width / 2 + CGFloat(cos(angleX)) * size.width * spec.orbitX
        let y = size.height / 2 + CGFloat(sin(angleY)) * size.height * spec.orbitY

        // Driven by `swell`, not `pulse`. Swell is the slow-moving density of
        // a passage, so the blobs gain and lose size over bars rather than
        // snapping on each hit. Staggering by slot keeps them off lockstep,
        // which would read as the whole screen breathing at once.
        let stagger = 0.72 + 0.28 * sin(Double(slot) * 2.1)
        let lean = reactivity.swell * stagger
        let breathe = 1 + 0.05 * sin(time / spec.periodRadius * turn + spec.phase)
        let radius = shortest * spec.radius * CGFloat(breathe) * CGFloat(1 + 0.05 * lean)

        let colour = colour(for: spec)

        return RadialGradient(
            gradient: Gradient(stops: [
                .init(color: colour.opacity(0.85), location: 0.0),
                .init(color: colour.opacity(0.42), location: 0.42),
                .init(color: colour.opacity(0.0), location: 1.0),
            ]),
            center: .center,
            startRadius: 0,
            endRadius: radius
        )
        .frame(width: radius * 2, height: radius * 2)
        .position(x: x, y: y)
    }

    /// Beats lift saturation and brightness a little. Hue never moves -- a
    /// shifting hue is what previously made the palette look like it was
    /// swapping rather than pulsing.
    /// Takes no beat input at all. Lifting saturation and brightness on each
    /// hit was the colour layer's share of the glow -- the same lamp-switch
    /// effect the shaders had -- so the blob now holds one steady colour and
    /// lets its movement carry the music.
    private func colour(for spec: BlobSpec) -> Color {
        let base = palette.indices.contains(spec.paletteIndex)
            ? palette[spec.paletteIndex]
            : SIMD3(0.6, 0.4, 0.5)
        return Color(
            hue: base.x,
            saturation: min(base.y * 1.05, 1),
            brightness: min(base.z * 0.98 + 0.05, 1)
        )
    }

    // MARK: - Blob definitions

    private struct BlobSpec {
        var paletteIndex: Int
        var periodX: Double
        var periodY: Double
        var periodRadius: Double
        var orbitX: CGFloat
        var orbitY: CGFloat
        var radius: CGFloat
        var phase: Double
    }

    /// Long, mutually prime-ish periods so the combined arrangement takes
    /// many minutes to come back around.
    private func specification(slot: Int) -> BlobSpec {
        let periodsX: [Double] = [37, 43, 53, 61, 71]
        let periodsY: [Double] = [47, 59, 41, 67, 79]
        let periodsR: [Double] = [23, 29, 31, 19, 26]
        let orbitsX: [CGFloat] = [0.26, 0.30, 0.20, 0.32, 0.16]
        let orbitsY: [CGFloat] = [0.22, 0.16, 0.28, 0.20, 0.30]
        let radii: [CGFloat] = [0.72, 0.62, 0.80, 0.58, 0.68]

        return BlobSpec(
            paletteIndex: sampleIndices[slot],
            periodX: periodsX[slot],
            periodY: periodsY[slot],
            periodRadius: periodsR[slot],
            orbitX: orbitsX[slot],
            orbitY: orbitsY[slot],
            radius: radii[slot],
            phase: Double(slot) * 1.27
        )
    }
}
