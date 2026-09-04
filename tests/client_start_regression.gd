extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var host := "--start-host" in OS.get_cmdline_user_args()
	if host:
		main._prepare_session()
		main.session_mode = &"hosting"
		main.peer_to_slot = {1:0}
		main.network_session.host_room(27996, false)
		# A local/unadmitted sender must not start a lobby.
		main._request_match_start()
		assert(not main.round_running)
	else:
		main.code_input.text = "127.0.0.1:27996"
		main._join_online()
	for tick in 400:
		await create_timer(0.02, true).timeout
		if not host and main.session_mode == &"client" and main.active_slots.count(true) >= 2 and main.waiting_for_start:
			main.kitchen_menu.refresh()
			assert(main.menu_controls.Start.visible and not main.menu_controls.Start.disabled)
			main.menu_controls.Start.pressed.emit()
		if main.round_running: break
	assert(main.round_running and not main.lobby.visible and not paused)
	assert(main.round_epoch == 1)
	if not host:
		main._request_match_start.rpc_id(1)
	await create_timer(0.4, true).timeout
	assert(main.round_epoch == 1)
	print("CLIENT_START passed: ", "host validation and single start" if host else "client button and gameplay transition")
	if host: await create_timer(1.0, true).timeout
	main._prepare_session()
	main.queue_free()
	await process_frame
	quit()
