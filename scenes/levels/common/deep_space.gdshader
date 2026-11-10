shader_type canvas_item;

// Deep space surrounding the arena: drifting nebula, two parallax star layers
// and a halo hugging the arena so that it reads as a floating platform.
//
// Tint it per level by overriding the material on the Base/Space node. The
// strips around the arena inherit it via use_parent_material, so the arena
// itself (covered by the floor) is never shaded twice.

#include "res://scenes/levels/common/noise.gdshaderinc"

uniform vec2 arena_size = vec2(1931.0, 1092.0);
uniform vec4 space_color : source_color = vec4(0.006, 0.008, 0.02, 1.0);
uniform vec4 nebula_color_a : source_color = vec4(0.22, 0.08, 0.42, 1.0);
uniform vec4 nebula_color_b : source_color = vec4(0.02, 0.22, 0.38, 1.0);
uniform float nebula_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec4 star_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform vec4 halo_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float halo_strength : hint_range(0.0, 2.0) = 0.6;

varying vec2 world;
varying vec2 screen;

void vertex() {
    // VERTEX is local to each strip; MODEL_MATRIX brings it into arena space.
    world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    screen = (CANVAS_MATRIX * MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// One layer of stars on a jittered grid. `depth` controls the parallax:
// 0 sticks to the screen, 1 sticks to the world.
vec3 star_layer(float depth, float cell, float density, float size, float seed) {
    vec2 q = screen + (world - screen) * depth + seed * 97.0;
    vec2 id = floor(q / cell);
    vec2 h = hash22(id + seed);
    if (h.x > density) {
        return vec3(0.0);
    }
    vec2 center = (id + 0.15 + 0.7 * hash22(id * 1.7 + seed)) * cell;
    float d = length(q - center);
    float r = size * (0.5 + h.y);
    float core = smoothstep(r, 0.0, d);
    // Fade the halo out before the cell border (the star sits at least 0.15
    // cells away from it) so that no square cut-offs show.
    float halo = exp(-d / (r * 2.5)) * 0.35 * smoothstep(cell * 0.15, cell * 0.05, d);
    float tw = 0.6 + 0.4 * sin(TIME * (1.0 + 3.0 * h.y) + h.x * 40.0);
    vec3 tint = mix(star_color.rgb, vec3(0.7, 0.8, 1.0), step(0.5, fract(h.x * 13.0)));
    return tint * (core + halo) * tw * (0.5 + h.y);
}

void fragment() {
    vec2 np = screen + (world - screen) * 0.15;
    // Two single-octave lookups keep this cheap; it covers much of the screen
    // when a player flies along the edge of the arena.
    float n1 = value_noise(np * 0.0016 + vec2(TIME * 0.006, 0.0));
    float n2 = value_noise(np * 0.0027 + vec2(4.2, -TIME * 0.004));
    float dust = 0.5 + 0.5 * sin(np.x * 0.011 + n2 * 4.0) * sin(np.y * 0.013 + n1 * 4.0);

    vec3 col = space_color.rgb;
    col += nebula_color_a.rgb * smoothstep(0.38, 0.85, n1) * 0.7 * nebula_strength;
    col += nebula_color_b.rgb * smoothstep(0.45, 0.9, n2) * 0.6 * nebula_strength;
    col *= 0.8 + 0.4 * dust;

    col += star_layer(0.25, 34.0, 0.35, 1.3, 1.0);
    col += star_layer(0.55, 70.0, 0.45, 2.0, 7.0);
    col += star_layer(1.0, 150.0, 0.4, 3.0, 13.0);

    // Halo around the arena.
    vec2 outside = max(max(-world, world - arena_size), vec2(0.0));
    float d = length(outside);
    float pulse = 0.85 + 0.15 * sin(TIME * 1.3);
    col += halo_color.rgb * exp(-d / 55.0) * halo_strength * pulse;

    COLOR = vec4(col, 1.0);
}
