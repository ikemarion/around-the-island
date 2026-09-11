extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.session_mode = &"client"
	main.round_epoch = 2
	var prop = main._sorted_obstacles()[0]
	var target: Transform3D = prop.global_transform
	target.origin += Vector3(0.5,0,0)
	var state := {"name":prop.name,"transform":target,"linear":Vector3.ZERO,"angular":Vector3.ZERO,"holder":-1}
	main._receive_obstacle_batch([state],2,100)
	assert(prop.global_transform == target)
	var stale := state.duplicate()
	stale.transform.origin += Vector3(3,0,0)
	main._receive_obstacle_batch([stale],2,99)
	assert(prop.global_transform == target)
	main._receive_obstacle_batch([stale],1,200)
	assert(prop.global_transform == target)
	# Simulate missing intermediate updates, then receiving the next keyframe.
	main._receive_obstacle_batch([stale],2,120)
	assert(prop.global_transform == stale.transform)
	print("OBSTACLE_BATCH passed: ordered state, stale epoch rejection, lost-update recovery")
	quit()
