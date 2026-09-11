extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_solo()
	main.set_physics_process(false)
	assert(not main.get_node("HUD/Controls").visible)
	var prop = load("res://scripts/shoveable.gd").new()
	root.add_child(prop)
	prop.set_highlighted(true)
	assert(not prop.grab_prompt.visible and prop.grab_prompt.text.is_empty())
	prop.queue_free()
	var indicator = main.get_node("HUD/SparkIndicator")
	main.token_holder = main.local_slot
	indicator._process(0.1)
	assert(indicator.carrying and indicator.spark_strength > 0.0)
	main.token_holder = (main.local_slot + 1) % 4
	indicator._process(0.1)
	assert(not indicator.carrying)
	main.players[main.local_slot].set_network_invisibility(5.0)
	indicator._process(0.2)
	assert(indicator.invisible and indicator.invisible_strength > 0.0)
	main.token_holder = main.local_slot
	indicator._process(0.2)
	assert(indicator.carrying and indicator.invisible)
	main.players[main.local_slot].set_network_invisibility(0.0)
	indicator._process(1.0)
	assert(not indicator.invisible and indicator.invisible_strength < 0.01)
	main.lobby.show()
	indicator._process(0.1)
	assert(not indicator.visible)
	assert(indicator.spark_strength == 0.0 and indicator.invisible_strength == 0.0)
	var geometry = load("res://scripts/cartoon_geometry.gd")
	var mesh = geometry.rounded_box(Vector3.ONE)
	assert(mesh == geometry.rounded_box(Vector3.ONE))
	assert(mesh.get_aabb().size.is_equal_approx(Vector3.ONE))
	print("SPARK_INDICATOR passed: spark, invisibility, overlap, expiry, menu cleanup")
	quit()
