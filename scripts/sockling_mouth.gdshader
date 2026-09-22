shader_type spatial;
render_mode unshaded;
uniform vec4 felt_color : source_color = vec4(0.34,0.150,0.105,1.0);
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	// A little bounced light inside the puppet keeps its mouth from reading
	// as a featureless black hole under the game's hard directional shadow.
	float bounce = 0.50+0.65*smoothstep(-0.04,0.33,local_point.z);
	float lower = 1.0-smoothstep(0.26,0.51,local_point.y);
	ALBEDO = felt_color.rgb*(bounce+lower*0.15);
}
