extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	await process_frame
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	for p in main.players: p.set_physics_process(false)
	assert(main._sorted_obstacles().size() == 12)
	var car = main.find_child("ProjectCar",true,false)
	var couch = main.find_child("Couch",true,false)
	var tv = main.find_child("Television",true,false)
	assert(car.get_node("CollisionShape3D").shape.size == Vector3(5.4,1.65,2.55))
	assert(couch.get_node("CollisionShape3D").shape.size == Vector3(5,1.45,1.55))
	assert(tv.get_node("CollisionShape3D").shape.size == Vector3(2.5,1.25,0.3))
	assert(car.has_node("SculptedCabin") and car.has_node("CurvedWindshield"))
	assert(couch.has_node("BackCushion") and couch.has_node("RolledArm"))
	assert(tv.has_node("CRTShell") and tv.has_node("ScreenStar"))
	assert(main.find_child("Cardboard",true,false) != null)
	for prop in [car,couch,tv]:
		for part in prop.find_children("*","MeshInstance3D",true,false):
			assert(part.mesh != null and part.mesh.get_aabb().size.is_finite())
	if DisplayServer.get_name() != "headless":
		main.get_node("HUD").hide()
		main.camera.set_process(false)
		main.camera.set_physics_process(false)
		main.camera.fov = 65
		for target in [car,couch,tv]:
			var offset := Vector3(5,2.7,4) if target == car else (Vector3(4,2.3,-4) if target == couch else Vector3(2,1.0,3))
			main.camera.global_position = target.global_position+offset
			main.camera.look_at(target.global_position+Vector3.UP*0.1)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/network-test/in-game-"+str(target.name)+".png")
	print("HOUSE_PROP_INTEGRATION PASS: all models present, finite meshes, original colliders and 12 networked obstacles")
	quit()
