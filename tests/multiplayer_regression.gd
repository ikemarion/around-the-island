extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	for player in main.players:
		player.set_physics_process(false)
	await physics_frame
	var p = main.players[0]
	var other = main.players[1]
	other.ai_controlled = false
	var chair = main._sorted_obstacles()[0]
	p._grab_chair(chair)
	other._grab_chair(chair)
	check(p.held_chair == chair and other.held_chair == null, "Chair acquired twice")
	p._release_chair()
	other._grab_chair(chair)
	check(other.held_chair == chair, "Released chair not available")
	other.equipped_spawn_item = &"stun_gun"
	other.network_controlled = true
	other.network_movement_input = Vector2.ONE
	other.network_quick_item_pressed = true
	other.action_queue.append(&"quick")
	main._cleanup_slot(1)
	check(chair.holder == null and other.held_chair == null, "Disconnect retained chair")
	check(other.equipped_spawn_item == &"" and other.action_queue.is_empty() and other.network_movement_input == Vector2.ZERO, "Reused slot retained input/item")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	other.set_slot_active(true, false)
	other.network_controlled = true
	other.equipped_spawn_item = &"stun_gun"
	other._unhandled_input(click)
	check(other.has_stun_gun(), "Host mouse spent remote gun")
	other.network_controlled = false
	other.network_replica = true
	other._unhandled_input(click)
	check(other.has_stun_gun(), "Client mouse spent replica gun")
	other.network_replica = false
	other.network_controlled = true
	other.action_throw = true
	other._update_quick_item(false)
	check(not other.has_stun_gun(), "Reliable remote fire action did not consume gun")
	other.action_throw = false
	other.network_movement_input = Vector2.ONE
	other.network_interact_pressed = true
	other.last_input_ms = Time.get_ticks_msec() - 1000
	other._physics_process(0.016)
	check(other.network_movement_input == Vector2.ZERO and not other.network_interact_pressed, "Stale input not neutralized")
	main.session_mode = &"client"
	p.network_replica = true
	p.client_predicted = true
	chair.freeze = true
	main._start_solo()
	check(not p.network_replica and not p.client_predicted and not chair.freeze, "Client to solo did not restore authority")
	main.session_mode = &"client"
	p.network_replica = true
	p.client_predicted = true
	chair.freeze = true
	main._prepare_session()
	check(not p.network_replica and not p.client_predicted and not chair.freeze, "Client to hosting preparation retained replicas")
	main._start_solo()
	p.global_position = Vector3(100, -20, 100)
	main.token_holder = 0
	main._physics_process(0.016)
	check(p.global_position.y > -1 and main.token_holder == 1, "Far-out fall failed respawn/spark forfeit")
	chair.launch(Vector3(75, 10, 0))
	check(chair.launch_time > 0, "Blast safety allowance missing")
	main.active_slots.assign([true, true, true, false])
	var potato = load("res://scripts/chaos_effect.gd").new()
	main.add_child(potato)
	potato.setup(&"hot_potato", other, main.players[2])
	potato.set_physics_process(false)
	main.active_slots[1] = false
	main._cleanup_slot(1)
	potato._physics_process(0.016)
	check(not potato.is_queued_for_deletion(), "Passed potato removed with original owner")
	main.session_mode = &"client"
	main.round_epoch = 1
	main.local_slot = 0
	var state: Dictionary = main._player_state(0)
	state.position = Vector3(0, 2, 0)
	state.motion_epoch = 50
	state.ack = 1
	state.cooldown = 3.0
	state.stun = 0.5
	main._receive_player_state(0, state, 1, 10)
	check(p.global_position == state.position and p.quick_item_cooldown_remaining == 3 and p.stun_time_remaining == 0.5, "Client HUD/motion state missing")
	state.position = Vector3(90, 90, 90)
	main._receive_player_state(0, state, 1, 9)
	check(p.global_position != state.position, "Stale snapshot rewound client")
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("MULTIPLAYER_REGRESSION failures=", failures)
	quit(1 if failures else 0)
