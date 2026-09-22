extends SceneTree
## Deterministic pose and real-player sampling checks. Optional native preview
## captures a 9-second sequence: -- --animation-preview --diagnostics-workspace
var game: Node3D
var art: Node3D

func _initialize() -> void:
	call_deferred("run")

func pose(seconds: float, speed := 0.0, holding := false, airborne := false, stunned := false, vertical := 0.0, crouched := false, sliding := false) -> void:
	for frame in int(seconds*60):
		art.animate(1.0/60.0,speed,holding,airborne,stunned,vertical,crouched,sliding)

func reset_pose() -> void:
	art.motion.reset()
	art.phase = 0
	art.motion.clock = 0

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._start_solo()
	await process_frame
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.camera.set_process(false)
	game.camera.set_physics_process(false)
	for p in game.players:
		p.set_physics_process(false)
		p.body_mesh.get_node("Sockling").animation_enabled = false
	var player: ATIPlayer = game.players[3]
	player.set_slot_active(true)
	player.set_local_visual_hidden(false)
	art = player.body_mesh.get_node("Sockling")
	player.global_position = Vector3(0,0,3.3)
	player.body_mesh.rotation = Vector3.ZERO
	var original_position := player.global_position
	var original_velocity := player.velocity
	var collider_height: float = player.collision_shape.shape.height
	reset_pose()
	pose(0.5)
	assert(art.motion.state == &"idle" and art.motion.gait < 0.001)
	pose(1.0,3.0)
	assert(art.motion.state == &"walk" and art.motion.gait > 0.9)
	var old_phase: float = art.phase
	pose(0.1,3.0)
	assert(not is_equal_approx(art.phase,old_phase))
	pose(0.75,10.0)
	assert(art.motion.state == &"run" and art.chest.rotation.x > 0.05)
	for i in 180:
		pose(1.0/60.0,6.0)
		for leg in 2:
			var floor_y: float = art.legs[leg].position.y+art.motion.foot_bottom(leg,art.legs[leg].basis,art.leg_meshes[leg].get_blend_shape_value(0))
			assert(floor_y >= -0.821,"Stride drove foot under the visual sole plane")
	pose(0.7,5.0,true)
	assert(art.arms[0].rotation.x < -1.0 and art.arm_meshes[0].get_blend_shape_value(0) > 0.5)
	pose(0.7,3.0,false,false,false,0,true)
	assert(art.motion.state == &"crouch")
	pose(0.5,7.0,false,false,false,0,true,true)
	assert(art.motion.state == &"slide" and art.legs[0].rotation.x < -0.7)
	reset_pose()
	pose(0.2)
	pose(0.1,5.0,false,true,false,7.0)
	assert(art.motion.state == &"rise" and art.motion.launch > 0)
	pose(0.3,5.0,false,true,false,0.0)
	assert(art.motion.was_airborne and art.motion.landing == 0,"Apex was mistaken for a landing")
	pose(0.3,5.0,false,true,false,-8.0)
	assert(art.motion.state == &"fall")
	pose(0.1,3.0)
	assert(art.motion.state == &"land" and art.scale.y < 0.95)
	pose(0.6)
	assert(art.motion.landing == 0 and is_equal_approx(art.scale.y,1.0))
	pose(0.5,0,false,false,true)
	assert(art.motion.state == &"stun")
	assert(player.global_position == original_position and player.velocity == original_velocity)
	assert(player.collision_shape.shape.height == collider_height,"Animation modified collision")
	# Compare equal elapsed-time updates at common client frame rates.
	reset_pose()
	for i in 60: art.animate(1.0/30.0,6,false,false,false)
	var at_30: float = art.phase
	reset_pose()
	for i in 288: art.animate(1.0/144.0,6,false,false,false)
	assert(absf(angle_difference(at_30,art.phase)) < 0.35,"Stride is frame-rate dependent")
	# Replica support: surface contact, jump apex, and teleport reset.
	player.network_replica = true
	player.client_predicted = false
	player.simulation_enabled = true
	player.velocity = Vector3.ZERO
	await physics_frame
	assert(art.supported(),"Replica can't see floor support")
	player.global_position.y = 1.2
	assert(not art.supported(),"Replica at apex is incorrectly grounded")
	art.animation_enabled = true
	art._physics_process(1.0/60.0)
	art._process(1.0/60.0)
	assert(art.sampled_airborne)
	player.global_position.y = 0
	player.motion_epoch += 1
	art._physics_process(1.0/60.0)
	art._process(1.0/60.0)
	assert(art.motion.landing == 0 and art.sampled_speed == 0,"Teleport generated a fake landing/stride")
	player.set_network_invisibility(3)
	art._physics_process(1.0/60.0)
	assert(not art.tracking and not art.is_visible_in_tree())
	player.set_network_invisibility(0)
	art._physics_process(1.0/60.0)
	assert(art.tracking)
	art.animation_enabled = false
	reset_pose()
	if "--animation-preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await preview(player)
	game._prepare_session()
	game.queue_free()
	await process_frame
	print("SOCKLING_ANIMATION PASS: stride, sole contact, carry, crouch/slide, rise/apex/fall/land, stun, FPS, replica support, teleport/invisibility reset, unchanged physics")
	quit()

func preview(player: ATIPlayer) -> void:
	for prop in game._sorted_obstacles():
		prop.freeze = true
		prop.hide()
	game.get_node("HUD").hide()
	game.get_node("Arena/IslandDisplay").hide()
	game.get_node("DistantScoreboards").hide()
	player.set_has_token(false)
	for p in game.players:
		p.visible = p == player
		p.name_label.hide()
		p.token_marker.hide()
	game.camera.fov = 45
	game.camera.position = Vector3(3.4,2.5,7.5)
	game.camera.look_at(Vector3(0,1.55,3.3))
	DirAccess.make_dir_recursive_absolute("res://build/network-test/sockling-animation-frames")
	for frame in 270:
		var t := frame/30.0
		var speed := 0.0
		var holding := false
		var flying := false
		var vertical := 0.0
		var crouched := false
		var sliding := false
		player.position.y = -0.05
		if t >= 1 and t < 2.5: speed = 3
		if t >= 2.5 and t < 4: speed = 8
		if t >= 4 and t < 4.71:
			var jump_t := t-4
			flying = true
			speed = 6
			vertical = 8.5-jump_t*24
			player.position.y = -0.05+maxf(0,8.5*jump_t-12*jump_t*jump_t)
		if t >= 5.3 and t < 6.3:
			holding = true
			speed = 3
		if t >= 6.3 and t < 7.0:
			crouched = true
			speed = 2
		if t >= 7.0 and t < 7.6:
			crouched = true
			sliding = true
			speed = 7
		player._set_crouched(crouched)
		art.animate(1.0/30.0,speed,holding,flying,t>=8.0,vertical,crouched,sliding)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/network-test/sockling-animation-frames/frame-%03d.png" % frame)
