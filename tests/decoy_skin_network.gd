extends SceneTree
## Two processes verify owner skins and independent visible replicas using the
## existing authoritative effect snapshots. Not an Internet reliability test.
func _initialize() -> void:
	call_deferred("run")
	create_timer(25.0).timeout.connect(func():
		push_error("DECOY_SKIN_NETWORK timeout")
		quit(1))

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var host := "--decoy-host" in OS.get_cmdline_user_args()
	if host:
		game._prepare_session()
		game.session_mode = &"hosting"
		game.peer_to_slot = {1: 0}
		game.network_session.host_room(27997, false)
		while game.active_slots.count(true) < 2:
			await create_timer(0.02, true).timeout
		game._start_hosted_game()
		game.set_physics_process(false)
		for player in game.players: player.set_physics_process(false)
		var decoys: Array = []
		for slot in 2:
			var source: ATIPlayer = game.players[slot]
			source.global_position = Vector3(-2 + slot * 3, -0.05, 3.5)
			source._use_chaos_effect(&"decoy_double")
			var decoy = get_nodes_in_group("chaos_decoy").back()
			decoy.set_physics_process(false)
			decoys.append(decoy)
		game._broadcast_snapshot(true)
		for frame in 120:
			for decoy in decoys: decoy.global_position.x += 0.018
			if frame % 6 == 0: game._broadcast_snapshot(true)
			await physics_frame
		for decoy in decoys: decoy._physics_process(4.1)
		await process_frame
		game._broadcast_snapshot(true)
		while game.active_slots.count(true) > 1:
			await create_timer(0.02, true).timeout
		print("DECOY_SKIN_NETWORK host PASS: both owner skins, motion, expiry")
	else:
		game.code_input.text = "127.0.0.1:27997"
		game._join_online()
		while game.remote_temporary_items.size() < 2:
			await create_timer(0.02, true).timeout
		assert(game.local_slot == 1)
		var owners := {}
		for decoy in game.remote_temporary_items.values():
			assert(decoy.kind == &"decoy_double")
			var source: ATIPlayer = game.players[decoy.owner_slot]
			var visual = decoy.decoy_body.get_node("DecoyCharacter")
			assert(visual.model.fleece.get_shader_parameter("fleece_color") == source.body_mesh.get_node("Sockling").fleece.get_shader_parameter("fleece_color"))
			assert(visual.model.is_visible_in_tree() and not source.body_mesh.visible)
			assert(visual.model.actor == null and decoy.decoy_body.collision_mask == 0)
			owners[decoy.owner_slot] = true
		assert(owners.has(0) and owners.has(1), "One owner's decoy was missing")
		var saw_running := false
		while not game.remote_temporary_items.is_empty():
			for decoy in game.remote_temporary_items.values():
				var model = decoy.decoy_body.get_node("DecoyCharacter").model
				saw_running = saw_running or model.motion.gait > 0.3
			await create_timer(0.02, true).timeout
		assert(saw_running, "Replica decoys stayed in a static pose")
		await process_frame
		assert(get_nodes_in_group("chaos_decoy").is_empty(), "Expired decoy model remained on client")
		print("DECOY_SKIN_NETWORK client PASS: host and local-owner skins, invisible originals, visible animated copies, removal")
	game._prepare_session()
	for player in game.players:
		for audio_player in player.sfx_players: audio_player.stop()
	game.queue_free()
	await process_frame
	quit()
