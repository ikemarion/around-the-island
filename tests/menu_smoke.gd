extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._enter_lobby()
	await process_frame
	await process_frame
	assert(main.lobby.visible and paused)
	assert(not main.get_node("HUD").visible)
	assert(not main.menu_controls.Join.disabled)
	assert(not main.code_input.visible)
	main._start_hosted_game()
	assert(not main.round_running)
	main._start_solo()
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	main._input(escape)
	assert(main.session_menu.visible and main.players[0].input_suspended)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/session-menu.png")
	main._input(escape)
	assert(not main.session_menu.visible and not main.players[0].input_suspended)
	main._enter_lobby()
	main.session_mode = &"joining"
	main.connection_started_ms = Time.get_ticks_msec() - 16000
	main._process(0.016)
	assert(main.session_mode == &"lobby" and "timed out" in main.lobby_status.text)
	main._enter_lobby()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/menu-home.png")
	main.session_mode = &"hosting"
	main.waiting_for_start = true
	main.hosted_room_code = "jakarta-oki.tun.ply.gg:23862"
	main.room_code_label.text = main.hosted_room_code
	main.active_slots.assign([true, true, true, false])
	main.lobby_status.text = "Share the address, then start when everyone is here."
	await process_frame
	await process_frame
	assert(not main.menu_controls.Start.disabled)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/menu-room.png")
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("MENU_SMOKE passed")
	quit()
