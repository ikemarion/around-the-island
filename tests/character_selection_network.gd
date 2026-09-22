extends SceneTree
## Real ENet peers: handshake choice, lobby changes, match lock, and mixed decoys.
## Localhost only; this fixture does not establish Internet reliability.
func _initialize() -> void:
	call_deferred("run")
	create_timer(35.0).timeout.connect(func():
		push_error("CHARACTER_NETWORK timeout")
		quit(1))

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._enter_lobby()
	game.choose_character(&"looper")
	var host := "--character-host" in OS.get_cmdline_user_args()
	if host:
		game._prepare_session()
		game.session_mode = &"hosting"
		game.peer_to_slot = {1: 0}
		game.network_session.host_room(27996, false)
		while game.active_slots.count(true) < 2:
			await create_timer(0.02, true).timeout
		assert(game.players[1].character_id == &"looper", "Join preference was not admitted")
		while game.players[1].character_id != &"sockling":
			await create_timer(0.02, true).timeout
		game.choose_character(&"sockling")
		while game.players[1].character_id != &"looper":
			await create_timer(0.02, true).timeout
		game._start_hosted_game()
		game.set_physics_process(false)
		for player in game.players: player.set_physics_process(false)
		var decoys: Array = []
		for slot in 2:
			var actor: ATIPlayer = game.players[slot]
			actor.global_position = Vector3(-2 + slot * 3, -0.05, 3.5)
			actor._use_chaos_effect(&"decoy_double")
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
		# Same client rejoins the already running game with a different preference.
		while game.active_slots.count(true) < 2:
			await create_timer(0.02, true).timeout
		assert(game.players[1].character_id == &"sockling", "Late-join choice retained the previous occupant's Looper")
		game._broadcast_snapshot(true)
		while game.active_slots.count(true) > 1:
			await create_timer(0.02, true).timeout
		print("CHARACTER_NETWORK host PASS: initial choice, lobby RPCs, mixed decoys, disconnect and late rejoin with a new skin")
	else:
		game.code_input.text = "127.0.0.1:27996"
		game._join_online()
		while game.received_roster_sequence < 0:
			await create_timer(0.02, true).timeout
		assert(game.local_slot == 1 and game.players[0].character_id == &"looper" and game.players[1].character_id == &"looper")
		game.choose_character(&"sockling")
		while game.players[0].character_id != &"sockling":
			await create_timer(0.02, true).timeout
		game.choose_character(&"looper")
		while game.remote_temporary_items.size() < 2:
			await create_timer(0.02, true).timeout
		assert(game.round_running)
		game.choose_character(&"sockling")
		assert(game.players[1].character_id == &"looper", "Running match accepted a skin change")
		var owners := {}
		for decoy in game.remote_temporary_items.values():
			var actor: ATIPlayer = game.players[decoy.owner_slot]
			var copy = decoy.decoy_body.get_node("DecoyCharacter").model
			assert(decoy.character_id == actor.character_id)
			assert(copy.get_script() == actor.character_model().get_script())
			assert(copy.fleece.get_shader_parameter("fleece_color") == actor.character_model().fleece.get_shader_parameter("fleece_color"))
			assert(copy.is_visible_in_tree() and not actor.body_mesh.visible)
			assert(copy.actor == null and decoy.decoy_body.collision_mask == 0)
			owners[decoy.owner_slot] = true
		assert(owners.has(0) and owners.has(1))
		var saw_running := false
		while not game.remote_temporary_items.is_empty():
			for decoy in game.remote_temporary_items.values():
				var model = decoy.decoy_body.get_node("DecoyCharacter").model
				saw_running = saw_running or model.motion.gait > 0.3
			await create_timer(0.02, true).timeout
		assert(saw_running, "Mixed character decoys did not animate remotely")
		game._enter_lobby()
		assert(game.players[0].character_id == &"looper", "Leave failed to restore the local preference")
		game.choose_character(&"sockling")
		# Give the host one poll to retire this peer before reconnecting.
		await create_timer(0.15, true).timeout
		game.code_input.text = "127.0.0.1:27996"
		game._join_online()
		while not game.round_running:
			await create_timer(0.02, true).timeout
		assert(game.local_slot == 1 and game.players[1].character_id == &"sockling")
		assert(game.players[1].character_model().name == "Sockling")
		assert(game.players[0].character_id == &"sockling")
		print("CHARACTER_NETWORK client PASS: lobby changes, mixed snapshots/decoys, match lock, preference restoration, late rejoin with another character")
	game._prepare_session()
	for player in game.players:
		for audio_player in player.sfx_players: audio_player.stop()
	game.queue_free()
	await process_frame
	quit()
