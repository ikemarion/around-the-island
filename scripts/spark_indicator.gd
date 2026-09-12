extends Control
## Local-only edge effects; no world geometry that could reveal invisible players.
var game: Node
var carrying := false
var invisible := false
var spark_strength := 0.0
var invisible_strength := 0.0
var effect: ColorRect
var age := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect = ColorRect.new()
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/status_vignette.gdshader")
	effect.material = mat

func _process(delta: float) -> void:
	age += delta
	if not is_instance_valid(game):
		return
	visible = not game.lobby.visible and not game.session_menu.visible and game.round_running
	var valid_slot: bool = game.local_slot >= 0 and game.local_slot < game.players.size()
	carrying = valid_slot and game.local_slot == game.token_holder
	invisible = valid_slot and game.players[game.local_slot].is_invisible()
	if not visible:
		spark_strength = 0.0
		invisible_strength = 0.0
	else:
		var blend := 1.0 - exp(-8.0 * delta)
		spark_strength = lerpf(spark_strength,1.0 if carrying else 0.0,blend)
		invisible_strength = lerpf(invisible_strength,1.0 if invisible else 0.0,blend)
	effect.material.set_shader_parameter("spark",spark_strength)
	effect.material.set_shader_parameter("invisible",invisible_strength)
	queue_redraw()

func _draw() -> void:
	# Tiny ballistic sparkler streaks travel across the screen, fading near aim.
	for i in 24:
		var phase := fmod(age*(0.28+0.04*sin(float(i)))+float(i)*0.618,1.0)
		var sign_x := 1.0 if i%2 == 0 else -1.0
		var x := -0.05+phase*1.1
		if sign_x < 0: x = 1.0-x
		var uv := Vector2(x,0.1+fmod(float(i)*0.381,0.8)-0.28*phase+0.35*phase*phase)
		var center_fade := smoothstep(0.07,0.28,uv.distance_to(Vector2(0.5,0.5)))
		var alpha := sin(phase*PI)*spark_strength*0.55*center_fade
		var p := uv*size
		var radius := 1.4*minf(size.x/1280.0,size.y/720.0)
		var tangent := Vector2(sign_x*1.1,-0.28+0.7*phase).normalized()
		draw_line(p-tangent*radius*8.0,p,Color(1,0.73,0.18,alpha*0.4),radius,true)
		draw_circle(p,radius*3.0,Color(1,0.73,0.18,alpha*0.12))
		draw_circle(p,radius,Color(1,0.95,0.67,alpha))
	# Ghost motes drift upward at the sides; no world-space reveal to opponents.
	for i in 20:
		var travel := fmod(age*0.07+float(i)*0.618,1.0)
		var x := 0.025+0.13*(0.5+0.5*sin(float(i)*2.1+age*0.35))
		if i%2 == 0: x = 1.0-x
		var p := Vector2(x,1.0-travel)*size
		var alpha := sin(travel*PI)*invisible_strength*0.65
		draw_line(p,p+Vector2(sin(age+i)*7,22),Color(0.65,0.8,1,alpha*0.4),2,true)
		draw_circle(p,3,Color(0.8,0.95,1,alpha))
