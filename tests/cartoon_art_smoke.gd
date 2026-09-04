extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	for p in main.players: p.set_physics_process(false)
	main.active_slots.assign([true,true,true,true])
	for index in 4:
		main.players[index].set_slot_active(true)
		main.players[index].set_local_visual_hidden(false)
		main.players[index].position = Vector3(-5+index*3.2,0.05,2.8)
		main.players[index].body_mesh.rotation.y = 0
	var art = main.get_node("CartoonArt")
	assert(art.find_children("*","CollisionObject3D",true,false).is_empty())
	for obstacle in get_nodes_in_group("shoveable"):
		assert(obstacle.has_node("CartoonProp"))
		assert(obstacle.get_node("CollisionShape3D").shape.size == Vector3.ONE*0.9)
	var p = main.players[1]
	p.set_network_invisibility(5.0)
	assert(not p.body_mesh.visible)
	for detail in p.body_mesh.get_children():
		if detail is Node3D: assert(not detail.is_visible_in_tree())
	p.set_network_invisibility(0)
	assert(p.body_mesh.visible)
	main.camera.gameplay_input_enabled = false
	main.camera.position = Vector3(9,7.5,10)
	main.camera.look_at(Vector3(0,0,0))
	main.camera.fov = 70
	await capture("cartoon-overview")
	main.players[0].position = Vector3(6,0.05,4)
	main._set_local_camera(0)
	main.players[0].equipped_spawn_item = &"air_horn"
	main._update_world_scoreboard()
	main.camera.fov = 100
	await process_frame
	art._process(0)
	assert(art.horn.visible)
	await capture("cartoon-first-person")
	main.players[0].equipped_spawn_item = &""
	art._process(0)
	assert(not art.horn.visible)
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("CARTOON_ART passed: props, collision envelopes, invisibility, first-person horn")
	quit()

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/"+filename+".png")
