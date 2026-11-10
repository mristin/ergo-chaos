shader_type canvas_item;
render_mode blend_premul_alpha;

// Chase: an industrial deck on red alert. Dark gunmetal grating, chevrons
// streaming along the corridors, a rotating amber beacon sweeping the floor and
// an alarm that breathes the whole deck red.
//
// The static layer is baked once (see base.gd); its alpha holds the vignette.

#include "res://scenes/levels/common/noise.gdshaderinc"

uniform bool bake_pass = false;
uniform sampler2D baked : filter_linear, repeat_disable, hint_default_black;

uniform vec2 arena_size = vec2(1931.0, 1092.0);
uniform vec4 metal_color : source_color = vec4(0.13, 0.15, 0.17, 1.0);
uniform vec4 alarm_color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform vec4 beacon_color : source_color = vec4(1.0, 0.6, 0.1, 1.0);
uniform vec2 beacon_position = vec2(966.0, 546.0);

varying vec2 world;

void vertex() {
    world = VERTEX;
}

vec4 static_layer(vec2 p) {
    // Diamond-plate grating.
    vec2 g = p / 18.0;
    vec2 cell = floor(g);
    vec2 f = fract(g) - 0.5;
    float flip = mod(cell.x + cell.y, 2.0) < 0.5 ? 1.0 : -1.0;
    vec2 rf = vec2(f.x + f.y * flip, f.y - f.x * flip) * 0.7071;
    float bump = smoothstep(0.32, 0.12, abs(rf.x)) * smoothstep(0.12, 0.04, abs(rf.y));
    vec3 col = metal_color.rgb * (0.85 + 0.3 * fbm4(p * 0.005));
    col += vec3(0.06) * bump * (0.6 + 0.4 * sign(rf.y + 0.001));

    // Large deck panels.
    vec2 pf = abs(fract(p / vec2(240.0, 120.0)) - 0.5) * vec2(240.0, 120.0);
    float panel_edge = smoothstep(117.0, 119.0, pf.x) + smoothstep(57.0, 59.0, pf.y);
    col *= 1.0 - 0.45 * clamp(panel_edge, 0.0, 1.0);

    // Wear and oil stains.
    col *= 0.8 + 0.25 * smoothstep(0.3, 0.7, fbm4(p * 0.012 + 40.0));

    float vig = arena_vignette(p, arena_size, 0.4);
    return vec4(col * vig, vig);
}

void fragment() {
    vec2 p = world;
    if (bake_pass) {
        COLOR = static_layer(p);
    } else {
        vec4 s = texture(baked, UV);
        float vig = s.a;
        vec3 col = s.rgb;

        // Chevrons streaming along horizontal lanes, alternating direction.
        float lane = floor(p.y / 120.0);
        float dir = mod(lane, 2.0) < 0.5 ? 1.0 : -1.0;
        float ly = abs(fract(p.y / 120.0) - 0.5) * 120.0;
        float cx = fract((p.x * dir - TIME * 140.0) / 90.0 + ly / 90.0);
        float chevron = smoothstep(0.04, 0.0, abs(cx - 0.5) - 0.06) * step(ly, 22.0);
        col += alarm_color.rgb * chevron * 0.22 * vig;

        // Rotating beacon sweep (two opposite lamps).
        vec2 bv = p - beacon_position;
        float ang = atan(bv.y, bv.x);
        float sweep = exp(-mod(ang - TIME * 1.8, 6.2831) * 2.2)
            + exp(-mod(ang - TIME * 1.8 + 3.14159, 6.2831) * 2.2);
        col += beacon_color.rgb * sweep * 0.22 * vig / (1.0 + length(bv) * 0.0015);

        // Global alarm breathing.
        float alarm = pow(0.5 + 0.5 * sin(TIME * 3.2), 3.0);
        col += alarm_color.rgb * alarm * 0.06 * vig;
        col *= 1.0 + alarm * 0.1;

        // Scanlines.
        col *= 0.94 + 0.06 * sin(p.y * 1.4 + TIME * 6.0);

        col += arena_rim(p, arena_size, mix(beacon_color.rgb, alarm_color.rgb, alarm), 0.9);
        COLOR = vec4(col, 1.0);
    }
}
