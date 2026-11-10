shader_type canvas_item;

// The goo counter of the HUD: a rounded glass tank which fills up with goo as
// the players collect it. The surface sloshes, and splashes when a goo is
// collected; bubbles rise through the goo.

uniform vec2 size = vec2(180.0, 76.0);
uniform float corner_radius = 22.0;

// The share of the goo collected so far, 0..1.
uniform float level : hint_range(0.0, 1.0) = 0.0;

// 1 right after a goo is collected, decaying to 0.
uniform float splash : hint_range(0.0, 1.0) = 0.0;

uniform vec4 glass_color : source_color = vec4(0.04, 0.05, 0.1, 0.72);
uniform vec4 border_color : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform vec4 thin_color : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 thick_color : source_color = vec4(0.95, 0.55, 0.0, 1.0);

float rounded_box(vec2 p, vec2 half_size, float r) {
    vec2 q = abs(p) - half_size + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
    vec2 p = UV * size;
    float margin = 6.0;  // room for the outer glow
    vec2 half_size = size * 0.5 - margin;
    float d = rounded_box(p - size * 0.5, half_size, corner_radius);

    vec4 result = vec4(0.0);

    // Outer glow.
    float glow = exp(-max(d, 0.0) / 3.5) * step(0.0, d);
    result = vec4(border_color.rgb, glow * (0.35 + 0.35 * splash));

    if (d < 0.0) {
        vec3 color = glass_color.rgb;
        float alpha = glass_color.a;

        // The goo: the surface rises with the level and sloshes.
        float top = margin;
        float bottom = size.y - margin;
        float amplitude = 1.2 + 5.0 * splash;
        float surface = mix(bottom, top - 4.0, level)
            + sin(p.x * 0.11 + TIME * 2.6) * amplitude
            + sin(p.x * 0.23 - TIME * 3.7) * amplitude * 0.5;

        if (level > 0.001 && p.y > surface) {
            float depth = clamp((p.y - surface) / max(bottom - surface, 1.0), 0.0, 1.0);
            vec3 goo = mix(thin_color.rgb, thick_color.rgb, depth);

            // Rising bubbles on a coarse grid.
            vec2 cell_size = vec2(14.0, 14.0);
            vec2 q = p + vec2(0.0, TIME * 18.0);
            vec2 cell = floor(q / cell_size);
            float h = hash(cell);
            vec2 center = (cell + 0.25 + 0.5 * vec2(hash(cell + 7.0), hash(cell + 3.0))) * cell_size;
            float bubble = step(0.72, h) * smoothstep(2.6, 1.6, length(q - center));
            goo += vec3(1.0, 0.95, 0.7) * bubble * 0.5;

            // A bright meniscus along the surface.
            goo += vec3(1.0, 0.95, 0.6) * smoothstep(3.0, 0.0, p.y - surface) * 0.6;

            color = goo;
            alpha = 0.88;
        }

        // Glass: a highlight across the top and a bright border.
        float highlight = smoothstep(top + 14.0, top + 2.0, p.y) * smoothstep(-2.0, -8.0, d);
        color += vec3(1.0) * highlight * 0.12;
        float border = smoothstep(-3.5, -1.0, d);
        color = mix(color, border_color.rgb, border);
        alpha = max(alpha, border);

        result = vec4(color, alpha * smoothstep(0.0, -1.0, d) + result.a * (1.0 - smoothstep(0.0, -1.0, d)));
    }

    COLOR = result;
}
