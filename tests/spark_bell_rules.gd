extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	main.active_slots.assign([true,true,true,false])
	for p in main.players: p.set_physics_process(false)
	main.players[0].global_position = Vector3(0,1,0)
	main.players[1].global_position = Vector3(1,1,0)
	main.players[2].global_position = Vector3(-20,1,0)
	main.players[3].global_position = Vector3(50,1,0)
	main.players[2].set_network_invisibility(5.0)
	main.players[0]._use_swap_bell()
	assert(main.players[0].global_position == Vector3(-20,1,0))
	assert(main.players[2].global_position == Vector3(0,1,0))
	assert(main.players[1].global_position == Vector3(1,1,0))
	main.active_slots.assign([true,false,false,false])
	main.players[0]._use_swap_bell()
	assert(main.players[0].equipped_spawn_item == &"swap_bell")
	main.active_slots.assign([false,true,false,true])
	seed(42)
	var selected := {}
	for i in 24:
		main.reset_round()
		assert(main.token_holder in [1,3])
		selected[main.token_holder] = true
	assert(selected.size()==2)
	print("SPARK_BELL_RULES passed: farthest active target including invisible, no-target keeps bell, random active starters")
	quit()
