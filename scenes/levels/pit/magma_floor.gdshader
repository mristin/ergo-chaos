shader_type canvas_item;
render_mode blend_premul_alpha;

// Pit: a cooled basalt island floating on a lava sea. Inside the spark ring the
// basalt is cracked with faintly glowing seams; beyond it the crust breaks up
// into plates over churning magma.
//
// The static layer is baked once (see base.gd); its alpha marks where molten
// lava shows through, which is animated per frame.

#include "res://scenes/levels/common/noise.gdshaderinc"

uniform bool bake_pass = false;
uniform sampler2D baked : filter_linear, repeat_disable, hint_default_black;

uniform vec2 arena_size = vec2(1931.0, 1092.0);
uniform vec2 center = vec2(966.0, 547.0);
uniform float island_radius = 470.0;
uniform vec4 rock_color : source_color = vec4(0.16, 0.13, 0.13, 1.0);
uniform vec4 lava_hot : source_color = vec4(1.0, 0.75, 0.25, 1.0);
uniform vec4 lava_cool : source_color = vec4(0.75, 0.12, 0.02, 1.0);

varying vec2 world;

void vertex() {
    world = VERTEX;
}

vec4 static_layer(vec2 p) {
    float r = length(p - center);

    // Crust plates over the lava, more broken further out.
    vec3 vc = voronoi(p / 90.0, 0.9);
    float out_t = smoothstep(island_radius + 40.0, island_radius + 420.0, r);
    float gap = mix(0.03, 0.16, out_t) + 0.04 * vc.z;
    float crust = smoothstep(gap, gap + 0.06, vc.y);
    vec3 crust_col = rock_color.rgb * (0.8 + 0.5 * vc.z) * (0.7 + 0.4 * value_noise(p * 0.03));
    // Plates glow from below near their edges and fade to dark rock inside.
    crust_col += lava_cool.rgb * 0.45 * smoothstep(gap + 0.25, gap, vc.y);

    // Island: basalt with fine cracks that glow brighter towards the shore.
    vec3 vi = voronoi(p / 120.0, 1.0);
    vec3 vf = voronoi(p / 38.0 + 3.1, 1.0);
    vec3 rock = rock_color.rgb * (0.75 + 0.35 * vi.z) * (0.8 + 0.35 * fbm4(p * 0.02));
    float big_crack = smoothstep(0.05, 0.0, vi.y);
    float small_crack = smoothstep(0.04, 0.0, vf.y);
    float heat = 0.5 + 0.5 * hash12(vec2(vi.z * 100.0));
    float rim_heat = smoothstep(island_radius - 260.0, island_radius + 10.0, r);
    rock = mix(rock, vec3(0.03, 0.02, 0.02), small_crack * 0.6);
    rock += lava_cool.rgb * big_crack * (0.25 + 0.55 * rim_heat) * (0.6 + 0.4 * heat);
    rock += lava_hot.rgb * big_crack * rim_heat * 0.35 * heat;

    // Ragged shore with a scorched, glowing lip.
    float shore_noise = (fbm4(p * 0.012) - 0.5) * 70.0;
    float shore = smoothstep(island_radius + 30.0 + shore_noise, island_radius + shore_noise, r);
    vec3 col = mix(crust_col, rock, shore);
    col += lava_hot.rgb * exp(-abs(r - island_radius - shore_noise - 15.0) / 14.0) * 0.45;

    float vig = arena_vignette(p, arena_size, 0.3);
    col *= vig;
    col += arena_rim(p, arena_size, lava_hot.rgb, 0.7);

    // Where the lava shows through, the colour is filled in per frame.
    float molten = (1.0 - crust) * (1.0 - shore);
    return vec4(col * (1.0 - molten), molten * vig);
}

void fragment() {
    vec2 p = world;
    if (bake_pass) {
        COLOR = static_layer(p);
    } else {
        vec4 s = texture(baked, UV);
        vec3 col = s.rgb;
        if (s.a > 0.002) {
            // Slowly churning magma with a cheap domain warp.
            vec2 warp = vec2(value_noise(p * 0.004 + TIME * 0.05), value_noise(p * 0.004 - TIME * 0.04 + 9.0));
            float n = fbm3(p * 0.006 + warp * 2.5 + vec2(TIME * 0.03, 0.0));
            vec3 lava = mix(lava_cool.rgb, lava_hot.rgb, smoothstep(0.35, 0.8, n));
            lava *= 0.6 + 0.15 * sin(TIME * 1.5 + n * 12.0);
            col += lava * s.a;
        }
        COLOR = vec4(col, 1.0);
    }
}
