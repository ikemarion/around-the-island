extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_solo()
	await process_frame
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	for p in main.players:
		p.set_physics_process(false)
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	main.camera.position = Vector3(6,1.4,4)
	main.camera.look_at(Vector3(0,0.8,0))
	main.camera.fov = 100
	var indicator = main.get_node("HUD/SparkIndicator")
	for child in main.get_node("HUD").get_children():
		if child is CanvasItem and child != indicator:
			child.hide()
	main.distant_scoreboards.hide()
	for mode in ["spark","invisible","both"]:
		main.token_holder = main.local_slot if mode != "invisible" else 1
		main.players[main.local_slot].set_network_invisibility(5.0 if mode != "spark" else 0.0)
		indicator._process(1.0)
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/network-test/vignette-"+mode+".png")
	print("VIGNETTE_PREVIEW passed")
	quit()
