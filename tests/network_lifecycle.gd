extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var host := "--lifecycle-host" in OS.get_cmdline_user_args()
	if host:
		main._prepare_session()
		main.session_mode = &"hosting"
		main.peer_to_slot = {1: 0}
		main.network_session.host_room(27992, false)
		for attempt in 2:
			while main.active_slots.count(true) < 2:
				await create_timer(0.05, true).timeout
			check(not main.players[1].ai_controlled and not main.players[1].has_spawn_item(), "Slot not clean on join")
			if attempt == 0:
				await create_timer(0.5, true).timeout
				check(not main.round_running and main.lobby.visible, "Match auto-started before host pressed Start")
				main._start_hosted_game()
				check(main.round_running and not main.lobby.visible, "Host Start did not begin match")
			for kind in [&"decoy_double", &"magnet_mayhem", &"pocket_wall", &"hot_potato", &"bungee_hook"]:
				var effect = load("res://scripts/chaos_effect.gd").new()
				main.add_child(effect)
				effect.setup(kind, main.players[0], main.players[1])
			main.players[1].equipped_spawn_item = &"invisibility"
			while main.active_slots.count(true) > 1:
				await create_timer(0.05, true).timeout
			check(main.players[1].equipped_spawn_item == &"" and main.players[1].held_chair == null, "Disconnect failed cleanup")
		print("NETWORK_LIFECYCLE host: two joins/disconnects clean")
	else:
		for attempt in 2:
			main.code_input.text = "127.0.0.1:27992"
			main._join_online()
			while main.session_mode != &"client":
				await create_timer(0.01, true).timeout
			if attempt == 0:
				check(main.lobby.visible and paused and not main.round_running, "Joining player bypassed waiting room")
			while main.session_mode != &"client" or not main.players[main.local_slot].has_spawn_item():
				await create_timer(0.05, true).timeout
			check(main.local_slot == 1 and main.camera.target == main.players[1], "Wrong slot/camera after rejoin")
			await create_timer(0.3, true).timeout
			check(main.remote_temporary_items.size() >= 5, "Late-join effects missing")
			var event := InputEventKey.new()
			event.physical_keycode = KEY_Q
			event.pressed = true
			Input.parse_input_event(event)
			await create_timer(0.1, true).timeout
			event.pressed = false
			Input.parse_input_event(event)
			await create_timer(0.25, true).timeout
			check(main.players[1].is_invisible(), "Client quick action failed")
			main._enter_lobby()
			await create_timer(0.4, true).timeout
		print("NETWORK_LIFECYCLE client: rejoin, effects and quick action passed")
	main._prepare_session()
	main.queue_free()
	await process_frame
	quit()

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
