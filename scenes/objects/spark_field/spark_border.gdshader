// Applied to a Line2D that traces the collision shape outline.
// UV.x = 0..1 along the line (LINE_TEXTURE_STRETCH), UV.y = 0..1 across the width.
//
// Set border_width to ~40 px and LINE_JOINT_ROUND for best results.
shader_type canvas_item;
render_mode blend_add;

uniform float spark_speed  : hint_range(0.1, 5.0) = 1.8;
uniform float line_glow    : hint_range(0.0, 1.0) = 0.25;
uniform float ambient_glow : hint_range(0.0, 1.0) = 0.18;  // constant baseline so border is always visible
// Organic-edge controls
uniform float edge_scale : hint_range(1.0, 40.0) = 12.0;  // noise spatial frequency along line
uniform float edge_speed : hint_range(0.0, 5.0)  = 1.5;   // animation speed of the boundary
uniform float edge_reach : hint_range(0.0, 0.9)  = 0.45;  // max extra reach of tendrils (fraction of half-width)
uniform float core_frac  : hint_range(0.0, 0.9)  = 0.20;  // fraction of half-width that is always solid

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise1d(float x) {
    float i = floor(x);
    float f = fract(x);
    return mix(hash(i), hash(i + 1.0), smoothstep(0.0, 1.0, f));
}

float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash2(i),                   hash2(i + vec2(1.0, 0.0)), u.x),
        mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

// Three octaves of noise for fire-like tendrils
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise2d(p);
        p = p * 2.1 + vec2(5.1, 3.7);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME;

    // Distance from line centre: 0 at centre, 1 at either edge
    float dist = abs(uv.y - 0.5) * 2.0;

    // Animated organic boundary — FBM noise makes it ripple like fire/plasma
    vec2 nc = vec2(uv.x * edge_scale + t * edge_speed * 0.25, t * edge_speed);
    float n = fbm(nc);                                    // 0..1

    // Visible boundary oscillates between core_frac and core_frac + edge_reach
    float boundary = core_frac + n * edge_reach;

    // Smooth falloff at the noise-driven boundary; inner side is hard, outer is soft
    float organic = 1.0 - smoothstep(boundary - 0.06, boundary + 0.12, dist);

    // Soft falloff from line centre used by the base glow
    float edge = 1.0 - smoothstep(0.0, 1.0, dist);

    // Constant ambient glow so the border is always visible, plus animated crackle on top
    float crack = noise1d(uv.x * 30.0 + t * 3.5)
                * noise1d(uv.x * 13.0 - t * 2.1);
    float base = edge * (ambient_glow + line_glow * (0.5 + 0.5 * crack));

    // Ten discrete sparks travelling along the outline
    float spark_acc = 0.0;
    float core_acc  = 0.0;

    for (int i = 0; i < 10; i++) {
        float fi  = float(i);
        float dir = hash(fi * 13.37) > 0.5 ? 1.0 : -1.0;
        float spd = spark_speed * (0.4 + hash(fi * 7.91) * 0.8);
        float sx  = fract(hash(fi * 3.14) + dir * spd * t * 0.08);

        float sy = 0.5 + sin(t * (1.5 + hash(fi) * 2.0) + fi * 1.7) * 0.12;

        vec2 delta = uv - vec2(sx, sy);
        delta.x *= 3.5;
        float d = length(delta);

        float flicker = 0.55 + 0.45 * sin(t * (7.0 + fi * 1.3) + fi * 2.9);

        spark_acc += exp(-d * 18.0) * flicker;
        core_acc  += exp(-d * 55.0) * flicker;
    }

    float total = clamp(spark_acc + base, 0.0, 1.0);
    float core  = clamp(core_acc,         0.0, 1.0);

    // Blue outer glow, white-blue inner core — both clipped by the organic mask
    vec3 col = vec3(0.05, 0.40, 1.00) * total
             + vec3(0.80, 0.90, 1.00) * core;

    float alpha = clamp(total + core, 0.0, 1.0) * organic;
    COLOR = vec4(col, alpha);
}
