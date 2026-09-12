extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	var nav = main.get_node("Arena/HouseNavigation")
	for i in 300:
		if nav.is_navigation_ready(): break
		await physics_frame
	assert(nav.is_navigation_ready())
	main.set_physics_process(false)
	for p in main.players: p.set_physics_process(false)
	var player = main.players[0]
	player.set_has_token(false)
	player._update_chase_charge(8.0,true)
	assert(player._try_boost(Vector2.RIGHT))
	assert(player.velocity.x > 10.0)
	player._update_chase_charge(5.0,true)
	assert(player.boost_time == 0.0 and player.chase_charge == 0.0)
	player._update_chase_charge(4.0,false)
	assert(is_equal_approx(player.chase_charge,0.5))
	player.set_has_token(true)
	assert(player.boost_time == 0.0 and player.chase_charge == 0.0)
	var pair: Array = nav.border_door_pair(player.global_position)
	assert(pair.size() == 2)
	for place in pair:
		var p: Vector3 = place.position
		var bounds: Rect2 = nav.map_bounds
		var edge := minf(minf(p.x-bounds.position.x,bounds.end.x-p.x),minf(p.z-bounds.position.y,bounds.end.y-p.z))
		assert(edge <= 1.0)
		assert(nav._has_floor(p+place.inward*1.25))
	player._deploy_emergency_doors()
	var doors = main.get_node("EmergencyDoors")
	var landing: Vector3 = doors.exit.global_position+doors.exit.global_basis.z*doors.exit_offset
	doors._on_door_entered(player,doors.exit)
	assert(Vector2(player.global_position.x,player.global_position.z).distance_to(Vector2(landing.x,landing.z)) < 0.1)
	var states: Array = main._temporary_item_states()
	var found := false
	for state in states:
		if state.has("entry"):
			assert(state.has("entry_yaw") and state.has("exit_yaw"))
			found = true
	assert(found)
	print("BOOST_BORDER_DOORS PASS: burst, expiry, recharge, transfer, border pair, inward landing, replicated orientation")
	quit()
