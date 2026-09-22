extends SceneTree
## Live scores, roster changes and round transitions; optional Godot captures.
func _initialize() -> void:
	call_deferred("run")


func settle(board: Node3D) -> void:
	board.refresh()
	board._process(2.0)


func capture(main: Node3D, title: String, eye: Vector3, target: Vector3, fov := 55.0) -> void:
	main.camera.global_position = eye
	main.camera.fov = fov
	main.camera.look_at(target)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://build/network-test/"+title+".png")
	assert(error == OK,"Could not save scoreboard capture")


func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_process(false)
	main.set_physics_process(false)
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	for p in main.players:
		p.set_physics_process(false)
	var board = main.distant_scoreboards
	main.active_slots.assign([true,true,true,true])
	main.scores.assign([16.0,10.0,7.0,4.0])
	main.time_remaining = 38.0
	settle(board)
	assert(board.displays.size() == 4)
	for display in board.displays:
		assert(is_equal_approx(display.rows[0].height,16.0/20.0*board.BAR_HEIGHT))
		assert(display.rows[0].name.text == "YOU")
		assert(display.rows[0].value.text == "16.0")
		assert(display.title.text == "00:38")
		assert(display.subtitle.text == "TIME LEFT")
		assert(display.crown.visible)
		assert(display.node.basis.z.dot((Vector3(0,5,0)-display.node.position).normalized()) > 0.99)
		for row in display.rows:
			assert(is_equal_approx(row.value.position.y,board.VALUE_Y))
			assert(row.height >= 0 and row.height <= board.BAR_HEIGHT)
			assert(row.node.find_children("*","CollisionObject3D",true,false).is_empty())
	for time_case in [[75.0,"01:15"],[60.0,"01:00"],[59.4,"01:00"],[59.0,"00:59"],[0.2,"00:01"],[0.0,"00:00"],[-0.1,"00:00"]]:
		main.time_remaining = time_case[0]
		board.refresh()
		for display in board.displays:
			assert(display.title.text == time_case[1],"Countdown rounding or formatting")
	main.time_remaining = 38.0
	main.scores[1] = 16.0
	settle(board)
	assert(not board.displays[0].crown.visible,"A tie must not crown either player")
	main.scores[1] = 10.0
	main.local_slot = 2
	main.active_slots[1] = false
	settle(board)
	for display in board.displays:
		assert(display.rows[2].name.text == "YOU","Every client needs its own YOU badge")
		assert(not display.rows[1].node.visible)
		assert(is_equal_approx(display.rows[2].node.position.x,0.0),"Three players recenter without a hole")
	# A departed player's old score must not determine the range or leader.
	main.scores[1] = 99.0
	settle(board)
	assert(is_equal_approx(board.displays[0].rows[0].height,16.0/20.0*board.BAR_HEIGHT))
	main.scores.assign([16.0,10.0,7.0,4.0])
	main.active_slots.assign([true,true,true,true])
	main.local_slot = 0
	settle(board)
	# Tiny and maximum scores stay inside the recessed channel; zero has no fake fill.
	for score in [0.0,0.01,0.5,75.0]:
		main.scores[0] = score
		settle(board)
		var row: Dictionary = board.displays[0].rows[0]
		assert(row.bar.visible == (score > 0.0))
		assert(row.height <= board.BAR_HEIGHT)
		assert(is_equal_approx(row.value.position.y,board.VALUE_Y))
		assert(row.bottom.scale.is_finite() and row.top.scale.is_finite())
	main.scores.assign([16.0,10.0,7.0,4.0])
	settle(board)
	var triangles := 0
	for part in board.displays[0].node.find_children("*","MeshInstance3D",true,false):
		assert(part.mesh.get_aabb().size.is_finite())
		for surface in part.mesh.get_surface_count():
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	assert(triangles < 100000,"Per-display art exceeded the triangle budget")
	if DisplayServer.get_name() != "headless":
		main.get_node("HUD").hide()
		await capture(main,"score-ribbons-four",Vector3(2.6,17.0,-1),Vector3(0,16.0,-28),53.0)
		await capture(main,"score-ribbons-player",Vector3(0,1.65,4),Vector3(0,13,-28),100.0)
	main.active_slots.assign([true,false,true,false])
	settle(board)
	for display in board.displays:
		assert(is_equal_approx(display.rows[0].node.position.x,-board.ROW_SPACING*0.5))
		assert(is_equal_approx(display.rows[2].node.position.x,board.ROW_SPACING*0.5))
	main.local_slot = 2
	main.scores[2] = 24.1
	main.time_remaining = 20.9
	settle(board)
	assert(board.displays[0].crown.position.x == board.displays[0].rows[2].node.position.x)
	if DisplayServer.get_name() != "headless":
		await capture(main,"score-ribbons-two",Vector3(2,17,-1),Vector3(0,16,-28),53.0)
	main.round_running = false
	main.time_remaining = 0.0
	settle(board)
	for display in board.displays:
		assert(display.title.text == "00:00" and display.subtitle.text == "FINAL SCORES")
		assert(display.rows[2].value.text == "24.1")
	if DisplayServer.get_name() != "headless":
		await capture(main,"score-ribbons-final",Vector3(2,17,-1),Vector3(0,16,-28),53.0)
	main.reset_round()
	settle(board)
	assert(not board.displays[0].rows[0].bar.visible)
	assert(not board.displays[0].crown.visible)
	assert(board.displays[0].title.text == "01:15")
	# Exercise the actual client snapshot path without changing the wire protocol.
	main.session_mode = &"client"
	main.active_slots.assign([true,true,true,true])
	main.local_slot = 3
	main._receive_match_state([2.5,18.0,4.2,7.5],42.0,1,{},true,main.round_epoch,1000)
	settle(board)
	assert(board.displays[0].title.text == "00:42")
	assert(board.displays[0].rows[3].name.text == "YOU")
	assert(board.displays[0].rows[1].value.text == "18.0")
	main._receive_match_state([0.0,0.0,0.0,0.0],75.0,0,{},true,main.round_epoch,999)
	settle(board)
	assert(board.displays[0].title.text == "00:42","Stale snapshots must not rewind the timer")
	main._enter_lobby()
	board.refresh()
	assert(not board.visible)
	main.queue_free()
	await process_frame
	print("DISTANT_SCOREBOARDS passed: timer, ties, scores, 2/3/4 seats, disconnect, fill bounds, reset, client snapshots, lobby; triangles/display=",triangles)
	quit()
