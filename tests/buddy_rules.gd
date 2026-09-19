extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	for p in main.players: p.set_physics_process(false)
	var player = main.players[0]
	player.set_local_visual_hidden(false)
	player.global_position = Vector3(5,0.05,3)
	player._use_chaos_effect(&"decoy_double")
	assert(player.is_invisible() and not player.body_mesh.visible)
	assert(player.invisibility_time_remaining == 0.0 and player.buddy_hide_time == 4.0)
	assert(main._player_state(0).buddy_hide == 4.0)
	var buddy = get_nodes_in_group("chaos_decoy")[0]
	assert(buddy.visible and buddy.decoy_body.visible)
	var steps = player.get_node("BuddyFootsteps")
	player.global_position = Vector3(5,0.05,3)
	steps._physics_process(0.02)
	await physics_frame
	player.global_position += Vector3.RIGHT*0.55
	steps._physics_process(0.02)
	assert(steps.next_print > 0)
	if DisplayServer.get_name() != "headless":
		main.get_node("HUD").hide()
		main.camera.set_process(false)
		main.camera.set_physics_process(false)
		main.camera.global_position = Vector3(8,3.5,6)
		main.camera.look_at(Vector3(5,0.5,3))
		main.camera.fov = 65
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/buddy-footsteps.png")
	player.motion_epoch += 1
	steps._physics_process(0.02)
	assert(steps.prints.all(func(p): return not p.visible))
	player._physics_process(4.1)
	assert(not player.is_invisible())
	player._use_invisibility()
	player.buddy_hide_time = 0
	steps._physics_process(0.02)
	assert(player.is_invisible() and not steps.active)
	player.reset_movement_state()
	assert(not player.is_invisible() and player.buddy_hide_time == 0.0)
	print("BUDDY_RULES PASS: hidden user, visible buddy, grounded footprints, snapshot, teleport cleanup, independent invisibility, reset")
	quit()
