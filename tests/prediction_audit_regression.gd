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
	var player = main.players[0]
	player.client_predicted = true
	player.network_controlled = true
	player.replica_target_ready = true
	player.motion_epoch = 50
	player.global_position = Vector3(4, 0.05, 3)
	player.velocity = Vector3(6, 0, 0)
	player.slide_time_remaining = 0.6
	player.prediction_history[10] = {"position":Vector3(0, 0.05, 3), "velocity":Vector3(2, 0, 0)}
	var state := {"position":Vector3(0.2, 0.05, 3), "velocity":Vector3(2, 0, 0), "motion_epoch":50, "ack":10}
	player.apply_authoritative_motion(state)
	check(player.global_position.is_equal_approx(Vector3(4.2, 0.05, 3)), "First ACK must reconcile against its predicted history")
	player.global_position.x += 0.2
	var before: Vector3 = player.global_position
	player.apply_authoritative_motion(state)
	check(player.global_position.is_equal_approx(before) and player.slide_time_remaining == 0.6, "Repeated ACK rewound prediction or cancelled slide")
	var stale := state.duplicate()
	stale.ack = 9
	stale.position = Vector3(90, 1, 0)
	player.apply_authoritative_motion(stale)
	check(player.global_position.is_equal_approx(before), "Stale ACK overwrote newer prediction")
	player.prediction_history[11] = {"position":Vector3(1, 0.05, 3), "velocity":Vector3(2, 0, 0)}
	state.ack = 11
	state.position = Vector3(1.2, 0.05, 3)
	player.apply_authoritative_motion(state)
	check(player.global_position.is_equal_approx(before + Vector3(0.2, 0, 0)), "Next new ACK must still reconcile")
	player.last_authoritative_ack_ms = Time.get_ticks_msec() - player.REPEATED_ACK_GRACE_MS - 1
	player.apply_authoritative_motion(state)
	check(player.global_position.is_equal_approx(state.position), "Stalled uplink exceeded bounded prediction grace")
	state.motion_epoch = 51
	state.position = Vector3(-6, 0.05, 3)
	state.velocity = Vector3(20, 4, 0)
	player.apply_authoritative_motion(state)
	check(player.global_position.is_equal_approx(state.position) and player.velocity.is_equal_approx(state.velocity), "Same-ACK authoritative impulse/teleport must bypass grace")
	state.ack = 200
	state.position = Vector3(-5, 0.05, 3)
	player.apply_authoritative_motion(state)
	check(player.global_position.is_equal_approx(state.position), "New ACK outside retained history must rebase")
	player.reset_movement_state()
	check(player.last_authoritative_ack == -1 and player.last_authoritative_ack_ms == 0, "Session/round reset retained ACK baseline")
	var authority = main.players[1]
	authority.simulated_sequence = 12
	authority.slide_time_remaining = 0.6
	authority.slide_direction = Vector2.RIGHT
	player.motion_epoch = authority.motion_epoch
	player.replica_target_ready = true
	player.last_authoritative_ack = authority.simulated_sequence
	player.last_authoritative_ack_ms = Time.get_ticks_msec()
	var epoch: int = authority.motion_epoch
	authority.apply_knockback(Vector3(10, 3, 0))
	check(authority.motion_epoch > epoch, "Authoritative knockback must be delivered even with an unchanged input ACK")
	player.apply_authoritative_motion(main._player_state(1))
	check(is_equal_approx(player.slide_time_remaining, authority.slide_time_remaining) and player.slide_direction.is_equal_approx(authority.slide_direction), "Mid-slide knockback cancelled only the guest slide")
	check(player.velocity.is_equal_approx(authority.velocity), "Mid-slide knockback velocity did not reach the guest")
	authority.receive_token_escape(authority.global_position - Vector3.RIGHT)
	player.apply_authoritative_motion(main._player_state(1))
	check(is_equal_approx(player.slide_time_remaining, authority.slide_time_remaining) and player.slide_direction.is_equal_approx(authority.slide_direction), "Mid-slide spark transfer cancelled only the guest slide")
	# A newer ACK beyond retained history must restore slide state too.
	authority.simulated_sequence += 1000
	player.slide_time_remaining = 0.0
	player.apply_authoritative_motion(main._player_state(1))
	check(is_equal_approx(player.slide_time_remaining, authority.slide_time_remaining), "Missing-history rebase discarded the authoritative slide")
	epoch = authority.motion_epoch
	authority.velocity = Vector3(1, 0, 0)
	authority.slide_time_remaining = 0.8
	authority.slide_direction = Vector2.RIGHT
	authority.apply_stun(2.0)
	check(authority.motion_epoch > epoch and authority.slide_time_remaining == 0.0 and authority.slide_direction == Vector2.ZERO, "Stun must retire the authority slide and advance motion epoch")
	player.apply_authoritative_motion(main._player_state(1))
	check(player.slide_time_remaining == 0.0 and player.slide_direction == Vector2.ZERO, "Authoritative stun restored a guest slide")
	authority.slide_time_remaining = 0.6
	authority.slide_direction = Vector2.RIGHT
	authority.respawn_at(Vector3(-6, 0.05, -3))
	player.apply_authoritative_motion(main._player_state(1))
	check(player.slide_time_remaining == 0.0 and player.global_position.is_equal_approx(authority.global_position), "Respawn teleport retained the old slide")
	var bounded: Dictionary = main._player_state(1)
	bounded.motion_epoch += 1
	bounded.slide_time = 999.0
	bounded.slide_direction = Vector2(3, 0)
	player.apply_authoritative_motion(bounded)
	check(player.slide_time_remaining == player.slide_duration and player.slide_direction == Vector2.RIGHT, "Restored slide state was not bounded and normalized")
	bounded.motion_epoch += 1
	bounded.slide_time = INF
	player.apply_authoritative_motion(bounded)
	check(player.slide_time_remaining == 0.0, "Nonfinite slide state was accepted")
	player.global_position = Vector3(-6, 0.05, 3)
	player.network_controlled = true
	player.client_predicted = true
	player.set_network_input(Vector2.RIGHT, Vector3.FORWARD, false, true, false, false, false)
	player.velocity = Vector3(0.1, 0, 0)
	player.slide_time_remaining = 0.6
	player.slide_direction = Vector2.RIGHT
	player.stun_time_remaining = 2.0 # Replicates snapshot assignment on a guest.
	player._physics_process(0.016)
	check(player.slide_time_remaining == 0.0 and Vector2(player.velocity.x, player.velocity.z).length() <= 0.1, "Snapshot stun regenerated minimum slide speed on a guest")
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("PREDICTION_AUDIT failures=", failures)
	quit(1 if failures else 0)
