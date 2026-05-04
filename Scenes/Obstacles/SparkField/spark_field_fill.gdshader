shader_type canvas_item;

void fragment() {
    COLOR = vec4(fract(UV.x / 100.0), fract(UV.y / 100.0), 1.0, 0.8);
}