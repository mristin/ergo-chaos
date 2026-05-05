// Applied to a Line2D that traces the collision shape outline.
// UV.x = 0..1 along the line (LINE_TEXTURE_STRETCH), UV.y = 0..1 across the width.
shader_type canvas_item;
render_mode blend_add;

uniform float spark_speed : hint_range(0.1, 5.0) = 1.8;
uniform float line_glow   : hint_range(0.0, 1.0) = 0.25;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

float noise1d(float x) {
    float i = floor(x);
    float f = fract(x);
    return mix(hash(i), hash(i + 1.0), smoothstep(0.0, 1.0, f));
}

void fragment() {
    vec2 uv = UV;
    float t = TIME;

    // Soft falloff from line centre (UV.y == 0.5) to both edges
    float center_dist = abs(uv.y - 0.5) * 2.0;
    float edge = 1.0 - smoothstep(0.0, 1.0, center_dist);

    // Animated crackling base glow
    float crack = noise1d(uv.x * 30.0 + t * 3.5)
                * noise1d(uv.x * 13.0 - t * 2.1);
    float base = edge * line_glow * (0.5 + 0.5 * crack);

    // Ten discrete sparks travelling along the outline
    float spark_acc = 0.0;
    float core_acc  = 0.0;

    for (int i = 0; i < 10; i++) {
        float fi  = float(i);
        float dir = hash(fi * 13.37) > 0.5 ? 1.0 : -1.0;
        float spd = spark_speed * (0.4 + hash(fi * 7.91) * 0.8);
        float sx  = fract(hash(fi * 3.14) + dir * spd * t * 0.08);

        // Small vertical jitter so sparks sit slightly off-centre
        float sy = 0.5 + sin(t * (1.5 + hash(fi) * 2.0) + fi * 1.7) * 0.12;

        vec2 delta = uv - vec2(sx, sy);
        delta.x *= 3.5;   // elongate spark along the line direction
        float d = length(delta);

        float flicker = 0.55 + 0.45 * sin(t * (7.0 + fi * 1.3) + fi * 2.9);

        spark_acc += exp(-d * 18.0) * flicker;
        core_acc  += exp(-d * 55.0) * flicker;
    }

    float total = clamp(spark_acc + base, 0.0, 1.0);
    float core  = clamp(core_acc,         0.0, 1.0);

    // Blue outer glow, white-blue inner core
    vec3 col = vec3(0.05, 0.40, 1.00) * total
             + vec3(0.80, 0.90, 1.00) * core;

    COLOR = vec4(col, clamp(total + core, 0.0, 1.0));
}
