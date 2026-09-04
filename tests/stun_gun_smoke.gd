extends SceneTree


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	await process_frame
	await physics_frame

	var player = main.get_node("Players/PlayerOne")
	var bot = main.get_node("Players/PlayerTwo")
	var spawner = main.get_node("Arena/PowerUpSpawner")
	var jump_obstacle = main.get_node("Arena/ObstacleWest")
	bot.ai_controlled = false
	bot.global_position = Vector3(jump_obstacle.global_position.x, 0.05, jump_obstacle.global_position.z - 1.25)
	bot.reset_movement_state()
	for _frame in 12:
		await physics_frame
		if bot.is_on_floor():
			break
	bot.ai_cached_direction = Vector2(0.0, 1.0)
	if not bot._should_ai_jump():
		push_error("Bot jump check failed: on_floor=%s bot=%s obstacle=%s" % [bot.is_on_floor(), bot.global_position, jump_obstacle.global_position])
		quit(1)
		return
	bot.ai_controlled = true
	var first_location: Vector3 = spawner.global_position
	spawner.active_pickup._on_body_entered(player)
	# Crosshair checks deliberately equip the gun; first spawn is now random.
	player.equipped_spawn_item = &"stun_gun"
	main._update_world_scoreboard()
	var crosshair: Control = main.get_node("HUD/StunCrosshair")
	if not player.has_stun_gun() or not crosshair.visible:
		push_error("Stun pickup did not equip the gun and show its crosshair")
		quit(1)
		return
	if crosshair.size.x > 20.0 or crosshair.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		push_error("Stun crosshair is oversized or intercepts mouse input")
		quit(1)
		return
	for element in crosshair.get_children():
		if element is Control and element.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			push_error("Crosshair child intercepts mouse input: %s" % element.name)
			quit(1)
			return
	var camera = main.get_node("Camera3D")
	var yaw_before: float = camera.yaw
	camera._apply_mouse_look(Vector2(24.0, 0.0))
	if is_equal_approx(camera.yaw, yaw_before):
		push_error("Mouse look did not respond while the stun crosshair was visible")
		quit(1)
		return
	var mouse_click := InputEventMouseButton.new()
	mouse_click.button_index = MOUSE_BUTTON_LEFT
	mouse_click.pressed = true
	if DisplayServer.get_name() == "headless":
		player._use_stun_gun()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player._unhandled_input(mouse_click)
	if player.has_stun_gun():
		push_error("M1 did not fire and consume the stun gun")
		quit(1)
		return
	main._update_world_scoreboard()
	if crosshair.visible:
		push_error("Crosshair remained visible after the gun was spent")
		quit(1)
		return
	bot.apply_stun(0.2)

	var crown: Node3D = main.get_node("Arena/IslandDisplay/WinnerCrown")
	main.scores[0] = 3.0
	main.scores[1] = 1.0
	crown.visible = false
	main._update_world_scoreboard()
	if not crown.visible or not is_equal_approx(crown.position.x, main.get_node("Arena/IslandDisplay/YouScoreBar").position.x):
		push_error("Crown did not appear over the leading player score line")
		quit(1)
		return
	main.scores[0] = 1.0
	main.scores[1] = 3.0
	crown.visible = false
	main._update_world_scoreboard()
	if not crown.visible or not is_equal_approx(crown.position.x, main.get_node("Arena/IslandDisplay/BotScoreBar").position.x):
		push_error("Crown did not switch to the bot score line")
		quit(1)
		return
	main.scores[0] = 2.0
	main.scores[1] = 2.0
	main._update_world_scoreboard()
	if crown.visible:
		push_error("Crown remained visible during a tie")
		quit(1)
		return

	spawner._spawn_pickup()
	if spawner.global_position == first_location:
		push_error("Power-up spawner repeated its previous location")
		quit(1)
		return
	if not spawner.ITEM_POOL.has(spawner.active_pickup.item_type):
		push_error("Spawner drew an item outside the random pool")
		quit(1)
		return
	if spawner.ITEM_POOL.size() != 11 or spawner.ITEM_POOL.has(&"chair_cannon") or not spawner.ITEM_POOL.has(&"stun_gun"):
		push_error("Random pool must contain eleven items without the chair cannon")
		quit(1)
		return
	for _draw in 100:
		if not spawner.ITEM_POOL.has(spawner._draw_random_item()):
			push_error("Random draw returned an invalid item")
			quit(1)
			return
	spawner.active_pickup._on_body_entered(player)
	if not player.has_spawn_item():
		push_error("Relocated power-up could not be collected")
		quit(1)
		return
	player.equipped_spawn_item = &""

	player.try_pickup_item(&"air_horn")
	if not is_equal_approx(player.air_horn_impulse, 75.0):
		push_error("Air horn impulse was not increased")
		quit(1)
		return
	player._use_equipped_spawn_item()
	var player_before_swap: Vector3 = player.global_position
	var bot_before_swap: Vector3 = bot.global_position
	player.set_physics_process(false)
	bot.set_physics_process(false)
	player.global_position = Vector3(-6.0, 0.05, 2.0)
	bot.global_position = Vector3(-6.0, 0.05, -1.0)
	player.network_controlled = true
	player.network_aim_forward = (bot.global_position + Vector3.UP - player._get_aim_origin()).normalized()
	await physics_frame
	await physics_frame
	player_before_swap = player.global_position
	bot_before_swap = bot.global_position
	player.try_pickup_item(&"swap_bell")
	player._use_equipped_spawn_item()
	if player.global_position != bot_before_swap or bot.global_position != player_before_swap:
		push_error("Swap bell did not exchange player positions")
		quit(1)
		return
	player.network_controlled = false
	player.set_physics_process(true)
	bot.set_physics_process(true)
	bot.ai_controlled = false
	bot.try_pickup_item(&"invisibility")
	bot._use_equipped_spawn_item()
	if not bot.is_invisible() or bot.body_mesh.visible or bot.name_label.visible:
		push_error("Invisibility did not hide the player visuals")
		quit(1)
		return
	bot.set_network_invisibility(0.0)
	if not bot.body_mesh.visible:
		push_error("Player visuals did not return after invisibility")
		quit(1)
		return
	bot.ai_controlled = true
	player.set_network_invisibility(5.0)
	bot.ai_cached_direction = Vector2.ONE
	bot.ai_think_remaining = 1.0
	if bot._read_movement_input(0.01) != Vector2.ZERO or bot._calculate_ai_direction() != Vector2.ZERO:
		push_error("Bot tracked an invisible player")
		quit(1)
		return
	player.set_network_invisibility(0.0)
	player.global_position = Vector3(0.0, -4.0, 0.0)
	main.token_holder = 0
	main._set_token_holder(0)
	main._on_kill_box_body_entered(player)
	if main.token_holder != 1 or player.has_token or not bot.has_token:
		push_error("Falling holder did not forfeit the spark")
		quit(1)
		return
	main._on_kill_box_body_entered(player)
	if main.token_holder != 1:
		push_error("Falling non-holder changed spark ownership")
		quit(1)
		return
	if player.global_position != main.PLAYER_SPAWNS[0]:
		push_error("Kill box did not return the player to their spawn")
		quit(1)
		return
	player.movement_history.clear()
	player.movement_history.append({"position": Vector3(6.0, 0.05, 4.2), "velocity": Vector3(1.0, 0.0, 0.0)})
	player.try_pickup_item(&"rewind_watch")
	player._use_equipped_spawn_item()
	if player.global_position != Vector3(6.0, 0.05, 4.2):
		push_error("Rewind watch did not restore its recorded position")
		quit(1)
		return
	player.try_pickup_item(&"emergency_door")
	player._use_equipped_spawn_item()
	var found_doors := false
	for temporary_item in get_nodes_in_group("temporary_item"):
		if temporary_item.has_node("Entry") and temporary_item.has_node("Exit"):
			found_doors = true
	if not found_doors:
		push_error("Emergency door did not create a linked pair")
		quit(1)
		return
	await create_timer(0.3).timeout
	main.queue_free()
	await process_frame
	quit(0)
