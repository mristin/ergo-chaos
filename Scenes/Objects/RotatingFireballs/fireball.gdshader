shader_type canvas_item;

uniform float time_offset : hint_range(0.0, 6.28318) = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float angle = atan(uv.y, uv.x);

	// Spiky exploding edge from overlapping sine waves
	float spikes = sin(angle * 7.0  + TIME * 3.5 + time_offset)        * 0.15
	             + sin(angle * 13.0 - TIME * 5.0 + time_offset * 1.3)  * 0.08
	             + sin(angle * 3.0  + TIME * 1.8 + time_offset * 0.7)  * 0.13
	             + sin(angle * 19.0 + TIME * 7.0 + time_offset * 2.1)  * 0.05;

	float edge = 0.82 + spikes;
	float alpha = 1.0 - smoothstep(edge - 0.08, edge + 0.12, dist);

	// Energy rings pulsing outward
	float rings = sin(dist * 10.0 - TIME * 8.0 + time_offset) * 0.5 + 0.5;

	float heat = clamp(1.0 - dist / max(edge, 0.01), 0.0, 1.0);

	vec3 outer_col = vec3(0.0,  0.05, 0.9);   // deep blue
	vec3 mid_col   = vec3(0.1,  0.7,  1.0);   // electric cyan
	vec3 inner_col = vec3(0.85, 0.97, 1.0);   // white-blue core

	vec3 color = mix(outer_col, mid_col,   smoothstep(0.0, 0.5, heat));
	color      = mix(color,     inner_col, smoothstep(0.45, 0.92, heat));

	// Overlay pulsing rings
	color += vec3(0.0, 0.3, 0.6) * rings * heat * 0.6;

	COLOR = vec4(color, alpha);
}
