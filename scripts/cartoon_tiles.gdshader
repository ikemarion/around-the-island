shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 cream : source_color = vec4(0.902, 0.827, 0.686, 1.0);
uniform vec4 apricot : source_color = vec4(0.784, 0.592, 0.396, 1.0);
uniform vec4 grout : source_color = vec4(0.745, 0.658, 0.532, 1.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 tile = (world.xz + vec2(9.0, 6.0)) / 1.5;
	vec2 edge = min(fract(tile), 1.0 - fract(tile));
	float distance_to_edge = min(edge.x, edge.y);
	float aa = max(fwidth(distance_to_edge), 0.001);
	float seam = 1.0 - smoothstep(0.004-aa, 0.004+aa, distance_to_edge);
	float accent = mod(floor(tile.x) + floor(tile.y), 2.0);
	float variation = sin(dot(floor(tile), vec2(17.13, 41.71))) * 0.018;
	vec3 color = mix(cream.rgb, apricot.rgb, accent) * (1.0+variation);
	float bevel = smoothstep(0.005, 0.024, distance_to_edge);
	color *= mix(0.92, 1.0, bevel);
	// Calm cream border grounds the room without adding any floor geometry.
	float outer = min(9.0-abs(world.x), 6.0-abs(world.z));
	float border = 1.0-smoothstep(0.22,0.24,outer);
	color = mix(color, cream.rgb*0.94, border);
	ALBEDO = mix(color, grout.rgb, seam*(1.0-border));
	ROUGHNESS = 0.78;
	SPECULAR = 0.2;
}
