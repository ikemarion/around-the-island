shader_type canvas_item;
render_mode unshaded;
uniform float spark : hint_range(0.0,1.0) = 0.0;
uniform float invisible : hint_range(0.0,1.0) = 0.0;
void fragment() {
	float d = min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
	float edge = 1.0-smoothstep(0.0,0.13,d);
	float gold = edge*edge*0.38*spark*(0.94+0.06*sin(TIME*1.6));
	float ribbon = pow(0.5+0.5*sin(UV.y*30.0+UV.x*12.0-TIME*2.2),6.0);
	float ghost_edge = 1.0-smoothstep(0.0,0.30,d);
	float wave = 0.5+0.5*sin(UV.y*19.0+sin(UV.x*15.0+TIME*0.55)*2.5-TIME*0.9);
	float ghost = (0.065+ghost_edge*ghost_edge*(0.20+0.25*ribbon+0.18*wave))*invisible;
	vec3 tint = mix(vec3(0.30,0.65,0.90),vec3(0.62,0.40,0.95),0.5+0.5*sin(UV.y*13.0-TIME));
	vec3 color = (vec3(1.0,0.76,0.22)*gold+tint*ghost)/max(0.0001,gold+ghost);
	COLOR = vec4(color,min(0.60,gold+ghost));
}
