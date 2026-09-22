extends SceneTree
## Fixed-length joints, complete skinning, soft transitions and frame-rate checks.
const RIG := preload("res://scripts/sockling_arm_rig.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(25.0, true).timeout.connect(func():
		push_error("SOCKLING_ARM_RIG timed out")
		quit(1))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	for player in main.players:
		player.set_physics_process(false)
		player.set_character_skin(&"sockling") # A randomized practice bot must not change the rig under test.
		player.body_mesh.get_node("Sockling").animation_enabled = false
	var art = main.players[1].body_mesh.get_node("Sockling")
	art.motion.reset()
	var sockling_meshes := {}
	for player in main.players:
		var other = player.body_mesh.get_node("Sockling")
		for index in 2:
			var weighted: ArrayMesh = other.arm_meshes[index].mesh
			sockling_meshes[weighted.get_rid()] = true
			assert(weighted == art.arm_meshes[index].mesh and RIG.weighted_meshes.values().has(weighted), "Players must reuse the cached weighted Sockling arm")
	assert(sockling_meshes.size() == 2, "Build exactly two weighted Sockling arms, shared by all players")
	for index in 2:
		var skeleton: Skeleton3D = art.arm_skeletons[index]
		var mesh: MeshInstance3D = art.arm_meshes[index]
		assert(mesh.get_node(mesh.skeleton) == skeleton)
		assert(skeleton.get_bone_count() == 3 and skeleton.get_bone_parent(2) == 1)
		assert(skeleton.get_bone_name(1) == "Elbow" and skeleton.get_bone_name(2) == "Wrist")
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			assert(weights.size() == vertices.size() * 4 and bones.size() == weights.size())
			for vertex in vertices.size():
				var total := 0.0
				var rest := Vector3.ZERO
				for influence in 4:
					var slot := vertex * 4 + influence
					assert(weights[slot] >= 0.0 and bones[slot] >= 0 and bones[slot] < 3)
					total += weights[slot]
					rest += (skeleton.get_bone_global_rest(bones[slot]) * mesh.skin.get_bind_pose(bones[slot]) * vertices[vertex]) * weights[slot]
				assert(absf(total - 1.0) < 0.001, "Unweighted or over-weighted arm vertex")
				assert(rest.distance_to(vertices[vertex]) < 0.001, "Skin bind changes the sculpt's rest position")
		for angle in [0.0, 0.2, 0.55, 0.85, 1.1]:
			skeleton.set_bone_pose_rotation(1, Quaternion(Vector3.RIGHT, -angle))
			skeleton.set_bone_pose_rotation(2, Quaternion(Vector3.RIGHT, 0.16))
			var elbow: Vector3 = skeleton.get_bone_global_pose(1).origin
			var wrist: Vector3 = skeleton.get_bone_global_pose(2).origin
			assert(absf(wrist.distance_to(elbow) - RIG.wrist(-1.0 if index == 0 else 1.0).distance_to(RIG.elbow(-1.0 if index == 0 else 1.0))) < 0.0001, "Bending shrank the forearm")
			skeleton.reset_bone_poses()
	# Continuous pendulum with bounded acceleration; shoulders oppose each other.
	art.motion.reset()
	for frame in 120: art.animate(1.0/60.0, 7.0, false, false, false)
	var last_pitch: float = art.arms[0].rotation.x
	var last_velocity := 0.0
	var opposing_sum := 0.0
	var max_acceleration := 0.0
	for frame in 180:
		art.animate(1.0/60.0, 7.0, false, false, false)
		var pitch: float = art.arms[0].rotation.x
		var velocity := (pitch-last_pitch)*60.0
		if frame > 0: max_acceleration = maxf(max_acceleration, absf(velocity-last_velocity)*60.0)
		opposing_sum += absf(art.arms[0].rotation.x+art.arms[1].rotation.x)
		assert(absf(art.motion.wrist_springs[0].x) <= 0.23, "Wrist follow-through escaped its limit")
		last_pitch = pitch
		last_velocity = velocity
	assert(opposing_sum/180 < 0.015, "Arms swing together instead of opposing each other")
	assert(max_acceleration < 100, "Arm reversals are abrupt")
	for frame in 120: art.animate(1.0/60.0, 0.0, false, false, false)
	assert(absf(art.arms[0].rotation.x) < 0.025 and absf(art.motion.wrist_springs[0].y) < 0.05, "Stop did not settle softly")
	# Equal elapsed time and representative low/high client frame rates.
	var endings: Array[Vector3] = []
	for fps in [30, 60, 144]:
		art.motion.reset()
		art.motion.clock = 0.0
		art.phase = 0.0
		for frame in fps * 3: art.animate(1.0/fps, 6.0, false, false, false)
		endings.append(Vector3(art.arms[0].rotation.x, art.motion.elbow_springs[0].x, art.motion.wrist_springs[0].x))
	print("SOCKLING_ARM_RIG frame-rate endpoints=", endings)
	assert(endings[0].distance_to(endings[2]) < 0.06, "Arm motion depends on client frame rate")
	art.motion.reset()
	assert(art.motion.shoulder_springs[0] == Vector2.ZERO and art.motion.wrist_springs[0] == Vector2.ZERO)
	assert(art.arm_skeletons[0].get_bone_pose_rotation(1).is_equal_approx(Quaternion.IDENTITY))
	main.queue_free()
	await process_frame
	print("SOCKLING_ARM_RIG PASS: cached weights, rest identity, fixed forearm length, smooth opposing swing, wrist limits, stop, FPS, reset; max acceleration=", max_acceleration)
	quit()
