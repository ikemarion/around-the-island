extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/" + filename + ".png")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._enter_lobby()
	var ui = main.kitchen_menu
	main._process(0)
	assert(main.menu_controls.Host.is_visible_in_tree() and main.menu_controls.Join.is_visible_in_tree())
	assert(not main.menu_controls.TunnelHost.is_visible_in_tree())
	await capture("kitchen-host-options")
	main.session_mode = &"joining"
	main.connection_started_ms = Time.get_ticks_msec()
	main.connection_stage = "Contacting host"
	main._process(0)
	assert(main.menu_controls.Progress.visible and main.menu_controls.Back.visible)
	assert(not ui.home_actions.visible)
	await capture("kitchen-connecting")
	main.connection_started_ms = 0
	main.session_mode = &"client"
	main.local_slot = 2
	main._receive_roster([true, true, true, false], 1)
	main._process(0)
	assert(ui.seats[2].name.text == "You" and ui.seats[0].role.text == "Host")
	assert(ui.seats[2].portrait.player_color == main.PLAYER_COLORS[2])
	assert(main.menu_controls.Start.visible and not main.menu_controls.Start.disabled)
	await capture("kitchen-joiner")
	main.session_mode = &"hosting"
	main.local_slot = 0
	main.active_slots.assign([true, false, false, false])
	main._process(0)
	assert(main.menu_controls.Start.disabled)
	main.active_slots[1] = true
	main._process(0)
	assert(not main.menu_controls.Start.disabled)
	main.menu_controls.Start.pressed.emit()
	assert(main.round_running and not main.lobby.visible)
	main._enter_lobby()
	root.content_scale_size = Vector2i(800, 600)
	root.size = Vector2i(800, 600)
	await capture("kitchen-small")
	var panel: Control = main.get_node("Lobby/Panel")
	var bounds := Rect2(panel.position, panel.size * panel.scale)
	assert(bounds.position.x >= 0 and bounds.position.y >= 0)
	assert(bounds.end.x <= root.get_visible_rect().size.x + 1 and bounds.end.y <= root.get_visible_rect().size.y + 1)
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("KITCHEN_MENU passed: host, joining, roster, start, small window")
	quit()
