shader_type spatial;
render_mode diffuse_burley;
varying vec3 local_position;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { local_position = VERTEX; }
void fragment() {
	vec2 p = (local_position.xz + vec2(9.0, 6.0)) / 1.5;
	vec2 tile = floor(p);
	vec2 edge = min(fract(p), 1.0 - fract(p));
	vec2 aa = max(fwidth(p), vec2(0.0001));
	float joint = 1.0 - min(smoothstep(0.005, 0.005 + aa.x, edge.x), smoothstep(0.005, 0.005 + aa.y, edge.y));
	float alternate = mod(tile.x + tile.y, 2.0);
	vec3 base = mix(vec3(0.56, 0.58, 0.50), vec3(0.63, 0.63, 0.53), alternate);
	base += (hash21(tile) - 0.5) * 0.035;
	// Fine plaster-like aggregate; fade frequencies smaller than a screen pixel.
	vec2 fleck_grid = local_position.xz * 85.0;
	float fade = 1.0 - smoothstep(0.45, 1.2, max(fwidth(fleck_grid.x), fwidth(fleck_grid.y)));
	float aggregate = (hash21(floor(fleck_grid)) - 0.5) * 0.035 * fade;
	ALBEDO = mix(base + aggregate, vec3(0.40, 0.45, 0.39), joint * 0.6);
	ROUGHNESS = 0.84;
}
