shader_type spatial;
render_mode diffuse_burley;
// Looper is short-pile velvet/felt, not Sockling's large curly terry loops.
uniform vec4 fleece_color : source_color = vec4(0.533,0.455,0.620,1.0);
uniform float stunned = 0.0;
uniform float pile_bump = 0.20;
varying vec3 fabric_position;
void vertex() { fabric_position = VERTEX; }
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float soft_noise(vec3 p) {
	vec3 c = floor(p);
	vec3 f = fract(p);
	vec3 u = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(c),hash(c+vec3(1,0,0)),u.x),mix(hash(c+vec3(0,1,0)),hash(c+vec3(1,1,0)),u.x),u.y),mix(mix(hash(c+vec3(0,0,1)),hash(c+vec3(1,0,1)),u.x),mix(hash(c+vec3(0,1,1)),hash(c+vec3(1,1,1)),u.x),u.y),u.z);
}
void fragment() {
	vec3 p = fabric_position;
	float cloud = soft_noise(p*38.0)-0.5;
	float nap = soft_noise(p*vec3(210.0,300.0,220.0))-0.5;
	float fine = soft_noise(p*520.0)-0.5;
	float fade = 1.0-smoothstep(0.65,2.2,length(fwidth(p*210.0)));
	float height = (nap*0.00095+fine*0.00035)*fade*pile_bump;
	vec3 base = mix(fleece_color.rgb,vec3(1.0,0.80,0.22),stunned*0.7);
	ALBEDO = base*(0.96+cloud*0.025+(nap*0.17+fine*0.045)*fade);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL);
	vec3 r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	if (abs(determinant)>0.000000001) {
		NORMAL = normalize(abs(determinant)*NORMAL-sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2));
	}
	// A broad grazing sheen suggests soft pile without shiny plastic highlights.
	ROUGHNESS = 0.96;
	SPECULAR = 0.06;
	RIM = 0.09;
	RIM_TINT = 0.80;
	EMISSION = base*0.006;
}
