shader_type canvas_item;
render_mode blend_add;

// A quick electric shockwave: a spiky ring expands outward from the center
// and the whole thing fades out towards the end of `progress` (0..1,
// driven by hit_explosion.gd).
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    // Snappy expansion: fast at first, then settling near the full radius.
    float radius = mix(0.05, 1.0, sqrt(progress));

    float spikes = sin(angle * 9.0 + progress * 20.0) * 0.12
                 + sin(angle * 17.0 - progress * 14.0) * 0.06;

    float edge = radius + spikes;
    float ring = 1.0 - smoothstep(edge - 0.12, edge + 0.05, dist);

    float heat = clamp(1.0 - dist / max(edge, 0.01), 0.0, 1.0);

    vec3 outer_col = vec3(0.05, 0.4, 1.0);
    vec3 mid_col   = vec3(0.6, 0.9, 1.0);
    vec3 inner_col = vec3(1.0, 1.0, 1.0);

    vec3 color = mix(outer_col, mid_col, smoothstep(0.0, 0.5, heat));
    color = mix(color, inner_col, smoothstep(0.5, 0.95, heat));

    float fade = 1.0 - smoothstep(0.55, 1.0, progress);
    float alpha = ring * fade;

    COLOR = vec4(color, alpha);
}
