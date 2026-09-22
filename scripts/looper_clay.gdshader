shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Preserve the shared character color/stun contract; the surface is clay, not fleece.
uniform vec4 fleece_color : source_color = vec4(0.533, 0.455, 0.620, 1.0);
uniform float stunned = 0.0;
uniform float clay_relief = 1.4;
varying vec3 clay_position;

void vertex() {
	clay_position = VERTEX;
}

float clay_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float clay_noise(vec3 p) {
	vec3 c = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(clay_hash(c), clay_hash(c + vec3(1,0,0)), u.x), mix(clay_hash(c + vec3(0,1,0)), clay_hash(c + vec3(1,1,0)), u.x), u.y),
		mix(mix(clay_hash(c + vec3(0,0,1)), clay_hash(c + vec3(1,0,1)), u.x), mix(clay_hash(c + vec3(0,1,1)), clay_hash(c + vec3(1,1,1)), u.x), u.y), u.z);
}

void fragment() {
	vec3 p = clay_position;
	float pressed = clay_noise(p * 17.0) - 0.5;
	float worked = clay_noise(p * vec3(62.0, 81.0, 68.0) + pressed * 1.7) - 0.5;
	float pores = clay_noise(p * 260.0) - 0.5;
	// Sub-millimetre tooling/pore relief, faded before it can shimmer at distance.
	float detail_fade = 1.0 - smoothstep(0.6, 1.8, length(fwidth(p * 260.0)));
	float height = (pressed * 0.0011 + worked * 0.00032 + pores * 0.00012 * detail_fade) * clay_relief;
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy, NORMAL);
	vec3 r2 = cross(NORMAL, dx);
	float determinant = dot(dx, r1);
	if (abs(determinant) > 0.000000001) {
		NORMAL = normalize(abs(determinant) * NORMAL - sign(determinant) * (dFdx(height) * r1 + dFdy(height) * r2));
	}
	vec3 base = mix(fleece_color.rgb, vec3(1.0, 0.80, 0.22), stunned * 0.7);
	ALBEDO = base * (0.985 + pressed * 0.024 + worked * 0.012);
	// Broad, restrained highlights suggest kneaded modeling clay, not glazed plastic.
	ROUGHNESS = 0.82 + worked * 0.08;
	SPECULAR = 0.24;
	RIM = 0.0;
	EMISSION = base * 0.012;
}
