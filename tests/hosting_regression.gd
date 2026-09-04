extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._enter_lobby()
	assert(main.session_mode == &"lobby" and not main.round_running)
	main.instance_blocked = true
	main.menu_controls.Host.pressed.emit()
	main.menu_controls.Join.pressed.emit()
	main.menu_controls.Solo.pressed.emit()
	assert(main.session_mode == &"lobby")
	main.instance_blocked = false
	# A second listener must fail visibly, without disturbing the first.
	var occupied := ENetMultiplayerPeer.new()
	assert(occupied.create_server(27998,3,3) == OK)
	main.session_mode = &"hosting"
	main.network_session.host_room(27998,false)
	assert(main.session_mode == &"lobby")
	assert("Lobby NOT opened" in main.lobby_status.text)
	assert(main.lobby_id.is_empty())
	assert(occupied.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	occupied.close()
	var ids: Array[String] = []
	for attempt in 3:
		main._prepare_session()
		main.session_mode = &"hosting"
		main.network_session.host_room(27998,false)
		assert(main.session_mode == &"hosting" and main.connection_started_ms == 0)
		assert(not main.lobby_id.is_empty())
		assert(not ids.has(main.lobby_id))
		ids.append(main.lobby_id)
		main.kitchen_menu.refresh()
		assert(main.menu_controls.Start.disabled)
		assert(main.menu_controls.Back.text == "Close lobby for everyone")
		main.menu_controls.Back.pressed.emit()
		assert(main.session_mode == &"lobby")
		assert(main.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	# Joining UI only reflects the server's admitted roster and ID.
	main._assign_slot(2,"ABC123")
	main._receive_roster([true,false,true,false],1)
	main.kitchen_menu.refresh()
	assert(main.menu_controls.Start.visible and not main.menu_controls.Start.disabled)
	assert(main.menu_controls.RoomCode.text == "LOBBY ABC123")
	assert(main.kitchen_menu.seats[2].name.text == "You")
	main.start_requested_ms = Time.get_ticks_msec()-5100
	main._process(0)
	assert(main.start_requested_ms == 0 and not main.menu_controls.Start.disabled)
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("HOSTING_REGRESSION passed: duplicate blocking, port conflict, close/rehost x3, lobby ID, client start retry")
	quit()
