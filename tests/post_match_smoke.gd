extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_solo()
	main.set_physics_process(false)
	main.scores.assign([20.0,10.0,0.0,0.0])
	main.time_remaining = 0
	main._end_round()
	assert(not main.round_running and main.players[0].simulation_enabled)
	assert(is_instance_valid(main.celebration))
	if DisplayServer.get_name() != "headless":
		for i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/post-match.png")
	var celebration = main.celebration
	main._celebrate_round()
	assert(main.celebration == celebration)
	main._physics_process(0.1)
	assert(main.scores[0] == 20.0 and main.time_remaining == 0)
	main.players[0].global_position.y = -5
	main._physics_process(0.1)
	assert(main.players[0].global_position.y > -3)
	var p = main.players[0]
	p.network_controlled = true
	p.global_position = Vector3(0,1,4)
	p.set_network_input(Vector2(1,0),Vector3.FORWARD,false,false,false,false,false)
	var start: Vector3 = p.global_position
	for i in 20:
		await physics_frame
	assert(p.global_position.distance_to(start) > 0.1)
	# Exercise client snapshot handling without a live transport.
	main.session_mode = &"client"
	main.local_slot = 0
	main._receive_match_state([20.0,10.0,0.0,0.0],0,0,{},false,main.round_epoch,100)
	main._receive_player_state(0,main._player_state(0),main.round_epoch,101)
	assert(p.simulation_enabled and main._can_roam())
	assert(main.celebration == celebration)
	main.session_mode = &"solo"
	main.reset_round()
	assert(main.round_running and main.scores[0] == 0)
	await process_frame
	assert(not is_instance_valid(celebration))
	main._enter_lobby()
	assert(not main._can_roam() and not p.simulation_enabled)
	print("POST_MATCH passed: movement, frozen scores, respawn, client state, one celebration, restart, lobby")
	quit()
