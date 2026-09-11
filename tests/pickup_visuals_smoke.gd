extends SceneTree

const GENERIC_PICKUP := preload("res://scenes/generic_powerup_pickup.tscn")
const TYPES: Array[StringName] = [
	&"air_horn",
	&"swap_bell",
	&"invisibility",
	&"rewind_watch",
	&"emergency_door",
	&"decoy_double",
	&"magnet_mayhem",
	&"pocket_wall",
	&"hot_potato",
	&"stun_gun",
]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_physics_process(false)
	for player in main.players:
		player.set_physics_process(false)
	assert(not main.has_node("Arena/IslandDisplay/Countdown"))
	for bar_name in ["YouScoreBar", "BotScoreBar", "PlayerThreeScoreBar", "PlayerFourScoreBar"]:
		assert(main.has_node("Arena/IslandDisplay/" + bar_name))
	var colors: Dictionary = main.get_node("Arena/PowerUpSpawner").ITEM_COLORS
	for index in TYPES.size():
		var pickup = GENERIC_PICKUP.instantiate()
		main.add_child(pickup)
		pickup.configure(TYPES[index], colors[TYPES[index]])
		pickup.set_process(false)
		pickup.global_position = Vector3((index % 5 - 2) * 1.65, 1.25, (index / 5 - 0.5) * 2.0)
		var art := pickup.get_node("IconArt")
		assert(art.get_meta("item_type") == String(TYPES[index]))
		assert(art.get_child_count() >= 3)
	main.camera.gameplay_input_enabled = false
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	main.camera.global_position = Vector3(0, 6.3, 8.8)
	main.camera.look_at(Vector3(0, 1.1, 0))
	main.camera.fov = 48
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/powerup-icons.png")
	main.queue_free()
	await process_frame
	print("PICKUP_VISUALS passed: tabletop timer removed, score bars retained, ten unique pickup models")
	quit()
