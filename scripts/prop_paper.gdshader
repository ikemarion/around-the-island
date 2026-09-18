shader_type spatial;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float grain = fract(sin(dot(floor(local_position*420.0),vec3(12.9898,78.233,43.17)))*43758.5453);
	ALBEDO = vec3(0.515,0.279,0.100)*(0.965+0.07*grain);
	ROUGHNESS = 0.97;
	SPECULAR = 0.15;
}
