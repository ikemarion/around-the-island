extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a8d3c8")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fff2d5")
	environment.environment.ambient_light_energy = 0.3
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("a8d3c8")
	floor_mesh.material_override = mat
	world.add_child(floor_mesh)
	var door = load("res://scripts/emergency_door_art.gd").new()
	world.add_child(door)
	door.position.x = 0.7
	var mini = load("res://scripts/emergency_door_art.gd").new()
	world.add_child(mini)
	mini.position = Vector3(-1.7,0.45,0.2)
	mini.scale = Vector3.ONE*0.45
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-2.0,2.9,7.6)
	camera.look_at(Vector3(-0.2,1.15,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/network-test/door-v045.png")
	print("DOOR_ART_PREVIEW PASS")
	quit()
