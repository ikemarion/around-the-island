extends SceneTree

# Run as a localhost pair with --network-audit-host / --network-audit-client.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--network-audit-host") and not args.has("--network-audit-client"):
		push_error("Use the host and client roles together")
		quit(1)
		return
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._prepare_session()
	# Never upload a real player's prior connection reports during a fixture.
	main.network_diagnostics.directory = "res://build/network-test/network-audit-%d" % OS.get_process_id()
	var host := args.has("--network-audit-host")
	if host:
		main.session_mode = &"hosting"
		main.peer_to_slot = {1:0}
		main.network_session.host_room(27996, false)
	else:
		await create_timer(0.4, true).timeout
		main.code_input.text = "127.0.0.1:27996"
		main._join_online()
	var deadline := Time.get_ticks_msec() + 15000
	while (main.active_slots.count(true) < 2 if host else main.session_mode != &"client") and Time.get_ticks_msec() < deadline:
		await create_timer(0.1, true).timeout
	if Time.get_ticks_msec() >= deadline:
		check(false, "Localhost admission timed out")
	else:
		if host:
			await create_timer(8.5, true).timeout
			check(not main.round_running and main.session_mode == &"hosting", "Lobby started unexpectedly")
			check(not main.network_diagnostics.peer_stats.is_empty(), "Admitted waiting client probes were ignored")
			main._start_hosted_game()
			await create_timer(3.0, true).timeout
		else:
			await create_timer(7.0, true).timeout
			check(main.waiting_for_start and main.network_diagnostics.rtt_ms >= 0, "Waiting lobby never measured a round trip")
			# Probes are deliberately unreliable: require an actual lobby reply,
			# not zero transport losses under every scheduler/network condition.
			print("NETWORK_AUDIT_LOBBY waiting RTT=", main.network_diagnostics.rtt_ms,
				" misses=", main.network_diagnostics.unanswered_probes)
			deadline = Time.get_ticks_msec() + 5000
			while not main.round_running and Time.get_ticks_msec() < deadline:
				await create_timer(0.1, true).timeout
			check(main.round_running, "Host start did not reach client")
			if main.round_running:
				var player = main.players[main.local_slot]
				player.remote_held_name = "Chair"
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				Input.parse_input_event(click)
				Input.flush_buffered_events()
				main._send_local_input()
				player._update_client_highlight()
				main._process(0)
				check(main.local_buttons[3] and player.network_throw_pressed, "Guest throw-held state was discarded locally")
				check(player.charging_throw and player.throw_charge > 0 and main.obstacle_hint.text.begins_with("THROW POWER"), "Guest throw charge cue missing")
				var release := click.duplicate()
				release.pressed = false
				Input.parse_input_event(release)
				Input.flush_buffered_events()
				main._send_local_input()
				player._update_client_highlight()
				check(not player.charging_throw and player.throw_charge == 0, "Guest throw charge did not clear on release")
				await create_timer(1.0, true).timeout
				print("NETWORK_AUDIT_LOBBY match RTT=", main.network_diagnostics.rtt_ms,
					" misses=", main.network_diagnostics.unanswered_probes)
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("NETWORK_AUDIT_LOBBY ", "host" if host else "client", " failures=", failures)
	quit(1 if failures else 0)
