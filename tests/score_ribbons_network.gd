extends SceneTree
## Bounded two-process ENet regression: existing match packets drive the new art.
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(20.0,true).timeout.connect(func():
		push_error("SCORE_RIBBONS_NETWORK timed out")
		quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var host := "--ribbons-host" in OS.get_cmdline_user_args()
	if host:
		game._prepare_session()
		game.session_mode = &"hosting"
		game.peer_to_slot = {1:0}
		game.network_session.host_room(27994,false)
		while game.active_slots.count(true) < 2:
			await create_timer(0.02,true).timeout
		game._start_hosted_game()
		game.set_physics_process(false)
		for player in game.players:
			player.set_physics_process(false)
		game.scores.assign([16.0,10.0,0.0,0.0])
		game.time_remaining = 38.0
		game._broadcast_snapshot(true)
		game._update_world_scoreboard()
		await create_timer(1.25,true).timeout
		game.scores[1] = 25.3
		game.time_remaining = 12.4
		game._broadcast_snapshot(true)
		game._update_world_scoreboard()
		await create_timer(1.25,true).timeout
		game.time_remaining = 0.0
		game._end_round()
		game._update_world_scoreboard()
		await create_timer(1.25,true).timeout
		game.reset_round()
		game._broadcast_snapshot(true)
		while game.active_slots.count(true) > 1:
			await create_timer(0.02,true).timeout
		game.distant_scoreboards.refresh()
		for board in game.distant_scoreboards.displays:
			assert(not board.rows[1].node.visible)
			assert(is_equal_approx(board.rows[0].node.position.x,0.0))
		print("SCORE_RIBBONS_NETWORK host passed: disconnect recenters surviving ribbon")
	else:
		game.code_input.text = "127.0.0.1:27994"
		game._join_online()
		while not game.round_running or game.time_remaining != 38.0:
			await create_timer(0.02,true).timeout
		assert(game.local_slot == 1)
		game.distant_scoreboards.refresh()
		for board in game.distant_scoreboards.displays:
			assert(board.title.text == "00:38")
			assert(board.rows[1].name.text == "YOU" and board.rows[0].name.text == "P1")
			assert(board.rows[0].value.text == "16.0")
			assert(not board.rows[2].node.visible and not board.rows[3].node.visible)
		while game.scores[1] < 25.0:
			await create_timer(0.02,true).timeout
		game.distant_scoreboards.refresh()
		for board in game.distant_scoreboards.displays:
			assert(board.title.text == "00:13")
			assert(board.rows[1].value.text == "25.3")
			assert(board.crown.visible and board.crown.position.x == board.rows[1].node.position.x)
		while game.round_running:
			await create_timer(0.02,true).timeout
		game.distant_scoreboards.refresh()
		for board in game.distant_scoreboards.displays:
			assert(board.title.text == "00:00" and board.subtitle.text == "FINAL SCORES")
			assert(board.rows[1].value.text == "25.3")
		while not game.round_running:
			await create_timer(0.02,true).timeout
		game.distant_scoreboards.refresh()
		for board in game.distant_scoreboards.displays:
			assert(board.title.text == "01:15")
			assert(not board.crown.visible)
			assert(not board.rows[0].bar.visible and not board.rows[1].bar.visible)
		print("SCORE_RIBBONS_NETWORK client passed: local badge, timer, score, leader, finish and reset via existing packets")
	game._enter_lobby()
	game.queue_free()
	await process_frame
	quit()
