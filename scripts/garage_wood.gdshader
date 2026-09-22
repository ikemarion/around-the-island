shader_type spatial;
render_mode diffuse_burley;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	vec2 p = local_position.xz;
	float grain = sin(p.y * 115.0 + sin(p.x * 1.9 + p.y * 7.0) * 2.3);
	float broad = sin(p.y * 22.0 + sin(p.x * 1.4) * 1.1);
	ALBEDO = vec3(0.57, 0.36, 0.19) + grain * 0.010 + broad * 0.021;
	ROUGHNESS = 0.64;
}
