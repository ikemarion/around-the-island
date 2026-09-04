extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var args := OS.get_cmdline_user_args()
	var host := "--ati-host-local" in args or "--chaos-host" in args
	if "--chaos-host" in args:
		main._prepare_session()
		main.session_mode = &"hosting"
		main.peer_to_slot = {1: 0}
		main.network_session.host_room(27995, false)
	elif "--chaos-client" in args:
		main.code_input.text = "127.0.0.1:27995"
		main._join_online()
	var created := false
	for _attempt in 200:
		await create_timer(0.05, true).timeout
		if host and created and main.active_slots.count(true) == 1:
			break
		if host and main.session_mode == &"hosting" and main.active_slots.count(true) >= 2:
			main._start_hosted_game()
		if host and main.session_mode == &"host" and not created:
			created = true
			for kind in [&"decoy_double", &"magnet_mayhem", &"pocket_wall", &"hot_potato", &"bungee_hook"]:
				var effect = load("res://scripts/chaos_effect.gd").new()
				main.add_child(effect)
				effect.setup(kind, main.players[0], main.players[1])
				effect.set_physics_process(false)
		if not host and main.session_mode == &"client":
			var kinds := {}
			for effect in main.remote_temporary_items.values():
				if effect.has_method("network_state"):
					kinds[effect.kind] = true
			if kinds.size() == 5:
				print("CHAOS_NETWORK all five effects replicated")
				main._prepare_session()
				quit(0)
				return
	if host and created:
		print("CHAOS_NETWORK host created all five effects")
		main._prepare_session()
		quit(0)
	else:
		push_error("CHAOS_NETWORK timeout")
		quit(1)
