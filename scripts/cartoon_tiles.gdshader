shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 tile = world.xz / 1.2;
	vec2 edge = min(fract(tile), 1.0 - fract(tile));
	float seam = 1.0 - smoothstep(0.006, 0.022, min(edge.x, edge.y));
	float accent = step(3.5, mod(floor(tile.x) + floor(tile.y)*3.0, 5.0));
	vec3 color = mix(vec3(0.94,0.84,0.63), vec3(0.83,0.49,0.22),accent);
	ALBEDO = mix(color, vec3(0.42,0.35,0.24),seam*0.6);
	ROUGHNESS = 1.0;
}
