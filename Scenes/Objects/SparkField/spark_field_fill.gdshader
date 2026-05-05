shader_type canvas_item;

uniform vec4 background_color : source_color = vec4(0.01, 0.015, 0.04, 1.0);
uniform vec4 glow_color : source_color = vec4(0.25, 0.75, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float speed = 2.0;
uniform float thickness = 0.01;
uniform float glow = 0.06;
uniform float jaggedness = 0.22;
uniform float flash_rate = 0.5;
uniform int arc_count = 8;

uniform float edge_fade = 0.12;
uniform float branch_strength = 0.75;
uniform float branch_length = 0.28;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float line_segment(vec2 p, vec2 a, vec2 b, float w) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return smoothstep(w, 0.0, length(pa - ba * h));
}

float edge_mask(vec2 uv) {
    float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    return smoothstep(0.0, edge_fade, d);
}

float lightning_arc(vec2 uv, float id) {
    float t = floor(TIME * flash_rate + id * 19.37);

    float y_base = hash(vec2(id, t)) * 0.85 + 0.075;
    float alive = step(0.35, hash(vec2(t, id * 7.1)));

    float pulse = fract(TIME * flash_rate + id * 0.23);
    float flash = smoothstep(1.0, 0.65, pulse);

    float path = y_base;
    path += (noise(vec2(uv.x * 10.0 + id * 3.0, t)) - 0.5) * jaggedness;
    path += (noise(vec2(uv.x * 28.0 + id * 9.0, t * 1.7)) - 0.5) * jaggedness * 0.45;

    float d = abs(uv.y - path);

    float core = smoothstep(thickness, 0.0, d);
    float aura = smoothstep(glow, 0.0, d) * 0.45;

    float branch_energy = 0.0;

    for (int b = 0; b < 3; b++) {
        float bid = id * 11.0 + float(b) * 3.7;

        float bx = hash(vec2(bid, t));
        float by = y_base;
        by += (noise(vec2(bx * 10.0 + id * 3.0, t)) - 0.5) * jaggedness;

        float dir = mix(-1.0, 1.0, step(0.5, hash(vec2(bid + 4.0, t))));
        float len = branch_length * hash(vec2(bid + 8.0, t));
        float angle = dir * (0.45 + hash(vec2(bid + 12.0, t)) * 0.8);

        vec2 a = vec2(bx, by);
        vec2 c = a + vec2(len * cos(angle), len * sin(angle));

        float branch = line_segment(uv, a, c, thickness * 0.75);
        float branch_glow = line_segment(uv, a, c, glow * 0.55) * 0.35;

        branch_energy += (branch + branch_glow) * branch_strength;
    }

    return alive * flash * (core + aura + branch_energy);
}

void fragment() {
    vec2 uv = UV;

    float mask = edge_mask(uv);
    float energy = 0.0;

    for (int i = 0; i < 10; i++) {
        if (i >= arc_count) {
            break;
        }

        energy += lightning_arc(uv, float(i));
    }

    energy *= mask;
    energy = clamp(energy, 0.0, 1.8);

    float flicker = 0.55 + 0.45 * step(0.35, hash(vec2(floor(TIME * 40.0), 12.3)));

    vec3 color = background_color.rgb;
    color += glow_color.rgb * energy * flicker;
    color += core_color.rgb * pow(energy, 2.2) * flicker;

    COLOR = vec4(color, background_color.a);
}