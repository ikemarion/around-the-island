extends SceneTree
## Real session creation, raw ENet client: channel setup must not cap guest input.
## Localhost only. Throttle *limit* detects the accidental bandwidth cap without
## treating normal RTT-based throttle changes as an application failure.

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	multiplayer_poll = false
	var session := ATINetworkSession.new()
	root.add_child(session)
	session.host_room(27995, false)
	var server = root.multiplayer.multiplayer_peer
	if not server is ENetMultiplayerPeer:
		check(false, "Localhost host could not bind")
		session.queue_free()
		quit(1)
		return
	var client := ENetMultiplayerPeer.new()
	check(client.create_client("127.0.0.1", 27995, 3) == OK, "Localhost client creation failed")
	var deadline := Time.get_ticks_msec() + 3000
	while client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec() < deadline:
		server.poll()
		client.poll()
		await create_timer(0.005).timeout
	check(client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Localhost connection timed out")
	var sent := 0
	var received := 0
	var minimum_limit := float(ENetPacketPeer.PACKET_THROTTLE_SCALE)
	if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		client.set_target_peer(1)
		client.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		client.transfer_channel = 1
		var packet := PackedByteArray()
		packet.resize(120)
		deadline = Time.get_ticks_msec() + 4500
		while Time.get_ticks_msec() < deadline:
			check(client.put_packet(packet) == OK, "Guest input packet rejected")
			sent += 1
			server.poll()
			client.poll()
			while server.get_available_packet_count() > 0:
				server.get_packet()
				received += 1
			minimum_limit = minf(minimum_limit, client.get_peer(1).get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT))
			await create_timer(0.01).timeout
		check(minimum_limit == ENetPacketPeer.PACKET_THROTTLE_SCALE, "Server channel count became a guest bandwidth cap")
		check(received > 0, "Host never received guest input")
	client.close()
	session.close_session()
	session.queue_free()
	await process_frame
	print("NETWORK_BANDWIDTH sent=", sent, " received=", received, " min_limit=", minimum_limit, " failures=", failures)
	quit(1 if failures else 0)
