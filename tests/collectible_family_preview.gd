extends SceneTree
const TYPES := [&"invisibility", &"rewind_watch", &"air_horn", &"swap_bell"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	await process_frame
	await physics_frame
	main.set_physics_process(false)
	main.set_process(false)
	for p in main.players:
		p.set_physics_process(false)
		p.hide()
	for obstacle in get_nodes_in_group("shoveable"):
		obstacle.hide()
	main.get_node("HUD").hide()
	main.distant_scoreboards.hide()
	main.get_node("Arena/PowerUpSpawner").hide()
	main.get_node("Arena/SouthWall").hide()
	for index in TYPES.size():
		var holder := Node3D.new()
		main.add_child(holder)
		holder.position = Vector3(-3.3+index*2.2,0,3.8)
		var saucer = load("res://scripts/spawn_saucer.gd").new()
		holder.add_child(saucer)
		saucer.set_available(true)
		var pickup = load("res://scenes/generic_powerup_pickup.tscn").instantiate()
		holder.add_child(pickup)
		pickup.configure(TYPES[index], Color("ffd68a"))
		pickup.set_process(false)
		pickup.position.y = 1.07
		pickup.rotation.y = -0.45 if TYPES[index] == &"air_horn" else 0.0
		assert(pickup.get_node("IconArt").get_child_count() >= 3)
		assert(pickup.get_node("Glow").light_energy <= 0.25)
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	main.camera.position = Vector3(0,2.9,11.4)
	main.camera.look_at(Vector3(0,0.85,3.8))
	main.camera.fov = 38
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/collectible-family.png")
	print("COLLECTIBLE_FAMILY passed: ghost, watch, horn, bell, warm restrained lighting")
	quit()
