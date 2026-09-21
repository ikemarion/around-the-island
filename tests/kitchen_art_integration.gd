extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func collider_signature(arena: Node) -> Array:
	var result: Array = []
	for collision in arena.find_children("*","CollisionShape3D",true,false):
		var path := str(arena.get_path_to(collision))
		# Room modules and pickup areas are instantiated during normal startup.
		if path.begins_with("Rooms/") or path.begins_with("PowerUpSpawner/"): continue
		var shape = collision.shape
		result.append([str(arena.get_path_to(collision)),collision.transform,shape.get_class(),shape.size if shape is BoxShape3D else Vector3.ZERO])
	return result

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	var original := collider_signature(main.get_node("Arena"))
	root.add_child(main)
	current_scene = main
	main._start_solo()
	await process_frame
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	for p in main.players: p.set_physics_process(false)
	var arena: Node3D = main.get_node("Arena")
	var final_colliders := collider_signature(arena)
	assert(final_colliders == original,"Kitchen collision geometry must remain unchanged")
	assert(main._sorted_obstacles().size() == 12)
	var island: Node3D = arena.get_node("Island/KitchenArt")
	assert(island.get_node("CreamCountertop").position.y < 0.475)
	assert(island.find_children("*","CollisionObject3D",true,false).is_empty())
	assert(island.has_node("Front/Cabinet0/InsetPanel"))
	assert(island.has_node("TeaCorner/KettleBody"))
	assert(island.has_node("FruitBowl/CeramicBowl"))
	assert(arena.get_node("IslandDisplay").visible)
	assert(arena.get_node("Floor/MeshInstance3D").material_override is ShaderMaterial)
	var chair: Node3D = arena.get_node("Chair/CartoonProp")
	assert(chair.has_node("RoundedWoodSeat") and chair.has_node("RoundedBackrest"))
	for part in chair.find_children("*","MeshInstance3D",true,false):
		var bounds: AABB = part.transform * part.mesh.get_aabb()
		assert(bounds.position.x >= -0.451 and bounds.end.x <= 0.451)
		assert(bounds.position.y >= -0.451 and bounds.end.y <= 0.451)
		assert(bounds.position.z >= -0.451 and bounds.end.z <= 0.451)
	var triangles := 0
	for part in island.find_children("*","MeshInstance3D",true,false):
		assert(part.mesh.get_aabb().size.is_finite())
		for surface in part.mesh.get_surface_count():
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	assert(triangles < 150000,"Keep visual detail within a sensible triangle budget")
	if DisplayServer.get_name() != "headless":
		main.get_node("HUD").hide()
		main.camera.set_process(false)
		main.camera.set_physics_process(false)
		main.camera.fov = 65
		var views := {
			"kitchen-wide": [Vector3(7.7,5.8,7.0),Vector3(0,0.45,0)],
			"kitchen-player": [Vector3(4.8,1.65,4.6),Vector3(0,0.65,0)],
			"kitchen-chair": [chair.global_position+Vector3(1.25,0.8,-1.6),chair.global_position],
		}
		for title in views:
			main.camera.global_position = views[title][0]
			main.camera.look_at(views[title][1])
			for i in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/network-test/"+title+".png")
	print("KITCHEN_ART_INTEGRATION PASS: unchanged colliders, 12 props, chair envelope, score display, finite meshes; island triangles=",triangles)
	quit()
