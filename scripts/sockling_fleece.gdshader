shader_type spatial;
render_mode diffuse_burley;
uniform vec4 fleece_color : source_color = vec4(0.80,0.53,0.15,1.0);
uniform float stunned = 0.0;
uniform bool striped_cuff = false;
uniform bool sock_foot = false;
uniform vec4 stripe_color : source_color = vec4(0.694,0.420,0.369,1.0);
varying vec3 fabric_position;
varying vec3 fabric_normal;
void vertex() { fabric_position = VERTEX; fabric_normal = NORMAL; }
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float soft_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 u = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(cell),hash(cell+vec3(1,0,0)),u.x),mix(hash(cell+vec3(0,1,0)),hash(cell+vec3(1,1,0)),u.x),u.y),mix(mix(hash(cell+vec3(0,0,1)),hash(cell+vec3(1,0,1)),u.x),mix(hash(cell+vec3(0,1,1)),hash(cell+vec3(1,1,1)),u.x),u.y),u.z);
}
float yarn_loops(vec2 p) {
	vec2 origin = floor(p-0.5);
	float loops = 0.0;
	for (int y=0;y<2;y++) {
		for (int x=0;x<2;x++) {
			vec2 cell = origin+vec2(float(x),float(y));
			float r = hash(vec3(cell,17.0));
			vec2 d = p-(cell+0.5+vec2(r-0.5,fract(r*31.0)-0.5)*0.24);
			float a = r*6.2831853;
			d = mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)))*d;
			float ring = length(d*vec2(1.0,1.20))-(0.28+r*0.08);
			loops = max(loops,exp(-ring*ring/0.009));
		}
	}
	return loops;
}
void fragment() {
	// Triplanar curly terry yarn: rounded little loops rather than glittery
	// random dots. Broad clumps survive at normal gameplay distances.
	vec3 p = fabric_position*90.0;
	vec3 weights = pow(abs(normalize(fabric_normal)),vec3(4.0));
	weights /= max(dot(weights,vec3(1.0)),0.001);
	float loops = yarn_loops(p.yz)*weights.x+yarn_loops(p.xz)*weights.y+yarn_loops(p.xy)*weights.z;
	float fade = 1.0-smoothstep(0.55,2.0,length(fwidth(p)));
	float clumps = soft_noise(fabric_position*36.0)-0.5;
	float height = ((loops-0.4)*0.0016+clumps*0.0008)*fade;
	vec3 base = fleece_color.rgb;
	if (sock_foot) {
		base = mix(stripe_color.rgb,base,smoothstep(-0.201,-0.193,fabric_position.y));
	}
	if (striped_cuff) {
		float stripe = smoothstep(-0.019,-0.016,fabric_position.y)*(1.0-smoothstep(0.025,0.028,fabric_position.y));
		base = mix(base,stripe_color.rgb,stripe);
		float around = atan(fabric_position.z,fabric_position.x)*28.0/6.2831853;
		float chevron = abs(fract(around)*2.0-1.0);
		float stitches = sin((fabric_position.y*36.0+chevron*0.45)*6.2831853);
		height = (stitches*0.0012+(loops-0.4)*0.00025)*fade;
	}
	ALBEDO = mix(base,vec3(1.0,0.80,0.22),stunned*0.7)*(0.94+clumps*0.07+(loops-0.4)*0.055*fade);
	// Screen-derivative bump from object-space fibre height, stable as the
	// character moves. It fades before the fibres become subpixel noise.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL);
	vec3 r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	if (abs(determinant)>0.000000001) {
		NORMAL = normalize(abs(determinant)*NORMAL-sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2));
	}
	EMISSION = base*0.012;
	RIM = 0.12;
	RIM_TINT = 0.85;
	ROUGHNESS = 1.0;
	SPECULAR = 0.03;
}
