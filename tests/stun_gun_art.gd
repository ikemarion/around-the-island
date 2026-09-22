extends SceneTree
## Native Godot art checks and unretouched captures under the actual game lighting.

func _initialize() -> void:
	call_deferred("run")


func capture(main: Node3D, filename: String, eye: Vector3, target: Vector3, fov: float) -> void:
	main.camera.position = eye
	main.camera.look_at(target)
	main.camera.fov = fov
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://build/network-test/" + filename + ".png")
	assert(error == OK, "Could not save native stun gun capture")


func inspect_model(pickup: Node3D) -> void:
	var model := pickup.get_node("IconArt/StunGunModel")
	for part in ["MintShell", "CreamMuzzleCollar", "CyanLens", "CoralGrip", "CreamGripFoot", "CreamTrigger", "ReadyLamp", "RearGoldCap", "LightningBadgeLeft", "LightningBadgeRight", "GoldVent1Left", "GoldVent3Right"]:
		assert(model.find_child(part, true, false) != null, "Missing concept detail: " + part)
	assert(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Pickup art must not add collision")
	var triangles := 0
	var bounds := AABB()
	var first := true
	for part in model.find_children("*", "MeshInstance3D", true, false):
		assert(part.mesh != null and part.mesh.get_aabb().size.is_finite())
		var part_bounds: AABB = part.transform * part.mesh.get_aabb()
		bounds = part_bounds if first else bounds.merge(part_bounds)
		first = false
		for surface in part.mesh.get_surface_count():
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	assert(triangles < 50000, "Stun collectible exceeded its triangle budget")
	assert(bounds.size.x < 2.1 and bounds.size.y < 1.7 and bounds.size.z < 0.85, "Sculpt proportions drifted")
	var lowest_y: float = pickup.base_height - pickup.bob_height + model.position.y + bounds.position.y * model.scale.y
	assert(lowest_y > 0.34, "Grip clips the saucer at the bottom of its bob")
	assert(pickup.get_node("Glow").light_energy <= 0.25, "Pickup light should not wash out the enamel")
	assert(not pickup.get_node("Body").visible and not pickup.get_node("Grip").visible and not pickup.get_node("Charge").visible)
	assert(is_equal_approx(pickup.get_node("CollisionShape3D").shape.radius, 0.72), "Collection area was changed")
	print("STUN_GUN_ART model triangles=", triangles, " bounds=", bounds, " min_hover=", lowest_y)


func run() -> void:
	create_timer(20.0, true).timeout.connect(func():
		push_error("STUN_GUN_ART timed out")
		quit(1))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	await process_frame
	await physics_frame
	main.set_physics_process(false)
	main.set_process(false)
	main.camera.gameplay_input_enabled = false
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	for player in main.players:
		player.set_physics_process(false)
		player.hide()
	for obstacle in get_nodes_in_group("shoveable"):
		obstacle.freeze = true
		obstacle.hide()
	main.get_node("HUD").hide()
	main.distant_scoreboards.hide()
	main.get_node("Arena/SouthWall").hide()
	var spawner = main.get_node("Arena/PowerUpSpawner")
	spawner.set_authoritative(false)
	await process_frame
	# Exercise the real remote pickup path, not a separate display-only instance.
	var state := {"position": Vector3(0, 0, 3.7), "available": true, "item_type": &"stun_gun", "time_left": 0.0}
	spawner.apply_network_state(state)
	var pickup: Node3D = spawner.active_pickup
	pickup.set_process(false)
	inspect_model(pickup)
	assert(not pickup.monitoring, "Remote collectible must not claim items locally")
	assert(pickup.item_type == &"stun_gun")
	var instance_id := pickup.get_instance_id()
	spawner.apply_network_state(state)
	assert(spawner.active_pickup.get_instance_id() == instance_id, "Unchanged snapshots rebuilt the pickup")
	if DisplayServer.get_name() != "headless":
		await capture(main, "stun-gun-hero", Vector3(-2.45, 2.2, 8.0), Vector3(0, 0.95, 3.7), 26)
		await capture(main, "stun-gun-side", Vector3(0, 1.25, 8.2), Vector3(0, 1.0, 3.7), 26)
		await capture(main, "stun-gun-reverse", Vector3(2.3, 1.8, -0.1), Vector3(0, 1.0, 3.7), 26)
		await capture(main, "stun-gun-player", Vector3(0, 1.65, 6.5), Vector3(0, 1.05, 3.7), 100)
	state.available = false
	state.item_type = &""
	spawner.apply_network_state(state)
	await process_frame
	assert(spawner.active_pickup == null, "Spent remote pickup left a ghost model")
	state.available = true
	state.item_type = &"stun_gun"
	spawner.apply_network_state(state)
	inspect_model(spawner.active_pickup)
	# Local collection remains the original one-shot inventory action.
	var local_pickup = load("res://scenes/stun_gun_pickup.tscn").instantiate()
	main.add_child(local_pickup)
	local_pickup.configure(&"stun_gun", Color("ffe56b"))
	inspect_model(local_pickup)
	main.players[0].equipped_spawn_item = &""
	local_pickup._on_body_entered(main.players[0])
	assert(local_pickup.claimed and main.players[0].has_stun_gun())
	main.queue_free()
	await process_frame
	print("STUN_GUN_ART PASS: concept parts, mesh budget, hover clearance, pickup, remote spawn/remove/respawn")
	quit()
