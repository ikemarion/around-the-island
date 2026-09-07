extends SceneTree

# Exercise the real collision and snapshot paths: decorative geometry alone
# must never make a room appear connected while its old wall still blocks play.
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	main.set_process(false)
	main.camera.gameplay_input_enabled = false
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	for player in main.players:
		player.set_physics_process(false)
	var obstacles: Array = main._sorted_obstacles()
	for obstacle in obstacles:
		obstacle.freeze = true
	await physics_frame
	await physics_frame
	var navigation = main.get_node("Arena/HouseNavigation")
	for attempt in 10:
		if navigation.is_navigation_ready():
			break
		await physics_frame
	check(navigation.is_navigation_ready(), "House navigation failed to initialize")
	if navigation.is_navigation_ready():
		check(is_equal_approx(navigation.map_bounds.size.x, 54.0), "Navigation did not include both room floors")
		var route: PackedVector3Array = navigation.find_path(Vector3(-23, 0.05, 3.5), Vector3(23, 0.05, -3.5))
		check(not route.is_empty() and route[-1].x > 20, "Bot cannot navigate garage to living room")
		for index in range(1, route.size()):
			check(navigation._can_travel(route[index - 1], route[index]), "Bot route clips a wall or furnishing")
		for point in [Vector3(-40, 0, 0), Vector3(18, 0, 0.8), Vector3(-18, 0, 0)]:
			var landing: Vector3 = navigation.nearest_safe_position(point)
			check(landing.is_finite() and navigation._has_floor(landing) and navigation._body_fits(landing), "Emergency door destination is unsafe")

	var rooms: Array[Node3D] = []
	for room_name in ["LivingRoom", "Garage"]:
		var room = main.get_node_or_null("Arena/Rooms/" + room_name)
		check(room != null, room_name + " module missing")
		if room != null:
			rooms.append(room)
			check(room.has_node("Geometry/Floor"), room_name + " needs its own collision floor")
			var room_props := 0
			for obstacle in obstacles:
				if room.is_ancestor_of(obstacle):
					room_props += 1
			check(room_props >= 4, room_name + " needs four interactive themed props")

	# Sweep a full standing player in both directions through both doorways.
	var player: CharacterBody3D = main.players[0]
	for doorway_x in [-9.0, 9.0]:
		for doorway_z in [-3.5, 3.5]:
			for direction in [-1.0, 1.0]:
				var start := Vector3(doorway_x - direction * 1.8, 0.05, doorway_z)
				var collision := KinematicCollision3D.new()
				var blocked := player.test_move(Transform3D(Basis.IDENTITY, start), Vector3(direction * 3.6, 0, 0), collision)
				var blocker: String = str(collision.get_collider().get_path()) if blocked else ""
				check(not blocked, "Standing player blocked at doorway %.1f, %.1f, direction %.0f by %s" % [doorway_x, doorway_z, direction, blocker])

	var spawners := get_nodes_in_group("item_spawner")
	check(spawners.size() == 1, "Multiplayer expects exactly one replicated pickup spawner")
	if spawners.size() == 1:
		var spawner = spawners[0]
		check(spawner.get_node("Pad").collision_layer == 0, "Moving pickup pedestal should not snag a chase route")
		for room in rooms:
			var markers := room.get_node_or_null("PickupSpawns")
			check(markers != null, str(room.name) + " needs modular pickup markers")
			if markers == null:
				continue
			check(markers.get_child_count() >= 2, str(room.name) + " has too few pickup locations")
			for marker in markers.get_children():
				if marker is Marker3D:
					var assigned := false
					for location in spawner.spawn_locations:
						if marker.global_position.is_equal_approx(location):
							assigned = true
					check(assigned, "Room pickup location missing from authority spawner: " + str(marker.get_path()))
		# Floor rays also cover spawn validity in every module. Start just above
		# the ground, below the pickup's own area and any floating art.
		for location in spawner.spawn_locations:
			var ray := PhysicsRayQueryParameters3D.create(location + Vector3.UP * 0.15, location + Vector3.DOWN * 0.5, 1)
			var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.get("collider") is StaticBody3D, "Pickup has no supporting floor at " + str(location))
		for center_x in [-18.0, 0.0, 18.0]:
			var represented := false
			for location in spawner.spawn_locations:
				if absf(location.x - center_x) < 9.0:
					represented = true
			check(represented, "Room has no randomized pickup location at x=" + str(center_x))

	# Obstacle names are their wire IDs, so duplicates anywhere in the map
	# would move two props together on a client.
	var names := {}
	check(obstacles.size() >= 12, "Expanded house should include kitchen and both rooms' interactive props")
	for obstacle in obstacles:
		check(not names.has(obstacle.name), "Duplicate network obstacle name: " + str(obstacle.name))
		names[obstacle.name] = true
		check(main.obstacle_spawn_transforms.has(obstacle), "Late-created prop absent from round reset: " + str(obstacle.name))
		check(obstacle.has_node("CartoonProp"), "Missing themed art on " + str(obstacle.name))
		obstacle.global_position += Vector3(0.4, 1.0, 0.2)
		obstacle.linear_velocity = Vector3(3, 4, 5)
		obstacle.angular_velocity = Vector3(1, 2, 3)
		obstacle.holder = player
	main.reset_round()
	for obstacle in obstacles:
		if main.obstacle_spawn_transforms.has(obstacle):
			check(obstacle.global_transform.is_equal_approx(main.obstacle_spawn_transforms[obstacle]), "Round reset did not restore " + str(obstacle.name))
		check(obstacle.holder == null and obstacle.linear_velocity == Vector3.ZERO and obstacle.angular_velocity == Vector3.ZERO, "Round reset retained motion/holder on " + str(obstacle.name))
		obstacle.freeze = true

	main.session_mode = &"client"
	main.world_sequences.clear()
	var expected := {}
	for index in obstacles.size():
		var obstacle = obstacles[index]
		var target: Transform3D = obstacle.global_transform
		target.origin += Vector3(0, 0.2 + float(index) * 0.02, 0)
		expected[obstacle] = target
		main._receive_obstacle_state({"name": obstacle.name, "transform": target, "linear": Vector3.ZERO, "angular": Vector3.ZERO, "holder": -1}, main.round_epoch, 1)
	for obstacle in obstacles:
		check(obstacle.global_transform.is_equal_approx(expected[obstacle]), "Client snapshot mapped wrong prop: " + str(obstacle.name))
	main._start_solo()
	main.set_physics_process(false)
	for other in main.players:
		other.set_physics_process(false)
	for obstacle in obstacles:
		obstacle.freeze = true

	# The fallback must also forfeit the spark for a fall beyond the old
	# kitchen kill-box footprint.
	if "--check-bot" in OS.get_cmdline_user_args():
		main.players[0].global_position = Vector3(23, 0.05, 3.5)
		main.players[1].global_position = Vector3(-23, 0.05, 3.5)
		main._set_token_holder(0)
		main.players[1].set_physics_process(true)
		for tick in 1000:
			await physics_frame
			if main.players[1].global_position.distance_to(main.players[0].global_position) < 1.8:
				break
		check(main.players[1].global_position.distance_to(main.players[0].global_position) < 1.8, "Live bot failed to chase from garage through kitchen into living room: " + str(main.players[1].global_position))
		main.players[1].set_physics_process(false)
	main.players[0].global_position = Vector3(24, -8, 0)
	main.token_holder = 0
	main._physics_process(0.0)
	check(main.players[0].global_position.y >= 0 and main.token_holder == 1, "Side-room fall failed respawn or spark forfeit")

	if DisplayServer.get_name() != "headless":
		main.get_node("HUD").hide()
		main.distant_scoreboards.hide()
		await capture(main, "modular-house-overview", Vector3(0, 38, 32), Vector3(0, 0, 0), 44)
		await capture(main, "living-room", Vector3(25, 8, 8.5), Vector3(18, 0.5, 0), 65)
		await capture(main, "garage", Vector3(-10, 8, 8.5), Vector3(-18, 0.5, 0), 65)
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("MODULAR_HOUSE failures=", failures)
	quit(1 if failures else 0)


func capture(main: Node3D, filename: String, camera_position: Vector3, target: Vector3, fov: float) -> void:
	main.camera.global_position = camera_position
	main.camera.look_at(target)
	main.camera.fov = fov
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/network-test")
	root.get_texture().get_image().save_png("res://build/network-test/" + filename + ".png")
