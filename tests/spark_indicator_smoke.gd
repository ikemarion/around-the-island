extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_solo()
	main.set_physics_process(false)
	var indicator = main.get_node("HUD/SparkIndicator")
	main.token_holder = main.local_slot
	indicator._process(0.1)
	assert(indicator.carrying and indicator.caption.text == "YOU HAVE THE SPARK")
	main.token_holder = (main.local_slot + 1) % 4
	indicator._process(0.1)
	assert(not indicator.carrying and indicator.caption.text == "CHASE THE SPARK")
	assert(indicator.change_time > 0.0)
	main.lobby.show()
	indicator._process(0.1)
	assert(not indicator.visible)
	var geometry = load("res://scripts/cartoon_geometry.gd")
	var mesh = geometry.rounded_box(Vector3.ONE)
	assert(mesh == geometry.rounded_box(Vector3.ONE))
	assert(mesh.get_aabb().size.is_equal_approx(Vector3.ONE))
	print("SPARK_INDICATOR passed: local possession, transfer, lobby hiding, cached geometry")
	quit()
