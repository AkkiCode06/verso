import SwiftUI

/// Every effect in the library, running at once.
///
/// This is cheaper than it looks. Shader cost is per-pixel, not per-instance,
/// so twenty-five tiles at roughly 108x76 come to about a third of the pixels
/// of a single full-window background — the grid costs *less* than the effect
/// it interrupts. The line patterns are drawn on the CPU and are the more
/// expensive half, so they run on a slower clock and at reduced complexity.
struct EffectLibraryGrid: View {
    let time: Double

    private let columns = 9

    var body: some View {
        GeometryReader { geo in
            let rows = Int(ceil(Double(ShaderStyle.allCases.count + BackgroundStyle.allCases.count)
                                / Double(columns)))
            let gap: CGFloat = 5
            let tileW = (geo.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let tileH = max((geo.size.height - gap * CGFloat(rows - 1)) / CGFloat(rows), 10)

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<columns, id: \.self) { column in
                            tile(at: row * columns + column, width: tileW, height: tileH)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(at index: Int, width: CGFloat, height: CGFloat) -> some View {
        let shaders = ShaderStyle.allCases
        let patterns = BackgroundStyle.allCases

        Group {
            if index < shaders.count {
                ShaderBackgroundView(
                    style: shaders[index],
                    // Each tile is offset in time so the grid does not pulse in
                    // unison, which reads as one animation rather than many.
                    time: time + Double(index) * 3.1,
                    flow: time + Double(index) * 3.1,
                    tintA: Color(hue: 0.74, saturation: 0.58, brightness: 0.86),
                    tintB: Color(hue: 0.90, saturation: 0.44, brightness: 0.46)
                )
            } else if index - shaders.count < patterns.count {
                FractalBackgroundView(
                    seed: index,
                    // A third of the rate. These are Canvas draws on the CPU,
                    // and eighteen of them at full speed is the one part of
                    // this grid that would actually cost something.
                    phase: time * 0.33 + Double(index) * 2.3,
                    style: patterns[index - shaders.count]
                )
                .background(Color(hue: 0.76, saturation: 0.42, brightness: 0.20))
            } else {
                Color.white.opacity(0.03)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
