extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	for p in main.players: p.set_physics_process(false)
	var p = main.players[0]
	p.set_has_token(false)
	assert(&"double_speed" in load("res://scripts/item_spawner.gd").ITEM_POOL)
	p.equipped_spawn_item = &"double_speed"
	assert(p.get_quick_item_name() == "2× SPEED")
	p._use_equipped_spawn_item()
	assert(p.equipped_spawn_item == &"" and p.double_speed_time == 5.0)
	assert(p._chase_speed_multiplier() == 2.0)
	p.boost_time = 3.0
	assert(p._chase_speed_multiplier() == 2.0)
	p._set_crouched(true)
	assert(p._chase_speed_multiplier() == 2.0)
	p._set_crouched(false)
	p.set_has_token(true)
	assert(is_equal_approx(p._chase_speed_multiplier(),1.86))
	assert(main._player_state(0).double_speed == 5.0)
	p._physics_process(5.1)
	assert(p.double_speed_time == 0.0 and is_equal_approx(p._chase_speed_multiplier(),0.93))
	p.double_speed_time = 5
	p.respawn_at(Vector3(5,0.05,3))
	assert(p.double_speed_time == 0.0)
	p.double_speed_time = 5
	p.reset_movement_state()
	assert(p.double_speed_time == 0.0)
	var art := Node3D.new()
	main.add_child(art)
	var builder = load("res://scripts/item_pickup.gd").new()
	builder._make_speed_shoe(art)
	assert(art.has_node("SneakerSole") and art.has_node("SneakerUpper"))
	builder.free()
	print("DOUBLE_SPEED PASS: pool, use, HUD, x2 walk/crouch, no stacking, carrier modifier, snapshot, expiry, resets, sneaker")
	quit()
