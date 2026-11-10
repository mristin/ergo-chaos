shader_type canvas_item;

// Glossy, slightly transparent goo drawn from a monochrome splat texture.
//
// The splat's alpha is blurred to estimate the thickness of the goo and a
// surface normal; from them we shade a liquid: deep amber where it pools,
// lighter at the thin edges, with a specular highlight, a glowing rim, slowly
// drifting caustics and a gentle wobble. Each splat gets its own phase from its
// position, so they do not pulse in unison.

uniform vec4 thin_color : source_color = vec4(1.0, 0.92, 0.35, 1.0);
uniform vec4 thick_color : source_color = vec4(1.0, 0.62, 0.02, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.7, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.78;

// Blur radius in texture pixels for the thickness and the normal.
uniform float blur_radius = 7.0;

varying float phase;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
    phase = hash(floor(MODEL_MATRIX[3].xy)) * 6.2831;
    // Breathe a little.
    VERTEX *= 1.0 + 0.035 * sin(TIME * 2.1 + phase);
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

// NOTE: A macro, since passing TEXTURE to a function upsets the shader compiler.
#define alpha_at(uv) texture(TEXTURE, uv).a

void fragment() {
    vec2 px = TEXTURE_PIXEL_SIZE;

    // Wobble the outline slightly.
    vec2 uv = UV + px * 1.2 * vec2(
        sin(UV.y * 18.0 + TIME * 2.7 + phase),
        cos(UV.x * 16.0 + TIME * 2.3 + phase)
    );

    float a = alpha_at(uv);
    if (a < 0.01) {
        discard;
    }

    // Thickness: a blur of the alpha (8 taps).
    vec2 r = px * blur_radius;
    float right = alpha_at(uv + vec2(r.x, 0.0));
    float left = alpha_at(uv - vec2(r.x, 0.0));
    float down = alpha_at(uv + vec2(0.0, r.y));
    float up = alpha_at(uv - vec2(0.0, r.y));
    float d1 = alpha_at(uv + r * 0.7071);
    float d2 = alpha_at(uv - r * 0.7071);
    float d3 = alpha_at(uv + vec2(r.x, -r.y) * 0.7071);
    float d4 = alpha_at(uv + vec2(-r.x, r.y) * 0.7071);
    float thickness = (right + left + down + up + d1 + d2 + d3 + d4) / 8.0;
    thickness = smoothstep(0.2, 1.0, thickness);

    // Normal of the goo surface from the gradient of the thickness, using the
    // diagonal taps as well for a smoother surface.
    float gx = (left + 0.7 * (d2 + d4)) - (right + 0.7 * (d1 + d3));
    float gy = (up + 0.7 * (d2 + d3)) - (down + 0.7 * (d1 + d4));
    vec3 n = normalize(vec3(gx, gy, 2.2));

    vec3 light = normalize(vec3(-0.55, -0.65, 0.75));
    float diffuse = clamp(dot(n, light), 0.0, 1.0);
    vec3 h = normalize(light + vec3(0.0, 0.0, 1.0));
    float specular = pow(clamp(dot(n, h), 0.0, 1.0), 40.0);

    vec3 color = mix(thin_color.rgb, thick_color.rgb, thickness);
    color *= 0.82 + 0.3 * diffuse;

    // Caustics drifting through the goo: ridges of a slowly warped noise.
    vec2 cp = uv * 7.0 + vec2(phase);
    cp += vec2(value_noise(cp + TIME * 0.4), value_noise(cp - TIME * 0.35 + 3.0)) * 1.5;
    float caustic = 1.0 - abs(value_noise(cp) * 2.0 - 1.0);
    color += vec3(1.0, 0.95, 0.6) * pow(caustic, 6.0) * 0.35 * thickness;

    // A glossy highlight and a glowing rim.
    color += vec3(1.0) * specular * 0.9;
    float rim = (1.0 - thickness) * a;
    color += rim_color.rgb * rim * (0.35 + 0.15 * sin(TIME * 3.0 + phase));

    // Thin edges are more see-through than the pooled middle.
    float alpha = a * opacity * mix(0.6, 1.0, thickness);
    alpha = max(alpha, specular * a);

    COLOR = vec4(color, alpha);
}
