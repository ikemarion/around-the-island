extends SceneTree

func _initialize() -> void:
	call_deferred("run")
	create_timer(25.0).timeout.connect(func():
		push_error("KITCHEN_MENU timeout")
		quit(1))

func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	root.push_input(event)

func controller_event(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	root.push_input(event)

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
	assert(ui.skin_buttons.size() == 2 and ui.skin_buttons[0].is_visible_in_tree() and ui.skin_buttons[1].is_visible_in_tree())
	assert(ui.skin_buttons[0].button_pressed and not ui.skin_buttons[1].button_pressed)
	ui.skin_buttons[0].grab_focus()
	key_event(KEY_RIGHT, true)
	key_event(KEY_RIGHT, false)
	assert(root.gui_get_focus_owner() == ui.skin_buttons[1], "Keyboard cannot focus the second skin")
	key_event(KEY_ENTER, true)
	key_event(KEY_ENTER, false)
	assert(main.preferred_character == &"looper" and ui.skin_buttons[1].button_pressed and not ui.skin_buttons[0].button_pressed)
	await process_frame
	controller_event(JOY_BUTTON_DPAD_LEFT, true)
	controller_event(JOY_BUTTON_DPAD_LEFT, false)
	assert(root.gui_get_focus_owner() == ui.skin_buttons[0], "Controller cannot focus the first skin")
	controller_event(JOY_BUTTON_A, true)
	await process_frame
	controller_event(JOY_BUTTON_A, false)
	await process_frame
	assert(main.preferred_character == &"sockling" and ui.skin_buttons[0].button_pressed)
	await capture("kitchen-host-options")
	ui.skin_buttons[1].pressed.emit()
	assert(main.preferred_character == &"looper" and main.players[0].character_id == &"looper")
	await capture("kitchen-looper-selected")
	main.session_mode = &"joining"
	main.connection_started_ms = Time.get_ticks_msec()
	main.connection_stage = "Contacting host"
	main._process(0)
	assert(main.menu_controls.Progress.visible and main.menu_controls.Back.visible)
	assert(not ui.home_actions.visible)
	assert(ui.skin_buttons[0].disabled and ui.skin_buttons[1].disabled)
	ui.skin_buttons[0].pressed.emit()
	assert(main.preferred_character == &"looper", "Connecting state accepted a skin change")
	await capture("kitchen-connecting")
	main.connection_started_ms = 0
	main.session_mode = &"client"
	main.local_slot = 2
	main._receive_roster([true, true, true, false], 1)
	main._process(0)
	assert(ui.seats[2].name.text == "You" and ui.seats[0].role.text == "Host")
	assert(ui.seats[2].portrait.player_color == main.CHARACTER_CATALOG.color_for(&"sockling", 2))
	assert(main.menu_controls.Start.visible and not main.menu_controls.Start.disabled)
	assert(not ui.skin_buttons[0].disabled and not ui.skin_buttons[1].disabled)
	await capture("kitchen-joiner")
	main.session_mode = &"hosting"
	main.local_slot = 0
	main.active_slots.assign([true, false, false, false])
	main._process(0)
	assert(main.menu_controls.Start.disabled)
	ui.skin_buttons[0].pressed.emit()
	assert(main.preferred_character == &"sockling" and main.players[0].character_id == &"sockling")
	main.active_slots[1] = true
	main._process(0)
	assert(not main.menu_controls.Start.disabled)
	main.menu_controls.Start.pressed.emit()
	assert(main.round_running and not main.lobby.visible)
	ui.refresh()
	assert(ui.skin_buttons[0].disabled and ui.skin_buttons[1].disabled)
	ui.skin_buttons[1].pressed.emit()
	assert(main.preferred_character == &"sockling", "Running match accepted a skin change")
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
	print("KITCHEN_MENU passed: clear two-skin buttons, keyboard/controller selection, connecting/match locks, host, roster, start, small window")
	quit()
