shader_type canvas_item;
render_mode blend_premul_alpha;

// Playground: a training hangar deck. Large bevelled steel plates with rivets,
// cyan seam lights that pulse outward from the centre, painted deck markings
// and a hazard-striped border.
//
// The static layer is baked once (see base.gd); its alpha holds the seam mask.

#include "res://scenes/levels/common/noise.gdshaderinc"

uniform bool bake_pass = false;
uniform sampler2D baked : filter_linear, repeat_disable, hint_default_black;

uniform vec2 arena_size = vec2(1931.0, 1092.0);
uniform float plate_size = 160.0;
uniform vec4 steel_color : source_color = vec4(0.17, 0.2, 0.25, 1.0);
uniform vec4 seam_color : source_color = vec4(0.2, 0.85, 1.0, 1.0);
uniform vec4 marking_color : source_color = vec4(0.95, 0.75, 0.15, 1.0);

varying vec2 world;

void vertex() {
    world = VERTEX;
}

vec4 static_layer(vec2 p) {
    vec2 cell = floor(p / plate_size);
    vec2 f = fract(p / plate_size) * plate_size;
    float h = hash12(cell);
    vec2 edge = min(f, plate_size - f);
    float e = min(edge.x, edge.y);

    vec3 col = steel_color.rgb * (0.85 + 0.25 * h);

    // Brushed metal grain, alternating direction per plate.
    vec2 grain_p = (mod(cell.x + cell.y, 2.0) < 0.5) ? p.xy : p.yx;
    float grain = value_noise(vec2(grain_p.x * 0.6, grain_p.y * 0.02));
    col *= 0.92 + 0.12 * grain;

    // Grime.
    col *= 0.85 + 0.25 * fbm4(p * 0.006);

    // Bevel: lit top-left, shaded bottom-right.
    float bevel = 5.0;
    col += 0.07 * smoothstep(bevel, 0.0, f.x) + 0.07 * smoothstep(bevel, 0.0, f.y);
    col -= 0.08 * smoothstep(bevel, 0.0, plate_size - f.x) + 0.08 * smoothstep(bevel, 0.0, plate_size - f.y);

    // Dark seam groove with a dim resting light.
    float seam = smoothstep(2.2, 0.6, e);
    col = mix(col, vec3(0.03, 0.04, 0.05), smoothstep(2.6, 1.2, e));
    col += seam_color.rgb * seam * 0.18;

    // Rivets in plate corners.
    vec2 rv = abs(f - plate_size * 0.5) - (plate_size * 0.5 - 12.0);
    float rd = length(rv);
    col += 0.18 * smoothstep(3.2, 1.5, rd) - 0.08 * smoothstep(5.0, 3.5, rd) * step(3.2, rd);

    // Painted deck markings: a big centre circle and dashed cross lines.
    float r = length(p - arena_size * 0.5);
    float paint = smoothstep(7.0, 5.0, abs(r - 300.0));
    vec2 c = abs(p - arena_size * 0.5);
    paint = max(paint, smoothstep(4.0, 2.5, c.y) * step(330.0, c.x) * step(mod(p.x, 60.0), 34.0));
    paint = max(paint, smoothstep(4.0, 2.5, c.x) * step(330.0, c.y) * step(mod(p.y, 60.0), 34.0));
    paint *= 0.55 + 0.45 * value_noise(p * 0.08);
    col = mix(col, marking_color.rgb * 0.75, paint * 0.55);

    // Hazard stripes along the border.
    float d = rect_inner_distance(p, arena_size);
    float band = step(d, 26.0) * step(10.0, d);
    float stripe = step(0.5, fract((p.x + p.y) / 40.0));
    vec3 hazard = mix(vec3(0.05), marking_color.rgb * 0.8, stripe);
    col = mix(col, hazard, band * 0.85);

    float vig = arena_vignette(p, arena_size, 0.35);
    col *= vig;
    col += arena_rim(p, arena_size, seam_color.rgb, 0.7);

    return vec4(col, seam * vig * (1.0 - band));
}

void fragment() {
    vec2 p = world;
    if (bake_pass) {
        COLOR = static_layer(p);
    } else {
        vec4 s = texture(baked, UV);
        // Seam lights pulse outward from the centre.
        float r = length(p - arena_size * 0.5);
        float wave = pow(0.5 + 0.5 * sin(r * 0.012 - TIME * 2.2), 6.0);
        COLOR = vec4(s.rgb + seam_color.rgb * s.a * 0.75 * wave, 1.0);
    }
}
