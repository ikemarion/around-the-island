shader_type spatial;
render_mode diffuse_burley;
uniform vec4 fleece_color : source_color = vec4(0.80,0.53,0.15,1.0);
uniform float stunned = 0.0;
uniform bool striped_cuff = false;
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
	vec3 base = fleece_color.rgb;
	if (striped_cuff) {
		float stripe = smoothstep(-0.030,-0.027,fabric_position.y)*(1.0-smoothstep(0.039,0.042,fabric_position.y));
		base = mix(base,stripe_color.rgb,stripe);
	}
	ALBEDO = mix(base,vec3(1.0,0.80,0.22),stunned*0.7)*(0.94+grain*0.22);
	ROUGHNESS = 0.96;
	SPECULAR = 0.15;
}
