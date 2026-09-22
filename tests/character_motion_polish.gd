extends SceneTree
## Both visual rigs: continuous foot turns, weight shift, complete reset, and
## optional native in-level captures (--motion-preview). No physics changes.
const MOTION := preload("res://scripts/sockling_motion.gd")
var game: Node3D
var completed := false

func _initialize() -> void:
	call_deferred("run")
	create_timer(90.0, true).timeout.connect(func():
		if not completed:
			push_error("CHARACTER_MOTION_POLISH timeout")
			quit(1))

func advance(model: Node3D, seconds: float, speed: float, airborne := false, vertical := 0.0) -> void:
	for frame in roundi(seconds * 120.0):
		model.animate(1.0 / 120.0, speed, false, airborne, false, vertical)

func run() -> void:
	# The foot path now has zero-speed turns and a soft lift/landing tangent.
	var epsilon := 0.0001
	for turn in [0.0, 0.56]:
		var center: Vector2 = MOTION.stride_sample(turn)
		var before: Vector2 = MOTION.stride_sample(turn - epsilon)
		var after: Vector2 = MOTION.stride_sample(turn + epsilon)
		assert(before.distance_to(center) / epsilon < 0.02 and after.distance_to(center) / epsilon < 0.02, "Foot direction/lift has an abrupt velocity corner")
	for sample in 1000:
		var step: Vector2 = MOTION.stride_sample(sample / 1000.0)
		assert(step.is_finite() and absf(step.x) <= 1.0001 and step.y >= 0 and step.y <= 1.0001)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.camera.set_process(false)
	game.camera.set_physics_process(false)
	for player in game.players: player.set_physics_process(false)
	for slot in 2:
		var player: ATIPlayer = game.players[slot]
		player.set_character_skin(&"sockling" if slot == 0 else &"looper")
		player.set_slot_active(true)
		player.set_local_visual_hidden(false)
		var model: Node3D = player.character_model()
		model.animation_enabled = false
		var original_position := player.position
		var original_velocity := player.velocity
		var original_collider: Shape3D = player.collision_shape.shape
		model.motion.reset()
		advance(model, 0.15, 7)
		assert(model.motion.acceleration > 1.0, "Start has no forward weight shift")
		advance(model, 1.0, 7)
		advance(model, 0.15, 0)
		assert(model.motion.acceleration < -1.0, "Braking has no counterbalance")
		advance(model, 2.0, 0)
		assert(absf(model.motion.acceleration) < 0.01, "Braking lean did not settle")
		for frame in 720:
			model.animate(1.0 / 120.0, 7, false, false, false)
			for leg in 2:
				var floor_y: float = model.legs[leg].position.y + model.motion.foot_bottom(leg, model.legs[leg].basis, model.leg_meshes[leg].get_blend_shape_value(0))
				assert(floor_y >= -0.821, "Smoothed step penetrated the sole plane")
		advance(model, 0.12, 5, true, 7)
		advance(model, 0.28, 5, true, -8)
		advance(model, 0.1, 5)
		assert(model.motion.state == &"land")
		for limb in model.arms:
			assert(limb.rotation.is_finite())
		# Teleports, unhide and model swaps must not leave a closed eyelid, open
		# jaw or bent Looper loop behind after the shared pose has been reset.
		for eye in model.eyes: eye.scale.y = 0.09
		if slot == 0:
			model.jaw.rotation.x = 0.2
			model.sculpt_body.set_blend_shape_value(0, 0.8)
		else:
			model.loop_spring = Vector2(0.2, 2.0)
			model.loop_pivot.rotation.z = 0.2
		model.motion.reset()
		assert(model.motion.clock == 0 and model.motion.acceleration == 0)
		for eye in model.eyes: assert(is_equal_approx(eye.scale.y, 1))
		if slot == 0:
			assert(model.jaw.rotation == Vector3.ZERO and model.sculpt_body.get_blend_shape_value(0) == 0)
		else:
			assert(model.loop_spring == Vector2.ZERO and model.loop_pivot.rotation == Vector3.ZERO)
		assert(player.position == original_position and player.velocity == original_velocity and player.collision_shape.shape == original_collider)
	if "--motion-preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await preview()
	game._prepare_session()
	game.queue_free()
	await process_frame
	completed = true
	print("CHARACTER_MOTION_POLISH PASS: both skins; continuous step reversals/lift; acceleration/braking settle; sole contact; landing; blink/jaw/loop reset; unchanged physics")
	quit()

func preview() -> void:
	# Let the camera's startup deferred first-person hide complete before staging
	# the local actor beside the opponent for this external inspection camera.
	await process_frame
	for layer in game.find_children("*", "CanvasLayer", true, false): layer.hide()
	for prop in game._sorted_obstacles():
		prop.freeze = true
		prop.hide()
	game.get_node("Arena/IslandDisplay").hide()
	game.get_node("DistantScoreboards").hide()
	for player in game.players:
		player.visible = player.player_index < 2
		player.set_local_visual_hidden(false)
		player.set_has_token(false)
		player.name_label.hide()
		player.token_marker.hide()
		player.body_mesh.rotation = Vector3.ZERO
		player.character_model().animation_enabled = false
		player.character_model().motion.reset()
		player.character_model().phase = 0
	game.camera.fov = 42
	game.camera.position = Vector3(3.2, 2.15, 8.2)
	game.camera.look_at(Vector3(0, 1.45, 3.3))
	var captions := CanvasLayer.new()
	root.add_child(captions)
	var text := Label.new()
	captions.add_child(text)
	text.position = Vector2(32, 665)
	text.add_theme_font_size_override("font_size", 26)
	text.add_theme_color_override("font_color", Color("fff1d1"))
	text.add_theme_color_override("font_outline_color", Color("214f39"))
	text.add_theme_constant_override("outline_size", 6)
	DirAccess.make_dir_recursive_absolute("res://build/network-test/character-motion-frames")
	var contact_sheet := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	var sample_frames := [20, 55, 95, 130, 145, 173, 197, 219, 249]
	for frame in 270:
		var t := frame / 30.0
		var speed := 0.0
		var holding := false
		var flying := false
		var vertical := 0.0
		var crouched := false
		var sliding := false
		var height := -0.05
		var title := "IDLE"
		if t >= 1 and t < 2.5:
			speed = 3
			title = "WALK"
		if t >= 2.5 and t < 4:
			speed = 8
			title = "RUN"
		if t >= 4 and t < 4.71:
			var jump_t := t - 4
			flying = true
			speed = 6
			vertical = 8.5 - jump_t * 24
			height += maxf(0, 8.5 * jump_t - 12 * jump_t * jump_t)
			title = "JUMP"
		if t >= 4.71 and t < 5.3: title = "LAND / SETTLE"
		if t >= 5.3 and t < 6.3:
			holding = true
			speed = 3
			title = "CARRY"
		if t >= 6.3 and t < 7:
			crouched = true
			speed = 2
			title = "CROUCH"
		if t >= 7 and t < 7.6:
			crouched = true
			sliding = true
			speed = 7
			title = "SLIDE"
		if t >= 8: title = "STUN"
		for slot in 2:
			var player: ATIPlayer = game.players[slot]
			player.position = Vector3(-0.8 + slot * 1.6, height, 3.3)
			player._set_crouched(crouched)
			player.character_model().animate(1.0 / 30.0, speed, holding, flying, t >= 8, vertical, crouched, sliding)
		text.text = "SOCKLING + LOOPER  ·  " + title + "  ·  NATIVE GODOT CAPTURE"
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		assert(shot.save_png("res://build/network-test/character-motion-frames/frame-%03d.png" % frame) == OK)
		if frame in sample_frames:
			var index := sample_frames.find(frame)
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(640, 360, Image.INTERPOLATE_LANCZOS)
			contact_sheet.blit_rect(shot, Rect2i(0, 0, 640, 360), Vector2i(index % 3 * 640, index / 3 * 360))
	assert(contact_sheet.save_png("res://build/network-test/character-motion-contact-sheet.png") == OK)
	captions.queue_free()
