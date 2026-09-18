extends SceneTree
const ART = preload("res://scripts/house_prop_art.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("adc5b7")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.4
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-30,0)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_mesh.mesh = plane
	floor_mesh.material_override = ART.material(Color("adc5b7"))
	world.add_child(floor_mesh)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	for kind in ["box","car","couch","tv"]:
		sun.rotation_degrees.y = -150 if kind == "couch" else -30
		var prop := Node3D.new()
		world.add_child(prop)
		match kind:
			"box":
				ART.make_box(prop)
				prop.position.y = 0.45
				camera.position = Vector3(2,1.7,3)
				camera.look_at(Vector3(0,0.45,0))
				camera.size = 1.8
			"car":
				ART.make_car(prop)
				prop.position.y = 0.825
				camera.position = Vector3(7,3.8,7)
				camera.look_at(Vector3(0,0.85,0))
				camera.size = 7.1
			"couch":
				ART.make_couch(prop)
				prop.position.y = 0.725
				camera.position = Vector3(4.8,3.2,-7)
				camera.look_at(Vector3(0,0.7,0))
				camera.size = 6.2
			"tv":
				ART.make_tv_console(prop)
				prop.position.y = 0.375
				var tv := Node3D.new()
				prop.add_child(tv)
				tv.position = Vector3(0,1.005,-0.07)
				ART.make_tv(tv)
				camera.position = Vector3(3,2.7,6)
				camera.look_at(Vector3(0,1.1,0))
				camera.size = 4.8
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/prop-"+kind+".png")
		prop.queue_free()
		await process_frame
	print("HOUSE_PROP_PREVIEW PASS")
	quit()
