shader_type canvas_item;
render_mode blend_add;

// A single twinkling 5-pointed star, colored by `hue` (rolled randomly per
// star by rainbow_star.gd), that shrinks and fades out as `progress` goes
// from 0 (just spawned) to 1 (fully gone).
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float hue : hint_range(0.0, 1.0) = 0.0;

vec3 hsv2rgb(vec3 c) {
    vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
    return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    // Five-pointed star silhouette: modulate the radius by angle.
    float star = 0.55 + 0.45 * cos(angle * 5.0);
    star = pow(star, 1.7);

    float shrink = 1.0 - progress;
    float edge = star * 0.85 * shrink;

    float alpha = 1.0 - smoothstep(edge - 0.08, edge, dist);
    alpha *= 1.0 - progress;

    float twinkle = 0.7 + 0.3 * sin(progress * 40.0);
    vec3 color = hsv2rgb(vec3(hue, 0.65, 1.0)) * twinkle;

    // Bright core so each star has a hot little center.
    float core = 1.0 - smoothstep(0.0, 0.25, dist);
    color += vec3(1.0) * core * 0.6;

    COLOR = vec4(color, alpha);
}
