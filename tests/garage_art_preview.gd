extends SceneTree
## Actual main-scene captures, using the shipped environment and renderer.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(62)
	if "--verify-player-pack" in OS.get_cmdline_user_args():
		if FileAccess.file_exists("res://tests/garage_visual_integration.gd") or ResourceLoader.exists("res://docs/art/prop-refresh/approved-concept.png"):
			push_error("Garage pack preview resolved development-only resources")
			quit(1)
			return
		print("GARAGE_PLAYER_PACK exclusions verified")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._start_solo()
	await process_frame
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	for player in game.players:
		player.set_physics_process(false)
		player.hide()
	game.get_node("HUD").hide()
	game.camera.set_process(false)
	game.camera.set_physics_process(false)
	game.camera.fov = 64
	game.get_node("Arena/PowerUpSpawner").set_process(false)
	game.get_node("Arena/PowerUpSpawner").set_physics_process(false)
	var room: Node3D = game.get_node("Arena/Rooms/Garage")
	var tag := "before" if "--garage-before" in OS.get_cmdline_user_args() else "after"
	var path := "res://build/garage-v062/" + tag
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--garage-output="):
			path = argument.trim_prefix("--garage-output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	var views := {
		"wide": [Vector3(8.1, 5.8, 7.8), Vector3(-0.4, 0.75, -0.7)],
		"player": [Vector3(7.6, 1.65, 3.5), Vector3(-1.1, 1.0, -1.6)],
		"first-person": [Vector3(7.6, 1.65, 3.5), Vector3(-1.1, 1.0, -1.6)],
		"workshop": [Vector3(4.1, 2.35, -1.2), Vector3(-0.25, 1.43, -5.2)],
		"shutter": [Vector3(-3.8, 1.8, 3.5), Vector3(-8.5, 1.45, 0)],
		"car": [Vector3(5.1, 2.2, 3.8), Vector3(0, 0.94, 0)],
	}
	for title in views:
		game.camera.fov = 100 if title == "first-person" else 64
		game.camera.global_position = room.to_global(views[title][0])
		game.camera.look_at(room.to_global(views[title][1]))
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path + "/garage-" + title + ".png")
		print("GARAGE_CAPTURE ", title, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("GARAGE_ART_PREVIEW PASS ", tag)
	quit()
