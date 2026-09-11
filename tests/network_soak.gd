extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var host := "--soak-host" in OS.get_cmdline_user_args()
	main._prepare_session()
	if host:
		main.session_mode = &"hosting"
		main.peer_to_slot = {1:0}
		main.network_session.host_room(27994,false)
	else:
		await create_timer(1.0,true).timeout
		main.code_input.text = "127.0.0.1:27994"
		main._join_online()
	var deadline := Time.get_ticks_msec()+20000
	while (main.active_slots.count(true)<4 if host else not main.round_running) and Time.get_ticks_msec()<deadline:
		if host and main.active_slots.count(true)==4:
			break
		await create_timer(0.1,true).timeout
	if host:
		if not require(main.active_slots.count(true)==4,"SOAK: four players did not join"):
			return
		main._start_hosted_game()
	elif not require(main.session_mode==&"client" and main.round_running,"SOAK: client failed to start"):
		return
	var start := Time.get_ticks_msec()
	var rounds := 1
	while Time.get_ticks_msec()-start<180000:
		await create_timer(0.5,true).timeout
		if not require(main.session_mode == (&"host" if host else &"client"),"SOAK: disconnected during play"):
			return
		if host:
			if not require(main.multiplayer.get_peers().size()==3,"SOAK: host lost a peer"):
				return
			if not main.round_running:
				main.reset_round()
				rounds += 1
		else:
			if not require(Time.get_ticks_msec()-main.network_diagnostics.last_snapshot_ms<5000,"SOAK: snapshots stalled"):
				return
	if host:
		# Let clients finish their slightly later observation windows.
		await create_timer(2.0,true).timeout
	print("NETWORK_SOAK PASS role=", "host" if host else "client", " seconds=180 rounds=",rounds," rtt_ms=",main.network_diagnostics.rtt_ms)
	main._prepare_session()
	quit()
