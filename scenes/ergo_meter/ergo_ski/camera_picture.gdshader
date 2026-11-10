shader_type canvas_item;

// The camera picture with rounded corners and a slight vignette, to sit inside
// the neon frame (see camera_frame.gdshader).

uniform vec2 picture_size = vec2(320.0, 240.0);
uniform float corner_radius = 14.0;

float rounded_box(vec2 p, vec2 half_size, float r) {
    vec2 q = abs(p) - half_size + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    vec2 p = (UV - 0.5) * picture_size;
    float d = rounded_box(p, picture_size * 0.5, corner_radius);
    float mask = smoothstep(0.5, -0.5, d);

    vec2 v = UV - 0.5;
    float vignette = 1.0 - 0.45 * dot(v, v) * 2.0;

    COLOR = vec4(c.rgb * vignette, c.a * mask);
}
