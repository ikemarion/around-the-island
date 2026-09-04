extends SceneTree

class JoinSpy extends RefCounted:
	var address := ""
	var attempts := 0
	func close_session() -> void:
		pass
	func join_room(value: String) -> void:
		address = value
		attempts += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._enter_lobby()
	var network = main.network_session
	var spy := JoinSpy.new()
	main.network_session = spy
	main.code_input.text = "stale-address:1234"
	main._process(0)
	assert(not main.menu_controls.Join.disabled and not main.code_input.visible)
	main.menu_controls.Join.pressed.emit()
	assert(spy.address == "jakarta-oki.tun.ply.gg:23862" and spy.attempts == 1)
	assert(main.session_mode == &"joining")
	main._process(0)
	assert(main.menu_controls.Progress.visible and main.menu_controls.Back.visible)
	main.menu_controls.Join.pressed.emit()
	assert(spy.attempts == 1)
	main.menu_controls.Back.pressed.emit()
	assert(main.session_mode == &"lobby")
	main._process(0)
	assert(not main.menu_controls.Join.disabled)
	main.menu_controls.Join.pressed.emit()
	assert(spy.attempts == 2)
	main.connection_started_ms = Time.get_ticks_msec() - 16000
	main._process(0)
	assert(main.session_mode == &"lobby" and "timed out" in main.lobby_status.text)
	main.network_session = network
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("DEFAULT_JOIN passed: destination, click, duplicate guard, cancel, retry, timeout")
	quit()
