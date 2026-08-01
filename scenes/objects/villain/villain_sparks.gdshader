shader_type canvas_item;

// Tints the sprite towards whichever player is being hunted and covers it in
// dangerous crackling electricity: dense static, jagged arcing bolts that
// sweep across the body, a white-hot core where bolts strike, and a
// strobing danger pulse -- all masked by the sprite's own alpha so the
// silhouette stays intact.
uniform vec4 tint_color : source_color = vec4(0.85, 0.16, 0.16, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.45;
uniform vec3 spark_color : source_color = vec3(0.7, 0.95, 1.0);
uniform vec3 hot_core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float danger_pulse_speed : hint_range(0.0, 20.0) = 7.0;
uniform int bolt_count : hint_range(1, 8) = 2;

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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.3 + vec2(5.1, 3.7);
        a *= 0.5;
    }
    return v;
}

// A jagged lightning bolt sweeping horizontally across the body, flickering
// on and off and re-rolling its path every so often.
float bolt(vec2 uv, float id) {
    float seed = floor(TIME * 5.0 + id * 17.0);
    float alive = step(0.35, hash(vec2(seed, id * 3.1)));

    float y_base = hash(vec2(id, seed));
    float path = y_base;
    path += (noise(vec2(uv.x * 8.0 + id * 4.0, seed)) - 0.5) * 0.7;
    path += (noise(vec2(uv.x * 21.0 + id * 8.0, seed * 1.7)) - 0.5) * 0.3;

    float d = abs(uv.y - path);
    float core = smoothstep(0.03, 0.0, d);
    float glow = smoothstep(0.1, 0.0, d) * 0.4;

    float flicker = 0.5 + 0.5 * sin(TIME * (24.0 + id * 7.0) + id * 5.2);

    return alive * (core + glow) * flicker;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 tinted = mix(tex.rgb, tint_color.rgb * (0.35 + 0.65 * lum), tint_strength);

    // Sparse crackling static across the whole body.
    vec2 nc = UV * 8.0 + vec2(TIME * 2.0, -TIME * 2.4);
    float n = fbm(nc);
    float crackle = smoothstep(0.68, 0.92, n) * (0.6 + 0.4 * sin(TIME * 28.0 + UV.x * 60.0));

    // A couple of arcing bolts sweeping across the sprite now and then.
    float bolts = 0.0;
    for (int i = 0; i < 8; i++) {
        if (i >= bolt_count) {
            break;
        }
        bolts += bolt(UV, float(i));
    }
    bolts = clamp(bolts, 0.0, 1.2);

    // Whole-body danger pulse: a gentler strobe so the sprite stays readable.
    float pulse = pow(0.5 + 0.5 * sin(TIME * danger_pulse_speed), 3.0);

    vec3 energy = spark_color * (crackle * 0.6 + bolts * 0.8) + hot_core_color * bolts * bolts * 0.7;
    vec3 color = tinted + energy * (0.45 + 0.35 * pulse);

    COLOR = vec4(color, tex.a);
}
