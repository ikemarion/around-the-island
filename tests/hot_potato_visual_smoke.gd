extends SceneTree

const EFFECT = preload("res://scripts/chaos_effect.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	for player in main.players:
		player.set_physics_process(false)
	for obstacle in main.get_tree().get_nodes_in_group("shoveable"):
		obstacle.hide()
	main.players[0].global_position = Vector3(7, 0.05, 7)
	var carrier = main.players[1]
	carrier.global_position = Vector3(0, 0.05, 3.0)
	carrier.body_mesh.rotation.y = 0.0
	var potato = EFFECT.new()
	main.add_child(potato)
	potato.setup(&"hot_potato", main.players[0], carrier)
	potato.set_physics_process(false)
	potato.remaining = 0.55
	potato._physics_process(0.0)
	assert(potato.hot_potato_hands.size() == 2)
	assert(potato.hot_potato_light.light_energy > 1.0)
	main.camera.gameplay_input_enabled = false
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	main.camera.global_position = Vector3(0, 2.25, 7.2)
	main.camera.look_at(Vector3(0, 0.9, 3.0))
	main.camera.fov = 42
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/hot-potato-warning.png")
	main.queue_free()
	await process_frame
	print("HOT_POTATO_VISUAL passed: held pose, heat color, pulse and warning light")
	quit()
