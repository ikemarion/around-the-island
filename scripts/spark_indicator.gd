extends Control
## Local-only edge effects; no world geometry that could reveal invisible players.
var game: Node
var carrying := false
var invisible := false
var spark_strength := 0.0
var invisible_strength := 0.0
var effect: ColorRect

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
