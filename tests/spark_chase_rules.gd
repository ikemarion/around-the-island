extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	for p in main.players: p.set_physics_process(false)
	var p = main.players[0]
	p.set_has_token(false)
	p._update_chase_charge(8.0,true)
	assert(is_equal_approx(p._chase_speed_multiplier(),1.0))
	assert(p._try_boost(Vector2.RIGHT))
	assert(is_equal_approx(p._chase_speed_multiplier(),1.8))
	assert(not p._try_boost(Vector2.RIGHT))
	assert(is_equal_approx(main._player_state(0).boost_time,5.0))
	p._update_chase_charge(1.0,false)
	assert(is_equal_approx(p.boost_time,4.0) and p.chase_charge == 0.0)
	p.set_has_token(true)
	assert(p.chase_charge == 0.0 and is_equal_approx(p._chase_speed_multiplier(),0.93))
	var trail = p.get_child(0)
	for child in p.get_children():
		if child is CPUParticles3D: trail = child
	trail._process(0.1)
	assert(trail.visible and trail.emitting)
	p.set_network_invisibility(5.0)
	trail._process(0.1)
	assert(not trail.visible and not trail.emitting)
	main.round_running = false
	assert(p._chase_speed_multiplier() == 1.0)
	main.round_running = true
	var target = main.players[1]
	var prop = load("res://scripts/shoveable.gd").new()
	main.add_child(prop)
	prop.add_to_group("shoveable")
	prop.global_position = target.global_position + Vector3.RIGHT
	var magnet = load("res://scripts/chaos_effect.gd").new()
	main.add_child(magnet)
	magnet.setup(&"magnet_mayhem",p,target)
	magnet.remaining = 0.0
	magnet._finish_magnet()
	assert(prop.launch_time > 0.0)
	assert(p.magnet_effect == null)
	var bell = load("res://scripts/sfx_library.gd").get_effect("swap_bell")
	assert(bell.get_length() > 1.0)
	print("SPARK_CHASE_RULES PASS: charge, carrier penalty, snapshot, invisibility trail cleanup, expiry burst and bell")
	quit()
