shader_type canvas_item;
render_mode blend_premul_alpha;

// Stable: an enchanted wooden stable. Dark oak planks with grain and knots,
// scattered straw, warm lantern pools, soft rainbow aurora ribbons drifting
// over the floor and twinkling magic sparkles.
//
// The static layer is baked once (see base.gd); its alpha holds the vignette.

#include "res://scenes/levels/common/noise.gdshaderinc"

uniform bool bake_pass = false;
uniform sampler2D baked : filter_linear, repeat_disable, hint_default_black;

uniform vec2 arena_size = vec2(1931.0, 1092.0);
uniform float plank_width = 64.0;
uniform vec4 wood_color : source_color = vec4(0.3, 0.18, 0.12, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.9, 1.0);

varying vec2 world;

void vertex() {
    world = VERTEX;
}

vec3 rainbow(float t) {
    return 0.5 + 0.5 * cos(6.2831 * (t + vec3(0.0, 0.33, 0.67)));
}

vec4 static_layer(vec2 p) {
    // Planks running horizontally with staggered butt joints.
    float row = floor(p.y / plank_width);
    float plank_len = 260.0 + 200.0 * hash12(vec2(row, 1.0));
    float x = p.x + hash12(vec2(row, 2.0)) * 400.0;
    vec2 id = vec2(row, floor(x / plank_len));
    float h = hash12(id);
    vec2 lp = vec2(fract(x / plank_len) * plank_len, fract(p.y / plank_width) * plank_width);

    // Grain: stretched noise, warped around an occasional knot.
    vec2 knot_pos = vec2(plank_len * (0.2 + 0.6 * hash12(id + 5.0)), plank_width * (0.3 + 0.4 * hash12(id + 9.0)));
    float kd = length((lp - knot_pos) * vec2(0.6, 1.0));
    float has_knot = step(0.6, hash12(id + 13.0));
    float warp_y = has_knot * 14.0 * exp(-kd / 18.0);
    float grain = fbm4(vec2(lp.x * 0.012, (lp.y + warp_y) * 0.25) + id * 3.7);
    float rings = 0.5 + 0.5 * sin((lp.y + warp_y + grain * 30.0) * 0.5);

    vec3 col = wood_color.rgb * (0.7 + 0.45 * h);
    col *= 0.75 + 0.3 * grain + 0.12 * rings;
    col *= 1.0 - has_knot * 0.5 * smoothstep(9.0, 3.0, kd);

    // Gaps between planks, a worn highlight on each plank edge, and nails.
    float gy = min(lp.y, plank_width - lp.y);
    float gx = min(lp.x, plank_len - lp.x);
    col *= 0.35 + 0.65 * smoothstep(0.5, 2.5, min(gy, gx));
    col += vec3(0.05, 0.03, 0.02) * smoothstep(4.0, 2.0, abs(lp.y - 3.5));
    vec2 nail = vec2(min(gx, 14.0) - 14.0, abs(lp.y - plank_width * 0.5) - 18.0);
    col += vec3(0.25, 0.22, 0.2) * smoothstep(2.5, 1.2, length(nail));

    // Scattered straw.
    vec2 sc = floor(p / 30.0);
    vec2 sh = hash22(sc + 50.0);
    if (sh.x > 0.86) {
        vec2 sf = p - (sc + 0.5) * 30.0;
        float ang = sh.y * 6.2831;
        vec2 dirv = vec2(cos(ang), sin(ang));
        float along = dot(sf, dirv);
        float across = abs(dot(sf, vec2(-dirv.y, dirv.x)));
        float straw = smoothstep(1.4, 0.4, across) * step(abs(along), 14.0);
        col = mix(col, vec3(0.75, 0.6, 0.3), straw * 0.7);
    }

    // Warm lantern pools.
    float lanterns = exp(-length(p - vec2(480.0, 300.0)) / 260.0)
        + exp(-length(p - vec2(1450.0, 300.0)) / 260.0)
        + exp(-length(p - vec2(480.0, 790.0)) / 260.0)
        + exp(-length(p - vec2(1450.0, 790.0)) / 260.0);
    col *= 0.75 + 0.45 * lanterns;

    float vig = arena_vignette(p, arena_size, 0.35);
    col *= vig;
    col += arena_rim(p, arena_size, glow_color.rgb, 0.8);
    return vec4(col, vig);
}

void fragment() {
    vec2 p = world;
    if (bake_pass) {
        COLOR = static_layer(p);
    } else {
        vec4 s = texture(baked, UV);
        vec3 col = s.rgb;

        // Aurora ribbons drifting across.
        float t = TIME * 0.05;
        float band1 = p.y + 120.0 * sin(p.x * 0.003 + t * 4.0) + 60.0 * value_noise(vec2(p.x * 0.002, t));
        float band2 = p.y + 150.0 * sin(p.x * 0.0022 - t * 3.0 + 2.0) - 400.0;
        float r1 = exp(-pow((mod(band1, 700.0) - 350.0) / 90.0, 2.0));
        float r2 = exp(-pow((mod(band2, 900.0) - 450.0) / 120.0, 2.0));
        vec3 aurora = rainbow(p.x * 0.0006 + t) * r1 + rainbow(p.x * 0.0005 - t + 0.5) * r2 * 0.8;
        col = col * (1.0 + aurora * 0.5) + aurora * 0.07 * s.a;

        // Twinkling sparkles.
        vec2 gc = floor(p / 40.0);
        vec2 gh = hash22(gc + 20.0);
        if (gh.x > 0.55) {
            vec2 gpos = (gc + 0.2 + 0.6 * hash22(gc + 3.0)) * 40.0;
            vec2 dv = abs(p - gpos);
            float star = max(
                smoothstep(1.4, 0.0, dv.y) * smoothstep(7.0, 0.0, dv.x),
                smoothstep(1.4, 0.0, dv.x) * smoothstep(7.0, 0.0, dv.y));
            star += smoothstep(3.0, 0.0, length(dv));
            float tw = pow(max(0.0, sin(TIME * (1.0 + 2.0 * gh.y) + gh.x * 60.0)), 12.0);
            col += mix(vec3(1.0), glow_color.rgb, gh.y) * star * tw * 0.9;
        }

        COLOR = vec4(col, 1.0);
    }
}
