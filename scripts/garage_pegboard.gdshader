shader_type spatial;
render_mode diffuse_burley;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	vec2 p = local_position.xy / 0.135;
	vec2 cell = fract(p + 0.5) - 0.5;
	float distance_to_hole = length(cell);
	float aa = max(fwidth(distance_to_hole), 0.004);
	float hole = 1.0 - smoothstep(0.064, 0.064 + aa, distance_to_hole);
	float lip = (1.0 - smoothstep(0.093, 0.093 + aa, distance_to_hole)) - hole;
	ALBEDO = mix(vec3(0.59, 0.42, 0.24), vec3(0.24, 0.24, 0.18), hole * 0.8) + lip * 0.035;
	ROUGHNESS = 0.87;
}
