extends SceneTree
## Used with the exported build as well as the editor runtime.
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, detail: String) -> void:
	if not value:
		failed = true
		print("HOSTING_E2E FAIL ",detail)

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._enter_lobby()
	var args := OS.get_cmdline_user_args()
	var host := args.has("--flow-host")
	if args.has("--flow-overflow"):
		main.menu_controls.Join.pressed.emit()
		for tick in 300:
			await create_timer(0.02,true).timeout
			if main.session_mode == &"client": failed = true
		print("HOSTING_E2E ","FAIL" if failed else "PASS"," full room fifth client not admitted")
		main._prepare_session()
		main.queue_free()
		await process_frame
		quit(1 if failed else 0)
		return
	if host:
		main.menu_controls.Host.pressed.emit()
		check(main.session_mode == &"hosting", "host button did not open listener")
	else:
		if args.has("--flow-local"):
			main.code_input.text = "127.0.0.1:27888"
			main._join_online()
		else:
			main.menu_controls.Join.pressed.emit()
	var began := Time.get_ticks_msec()
	while main.active_slots.count(true) < 4 and Time.get_ticks_msec()-began < 18000:
		await create_timer(0.02,true).timeout
	check(main.active_slots.count(true)==4,"four players did not join")
	check(not main.round_running and main.lobby.visible,"lobby should wait for Start")
	check(not main.lobby_id.is_empty(),"missing lobby ID")
	print("HOSTING_E2E ROSTER ",JSON.stringify({"id":main.lobby_id,"slot":main.local_slot,"count":main.active_slots.count(true),"host":host}))
	# Allow the separate fifth-client probe to exercise a full room.
	await create_timer(9.0,true).timeout
	if not host and main.local_slot==1:
		main.kitchen_menu.refresh()
		check(main.menu_controls.Start.visible and not main.menu_controls.Start.disabled,"client Start button")
		main.menu_controls.Start.pressed.emit()
	for tick in 500:
		if main.round_running: break
		await create_timer(0.02,true).timeout
	check(main.round_running and not main.lobby.visible and not paused,"client-start transition")
	check(main.round_epoch==1,"duplicate start restarted match")
	if host:
		await create_timer(2.0,true).timeout
		main.time_remaining = 0.001
		await create_timer(0.5,true).timeout
		check(not main.round_running,"round did not end")
		main.reset_round()
		await create_timer(2.0,true).timeout
		main.menu_controls.Back.pressed.emit()
		check(main.session_mode==&"lobby","close host did not return home")
		# Socket must be reusable immediately from the same Host button.
		main.menu_controls.Host.pressed.emit()
		check(main.session_mode==&"hosting","rehost failed")
		print("HOSTING_E2E REHOST ",main.lobby_id)
		for tick in 600:
			if main.active_slots.count(true)==4: break
			await create_timer(0.02,true).timeout
		check(main.active_slots.count(true)==4 and not main.round_running,"clients did not rejoin fresh lobby")
		await create_timer(1.0,true).timeout
	else:
		for tick in 700:
			if main.round_epoch==2 and main.round_running: break
			await create_timer(0.02,true).timeout
		check(main.round_epoch==2 and main.round_running,"rematch did not arrive")
		for tick in 700:
			if main.session_mode==&"lobby": break
			await create_timer(0.02,true).timeout
		check(main.session_mode==&"lobby","host closure did not return client home")
		await create_timer(0.4,true).timeout
		main.menu_controls.Join.pressed.emit()
		for tick in 600:
			if main.session_mode==&"client" and main.active_slots.count(true)==4: break
			await create_timer(0.02,true).timeout
		check(main.session_mode==&"client" and main.active_slots.count(true)==4 and main.waiting_for_start,"fresh lobby rejoin")
		check(main.round_epoch==0,"old round state carried into new lobby")
		print("HOSTING_E2E REJOIN ",main.lobby_id)
	print("HOSTING_E2E ","FAIL" if failed else "PASS"," host=",host)
	main._prepare_session()
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)
