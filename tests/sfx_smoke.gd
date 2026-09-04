extends SceneTree

const SFX_LIBRARY := preload("res://scripts/sfx_library.gd")
const EFFECTS := ["jump", "slide", "grab", "throw", "slick", "slip", "tag", "ready", "round_end", "pickup", "stun_shot", "stunned", "air_horn", "swap_bell", "spring", "deploy", "rewind", "chair_cannon", "door_open", "door"]


func _initialize() -> void:
	for effect_name in EFFECTS:
		var stream := SFX_LIBRARY.get_effect(effect_name)
		if stream == null or stream.data.is_empty():
			push_error("Failed to synthesize effect: %s" % effect_name)
			quit(1)
			return
	quit(0)
