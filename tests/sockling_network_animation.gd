extends SceneTree
## Two-process localhost fixture; existing snapshots only, no animation RPCs.
func _initialize() -> void:
	call_deferred("run")
	create_timer(35.0).timeout.connect(func():
		push_error("SOCKLING_NETWORK timed out")
		quit(1))

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var host := "--animation-host" in OS.get_cmdline_user_args()
	if host:
		game._prepare_session()
		game.session_mode = &"hosting"
		game.peer_to_slot = {1: 0}
		game.network_session.host_room(27993,false)
		var deadline := Time.get_ticks_msec()+10000
		while game.active_slots.count(true) < 2 and Time.get_ticks_msec() < deadline:
			await create_timer(0.05,true).timeout
		assert(game.active_slots.count(true) == 2,"Animation test client failed to connect")
		game._start_hosted_game()
		var p: ATIPlayer = game.players[0]
		p.set_physics_process(false)
		# Repeat across transport startup/throttling; a single short jump can
		# be missed by unreliable snapshots without indicating an art failure.
		for frame in 900:
			var t := fmod(frame/60.0,3.0)
			p.position = Vector3(-1+t*0.6,-0.05,3.5)
			p.velocity = Vector3(0.6,0,0)
			p._set_crouched(t > 2.15)
			if t >= 1.0 and t < 1.71:
				var jump_t := t-1.0
				p.position.y += maxf(0,8.5*jump_t-12*jump_t*jump_t)
				p.velocity.y = 8.5-24*jump_t
			await physics_frame
		print("SOCKLING_NETWORK host: existing snapshots sent")
	else:
		game.code_input.text = "127.0.0.1:27993"
		game._join_online()
		var deadline := Time.get_ticks_msec()+12000
		while not game.round_running and Time.get_ticks_msec() < deadline:
			await create_timer(0.02,true).timeout
		assert(game.round_running,"Animation test lobby did not start")
		var observed := {}
		var art = game.players[0].body_mesh.get_node("Sockling")
		var elbow_min := INF
		var elbow_max := -INF
		var wrist_travel := 0.0
		for frame in 810:
			await physics_frame
			observed[art.motion.state] = true
			var elbow: float = art.arm_skeletons[0].get_bone_pose_rotation(1).get_euler().x
			elbow_min = minf(elbow_min, elbow)
			elbow_max = maxf(elbow_max, elbow)
			wrist_travel = maxf(wrist_travel, absf(art.arm_skeletons[0].get_bone_pose_rotation(2).get_euler().x))
		for expected in [&"walk",&"rise",&"fall",&"land",&"crouch"]:
			assert(observed.has(expected),"Remote animation state missing: "+str(expected)+" observed "+str(observed))
		assert(elbow_max - elbow_min > 0.12, "Remote elbow must articulate, not remain in bind pose")
		assert(wrist_travel > 0.005, "Remote wrist must follow the moving arm")
		assert(art.arm_meshes[0].skin != null and art.arm_meshes[0].get_node(art.arm_meshes[0].skeleton) == art.arm_skeletons[0])
		print("SOCKLING_NETWORK client: remote walk/rise/apex/fall/land/crouch and skinned elbow/wrist motion observed with existing protocol")
	game._prepare_session()
	game.queue_free()
	await process_frame
	quit()
