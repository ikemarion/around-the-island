extends SceneTree
## Two real localhost peers: new art uses the unchanged pickup/inventory packets.

func _initialize() -> void:
	call_deferred("run")


func spawn_gun(spawner: Node3D) -> void:
	spawner.respawn_timer.stop()
	if is_instance_valid(spawner.active_pickup):
		spawner.active_pickup.queue_free()
	spawner.active_pickup = load("res://scenes/stun_gun_pickup.tscn").instantiate()
	spawner.add_child(spawner.active_pickup)
	spawner.active_pickup.configure(&"stun_gun", spawner.ITEM_COLORS[&"stun_gun"])
	spawner.active_pickup.collected.connect(spawner._on_pickup_collected)
	spawner.position = Vector3(0, 0, 3.7)
	spawner.saucer.set_available(true)


func run() -> void:
	create_timer(20.0, true).timeout.connect(func():
		push_error("STUN_GUN_NETWORK_ART timed out")
		quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var spawner = game.get_node("Arena/PowerUpSpawner")
	var host := "--stun-host" in OS.get_cmdline_user_args()
	if host:
		game._prepare_session()
		game.session_mode = &"hosting"
		game.peer_to_slot = {1: 0}
		game.network_session.host_room(27996, false)
		while game.active_slots.count(true) < 2:
			await create_timer(0.02, true).timeout
		game._start_hosted_game()
		game.set_physics_process(false)
		for player in game.players:
			player.set_physics_process(false)
		await process_frame
		spawn_gun(spawner)
		game._broadcast_snapshot(true)
		await create_timer(1.0, true).timeout
		spawner.active_pickup._on_body_entered(game.players[1])
		spawner.respawn_timer.stop()
		assert(game.players[1].has_stun_gun())
		game._broadcast_snapshot(true)
		await create_timer(1.0, true).timeout
		game.players[1]._use_stun_gun()
		assert(not game.players[1].has_stun_gun())
		game._broadcast_snapshot(true)
		await create_timer(1.0, true).timeout
		spawn_gun(spawner)
		game._broadcast_snapshot(true)
		while game.active_slots.count(true) > 1:
			await create_timer(0.02, true).timeout
		print("STUN_GUN_NETWORK_ART host PASS: spawn, collect, one-shot consume, respawn")
	else:
		game.code_input.text = "127.0.0.1:27996"
		game._join_online()
		while not game.round_running or not is_instance_valid(spawner.active_pickup) or spawner.active_pickup.item_type != &"stun_gun":
			await create_timer(0.02, true).timeout
		assert(game.local_slot == 1)
		assert(spawner.active_pickup.has_node("IconArt/StunGunModel"))
		assert(not spawner.active_pickup.monitoring)
		while not game.players[1].has_stun_gun():
			await create_timer(0.02, true).timeout
		assert(spawner.active_pickup == null, "Collected model stayed visible on client")
		while game.players[1].has_stun_gun():
			await create_timer(0.02, true).timeout
		while not is_instance_valid(spawner.active_pickup):
			await create_timer(0.02, true).timeout
		assert(spawner.active_pickup.item_type == &"stun_gun")
		assert(spawner.active_pickup.has_node("IconArt/StunGunModel"))
		print("STUN_GUN_NETWORK_ART client PASS: model, pickup removal, one-shot inventory, respawn via existing snapshots")
	game._prepare_session()
	game.queue_free()
	await process_frame
	quit()
