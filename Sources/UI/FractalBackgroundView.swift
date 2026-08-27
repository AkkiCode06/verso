import SwiftUI

/// Deterministic value noise in 0...1 -- stable across frames and launches
/// (unlike `Hasher`, which is randomly seeded per process), so a given track
/// always draws the same pattern.
@inline(__always)
private func noise(_ a: Int, _ b: Int, _ c: Int) -> Double {
    var x = UInt64(bitPattern: Int64(a &* 73856093) ^ Int64(b &* 19349663) ^ Int64(c &* 83492791))
    x ^= x >> 33
    x = x &* 0xff51_afd7_ed55_8ccd
    x ^= x >> 33
    x = x &* 0xc4ce_b9fe_1a85_ec53
    x ^= x >> 33
    return Double(x % 10_000) / 10_000.0
}

/// The generative pattern styles. Every one is drawn as thin, low-opacity
/// white geometry composited with `plusLighter`, so it reads as light on the
/// colour field rather than a layer of its own -- and stays quiet enough for
/// lyrics to sit on top.
enum BackgroundStyle: Int, CaseIterable, Identifiable {
    // Calm
    case ripples, contours, waveBands, bubbles, orbits, starfield, petals
    // Mid
    case flowField, constellation, hexGrid, moire, perspectiveGrid, fractalTree
    // Energetic
    case lowPoly, spiralArms, diagonalRain, circuitry, crosshatch

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .ripples: return "Ripples"
        case .contours: return "Contours"
        case .waveBands: return "Wave Bands"
        case .bubbles: return "Bubbles"
        case .orbits: return "Orbits"
        case .starfield: return "Starfield"
        case .petals: return "Petals"
        case .flowField: return "Flow Field"
        case .constellation: return "Constellation"
        case .hexGrid: return "Hex Grid"
        case .moire: return "Moiré"
        case .perspectiveGrid: return "Perspective Grid"
        case .fractalTree: return "Fractal Tree"
        case .lowPoly: return "Low Poly"
        case .spiralArms: return "Spiral Arms"
        case .diagonalRain: return "Rain"
        case .circuitry: return "Circuitry"
        case .crosshatch: return "Crosshatch"
        }
    }

    static let calm: [BackgroundStyle] = [.ripples, .contours, .waveBands, .bubbles, .orbits, .starfield, .petals]
    static let mid: [BackgroundStyle] = [.flowField, .constellation, .hexGrid, .moire, .perspectiveGrid, .fractalTree]
    static let energetic: [BackgroundStyle] = [.lowPoly, .spiralArms, .diagonalRain, .circuitry, .crosshatch]
}

/// The structural layer: a slow, steady pattern that never reacts to the
/// music. All musical response lives in the colour field behind it, so the
/// geometry stays calm and legible under the lyrics.
struct FractalBackgroundView: View {
    let seed: Int
    /// Accumulated phase from `VisualClock`, advancing at a constant rate.
    let phase: Double
    var style: BackgroundStyle = .constellation

    var body: some View {
        Canvas { context, size in
            switch style {
            case .ripples: drawRipples(&context, size, phase, seed)
            case .contours: drawContours(&context, size, phase, seed)
            case .waveBands: drawWaveBands(&context, size, phase, seed)
            case .bubbles: drawBubbles(&context, size, phase, seed)
            case .orbits: drawOrbits(&context, size, phase, seed)
            case .starfield: drawStarfield(&context, size, phase, seed)
            case .petals: drawPetals(&context, size, phase, seed)
            case .flowField: drawFlowField(&context, size, phase, seed)
            case .constellation: drawConstellation(&context, size, phase, seed)
            case .hexGrid: drawHexGrid(&context, size, phase, seed)
            case .moire: drawMoire(&context, size, phase, seed)
            case .perspectiveGrid: drawPerspectiveGrid(&context, size, phase, seed)
            case .fractalTree: drawFractalTree(&context, size, phase, seed)
            case .lowPoly: drawLowPoly(&context, size, phase, seed)
            case .spiralArms: drawSpiralArms(&context, size, phase, seed)
            case .diagonalRain: drawDiagonalRain(&context, size, phase, seed)
            case .circuitry: drawCircuitry(&context, size, phase, seed)
            case .crosshatch: drawCrosshatch(&context, size, phase, seed)
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
        .opacity(0.85)
    }
}

private let ink = Color.white

// MARK: - Calm

private func drawRipples(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let maxRadius = Double(max(size.width, size.height)) * 0.8
    for k in 0..<3 {
        let center = CGPoint(
            x: CGFloat(0.2 + noise(k, seed, 1) * 0.6) * size.width,
            y: CGFloat(0.2 + noise(k, seed, 2) * 0.6) * size.height
        )
        let speed = 20.0 + Double(k) * 7
        for ring in 0..<14 {
            let offset = Double(ring) * (maxRadius / 14)
            let radius = (t * speed + offset).truncatingRemainder(dividingBy: maxRadius)
            let opacity = (1 - radius / maxRadius) * 0.13
            guard opacity > 0.004, radius > 1 else { continue }
            let rect = CGRect(x: center.x - CGFloat(radius), y: center.y - CGFloat(radius),
                              width: CGFloat(radius * 2), height: CGFloat(radius * 2))
            context.stroke(Path(ellipseIn: rect), with: .color(ink.opacity(opacity)), lineWidth: 1)
        }
    }
}

/// Topographic banding -- stacked lines warped by a drifting field.
private func drawContours(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let levels = 22
    let step = size.height / CGFloat(levels)
    for level in 0...levels {
        var path = Path()
        let baseY = CGFloat(level) * step
        let drift = Double(level) * 0.35 + noise(level, seed, 3) * 6
        var x: CGFloat = -20
        while x <= size.width + 20 {
            let n = sin(Double(x) * 0.006 + drift + t * 0.22)
                + 0.5 * cos(Double(x) * 0.013 - drift * 0.7 + t * 0.16)
            let y = baseY + CGFloat(n) * step * 0.75
            if x <= -20 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            x += 14
        }
        context.stroke(path, with: .color(ink.opacity(0.07)), lineWidth: 0.9)
    }
}

private func drawWaveBands(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let bands = 9
    for band in 0..<bands {
        let baseY = size.height * CGFloat(Double(band) + 0.5) / CGFloat(bands)
        let amplitude = size.height * CGFloat(0.03 + noise(band, seed, 4) * 0.05)
        let frequency = 0.004 + noise(band, seed, 5) * 0.005
        let speed = 0.25 + noise(band, seed, 6) * 0.3
        var path = Path()
        var x: CGFloat = 0
        while x <= size.width {
            let y = baseY + amplitude * CGFloat(sin(Double(x) * frequency + t * speed + Double(band)))
            if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            x += 10
        }
        context.stroke(path, with: .color(ink.opacity(0.10)), lineWidth: 1.2)
    }
}

private func drawBubbles(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let count = 34
    let travel = Double(size.height) + 200
    for i in 0..<count {
        let x = CGFloat(noise(i, seed, 7)) * size.width
        let radius = CGFloat(5 + noise(i, seed, 8) * 34)
        let speed = 14 + noise(i, seed, 9) * 26
        let start = noise(i, seed, 10) * travel
        let y = size.height + 100 - CGFloat((start + t * speed).truncatingRemainder(dividingBy: travel))
        let sway = CGFloat(sin(t * 0.5 + Double(i)) * 12)
        let rect = CGRect(x: x + sway - radius, y: y - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(ink.opacity(0.10)), lineWidth: 1)
    }
}

private func drawOrbits(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let maxRadius = min(size.width, size.height) * 0.72
    for ring in 0..<12 {
        let progress = Double(ring) / 12
        let rx = maxRadius * CGFloat(0.15 + progress * 0.85)
        let ry = rx * CGFloat(0.45 + noise(ring, seed, 11) * 0.5)
        let angle = t * (0.05 + Double(ring) * 0.012) + noise(ring, seed, 12) * 6
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: CGFloat(angle))
        let ellipse = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        context.stroke(ellipse.applying(transform), with: .color(ink.opacity(0.09)), lineWidth: 1)
        transform = .identity
    }
}

private func drawStarfield(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let count = 130
    for i in 0..<count {
        // Three depth layers drifting at different speeds gives parallax.
        let depth = Double(i % 3 + 1)
        let driftX = t * (4 + depth * 5)
        let x = CGFloat((noise(i, seed, 13) * Double(size.width) + driftX)
            .truncatingRemainder(dividingBy: Double(size.width)))
        let y = CGFloat(noise(i, seed, 14)) * size.height
        let twinkle = 0.5 + 0.5 * sin(t * 1.1 + Double(i))
        let r = CGFloat(0.7 + noise(i, seed, 15) * 1.8) * CGFloat(depth) * 0.6
        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect), with: .color(ink.opacity(0.10 + 0.18 * twinkle)))
    }
}

private func drawPetals(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = min(size.width, size.height) * 0.42
    let petals = 7 + Int(noise(seed, 1, 16) * 6)
    for layer in 0..<3 {
        let scale = CGFloat(1 - Double(layer) * 0.26)
        let spin = t * (0.05 + Double(layer) * 0.03)
        for petal in 0..<petals {
            let angle = Double(petal) / Double(petals) * 2 * .pi + spin
            let tip = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius * scale,
                y: center.y + CGFloat(sin(angle)) * radius * scale
            )
            let spread = 0.36
            let controlA = CGPoint(
                x: center.x + CGFloat(cos(angle - spread)) * radius * scale * 0.6,
                y: center.y + CGFloat(sin(angle - spread)) * radius * scale * 0.6
            )
            let controlB = CGPoint(
                x: center.x + CGFloat(cos(angle + spread)) * radius * scale * 0.6,
                y: center.y + CGFloat(sin(angle + spread)) * radius * scale * 0.6
            )
            var path = Path()
            path.move(to: center)
            path.addQuadCurve(to: tip, control: controlA)
            path.addQuadCurve(to: center, control: controlB)
            context.stroke(path, with: .color(ink.opacity(0.07)), lineWidth: 0.9)
        }
    }
}

// MARK: - Mid

private func drawFlowField(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    for k in 0..<34 {
        var x = noise(k, seed, 7) * Double(size.width)
        var y = noise(k, seed, 8) * Double(size.height)
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        for _ in 0..<46 {
            let angle = (sin(x * 0.0035 + t * 0.10)
                         + cos(y * 0.0042 - t * 0.08)
                         + sin((x + y) * 0.0022 + t * 0.05)) * .pi
            x += cos(angle) * 17
            y += sin(angle) * 17
            path.addLine(to: CGPoint(x: x, y: y))
        }
        context.stroke(path, with: .color(ink.opacity(0.05 + noise(k, seed, 11) * 0.07)), lineWidth: 1.1)
    }
}

private func drawConstellation(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let count = 26
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let maxRadius = min(size.width, size.height) * 0.62

    let points: [CGPoint] = (0..<count).map { i in
        let base = Double(i) / Double(count) * 2 * .pi
        let angle = base + (noise(i, seed, 3) - 0.5) * 0.5 + t * 0.02
        let radius = maxRadius * (0.28 + noise(i, seed, 4) * 0.78)
        let breathe = 1 + sin(t * 0.3 + Double(i)) * 0.03
        return CGPoint(x: center.x + CGFloat(cos(angle) * radius * breathe),
                       y: center.y + CGFloat(sin(angle) * radius * breathe))
    }

    let linkDistance = maxRadius * 0.42
    for i in points.indices {
        for j in points.indices where j > i {
            let distance = hypot(points[i].x - points[j].x, points[i].y - points[j].y)
            guard distance < linkDistance else { continue }
            var path = Path()
            path.move(to: points[i])
            path.addLine(to: points[j])
            context.stroke(path, with: .color(ink.opacity(0.16 * (1 - distance / linkDistance))), lineWidth: 0.8)
        }
    }
    for (i, point) in points.enumerated() {
        let r = 1.4 + CGFloat(noise(i, seed, 9) * 2.2)
        context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                     with: .color(ink.opacity(0.32)))
    }
}

private func drawHexGrid(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let radius: CGFloat = 46
    let horizontal = radius * 1.5
    let vertical = radius * CGFloat(3.0.squareRoot())
    let drift = CGFloat(sin(t * 0.12)) * 18
    let columns = Int(size.width / horizontal) + 3
    let rows = Int(size.height / vertical) + 3

    for column in -1..<columns {
        for row in -1..<rows {
            let x = CGFloat(column) * horizontal + drift
            let y = CGFloat(row) * vertical + (column % 2 == 0 ? 0 : vertical / 2)
            let pulse = 0.04 + 0.05 * (0.5 + 0.5 * sin(t * 0.5 + Double(column) * 0.4 + Double(row) * 0.3))
            var path = Path()
            for corner in 0..<6 {
                let angle = Double(corner) * .pi / 3
                let point = CGPoint(x: x + radius * CGFloat(cos(angle)), y: y + radius * CGFloat(sin(angle)))
                if corner == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(ink.opacity(pulse)), lineWidth: 0.8)
        }
    }
}

/// Two line grids at slightly different angles; where they cross, interference
/// bands drift across the screen.
private func drawMoire(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let diagonal = Double(max(size.width, size.height)) * 1.5
    let center = CGPoint(x: size.width / 2, y: size.height / 2)

    for layer in 0..<2 {
        let angle = t * (layer == 0 ? 0.03 : -0.045) + Double(layer) * 0.12 + noise(layer, seed, 17)
        let spacing = 15.0 + Double(layer) * 2.5
        var offset = -diagonal / 2
        while offset < diagonal / 2 {
            let dx = cos(angle), dy = sin(angle)
            let px = center.x + CGFloat(-dy * offset), py = center.y + CGFloat(dx * offset)
            var path = Path()
            path.move(to: CGPoint(x: px - CGFloat(dx * diagonal / 2), y: py - CGFloat(dy * diagonal / 2)))
            path.addLine(to: CGPoint(x: px + CGFloat(dx * diagonal / 2), y: py + CGFloat(dy * diagonal / 2)))
            context.stroke(path, with: .color(ink.opacity(0.045)), lineWidth: 0.7)
            offset += spacing
        }
    }
}

private func drawPerspectiveGrid(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let horizon = size.height * 0.42
    let vanish = CGPoint(x: size.width / 2, y: horizon)

    // Verticals converging on the vanishing point.
    for i in -14...14 {
        var path = Path()
        path.move(to: CGPoint(x: size.width / 2 + CGFloat(i) * size.width * 0.14, y: size.height + 40))
        path.addLine(to: vanish)
        context.stroke(path, with: .color(ink.opacity(0.06)), lineWidth: 0.8)
    }
    // Horizontals scrolling toward the viewer, spaced by a power curve so
    // they bunch up near the horizon.
    for row in 0..<18 {
        let progress = (Double(row) / 18 + t * 0.05).truncatingRemainder(dividingBy: 1)
        let y = horizon + CGFloat(pow(progress, 2.4)) * (size.height - horizon + 60)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(path, with: .color(ink.opacity(0.05 + 0.07 * progress)), lineWidth: 0.9)
    }
}

private func drawFractalTree(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    var pathsByDepth: [Int: Path] = [:]
    let maxDepth = 9
    let spread = 0.38 + noise(seed, 1, 2) * 0.18

    func branch(from origin: CGPoint, angle: Double, length: Double, depth: Int) {
        guard depth > 0, length > 2.5 else { return }
        let sway = sin(t * 0.32 + Double(depth) * 0.9 + noise(depth, seed, 5) * 6) * 0.06
        let a = angle + sway
        let end = CGPoint(x: origin.x + CGFloat(cos(a) * length), y: origin.y + CGFloat(sin(a) * length))
        var path = pathsByDepth[depth] ?? Path()
        path.move(to: origin)
        path.addLine(to: end)
        pathsByDepth[depth] = path
        branch(from: end, angle: a - spread, length: length * 0.73, depth: depth - 1)
        branch(from: end, angle: a + spread, length: length * 0.73, depth: depth - 1)
    }

    branch(from: CGPoint(x: size.width / 2, y: size.height * 1.02),
           angle: -.pi / 2, length: Double(size.height) * 0.23, depth: maxDepth)

    for (depth, path) in pathsByDepth {
        let thinness = Double(depth) / Double(maxDepth)
        context.stroke(path, with: .color(ink.opacity(0.05 + thinness * 0.10)),
                       lineWidth: CGFloat(0.5 + thinness * 2.0))
    }
}

// MARK: - Energetic

private func drawLowPoly(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let columns = 9, rows = 6
    let cellW = size.width / CGFloat(columns)
    let cellH = size.height / CGFloat(rows)

    func vertex(_ i: Int, _ j: Int) -> CGPoint {
        let jitterX = noise(i, j, seed) - 0.5
        let jitterY = noise(i, j, seed &+ 977) - 0.5
        let driftX = sin(t * 0.15 + Double(i) * 0.6 + Double(j) * 0.45) * 0.16
        let driftY = cos(t * 0.12 + Double(i) * 0.4 + Double(j) * 0.7) * 0.16
        return CGPoint(x: CGFloat(i) * cellW + CGFloat(jitterX * 0.68 + driftX) * cellW,
                       y: CGFloat(j) * cellH + CGFloat(jitterY * 0.68 + driftY) * cellH)
    }

    for j in -1...rows {
        for i in -1...columns {
            let a = vertex(i, j), b = vertex(i + 1, j)
            let c = vertex(i, j + 1), d = vertex(i + 1, j + 1)
            for (triangle, salt) in [([a, b, c], 0), ([b, d, c], 1)] {
                var path = Path()
                path.move(to: triangle[0])
                path.addLine(to: triangle[1])
                path.addLine(to: triangle[2])
                path.closeSubpath()
                context.fill(path, with: .color(ink.opacity(0.015 + noise(i, j, seed &+ 31 &+ salt) * 0.075)))
                context.stroke(path, with: .color(ink.opacity(0.045)), lineWidth: 0.6)
            }
        }
    }
}

private func drawSpiralArms(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let maxRadius = Double(min(size.width, size.height)) * 0.75
    let arms = 4 + Int(noise(seed, 2, 18) * 4)

    for arm in 0..<arms {
        var path = Path()
        let armOffset = Double(arm) / Double(arms) * 2 * .pi + t * 0.09
        var theta = 0.2
        while theta < 5.6 {
            let radius = maxRadius * (theta / 5.6) * (theta / 5.6)
            let angle = theta * 1.5 + armOffset
            let point = CGPoint(x: center.x + CGFloat(cos(angle) * radius),
                                y: center.y + CGFloat(sin(angle) * radius))
            if theta <= 0.2 { path.move(to: point) } else { path.addLine(to: point) }
            theta += 0.12
        }
        context.stroke(path, with: .color(ink.opacity(0.09)), lineWidth: 1.2)
    }
}

private func drawDiagonalRain(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let count = 70
    let angle = -0.42
    let travel = Double(size.height) + 260
    for i in 0..<count {
        let length = 30 + noise(i, seed, 19) * 90
        let speed = 90 + noise(i, seed, 20) * 190
        let x = CGFloat(noise(i, seed, 21)) * size.width * 1.3 - size.width * 0.15
        let start = noise(i, seed, 22) * travel
        let y = CGFloat((start + t * speed).truncatingRemainder(dividingBy: travel)) - 130
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + CGFloat(sin(angle) * length), y: y + CGFloat(cos(angle) * length)))
        context.stroke(path, with: .color(ink.opacity(0.06 + noise(i, seed, 23) * 0.09)), lineWidth: 1)
    }
}

/// Right-angle traces with junction pads, drifting like a board layout.
private func drawCircuitry(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let traces = 26
    let drift = CGFloat(sin(t * 0.09)) * 26

    for k in 0..<traces {
        var x = CGFloat(noise(k, seed, 24)) * size.width + drift
        var y = CGFloat(noise(k, seed, 25)) * size.height
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        var horizontal = noise(k, seed, 26) > 0.5

        for step in 0..<7 {
            let run = CGFloat(28 + noise(k, step, seed) * 90)
            let direction: CGFloat = noise(k, step, seed &+ 5) > 0.5 ? 1 : -1
            if horizontal { x += run * direction } else { y += run * direction }
            path.addLine(to: CGPoint(x: x, y: y))
            horizontal.toggle()

            if step % 3 == 2 {
                let r: CGFloat = 2.4
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(ink.opacity(0.22)))
            }
        }
        context.stroke(path, with: .color(ink.opacity(0.09)), lineWidth: 1)
    }
}

private func drawCrosshatch(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, _ seed: Int) {
    let diagonal = Double(max(size.width, size.height)) * 1.6
    let center = CGPoint(x: size.width / 2, y: size.height / 2)

    for layer in 0..<3 {
        let angle = Double(layer) * (.pi / 3) + t * 0.02 + noise(layer, seed, 27)
        let spacing = 34.0 + Double(layer) * 12
        var offset = -diagonal / 2
        while offset < diagonal / 2 {
            let dx = cos(angle), dy = sin(angle)
            let wobble = sin(offset * 0.01 + t * 0.4 + Double(layer)) * 7
            let px = center.x + CGFloat(-dy * (offset + wobble))
            let py = center.y + CGFloat(dx * (offset + wobble))
            var path = Path()
            path.move(to: CGPoint(x: px - CGFloat(dx * diagonal / 2), y: py - CGFloat(dy * diagonal / 2)))
            path.addLine(to: CGPoint(x: px + CGFloat(dx * diagonal / 2), y: py + CGFloat(dy * diagonal / 2)))
            context.stroke(path, with: .color(ink.opacity(0.05)), lineWidth: 0.8)
            offset += spacing
        }
    }
}
