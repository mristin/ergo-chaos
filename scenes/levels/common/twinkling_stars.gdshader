shader_type canvas_item;

uniform float star_density : hint_range(0.0, 1.0) = 0.12;
uniform float twinkle_speed = 2.5;
uniform float brightness = 1.4;
uniform float star_size = 0.015;
uniform vec4 star_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    vec2 grid = floor(uv / star_size);
    vec2 cell_uv = fract(uv / star_size) - 0.5;

    float rnd = hash(grid);
    float is_star = step(1.0 - star_density, rnd);

    float dist = length(cell_uv);
    float star = smoothstep(0.35, 0.0, dist);

    float twinkle = 0.5 + 0.5 * sin(TIME * twinkle_speed + rnd * 20.0);
    twinkle = pow(twinkle, 3.0);

    vec4 color = star_color * star * twinkle * brightness * is_star;
    COLOR = color;
}