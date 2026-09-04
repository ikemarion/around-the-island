extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	for p in main.players:
		p.set_physics_process(false)
	main.active_slots.assign([true, true, true, true])
	main.scores.assign([24.0, 12.0, 8.0, 3.0])
	main.time_remaining = 28
	main._update_world_scoreboard()
	assert(main.distant_scoreboards.displays.size() == 4)
	for display in main.distant_scoreboards.displays:
		assert(is_equal_approx(display.rows[0].bar.scale.x, 3.2))
		assert(display.rows[0].name.text == "YOU")
		assert(display.title.text.contains("28s"))
	main.local_slot = 2
	main.active_slots[1] = false
	main._update_world_scoreboard()
	assert(main.distant_scoreboards.displays[0].rows[2].name.text == "YOU")
	assert(not main.distant_scoreboards.displays[0].rows[1].node.visible)
	main.active_slots[1] = true
	main.local_slot = 0
	main._update_world_scoreboard()
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	main.camera.global_position = Vector3(-5.2, 1.5, 0)
	main.camera.look_at(Vector3(0, 9, -28))
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/distant-scores.png")
	main.round_running = false
	main._update_world_scoreboard()
	assert(main.distant_scoreboards.displays[0].title.text == "FINAL SCORES")
	main._enter_lobby()
	main._process(0)
	assert(not main.distant_scoreboards.visible)
	main.queue_free()
	await process_frame
	print("DISTANT_SCOREBOARDS passed")
	quit()
