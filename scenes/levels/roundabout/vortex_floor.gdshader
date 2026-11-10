shader_type canvas_item;
render_mode blend_premul_alpha;

// Roundabout: a violet turntable. Concentric dial rings with tick marks,
// slowly turning spiral arms of light and a faint hex lattice, all centred on
// the recharge pad.
//
// The static layer is baked once (see base.gd); its alpha holds the vignette.

#include "res://scenes/levels/common/noise.gdshaderinc"

uniform bool bake_pass = false;
uniform sampler2D baked : filter_linear, repeat_disable, hint_default_black;

uniform vec2 arena_size = vec2(1931.0, 1092.0);
uniform vec2 center = vec2(1018.0, 496.0);
uniform vec4 base_color : source_color = vec4(0.12, 0.07, 0.2, 1.0);
uniform vec4 arm_color : source_color = vec4(0.65, 0.3, 1.0, 1.0);
uniform vec4 ring_color : source_color = vec4(1.0, 0.45, 0.85, 1.0);
uniform float spin_speed = 0.12;

const float RING_SPACING = 150.0;

varying vec2 world;

void vertex() {
    world = VERTEX;
}

float hex_edge(vec2 p) {
    const vec2 s = vec2(1.0, 1.7320508);
    vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
    vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
    vec2 q = (dot(h.xy, h.xy) < dot(h.zw, h.zw)) ? h.xy : h.zw;
    q = abs(q);
    return 0.5 - max(dot(q, s * 0.5), q.x);
}

vec4 static_layer(vec2 p) {
    float r = length(p - center);

    vec3 col = base_color.rgb;
    col *= 0.8 + 0.4 * fbm4(p * 0.004);

    // Hex lattice.
    col += arm_color.rgb * 0.08 * smoothstep(0.06, 0.0, hex_edge(p / 46.0));

    // Dial rings.
    float rr = mod(r, RING_SPACING);
    float ring = smoothstep(3.0, 1.0, min(rr, RING_SPACING - rr));
    col += ring_color.rgb * ring * 0.35 * smoothstep(1400.0, 200.0, r);

    // Glow around the centre.
    col += arm_color.rgb * exp(-r / 160.0) * 0.35;

    float vig = arena_vignette(p, arena_size, 0.4);
    col *= vig;
    // The rim pulses, so it is added in the animated layer.
    return vec4(col, vig);
}

void fragment() {
    vec2 p = world;
    if (bake_pass) {
        COLOR = static_layer(p);
    } else {
        vec4 s = texture(baked, UV);
        vec2 v = p - center;
        float r = length(v);
        float a = atan(v.y, v.x);
        float fade = smoothstep(1400.0, 200.0, r);

        // Spiral arms.
        float spiral = sin(a * 3.0 - log(r + 40.0) * 5.0 + TIME * spin_speed * 6.2831);
        float arms = smoothstep(0.2, 1.0, spiral) * smoothstep(1300.0, 150.0, r);
        vec3 col = arm_color.rgb * arms * 0.32;

        // Tick marks turning in alternating directions per ring.
        float rr = mod(r, RING_SPACING);
        float to_ring = min(rr, RING_SPACING - rr);
        float ring_idx = floor((r + RING_SPACING * 0.5) / RING_SPACING);
        float dir = mod(ring_idx, 2.0) < 0.5 ? 1.0 : -1.0;
        float ticks_n = 24.0 + ring_idx * 12.0;
        float ta = fract((a / 6.2831) * ticks_n + TIME * spin_speed * dir * ticks_n * 0.05);
        float tick = smoothstep(0.12, 0.04, abs(ta - 0.5)) * smoothstep(18.0, 6.0, to_ring);
        col += ring_color.rgb * tick * 0.22 * fade;

        // A sparkle travelling around each ring.
        float ring = smoothstep(3.0, 1.0, to_ring);
        float sp_a = fract(a / 6.2831 - TIME * 0.08 * dir * (1.0 + hash12(vec2(ring_idx))));
        float sparkle = smoothstep(0.03, 0.0, min(sp_a, 1.0 - sp_a)) * ring;
        col += vec3(1.0, 0.85, 1.0) * sparkle * fade;

        col = s.rgb + col * s.a;
        col += arena_rim(p, arena_size, ring_color.rgb, 0.85 + 0.15 * sin(TIME * 2.0));
        COLOR = vec4(col, 1.0);
    }
}
