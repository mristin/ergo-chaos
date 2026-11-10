shader_type canvas_item;
render_mode blend_add;

// A neon frame around the camera picture: rounded corners, a soft outer glow,
// a pulse of light running around, and (with two players) a glowing energy
// line where the picture is split. The colours fade from the left player's to
// the right player's.
//
// The ColorRect is larger than the picture by `margin` on every side, so that
// the glow has room.

uniform vec2 picture_size = vec2(320.0, 240.0);
uniform float margin = 12.0;
uniform float corner_radius = 14.0;
uniform float border_width = 2.5;
uniform vec4 left_color : source_color = vec4(1.0, 0.3, 0.25, 1.0);
uniform vec4 right_color : source_color = vec4(0.25, 0.5, 1.0, 1.0);
uniform bool split = true;

float rounded_box(vec2 p, vec2 half_size, float r) {
    vec2 q = abs(p) - half_size + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

void fragment() {
    vec2 size = picture_size + 2.0 * margin;
    vec2 p = UV * size - size * 0.5;  // centred, in picture pixels
    vec2 half_size = picture_size * 0.5;

    float d = rounded_box(p, half_size, corner_radius);

    // Colour across the picture.
    float t = split ? smoothstep(-0.15, 0.15, p.x / picture_size.x) : 0.0;
    vec3 color = mix(left_color.rgb, right_color.rgb, t);

    // Crisp border and its glow, mostly outwards.
    float border = smoothstep(border_width, border_width * 0.3, abs(d));
    float glow = exp(-max(d, 0.0) / 5.0) * step(-border_width, d) * 0.6;

    // A pulse running around the frame (two of them, opposite).
    float angle = atan(p.y, p.x);
    float pulse = pow(0.5 + 0.5 * cos(2.0 * angle - TIME * 2.4), 10.0);

    float energy = border * (0.9 + 1.2 * pulse) + glow * (0.6 + 0.8 * pulse);

    // Energy line on the split, flickering upwards.
    if (split) {
        float inside = step(d, -border_width * 0.5);
        float wobble = sin(p.y * 0.35 + TIME * 9.0) * 0.6 + sin(p.y * 0.9 - TIME * 13.0) * 0.3;
        float x = abs(p.x - wobble);
        float flicker = 0.75 + 0.25 * hash(floor(TIME * 24.0));
        float line = smoothstep(1.4, 0.2, x) + exp(-x / 2.5) * 0.45;
        float sparks = pow(0.5 + 0.5 * sin(p.y * 0.25 + TIME * 14.0), 12.0);
        energy += inside * line * flicker * (0.8 + sparks);
        color = mix(color, vec3(1.0, 0.95, 1.0), inside * smoothstep(1.2, 0.0, x) * 0.6);
    }

    COLOR = vec4(color * energy, 1.0);
}
