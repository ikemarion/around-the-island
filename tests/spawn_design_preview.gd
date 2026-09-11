extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	await process_frame
	await physics_frame
	await process_frame
	main.set_physics_process(false)
	main.set_process(false)
	for p in main.players:
		p.set_physics_process(false)
		p.hide()
	for obstacle in get_nodes_in_group("shoveable"):
		obstacle.hide()
	main.get_node("HUD").hide()
	main.distant_scoreboards.hide()
	var spawner = main.get_node("Arena/PowerUpSpawner")
	spawner.set_authoritative(false)
	spawner.apply_network_state({"position":Vector3(5,0,2),"available":true,"item_type":&"swap_bell","time_left":0})
	spawner.active_pickup.set_process(false)
	spawner.active_pickup.position.y = 1.03
	spawner.active_pickup.rotation.y = 0.25
	assert(spawner.saucer.available)
	assert(not spawner.status_label.visible)
	assert(spawner.get_node("Pad").collision_layer == 0)
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	main.camera.position = Vector3(6.85,1.8,5.25)
	main.camera.look_at(Vector3(5,0.66,2))
	main.camera.fov = 43
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/spawn-design.png")
	spawner.apply_network_state({"position":Vector3(5,0,2),"available":false,"item_type":&"","time_left":5})
	assert(not spawner.saucer.available)
	assert(spawner.saucer.glow.emission_energy_multiplier == 0)
	print("SPAWN_DESIGN passed: bell, available/empty ring, nonblocking pedestal, no label")
	quit()
