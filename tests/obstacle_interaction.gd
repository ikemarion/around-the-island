extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.set_physics_process(false)
	main.set_process(false)
	for p in main.players:
		p.set_physics_process(false)
	var p = main.players[0]
	var chair = get_nodes_in_group("shoveable")[0]
	p.network_controlled = true
	p.network_interact_pressed = true
	p.network_aim_forward = Vector3.FORWARD
	p.global_position = Vector3(-6, 0.1, 3)
	chair.global_position = Vector3(-6, 1, 1.5)
	p._grab_chair(chair)
	check(chair.holder == p, "Grab must claim the obstacle")
	check(not chair.try_claim(main.players[1]), "Other players cannot steal a held obstacle")
	p.network_throw_pressed = true
	p.action_throw = true
	p._update_chair_interaction()
	check(p.held_chair == chair and p.charging_throw, "Press must charge, not immediately throw")
	p.action_throw = false
	p.throw_charge = p.throw_charge_seconds
	p.network_throw_pressed = false
	p._update_chair_interaction()
	check(p.held_chair == null and chair.holder == null, "Release must throw and clear ownership")
	check(chair.launch_time > 0.0, "Throw must use launch speed allowance")
	check(not p.charging_throw and p.throw_charge == 0.0, "Throw must clear charge state")
	p._grab_chair(chair)
	p.charging_throw = true
	p.throw_charge = 0.5
	p._release_chair()
	check(not p.charging_throw and p.throw_charge == 0.0, "Drop/reset must cancel charge")
	check(not p.get_collision_exceptions().has(chair), "Release must restore player collisions")
	check(p.obstacle_shove_impulse == 15.0, "Push/pull must use the reduced three-times-original impulse")
	check(not p.try_pickup_item(&"bungee_hook"), "Bungee must not be available")
	check(not load("res://scripts/item_spawner.gd").ITEM_POOL.has(&"bungee_hook"), "Bungee must not spawn")
	p.equipped_spawn_item = &""
	p.action_quick = true
	var children_before: int = main.get_child_count()
	p._update_quick_item()
	check(main.get_child_count() == children_before, "Empty quick action must not spawn slick trap")
	check(p.get_quick_item_name() == "NO POWER-UP", "Empty HUD must not advertise slick trap")
	p.network_interact_pressed = false
	p.action_throw = false
	p.action_pull = true
	chair.launch_time = 0.0
	await physics_frame
	p._update_chair_interaction()
	check(chair.launch_time > 0.0, "Network pull action must launch targeted prop")
	print("OBSTACLE_INTERACTION failures=", failures)
	quit(1 if failures else 0)
