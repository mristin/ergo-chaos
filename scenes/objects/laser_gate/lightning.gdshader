shader_type canvas_item;
render_mode blend_add;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    return mix(hash(i), hash(i + 1.0), smoothstep(0.0, 1.0, f));
}

float fbm(float x) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(x);
        x *= 2.0;
        a *= 0.5;
    }
    return v;
}

// Returns glow + core contribution for one bolt at vertical center `cy`.
vec2 bolt(vec2 uv, float cy, float amp, float freq, float speed, float seed) {
    float by = cy + amp * (fbm(uv.x * freq + TIME * speed + seed) - 0.5);
    float d = abs(uv.y - by);
    float glow = exp(-d * 10.0);
    float core = exp(-d * 80.0);
    return vec2(glow, core);
}

void fragment() {
    vec2 uv = UV;

    float total_glow = 0.0;
    float total_core = 0.0;

    // Five bolts spread across the full rect height (y = 0.1 … 0.9)
    vec2 b0 = bolt(uv, 0.1, 0.07, 12.0,  3.0,  0.0);
    vec2 b1 = bolt(uv, 0.3, 0.09, 10.0, -2.5,  5.3);
    vec2 b2 = bolt(uv, 0.5, 0.10,  8.0,  3.8, 11.7);
    vec2 b3 = bolt(uv, 0.7, 0.09, 14.0, -4.2,  3.1);
    vec2 b4 = bolt(uv, 0.9, 0.07, 11.0,  2.1,  8.9);

    total_glow = b0.x + b1.x + b2.x + b3.x + b4.x;
    total_core = b0.y + b1.y + b2.y + b3.y + b4.y;

    total_glow = clamp(total_glow, 0.0, 1.0);
    total_core = clamp(total_core, 0.0, 1.0);

    vec3 color = vec3(0.9, 0.0, 0.0) * total_glow + vec3(1.0, 0.5, 0.5) * total_core;
    float alpha = clamp(total_glow * 0.9 + total_core, 0.0, 1.0);

    COLOR = vec4(color, alpha);
}
