shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float wave = sin(UV.y*12.0 + sin(UV.x*7.0+TIME)*2.0 - TIME*1.8);
	float ribbon = pow(0.5+0.5*wave, 10.0);
	float edge = pow(abs(UV.x-0.5)*2.0, 4.0);
	ALBEDO = mix(vec3(0.35,0.78,0.64),vec3(1.0,0.91,0.55),ribbon*0.6+edge*0.4);
	EMISSION = vec3(1.0,0.84,0.38)*(ribbon*0.3+edge*0.15);
	ALPHA = 0.7;
}
