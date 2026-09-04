extends SceneTree

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
	await physics_frame
	var p = main.players[0]
	var remote = main.players[1]
	remote.ai_controlled = false
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	p.stun_time_remaining = 2.0
	p.equipped_spawn_item = &"stun_gun"
	p._unhandled_input(click)
	assert(p.has_stun_gun())
	remote.network_controlled = true
	remote.equipped_spawn_item = &"stun_gun"
	remote.stun_time_remaining = 2.0
	remote.set_network_input(Vector2.ZERO, Vector3.FORWARD, false, false, false, false, false)
	remote.action_queue.append(&"throw")
	remote._physics_process(0.016)
	assert(remote.has_stun_gun())
	p.reset_movement_state()
	p.client_predicted = true
	p.replica_target_ready = true
	p.motion_epoch = 50
	p.global_position = Vector3(-5, 0, 0)
	p.apply_authoritative_motion({"position": Vector3(5, 0, 0), "velocity": Vector3(3, 0, 0), "motion_epoch": 50, "ack": 200})
	assert(p.global_position == Vector3(5, 0, 0))
	p.client_predicted = false
	main._start_solo()
	remote.ai_controlled = false
	remote.network_controlled = true
	remote.equipped_spawn_item = &"stun_gun"
	main.peer_to_slot = {0: 1}
	var beams: Array = []
	remote.beam_event.connect(func(origin, end, _hit): beams.append((end - origin).normalized()))
	main._receive_action_state(1, main.round_epoch, [false, false, false, true, false], Vector3.FORWARD, ["throw"])
	main._receive_remote_input(Vector2.ZERO, Vector3.RIGHT, false, false, false, false, false, 1, main.round_epoch)
	remote._physics_process(0.016)
	assert(beams.size() == 1 and beams[0].is_equal_approx(Vector3.FORWARD))
	main.scores.assign([10.0, 10.0, 0.0, 0.0])
	main._end_round()
	main._update_world_scoreboard()
	assert(main.status_label.text.begins_with("Tie:") and not main.winner_crown.visible)
	main._start_solo()
	main.camera._set_first_person(false)
	var host_origin: Vector3 = p._get_aim_origin()
	p.network_controlled = true
	var remote_origin: Vector3 = p._get_aim_origin()
	assert(host_origin.is_equal_approx(remote_origin))
	p.network_controlled = false
	main.camera._set_first_person(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.equipped_spawn_item = &"stun_gun"
	p._unhandled_input(click)
	assert(p.has_stun_gun())
	# Simulate unreliable effect update overtaking a reliable full manifest.
	main.session_mode = &"client"
	main.round_epoch = 1
	var effect := {"id": 4242, "kind": "Chaos", "position": Vector3.ZERO,
		"chaos": {"effect": &"pocket_wall", "owner": 0, "target": -1, "time": 5.0, "tint": Color.WHITE, "end": Vector3.ZERO, "rotation": Vector3.ZERO}}
	main._receive_effect_manifest([effect], 1, 1)
	var newer: Dictionary = effect.duplicate(true)
	newer.position = Vector3(5, 0, 0)
	newer.chaos.time = 1.0
	main._receive_effect_state(newer, 1, 20)
	main._receive_effect_manifest([effect], 1, 10)
	assert(main.remote_temporary_items["4242"].global_position == Vector3(5, 0, 0) and main.remote_temporary_items["4242"].remaining == 1.0)
	main._start_solo()
	main.set_physics_process(false)
	for player in main.players: player.set_physics_process(false)
	p.global_position = Vector3(-6, 0.05, 0.6)
	remote.global_position = Vector3(-6, 0.05, -0.6)
	var wall = load("res://scripts/chaos_effect.gd").new()
	main.add_child(wall)
	wall.setup(&"pocket_wall", p)
	wall.set_physics_process(false)
	wall.global_position = Vector3(-6, 0.05, 0)
	wall.rotation = Vector3.ZERO
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP, remote.global_position + Vector3.UP, 3, [p.get_rid()])
	var hit = p.get_world_3d().direct_space_state.intersect_ray(ray)
	main.token_holder = 0
	main.tag_cooldown_remaining = 0
	main._physics_process(0.016)
	assert(not hit.is_empty() and hit.collider is StaticBody3D and main.token_holder == 0)
	main._set_session_menu(true)
	assert(main.session_menu.visible and p.input_suspended and not main.camera.gameplay_input_enabled)
	main._set_session_menu(false)
	assert(not main.session_menu.visible and not p.input_suspended)
	main._enter_lobby()
	assert(main.lobby.visible and not main.session_menu.visible)
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("SCALING_REGRESSION passed")
	quit()
