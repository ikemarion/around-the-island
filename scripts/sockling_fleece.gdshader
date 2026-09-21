shader_type spatial;
render_mode diffuse_burley;
uniform vec4 fleece_color : source_color = vec4(0.80,0.53,0.15,1.0);
uniform float stunned = 0.0;
uniform bool striped_cuff = false;
uniform bool sock_foot = false;
uniform vec4 stripe_color : source_color = vec4(0.737,0.396,0.345,1.0);
varying vec3 fabric_position;
void vertex() { fabric_position = VERTEX; }
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void fragment() {
	vec3 p = fabric_position*165.0;
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 u = f*f*(3.0-2.0*f);
	float nap = mix(mix(mix(hash(cell),hash(cell+vec3(1,0,0)),u.x),mix(hash(cell+vec3(0,1,0)),hash(cell+vec3(1,1,0)),u.x),u.y),mix(mix(hash(cell+vec3(0,0,1)),hash(cell+vec3(1,0,1)),u.x),mix(hash(cell+vec3(0,1,1)),hash(cell+vec3(1,1,1)),u.x),u.y),u.z);
	float fade = 1.0-smoothstep(0.4,1.5,length(fwidth(p)));
	float grain = (nap-0.5)*fade;
	float height = (nap-0.5)*0.0025*fade;
	vec3 base = fleece_color.rgb;
	if (sock_foot) {
		base = mix(stripe_color.rgb,base,smoothstep(-0.201,-0.193,fabric_position.y));
	}
	if (striped_cuff) {
		float stripe = smoothstep(-0.030,-0.027,fabric_position.y)*(1.0-smoothstep(0.039,0.042,fabric_position.y));
		base = mix(base,stripe_color.rgb,stripe);
		float around = atan(fabric_position.z,fabric_position.x)*40.0/6.2831853;
		float chevron = abs(fract(around)*2.0-1.0);
		float stitches = sin((fabric_position.y*82.0+chevron*0.45)*6.2831853);
		height += stitches*0.0007*fade;
	}
	ALBEDO = mix(base,vec3(1.0,0.80,0.22),stunned*0.7)*(0.94+grain*0.22);
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
	EMISSION = base*0.025;
	RIM = 0.24;
	RIM_TINT = 0.65;
	ROUGHNESS = 0.96;
	SPECULAR = 0.15;
}
