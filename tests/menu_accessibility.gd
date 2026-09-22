extends SceneTree

func _initialize() -> void:
	call_deferred("run")
	create_timer(25.0, true).timeout.connect(func():
		push_error("MENU_ACCESSIBILITY timeout")
		quit(1))

func pad(button: JoyButton, pressed := true, device := 0) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	event.device = device
	root.push_input(event)

func settle(main: Node) -> void:
	for frame in 6:
		main.kitchen_menu.refresh()
		await process_frame

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.players[0].joypad_id = 0
	pad(JOY_BUTTON_START, true, 1)
	assert(not main.session_menu.visible, "Unassigned controller opened menu")
	pad(JOY_BUTTON_START)
	assert(main.session_menu.visible and main.players[0].input_suspended)
	assert(not paused, "Session menu paused the running match")
	assert(root.gui_get_focus_owner() == main.session_menu.get_node("Panel/Box/Resume"))
	pad(JOY_BUTTON_START, false)
	assert(main.session_menu.visible, "Button release toggled the menu")
	pad(JOY_BUTTON_B)
	assert(not main.session_menu.visible and not main.players[0].input_suspended)
	pad(JOY_BUTTON_B, false)
	pad(JOY_BUTTON_B)
	assert(not main.session_menu.visible, "Back button opened instead of only dismissing")
	pad(JOY_BUTTON_START)
	pad(JOY_BUTTON_START, false)
	pad(JOY_BUTTON_A)
	pad(JOY_BUTTON_A, false)
	assert(not main.session_menu.visible, "Controller could not activate Resume")
	pad(JOY_BUTTON_START)
	pad(JOY_BUTTON_START, false)
	pad(JOY_BUTTON_START)
	assert(not main.session_menu.visible, "Start could not toggle menu closed")
	main._enter_lobby()
	pad(JOY_BUTTON_START)
	assert(not main.session_menu.visible, "Start opened session menu from lobby")
	main.session_mode = &"client"
	main.waiting_for_start = true
	pad(JOY_BUTTON_START)
	assert(not main.session_menu.visible, "Start bypassed the waiting room")
	main._enter_lobby()
	var ui = main.kitchen_menu
	for dimensions in [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(640, 360), Vector2i(540, 720)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		for direct in [false, true]:
			ui.direct_test.button_pressed = direct
			await settle(main)
			var panel: Control = main.get_node("Lobby/Panel")
			var viewport := root.get_visible_rect()
			assert(panel.scale.is_equal_approx(Vector2.ONE), "Menu shrank its text")
			assert(panel.position.x >= 0 and panel.position.y >= 0)
			assert(panel.get_global_rect().end.x <= viewport.end.x + 1)
			assert(panel.get_global_rect().end.y <= viewport.end.y + 1)
			assert(main.menu_controls.Join.get_theme_font_size("font_size") >= 16)
			assert(main.menu_controls.Join.size.y >= 44)
			assert(ui.size.x <= ui.scroll.size.x + 1, "Horizontal menu content clipped")
			assert(ui.grid.columns == (2 if dimensions.x < 620 else 4))
			assert(ui.body.vertical == (dimensions.x < 980))
			main.menu_controls.Solo.grab_focus()
			await settle(main)
			print("MENU_LAYOUT ", dimensions, " direct=", direct, " scroll=", ui.scroll.get_global_rect(), " focus=", main.menu_controls.Solo.get_global_rect(), " offset=", ui.scroll.scroll_vertical)
			assert(ui.scroll.get_global_rect().encloses(main.menu_controls.Solo.get_global_rect()), "Focused button did not scroll into view")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/network-test/menu-v061-%dx%d-%s.png" % [dimensions.x, dimensions.y, direct])
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("MENU_ACCESSIBILITY PASS: controller Start/Back/Resume, device guard, running match, waiting room, unscaled responsive layout, focus scrolling")
	quit()
