shader_type canvas_item;
render_mode blend_premul_alpha;

// Switcher: a giant circuit board. Green solder mask, copper traces routed on
// a grid, vias and pads, faint chip footprints with blinking LEDs, and data
// pulses racing along the traces.
//
// The static layer is baked once (see base.gd); its alpha holds the proximity
// to the nearest trace (1 on the trace centre, 0 at 12 px away).

#include "res://scenes/levels/common/noise.gdshaderinc"

uniform bool bake_pass = false;
uniform sampler2D baked : filter_linear, repeat_disable, hint_default_black;

uniform vec2 arena_size = vec2(1931.0, 1092.0);
uniform float cell_size = 48.0;
uniform vec4 board_color : source_color = vec4(0.03, 0.17, 0.11, 1.0);
uniform vec4 copper_color : source_color = vec4(0.75, 0.55, 0.25, 1.0);
uniform vec4 pulse_color : source_color = vec4(0.4, 1.0, 0.6, 1.0);

const float CHIP_GRID = 240.0;
const float TRACE_REACH = 12.0;

varying vec2 world;

void vertex() {
    world = VERTEX;
}

float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * t);
}

// Each cell routes one trace: horizontal, vertical, or a 45-degree jog.
// Returns (distance in px, coordinate along the trace).
vec2 trace(vec2 p) {
    vec2 g = p / cell_size;
    vec2 cell = floor(g);
    vec2 f = fract(g);
    float h = hash12(cell);
    float d = 10.0;
    float along = 0.0;
    if (h < 0.34) {
        d = abs(f.y - 0.5);
        along = g.x;
    } else if (h < 0.62) {
        d = abs(f.x - 0.5);
        along = g.y;
    } else if (h < 0.78) {
        d = min(seg(f, vec2(0.0, 0.5), vec2(0.5, 0.5)), seg(f, vec2(0.5, 0.5), vec2(1.0, 0.0)));
        along = g.x;
    } else if (h < 0.9) {
        d = min(seg(f, vec2(0.5, 0.0), vec2(0.5, 0.5)), seg(f, vec2(0.5, 0.5), vec2(1.0, 1.0)));
        along = g.y;
    }
    return vec2(d * cell_size, along);
}

// Chip geometry: (signed box distance, LED distance, chip hash); box > 1e3 if no chip.
vec3 chip(vec2 p) {
    vec2 chip_cell = floor(p / CHIP_GRID);
    float ch = hash12(chip_cell + 77.0);
    if (ch <= 0.72) {
        return vec3(1e4, 1e4, ch);
    }
    vec2 cf = fract(p / CHIP_GRID) * CHIP_GRID - CHIP_GRID * 0.5;
    vec2 csz = vec2(50.0 + 30.0 * ch, 34.0 + 20.0 * fract(ch * 9.0));
    vec2 q = abs(cf) - csz;
    float led = length(cf - vec2(-csz.x + 10.0, -csz.y + 10.0));
    return vec3(max(q.x, q.y), led, ch);
}

vec4 static_layer(vec2 p) {
    vec3 col = board_color.rgb * (0.85 + 0.3 * fbm3(p * 0.005));
    // Fibre weave of the substrate.
    col *= 0.95 + 0.05 * sin(p.x * 0.9) * sin(p.y * 0.9);

    vec2 tr = trace(p);
    float d = tr.x;
    float on_trace = smoothstep(4.0, 2.5, d);
    col *= 1.0 - 0.35 * smoothstep(7.0, 3.0, d);
    col = mix(col, copper_color.rgb * (0.55 + 0.25 * value_noise(p * 0.05)), on_trace * 0.8);

    // Vias.
    vec2 cell = floor(p / cell_size);
    float via_h = hash12(cell + 31.0);
    float vd = length((fract(p / cell_size) - 0.5) * cell_size);
    float has_via = step(0.82, via_h);
    col = mix(col, copper_color.rgb * 0.9, has_via * smoothstep(8.0, 6.5, vd));
    col = mix(col, vec3(0.01), has_via * smoothstep(3.5, 2.5, vd));

    // Chips with pins.
    vec3 c = chip(p);
    float in_chip = smoothstep(1.0, -1.0, c.x);
    if (c.x < 20.0) {
        vec2 cf = fract(p / CHIP_GRID) * CHIP_GRID - CHIP_GRID * 0.5;
        vec2 csz = vec2(50.0 + 30.0 * c.z, 34.0 + 20.0 * fract(c.z * 9.0));
        float pins = step(c.x, 10.0) * step(0.0, abs(cf.y) - csz.y) * step(0.5, fract(cf.x / 12.0))
            * step(abs(cf.x), csz.x);
        col = mix(col, copper_color.rgb * 0.8, pins * 0.45);
    }
    // NOTE: The chips are only a faint footprint with a printed outline, with
    // the traces showing through, so that the players never take them for
    // obstacles.
    col = mix(col, col * 0.78, in_chip);
    col += vec3(0.75, 0.95, 0.8) * smoothstep(1.6, 0.4, abs(c.x)) * 0.16;

    // Silkscreen dots.
    vec2 sd = fract(p / 24.0) - 0.5;
    col += vec3(0.05) * smoothstep(0.08, 0.04, length(sd)) * step(hash12(floor(p / 24.0) + 3.0), 0.12);

    col *= arena_vignette(p, arena_size, 0.35);
    col += arena_rim(p, arena_size, pulse_color.rgb, 0.8);

    float reach = clamp(1.0 - d / TRACE_REACH, 0.0, 1.0);
    return vec4(col, reach);
}

void fragment() {
    vec2 p = world;
    if (bake_pass) {
        COLOR = static_layer(p);
    } else {
        vec4 s = texture(baked, UV);
        vec3 col = s.rgb;
        float vig = arena_vignette(p, arena_size, 0.35);

        if (s.a > 0.0) {
            vec2 tr = trace(p);
            vec2 cell = floor(p / cell_size);
            float lane = hash12(vec2(0.0, cell.y) + cell * vec2(1.0, 0.0) + 5.0);
            float pulse_pos = fract(tr.y * 0.08 - TIME * (0.25 + 0.3 * lane) + lane * 7.0);
            float on_trace = smoothstep(1.0 - 4.0 / TRACE_REACH, 1.0 - 2.5 / TRACE_REACH, s.a);
            float head = abs(pulse_pos - 0.5);
            col += pulse_color.rgb * vig * (
                smoothstep(0.06, 0.0, head) * on_trace * 1.2
                + smoothstep(0.0, 1.0, s.a) * smoothstep(0.08, 0.0, head) * 0.25);
        }

        // Blinking chip LEDs.
        vec3 c = chip(p);
        if (c.y < 5.0) {
            float blink = step(0.5, fract(TIME * (0.5 + c.z) + c.z * 3.0));
            col += pulse_color.rgb * smoothstep(4.0, 1.0, c.y) * blink * vig;
        }

        COLOR = vec4(col, 1.0);
    }
}
