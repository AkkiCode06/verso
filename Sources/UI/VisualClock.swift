import Foundation

/// Accumulates animation phase from a rate that changes over time.
///
/// The obvious approach -- multiplying absolute time by a rate (`t * rate`)
/// -- looks fine until the rate moves. `timeIntervalSinceReferenceDate` is
/// around 7.9e8, so nudging the multiplier by a few percent shifts the result
/// by millions of seconds and the pattern jumps to an unrelated point in its
/// cycle. That is why speeding the visuals up on a drop read as the animation
/// resetting rather than accelerating.
///
/// Integrating instead (`phase += dt * rate`) makes rate a true velocity:
/// changing it alters speed while position stays continuous.
@MainActor
final class VisualClock {
    static let pattern = VisualClock()
    static let gradient = VisualClock()
    /// Advances faster on beats, driving how hard the shader effects flow.
    /// Integrating is what makes this safe: the surge changes speed, where
    /// scaling the clock directly would jump the fluid to a new state.
    static let flow = VisualClock()

    private var phase: Double = 0
    private var lastTime: Double?
    /// The rate actually in use, which chases the requested one rather than
    /// snapping to it.
    private var smoothedRate: Double?

    /// Seconds for the rate to close most of the way to a new target.
    ///
    /// Integrating already guaranteed the phase stays *continuous* when the
    /// rate moves -- but continuous is not the same as gradual. A beat can
    /// take `pulse` from 0 to 1 between two frames, and the motion visibly
    /// lurched even though it never jumped. Easing the velocity as well as
    /// the position is what makes a surge read as the effect gathering pace.
    private static let rateTimeConstant = 2.2

    /// Rate may be negative.
    ///
    /// Phase running backwards simply reverses the motion, which is the point:
    /// a clock that can only ever go forward turns every musical response into
    /// a fast-forward. Clamping to zero here is what made beats read as the
    /// effect skipping ahead.
    func advance(to time: Double, rate: Double) -> Double {
        let target = rate
        guard let last = lastTime else {
            lastTime = time
            smoothedRate = target
            return phase
        }
        // SwiftUI can evaluate a body more than once for the same frame;
        // only advance on a genuinely newer timestamp so repeats are no-ops.
        guard time > last else { return phase }
        lastTime = time
        // Clamp long gaps (display sleep) so the pattern does not lurch.
        let dt = min(time - last, 0.25)

        // Frame-rate independent exponential approach: the same wall-clock
        // easing whether this runs at 60Hz or 120Hz.
        let current = smoothedRate ?? target
        let blend = 1 - exp(-dt / Self.rateTimeConstant)
        let eased = current + (target - current) * blend
        smoothedRate = eased

        phase += dt * eased
        return phase
    }
}

/// An expanding ring of displacement fired when vocals return after a long
/// instrumental -- the geometry gets shoved outward as the wave passes
/// through it, so a drop deforms the pattern instead of restarting it.
struct Shockwave {
    var radius: Double
    var strength: Double

    /// Outward push applied to a point as the wavefront sweeps past.
    func offset(for point: CGPoint, center: CGPoint) -> CGSize {
        guard strength > 0.001 else { return .zero }
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let distance = max((dx * dx + dy * dy).squareRoot(), 1)

        // Only points near the wavefront move; a gaussian keeps the band soft.
        let band = 110.0
        let delta = abs(distance - radius)
        guard delta < band * 1.8 else { return .zero }
        let falloff = exp(-(delta * delta) / (2 * (band / 2) * (band / 2)))

        let push = strength * 42 * falloff
        return CGSize(width: dx / distance * push, height: dy / distance * push)
    }
}
