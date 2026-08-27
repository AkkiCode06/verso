#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Per-pixel background effects, run on the GPU via SwiftUI's `colorEffect`.
// These do work the Canvas styles cannot: raymarched geometry, escape-time
// fractals and volumetric layering, evaluated for every pixel every frame.
//
// Each takes the album's two dominant colours so the piece is tinted by the
// record rather than arriving in some fixed palette.

static float2 rotate2(float2 p, float a) {
    float s = sin(a), c = cos(a);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

static float hash21(float2 p) {
    p = fract(p * float2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}


/// A slow breath, and nothing else. Brightness is deliberately deaf to the
/// beat: lifting it on every hit reads as a lamp being switched, which is
/// the cheap version of reacting to music. The whole musical response lives
/// in `flow` instead, where a track changes how the effect *moves*.
static float beatLift(float pulse, float swell, float time) {
    return 1.0 + 0.055 * sin(time * 0.31) + 0.035 * sin(time * 0.17 + 1.7);
}

/// Retained as a pass-through. It used to add a bloom on each beat; that was
/// the glow, and it is gone. Kept in place so every effect keeps one shading
/// path rather than thirty of them growing their own.
static half3 bloom(half3 colour, float intensity, float pulse) {
    return colour;
}

/// Normalised, origin-centred coordinates with the aspect ratio preserved.
static float2 uvCentered(float2 position, float2 size) {
    return (position - 0.5 * size) / min(size.x, size.y);
}

// ---------------------------------------------------------------- plasma
// Stacked, drifting sine fields -- the smoothest of the set, so it sits
// quietly under text.
[[ stitchable ]] half4 wlPlasma(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = uvCentered(position, size) * 2.2;
    float v = 0.0;
    v += sin(uv.x * 1.7 + flow * 0.42);
    v += sin(uv.y * 1.4 - flow * 0.31);
    v += sin((uv.x + uv.y) * 1.1 + flow * 0.27);
    v += sin(length(uv * 1.6) - flow * 0.55);
    v = v * 0.25;

    float band = 0.5 + 0.5 * sin(v * 3.14159 + flow * 0.2);
    half3 colour = mix(tintA, tintB, half(band));
    float vignette = 1.0 - 0.35 * length(uvCentered(position, size));
    float intensity = (0.55 + 0.45 * band) * vignette * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(intensity), intensity, pulse), 1.0h);
}

// ----------------------------------------------------------- kaleidoscope
// Polar folding over a drifting noise field, producing shifting symmetry.
[[ stitchable ]] half4 wlKaleido(float2 position, half4 current,
                                 float2 size, float time, float flow,
                                 half3 tintA, half3 tintB,
                                 float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float radius = length(uv);
    float angle = atan2(uv.y, uv.x);

    const float segments = 8.0;
    float wedge = 6.28318 / segments;
    angle = abs(fmod(angle + flow * 0.09, wedge) - wedge * 0.5);

    float2 folded = float2(cos(angle), sin(angle)) * radius;
    float pattern = 0.0;
    float scale = 2.4;
    for (int i = 0; i < 4; i++) {
        pattern += sin(folded.x * scale + flow * 0.5) * cos(folded.y * scale - flow * 0.37) / scale;
        scale *= 1.9;
    }

    float intensity = clamp(0.5 + pattern * 1.6, 0.0, 1.0);
    half3 colour = mix(tintA, tintB, half(intensity));
    float falloff = smoothstep(1.05, 0.15, radius);
    float lit = intensity * falloff * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(lit), lit, pulse), 1.0h);
}

// ---------------------------------------------------------------- aurora
// Layered vertical curtains sheared by noise, drifting like polar light.
[[ stitchable ]] half4 wlAurora(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = position / size;
    float glow = 0.0;

    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float phase = flow * (0.16 + fi * 0.045) + fi * 2.1;
        // Each curtain is a horizontal ribbon warped by stacked sines.
        float centre = 0.5
            + sin(uv.x * 2.3 + phase) * 0.16
            + sin(uv.x * 5.1 - phase * 0.7) * 0.06;
        float thickness = 0.055 + 0.03 * sin(phase * 0.8);
        float band = thickness / (abs(uv.y - centre) + thickness * 0.55);
        glow += band * (0.35 + 0.25 * sin(phase));
    }

    glow = clamp(glow * 0.28, 0.0, 1.4) * beatLift(pulse, swell, time);
    half3 colour = mix(tintA, tintB, half(clamp(uv.y * 1.2, 0.0, 1.0)));
    return half4(bloom(colour * half(glow), glow, pulse), 1.0h);
}

// --------------------------------------------------------------- fractal
// Animated Julia set: escape-flow iteration with a slowly orbiting seed.
[[ stitchable ]] half4 wlFractal(float2 position, half4 current,
                                 float2 size, float time, float flow,
                                 half3 tintA, half3 tintB,
                                 float pulse, float swell) {
    float2 uv = uvCentered(position, size) * 2.6;
    uv = rotate2(uv, flow * 0.05);

    float2 seed = float2(0.7885 * cos(flow * 0.12), 0.7885 * sin(flow * 0.17));
    float2 z = uv;
    int iterations = 0;
    const int maxIterations = 64;
    for (int i = 0; i < maxIterations; i++) {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + seed;
        if (dot(z, z) > 16.0) break;
        iterations++;
    }

    // Smooth the banding that raw iteration counts produce.
    float smoothed = float(iterations) + 1.0 - log2(max(log2(length(z)), 1.0));
    float t = clamp(smoothed / float(maxIterations), 0.0, 1.0);
    float shade = pow(t, 0.55);
    half3 colour = mix(tintA, tintB, half(shade));
    float lit = shade * 1.15 * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(lit), lit, pulse), 1.0h);
}

// ---------------------------------------------------------------- liquid
// Metaballs: overlapping fields summed into a single flowing surface.
[[ stitchable ]] half4 wlLiquid(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float field = 0.0;

    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float2 centre = float2(
            sin(flow * (0.21 + fi * 0.031) + fi * 1.7) * 0.62,
            cos(flow * (0.17 + fi * 0.027) + fi * 2.3) * 0.44
        );
        float radius = 0.16 + 0.07 * sin(flow * 0.3 + fi);
        field += radius * radius / max(dot(uv - centre, uv - centre), 0.0006);
    }

    // Threshold the summed field so the blobs fuse and separate.
    // A hit lowers the threshold, so the blobs visibly expand and merge.
    float threshold = 1.1 - 0.10 * pulse;
    float surface = smoothstep(threshold, 3.4, field);
    float rim = smoothstep(3.4, 6.5, field);
    half3 colour = mix(tintA, tintB, half(rim));
    float lit = surface * 0.95 * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(lit), lit, pulse), 1.0h);
}

// ---------------------------------------------------------------- warp
// Domain-warped noise: a field displaced by another copy of itself, giving
// slow marbled turbulence.
[[ stitchable ]] half4 wlWarp(float2 position, half4 current,
                              float2 size, float time, float flow,
                              half3 tintA, half3 tintB,
                              float pulse, float swell) {
    float2 uv = uvCentered(position, size) * 1.8;

    float2 q = float2(
        sin(uv.x * 1.3 + flow * 0.21) + cos(uv.y * 1.7 - flow * 0.13),
        cos(uv.x * 1.9 - flow * 0.17) + sin(uv.y * 1.1 + flow * 0.23)
    );
    float2 r = float2(
        sin(uv.x * 2.1 + q.y * 1.4 + flow * 0.11),
        cos(uv.y * 2.3 + q.x * 1.2 - flow * 0.09)
    );
    float value = 0.5 + 0.5 * sin(uv.x * 1.1 + r.x * 2.2 + flow * 0.15)
                      * cos(uv.y * 1.3 + r.y * 1.8 - flow * 0.12);

    float grain = hash21(floor(position * 0.5)) * 0.03;
    half3 colour = mix(tintA, tintB, half(clamp(value, 0.0, 1.0)));
    float lit = (0.45 + 0.65 * value + grain) * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(lit), lit, pulse), 1.0h);
}

// ============================================================ additional

static float fbmNoise(float2 p) {
    float total = 0.0, amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        float2 cell = floor(p);
        float2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = hash21(cell);
        float b = hash21(cell + float2(1.0, 0.0));
        float c = hash21(cell + float2(0.0, 1.0));
        float d = hash21(cell + float2(1.0, 1.0));
        total += amplitude * mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
        p *= 2.02;
        amplitude *= 0.5;
    }
    return total;
}

// ---------------------------------------------------------------- nebula
// Layered fractal noise, drifting like interstellar cloud.
[[ stitchable ]] half4 wlNebula(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = uvCentered(position, size) * 2.6;
    // Warping the sample point by another noise field gives the billowing.
    float2 warp = float2(fbmNoise(uv + flow * 0.035), fbmNoise(uv.yx - flow * 0.028));
    float density = fbmNoise(uv * 1.4 + warp * 2.1 + flow * 0.02);
    float shaped = smoothstep(0.28, 0.86, density);

    half3 colour = mix(tintA, tintB, half(shaped));
    float lit = (0.22 + shaped * 0.95) * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(lit), lit, pulse), 1.0h);
}

// --------------------------------------------------------------- voronoi
// Drifting cell field; the seams between cells carry the light.
[[ stitchable ]] half4 wlVoronoi(float2 position, half4 current,
                                 float2 size, float time, float flow,
                                 half3 tintA, half3 tintB,
                                 float pulse, float swell) {
    float2 uv = uvCentered(position, size) * 4.2;
    float2 cell = floor(uv);
    float nearest = 10.0, second = 10.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 neighbour = cell + float2(float(x), float(y));
            float2 seed = float2(hash21(neighbour), hash21(neighbour + 41.7));
            // Each seed orbits its own cell so the mosaic keeps shifting.
            float2 point = neighbour + 0.5 + 0.42 * sin(flow * 0.32 + 6.28 * seed);
            float distance = length(point - uv);
            if (distance < nearest) { second = nearest; nearest = distance; }
            else if (distance < second) { second = distance; }
        }
    }

    // The gap between the two closest seeds is the cell border.
    float edge = smoothstep(0.0, 0.42, second - nearest);
    float glow = 1.0 - edge;
    half3 colour = mix(tintA, tintB, half(clamp(nearest * 0.9, 0.0, 1.0)));
    float lit = (0.16 + glow * 0.95) * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(lit), lit, pulse), 1.0h);
}

// ------------------------------------------------------------------ orbs
// Soft glowing spheres drifting at different depths.
[[ stitchable ]] half4 wlOrbs(float2 position, half4 current,
                              float2 size, float time, float flow,
                              half3 tintA, half3 tintB,
                              float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float light = 0.0;
    float tintMix = 0.0;

    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        float depth = 0.4 + hash21(float2(fi, 3.1)) * 0.9;
        float2 centre = float2(
            sin(flow * (0.13 + fi * 0.021) + fi * 2.4) * 0.72,
            cos(flow * (0.11 + fi * 0.019) + fi * 1.6) * 0.5
        );
        float radius = (0.05 + hash21(float2(fi, 7.7)) * 0.11) * depth;
        float distance = length(uv - centre);
        // Inverse-square falloff reads as a genuine light source.
        float contribution = radius * radius / max(distance * distance, 0.0008);
        light += contribution;
        tintMix += contribution * hash21(float2(fi, 11.3));
    }

    float shaped = clamp(light * 0.5, 0.0, 1.6);
    half3 colour = mix(tintA, tintB, half(clamp(tintMix / max(light, 0.001), 0.0, 1.0)));
    float lit = shaped * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(lit), lit, pulse), 1.0h);
}

// ------------------------------------------------------------------ silk
// Stacked flowing ribbons, like light across folded fabric.
[[ stitchable ]] half4 wlSilk(float2 position, half4 current,
                              float2 size, float time, float flow,
                              half3 tintA, half3 tintB,
                              float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float sheen = 0.0;

    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float phase = flow * (0.19 + fi * 0.028) + fi * 1.9;
        float fold = sin(uv.x * (1.7 + fi * 0.5) + phase)
                   * cos(uv.x * (0.9 + fi * 0.3) - phase * 0.6) * 0.24;
        float band = abs(uv.y - fold + (fi - 2.5) * 0.14);
        // Thin, bright highlight along each fold.
        sheen += 0.018 / (band + 0.022);
    }

    float shaped = clamp(sheen * 0.30, 0.0, 1.5);
    half3 colour = mix(tintA, tintB, half(clamp(uv.y + 0.5, 0.0, 1.0)));
    float lit = shaped * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(lit), lit, pulse), 1.0h);
}

// ================================================== raymarched 3D effects
//
// These march a ray through a signed-distance field, estimate a surface
// normal by sampling the field around the hit, and shade it. That is what
// separates them from the 2D pieces above: there is real geometry with
// depth, silhouettes and lighting rather than a pattern painted flat.

static float3 estimateNormal(float3 p, float (*field)(float3, float), float flow) {
    const float e = 0.0015;
    return normalize(float3(
        field(p + float3(e, 0, 0), flow) - field(p - float3(e, 0, 0), flow),
        field(p + float3(0, e, 0), flow) - field(p - float3(0, e, 0), flow),
        field(p + float3(0, 0, e), flow) - field(p - float3(0, 0, e), flow)
    ));
}

/// Shared shading: a key light plus a rim, tinted by the album.
static half4 shadeSurface(float3 normal, float3 rayDir, float depth,
                          half3 tintA, half3 tintB,
                          float pulse, float swell, float time) {
    float3 key = normalize(float3(0.6, 0.8, -0.5));
    float diffuse = max(dot(normal, key), 0.0);
    float rim = pow(1.0 - max(dot(normal, -rayDir), 0.0), 2.5);
    float fog = exp(-depth * 0.055);

    half3 colour = mix(tintA, tintB, half(clamp(diffuse, 0.0, 1.0)));
    float intensity = (0.16 + diffuse * 0.75 + rim * 0.55) * fog * beatLift(pulse, swell, time);
    return half4(bloom(colour * half(intensity), intensity, pulse), 1.0h);
}

// ---------------------------------------------------------------- waves
static float waveField(float3 p, float flow) {
    // Distance to an animated heightfield, approximated by the vertical gap.
    float h = sin(p.x * 0.9 + flow * 0.7) * 0.34
            + sin(p.z * 1.3 - flow * 0.5) * 0.26
            + sin((p.x + p.z) * 0.6 + flow * 0.3) * 0.18;
    return (p.y - h) * 0.62;
}

[[ stitchable ]] half4 wlWaves(float2 position, half4 current,
                               float2 size, float time, float flow,
                               half3 tintA, half3 tintB,
                               float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float3 origin = float3(0, 1.5, -4.0 + flow * 0.6);
    float3 dir = normalize(float3(uv, 1.0));

    float travelled = 0.0;
    for (int i = 0; i < 56; i++) {
        float d = waveField(origin + dir * travelled, flow);
        if (d < 0.004 || travelled > 24.0) break;
        travelled += d;
    }
    if (travelled > 24.0) return half4(0, 0, 0, 1);

    float3 hit = origin + dir * travelled;
    // Differentiating the height sum by hand costs three cosines; estimating
    // the same normal by sampling costs six more evaluations of the field.
    float cross = cos((hit.x + hit.z) * 0.6 + flow * 0.3) * 0.6 * 0.18;
    float dx = cos(hit.x * 0.9 + flow * 0.7) * 0.9 * 0.34 + cross;
    float dz = cos(hit.z * 1.3 - flow * 0.5) * 1.3 * 0.26 + cross;
    float3 normal = normalize(float3(-dx, 1.0, -dz));
    return shadeSurface(normal, dir, travelled, tintA, tintB, pulse, swell, time);
}

// ---------------------------------------------------------------- helix
static float helixField(float3 p, float flow) {
    float best = 10.0;
    for (int strand = 0; strand < 2; strand++) {
        float offset = float(strand) * 3.14159;
        float angle = p.z * 0.9 + flow * 0.5 + offset;
        float2 centre = float2(cos(angle), sin(angle)) * 0.85;
        best = min(best, length(p.xy - centre) - 0.17);
    }
    return best;
}

[[ stitchable ]] half4 wlHelix(float2 position, half4 current,
                               float2 size, float time, float flow,
                               half3 tintA, half3 tintB,
                               float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float3 origin = float3(0, 0, -4.2);
    float3 dir = normalize(float3(uv, 1.0));

    float travelled = 0.0;
    for (int i = 0; i < 52; i++) {
        float d = helixField(origin + dir * travelled, flow);
        if (d < 0.003 || travelled > 20.0) break;
        travelled += d * 0.85;
    }
    if (travelled > 20.0) return half4(0, 0, 0, 1);

    float3 hit = origin + dir * travelled;
    // Pick the strand actually hit, then take its normal analytically: the
    // radial offset with the strand's own axis projected out. Sampling the
    // field six times would give the same vector for far more work.
    float a0 = hit.z * 0.9 + flow * 0.5;
    float2 c0 = float2(cos(a0), sin(a0)) * 0.85;
    float2 c1 = -c0;
    float2 centre = length(hit.xy - c0) < length(hit.xy - c1) ? c0 : c1;
    float3 axis = normalize(float3(-centre.y * 0.9, centre.x * 0.9, 1.0));
    float3 radial = float3(hit.xy - centre, 0.0);
    float3 normal = normalize(radial - axis * dot(radial, axis));
    return shadeSurface(normal, dir, travelled, tintA, tintB, pulse, swell, time);
}


// ===================================================== analytic 3D effects
//
// Real perspective and depth without marching a ray. A plane or a sphere can
// be intersected in closed form -- one solve, and the surface normal falls
// out of the algebra instead of costing six extra field samples. That is the
// whole difference from the two marched pieces above: the same sense of
// space for a small fraction of the per-pixel cost, which is what keeps
// these smooth on integrated GPUs.

/// Horizon-to-zenith wash, so distance falls off into colour rather than
/// into dead black.
static half3 skyWash(float3 dir, half3 tintA, half3 tintB, float lift) {
    float h = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
    return mix(tintB * half(0.30), tintA * half(0.13), half(h)) * half(lift);
}

/// Ray/plane in closed form. Negative when the ray never reaches it.
static float planeHit(float3 origin, float3 dir, float height) {
    if (abs(dir.y) < 1e-4) return -1.0;
    float t = (height - origin.y) / dir.y;
    return t > 0.0 ? t : -1.0;
}

/// Ray/sphere in closed form: the near root of the quadratic, or -1.
static float sphereHit(float3 origin, float3 dir, float3 centre, float radius) {
    float3 oc = origin - centre;
    float b = dot(oc, dir);
    float c = dot(oc, oc) - radius * radius;
    float disc = b * b - c;
    if (disc < 0.0) return -1.0;
    float t = -b - sqrt(disc);
    return t > 0.0 ? t : -1.0;
}

/// Distance haze towards the sky colour.
static half3 haze(half3 colour, half3 sky, float depth, float density) {
    return mix(colour, sky, half(1.0 - exp(-depth * density)));
}

/// Two-octave value noise for pieces that want texture but not the full
/// five-octave fbm.
static float softNoise(float2 p) {
    float2 cell = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(cell), b = hash21(cell + float2(1, 0));
    float c = hash21(cell + float2(0, 1)), d = hash21(cell + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

/// Lambert key light plus rim, shared by the closed-form surfaces.
static half3 litSurface(float3 normal, float3 dir, half3 tintA, half3 tintB, float lift) {
    float3 key = normalize(float3(0.45, 0.75, -0.55));
    float diffuse = max(dot(normal, key), 0.0);
    float rim = pow(1.0 - max(dot(normal, -dir), 0.0), 2.5);
    half3 colour = mix(tintB, tintA, half(diffuse));
    return colour * half((0.17 + diffuse * 0.70 + rim * 0.45) * lift);
}

// ---------------------------------------------------------------- ripple
// A lit water surface. The plane is still one solve; all the interest is in
// the height field laid over it -- three circular wave trains from separate
// origins, plus a long directional swell underneath so the water has a set
// rather than looking like a pond. Because the gradient of a sum of sines is
// just the sum of the derivatives, the normal is exact and costs a handful
// of cosines instead of a sampled estimate.
[[ stitchable ]] half4 wlRipple(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    float3 dir = normalize(float3(uv.x, uv.y + 0.30, 1.0));
    float3 origin = float3(0.0, 1.35, 0.0);

    // A sun in the sky, because the water needs something to glitter from.
    // Without a light source to reflect, a water shader is just a gradient.
    float3 sun = normalize(float3(0.22, 0.40, 1.0));
    float toSun = max(dot(dir, sun), 0.0);
    half3 sky = skyWash(dir, tintA, tintB, lift)
              + tintA * half(pow(toSun, 7.0) * 0.35 * lift)
              + half3(half(pow(toSun, 220.0) * 0.85 * lift));

    float t = planeHit(origin, dir, 0.0);
    if (t < 0.0) return half4(sky, 1.0h);

    float3 hit = origin + dir * t;
    float2 p = float2(hit.x, hit.z);
    // Detail has to fade with distance or the far water aliases into noise.
    // This is the cheap stand-in for choosing a mip level.
    float detail = 1.0 / (1.0 + t * 0.20);

    float2 grad = float2(0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float2 centre = float2(sin(fi * 2.4) * 3.4, 5.0 + fi * 2.8);
        float2 d = p - centre;
        float r = length(d) + 1e-4;
        float k = 2.0 + fi * 0.75;
        // d/dr of amp*sin(kr - wt), pushed back out along the radius.
        float slope = (0.060 - fi * 0.013) * detail * k
                    * cos(r * k - flow * (1.05 + fi * 0.28)) * exp(-r * 0.11);
        grad += d / r * slope;
    }
    float2 set = float2(0.82, 0.57);
    grad += set * 0.05 * detail * cos(dot(p, set) * 0.75 - flow * 0.45);

    float3 normal = normalize(float3(-grad.x, 1.0, -grad.y));
    float3 view = -dir;

    // Blinn-Phong. The halfway vector is what draws the long glitter streak
    // across the water instead of one round hotspot.
    float3 halfway = normalize(sun + view);
    float facing = max(dot(normal, halfway), 0.0);
    float glitter = pow(facing, 110.0);
    float sheen = pow(facing, 16.0) * 0.16;

    // Fresnel: water at a grazing angle is a mirror, water underfoot is not.
    // This is most of what makes a surface read as wet.
    float fresnel = 0.03 + 0.97 * pow(1.0 - max(dot(normal, view), 0.0), 5.0);
    half3 depths = tintB * half(0.24 * lift);
    half3 mirrored = mix(tintB * half(0.5), tintA, half(0.65)) * half(0.9 * lift);

    half3 colour = mix(depths, mirrored, half(fresnel))
                 + half3(half((glitter + sheen) * lift));
    colour = haze(colour, sky, t, 0.055);
    return half4(colour, 1.0h);
}

// ---------------------------------------------------------------- mirror
// A polished floor: the reflected ray is one `reflect()`, and what it
// returns is the sky, so the reflection costs a wash lookup rather than a
// second trace.
[[ stitchable ]] half4 wlMirror(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    float3 dir = normalize(float3(uv.x, uv.y + 0.05, 1.0));
    float3 origin = float3(0.0, 0.9, 0.0);

    float bands = 0.5 + 0.5 * sin(dir.y * 7.0 - flow * 0.35) * exp(-abs(dir.y) * 1.4);
    half3 sky = skyWash(dir, tintA, tintB, lift) + mix(tintA, tintB, half(bands)) * half(bands * 0.42 * lift);

    float t = planeHit(origin, dir, 0.0);
    if (t < 0.0) return half4(sky, 1.0h);

    float3 hit = origin + dir * t;
    float wobble = sin(hit.z * 1.6 + flow * 0.8) * 0.02 + sin(hit.x * 2.1 - flow * 0.5) * 0.015;
    float3 normal = normalize(float3(wobble, 1.0, wobble * 0.6));
    float3 bounce = reflect(dir, normal);
    float rippled = 0.5 + 0.5 * sin(bounce.y * 7.0 - flow * 0.35) * exp(-abs(bounce.y) * 1.4);

    half3 colour = mix(tintB * half(0.35), tintA, half(rippled)) * half(rippled * 0.85 * lift);
    // Fresnel: a glancing ray reflects most, a steep one drinks the floor.
    float fresnel = pow(1.0 - max(-dir.y, 0.0), 4.0);
    colour = mix(colour * half(0.35), colour, half(fresnel));
    colour = haze(colour, sky, t, 0.05);
    return half4(bloom(colour, rippled * fresnel, pulse), 1.0h);
}

// -------------------------------------------------------------- wormhole
// Circular tunnel with the twist applied as a function of depth, so the
// walls appear to spiral away from the camera.
[[ stitchable ]] half4 wlWormhole(float2 position, half4 current,
                                  float2 size, float time, float flow,
                                  half3 tintA, half3 tintB,
                                  float pulse, float swell) {
    float2 uv = uvCentered(position, size) * 2.0;
    float lift = beatLift(pulse, swell, time);
    float r = max(length(uv), 1e-3);
    float depth = 1.0 / r + flow * 0.6;
    float around = atan2(uv.y, uv.x) * 0.15915494 + depth * 0.10;

    float strands = 0.5 + 0.5 * sin(around * 25.1327 + depth * 3.0);
    float rings = 0.5 + 0.5 * sin(depth * 12.0);
    float pattern = strands * 0.55 + rings * 0.35;

    half3 colour = mix(tintB, tintA, half(strands));
    float near = clamp(r * 1.5, 0.0, 1.0);
    float intensity = (0.08 + pattern * 0.95) * near * lift;
    return half4(bloom(colour * half(intensity), intensity, pulse), 1.0h);
}

// ----------------------------------------------------------------- rings
// Concentric rings marching toward the camera. Each one's screen radius is
// its true radius over its depth -- the projection is the whole effect.
[[ stitchable ]] half4 wlRings(float2 position, half4 current,
                               float2 size, float time, float flow,
                               half3 tintA, half3 tintB,
                               float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    float r = length(uv);
    float glow = 0.0;

    for (int i = 0; i < 9; i++) {
        // Each ring recycles through depth on its own offset.
        float z = fract(flow * 0.06 + float(i) * 0.1111) * 5.0 + 0.28;
        float radius = 1.15 / z;
        float band = exp(-abs(r - radius) * (55.0 / (1.0 + z)));
        glow += band * (1.0 - z * 0.18);
    }

    half3 colour = mix(tintB, tintA, half(clamp(r * 1.4, 0.0, 1.0)));
    float intensity = clamp(glow, 0.0, 1.6) * 0.7 * lift;
    return half4(bloom(colour * half(intensity), intensity, pulse), 1.0h);
}

// ---------------------------------------------------------------- vortex
// A spiral drain: radius and angle in one term, depth-faded toward the eye.
[[ stitchable ]] half4 wlVortex(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    float r = max(length(uv), 1e-3);
    float around = atan2(uv.y, uv.x);
    // log(r) makes the spiral self-similar, so it never visibly repeats.
    float spiral = sin(around * 3.0 + log(r) * 5.0 - flow * 0.9);
    float arms = 0.5 + 0.5 * spiral;

    float core = exp(-r * 3.4);
    half3 colour = mix(tintB, tintA, half(arms));
    float intensity = (arms * 0.62 * smoothstep(0.0, 0.35, r) + core * 0.85) * lift;
    return half4(bloom(colour * half(intensity), intensity, pulse), 1.0h);
}

// ----------------------------------------------------------------- orbit
// Five genuine spheres, each solved with the quadratic. Real silhouettes and
// real normals, at five intersection tests per pixel instead of a march.
[[ stitchable ]] half4 wlOrbit(float2 position, half4 current,
                               float2 size, float time, float flow,
                               half3 tintA, half3 tintB,
                               float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    float3 dir = normalize(float3(uv, 1.3));
    float3 origin = float3(0.0, 0.0, -5.0);
    half3 sky = skyWash(dir, tintA, tintB, lift);

    float nearest = 1e9;
    float3 normal = float3(0, 1, 0);
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float a = flow * 0.32 + fi * 1.2566;
        float3 centre = float3(cos(a) * 1.9, sin(a * 1.3) * 0.8, sin(a) * 1.9);
        float radius = 0.44 + 0.09 * sin(flow * 0.6 + fi);
        float t = sphereHit(origin, dir, centre, radius);
        if (t > 0.0 && t < nearest) {
            nearest = t;
            normal = ((origin + dir * t) - centre) / radius;
        }
    }
    if (nearest > 1e8) return half4(sky, 1.0h);

    half3 colour = haze(litSurface(normal, dir, tintA, tintB, lift), sky, nearest, 0.045);
    return half4(bloom(colour, 0.6, pulse), 1.0h);
}

// --------------------------------------------------------------- bubbles
// Glass spheres. The shell is Fresnel only -- bright at the silhouette,
// clear through the middle -- which is why they read as hollow without any
// refraction being traced.
[[ stitchable ]] half4 wlBubbles(float2 position, half4 current,
                                 float2 size, float time, float flow,
                                 half3 tintA, half3 tintB,
                                 float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    float3 dir = normalize(float3(uv, 1.4));
    float3 origin = float3(0.0, 0.0, -4.5);
    half3 colour = skyWash(dir, tintA, tintB, lift);

    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float3 centre = float3(
            sin(fi * 2.1 + flow * 0.16) * 1.9,
            fract(hash21(float2(fi, 4.0)) + flow * 0.045) * 4.0 - 2.0,
            sin(fi * 1.3) * 1.4
        );
        float radius = 0.30 + hash21(float2(fi, 9.0)) * 0.34;
        float t = sphereHit(origin, dir, centre, radius);
        if (t < 0.0) continue;
        float3 normal = ((origin + dir * t) - centre) / radius;
        float fresnel = pow(1.0 - max(dot(normal, -dir), 0.0), 3.0);
        float sheen = pow(max(dot(normal, normalize(float3(0.5, 0.8, -0.4))), 0.0), 32.0);
        colour += mix(tintA, tintB, half(fract(fi * 0.37))) * half((fresnel * 0.75 + sheen * 0.6) * lift);
    }
    return half4(bloom(colour, 0.55, pulse), 1.0h);
}

// ---------------------------------------------------------------- galaxy
// Logarithmic spiral arms seen at a tilt. Squashing y before taking the
// radius is what turns a face-on disc into one lying in perspective.
[[ stitchable ]] half4 wlGalaxy(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float2 disc = float2(uv.x, uv.y / 0.42);   // the tilt
    float lift = beatLift(pulse, swell, time);
    float r = max(length(disc), 1e-3);
    float around = atan2(disc.y, disc.x);

    float arms = 0.5 + 0.5 * sin(around * 2.0 + log(r) * 4.2 - flow * 0.32);
    arms *= smoothstep(1.5, 0.25, r);
    float grain = softNoise(disc * 5.0 + flow * 0.05) * 0.35 + 0.65;
    float core = exp(-r * 4.5);

    half3 colour = mix(tintB, tintA, half(arms));
    float intensity = (arms * grain * 0.7 + core * 1.1) * lift;
    return half4(bloom(colour * half(intensity), intensity, pulse), 1.0h);
}

// ---------------------------------------------------------------- strata
// Parallax layers: each sits at its own depth and scrolls at a rate
// proportional to 1/depth, which is the same relationship that makes distant
// scenery crawl past a car window.
[[ stitchable ]] half4 wlStrata(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    half3 colour = mix(tintB * half(0.28), tintA * half(0.08), half(uv.y + 0.5)) * half(lift);

    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float depth = 1.0 + fi * 0.9;
        float scroll = flow * (0.20 / depth);
        float ridge = sin(uv.x * (1.4 + fi * 0.35) + scroll) * 0.09
                    + sin(uv.x * (3.1 - fi * 0.2) - scroll * 1.6) * 0.045;
        float top = -0.32 + fi * 0.085 + ridge;
        float mask = smoothstep(top + 0.012, top - 0.012, uv.y);
        half3 band = mix(tintA, tintB, half(fi / 5.0)) * half((1.0 - fi * 0.13) * lift);
        colour = mix(colour, band, half(mask * 0.85));
    }
    return half4(bloom(colour, 0.4, pulse), 1.0h);
}

// ---------------------------------------------------------------- clouds
// Three noise layers at different depths, offset against each other. Kept to
// two octaves apiece -- the full fbm is five, and at three layers that would
// be fifteen octaves a pixel for no visible gain.
[[ stitchable ]] half4 wlClouds(float2 position, half4 current,
                                float2 size, float time, float flow,
                                half3 tintA, half3 tintB,
                                float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    half3 colour = mix(tintB * half(0.30), tintA * half(0.10), half(uv.y + 0.5)) * half(lift);

    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float depth = 1.0 + fi * 1.2;
        float2 p = uv * (2.2 + fi * 1.5) + float2(flow * (0.14 / depth), -fi * 3.7);
        float n = softNoise(p) * 0.65 + softNoise(p * 2.3 + 11.0) * 0.35;
        float body = smoothstep(0.48, 0.78, n) * (1.0 - fi * 0.22);
        colour += mix(tintA, tintB, half(fi * 0.4)) * half(body * 0.55 * lift);
    }
    return half4(bloom(colour, 0.5, pulse), 1.0h);
}

// -------------------------------------------------------------- curtains
// Aurora sheets standing at different distances. The vertical falloff plus
// horizontal drift is what makes them hang rather than lie flat.
[[ stitchable ]] half4 wlCurtains(float2 position, half4 current,
                                  float2 size, float time, float flow,
                                  half3 tintA, half3 tintB,
                                  float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    half3 colour = tintB * half(0.07 * lift);

    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float depth = 1.0 + fi * 0.7;
        float sway = sin(uv.x * (2.2 + fi * 0.6) + flow * (0.34 / depth) + fi * 2.0) * 0.16;
        float centre = -0.05 + fi * 0.04 + sway;
        float sheet = exp(-abs(uv.y - centre) * (7.0 + fi * 2.2));
        // Vertical striations, so the sheet has grain instead of being a
        // smooth smear.
        float grain = 0.65 + 0.35 * sin(uv.x * 30.0 + flow * 0.5 + fi * 3.1);
        colour += mix(tintA, tintB, half(fi / 4.0)) * half(sheet * grain * (0.75 / depth) * lift);
    }
    return half4(bloom(colour, 0.6, pulse), 1.0h);
}

// --------------------------------------------------------------- ribbons
// Sine bands whose thickness and brightness both scale with 1/depth, which
// is enough to make them stack away from the eye.
[[ stitchable ]] half4 wlRibbons(float2 position, half4 current,
                                 float2 size, float time, float flow,
                                 half3 tintA, half3 tintB,
                                 float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    half3 colour = tintB * half(0.06 * lift);

    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float depth = 0.6 + fi * 0.45;
        float wave = sin(uv.x * (1.8 / depth) * 2.4 + flow * (0.5 / depth) + fi) * (0.30 / depth);
        float thickness = 0.020 + 0.030 / depth;
        float band = smoothstep(thickness, 0.0, abs(uv.y - wave - (fi - 3.0) * 0.055));
        colour += mix(tintA, tintB, half(fi / 6.0)) * half(band * (0.9 / depth) * lift);
    }
    return half4(bloom(colour, 0.65, pulse), 1.0h);
}

// ----------------------------------------------------------------- prism
// One refraction, done honestly: the three channels are offset by different
// amounts because they bend by different amounts, which is where the fringe
// colour comes from.
[[ stitchable ]] half4 wlPrism(float2 position, half4 current,
                               float2 size, float time, float flow,
                               half3 tintA, half3 tintB,
                               float pulse, float swell) {
    float2 uv = uvCentered(position, size);
    float lift = beatLift(pulse, swell, time);
    float2 p = rotate2(uv, flow * 0.05);
    float spread = 0.055 + 0.02 * pulse;

    half3 colour = half3(0.0);
    for (int c = 0; c < 3; c++) {
        float shift = (float(c) - 1.0) * spread;
        float fan = sin((p.x + shift) * 6.0 + p.y * 2.0 + flow * 0.28);
        float band = smoothstep(0.35, 0.95, fan) * exp(-abs(p.y) * 1.1);
        half3 channel = c == 0 ? half3(1.0, 0.25, 0.25)
                     : c == 1 ? half3(0.25, 1.0, 0.45)
                              : half3(0.35, 0.4, 1.0);
        colour += channel * half(band * 0.45);
    }
    // Pulled back toward the album so it tints rather than going full rainbow.
    colour = mix(colour, mix(tintA, tintB, half(0.5)) * half(length(float3(colour)) * 0.6), half(0.55));
    float intensity = clamp(float(colour.r + colour.g + colour.b) * 0.4, 0.0, 1.4) * lift;
    return half4(bloom(colour * half(lift), intensity, pulse), 1.0h);
}

