shader_type canvas_item;
render_mode blend_add;

// A flame trail behind a fireball, drawn on a Line2D in the stretch texture
// mode: UV.x runs from the head (0, at the fireball) to the tail (1), UV.y
// across the ribbon. The Line2D tapers it with a width curve.
//
// White-hot at the head, cooling to the glow colour and then to embers, with
// turbulence which flows back along the trail.

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.15, 1.0);

// 0..1, how fast the hand moves; a faster hand burns brighter.
uniform float intensity : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

void fragment() {
    float along = clamp(UV.x, 0.0, 1.0);
    float across = (UV.y - 0.5) * 2.0;

    // Turbulence flowing towards the tail, stronger further back.
    vec2 q = vec2(along * 5.0 - TIME * 6.0, UV.y * 2.5 + TIME * 1.3);
    float n = value_noise(q) * 0.65 + value_noise(q * 2.3 + 7.1) * 0.35;
    float edge = abs(across + (n - 0.5) * 0.9 * along) + (n - 0.5) * 0.3 * along;

    float body = smoothstep(1.0, 0.15, edge);
    float core = smoothstep(0.5, 0.0, edge) * smoothstep(0.7, 0.0, along);

    // Embers break up the end of the trail.
    float embers = smoothstep(0.35, 0.75, n) * smoothstep(0.3, 0.8, along);
    body *= 1.0 - embers * 0.7;

    float fade = pow(1.0 - along, 1.6);

    vec3 ember_color = glow_color.rgb * vec3(0.9, 0.35, 0.25);
    vec3 color = mix(glow_color.rgb, ember_color, smoothstep(0.2, 1.0, along));
    color += core_color.rgb * core * 1.2;

    float energy = body * fade * (0.55 + 0.6 * intensity);
    // Additive blending scales the colour by the alpha, so we fade only once.
    COLOR = vec4(color, energy);
}
