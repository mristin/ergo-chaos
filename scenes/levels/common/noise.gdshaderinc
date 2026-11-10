// Shared, cheap procedural helpers for the level backgrounds.
//
// Everything here is written with an integrated GPU in mind: hashes are
// arithmetic only (no sin), and the fbm variants are capped at a few octaves.

// hash12 and hash22 are David Hoskins' "Hash without Sine",
// https://www.shadertoy.com/view/4djSRW, MIT License, Copyright (c) 2014 David Hoskins.
// See THIRD_PARTY.md.
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

const mat2 FBM_ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

float fbm3(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * value_noise(p);
        p = FBM_ROT * p * 2.03 + 17.1;
        a *= 0.5;
    }
    return v / 0.875;
}

float fbm4(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * value_noise(p);
        p = FBM_ROT * p * 2.03 + 17.1;
        a *= 0.5;
    }
    return v / 0.9375;
}

// Voronoi over a unit grid.
// Returns (distance to nearest site, F2 - F1 as an edge measure, id of nearest cell).
vec3 voronoi(vec2 x, float jitter) {
    vec2 n = floor(x);
    vec2 f = fract(x);
    float f1 = 8.0;
    float f2 = 8.0;
    float id = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = 0.5 + (hash22(n + g) - 0.5) * jitter;
            float d = length(g + o - f);
            if (d < f1) {
                f2 = f1;
                f1 = d;
                id = hash12(n + g);
            } else if (d < f2) {
                f2 = d;
            }
        }
    }
    return vec3(f1, f2 - f1, id);
}

// Signed distance (pixels) from p to the border of the rectangle [0, size].
// Positive inside the rectangle.
float rect_inner_distance(vec2 p, vec2 size) {
    vec2 d = min(p, size - p);
    return min(d.x, d.y);
}

// A crisp neon rim along the inside of the arena with a soft inner glow.
vec3 arena_rim(vec2 p, vec2 size, vec3 rim_color, float pulse) {
    float d = rect_inner_distance(p, size);
    float line = smoothstep(6.0, 2.0, d);
    float glow = exp(-d / 26.0) * 0.55;
    return rim_color * (line * 1.3 + glow) * pulse;
}

// Darken towards the arena edges, which reads as depth / lighting falloff.
float arena_vignette(vec2 p, vec2 size, float strength) {
    vec2 uv = p / size - 0.5;
    return 1.0 - strength * dot(uv, uv) * 1.6;
}
