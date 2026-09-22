extends SceneTree
const EFFECT := preload("res://scripts/chaos_effect.gd")
var game: Node3D

func _initialize() -> void:
	call_deferred("run")
	create_timer(25.0).timeout.connect(func():
		push_error("DECOY_SKIN timeout")
		quit(1))

func verify(decoy: Node3D, source: ATIPlayer) -> Node3D:
	var visual = decoy.decoy_body.get_node("DecoyCharacter")
	var original = source.body_mesh.get_node("Sockling")
	assert(visual.model.get_script() == original.get_script(), "Decoy is not using the real player skin")
	assert(visual.position == Vector3(0, 0.85, 0) and visual.scale == Vector3.ONE, "Decoy size differs from standing player")
	assert(visual.model.fleece.get_shader_parameter("fleece_color") == original.fleece.get_shader_parameter("fleece_color"))
	assert(visual.model.fleece != original.fleece, "Decoy must have independent materials")
	assert(visual.model.actor == null, "Decoy must not inherit owner hiding or input")
	assert(visual.model.sculpt_body.mesh == original.sculpt_body.mesh)
	assert(visual.model.arm_meshes[0].mesh == original.arm_meshes[0].mesh)
	assert(visual.model.arm_skeletons[0] != original.arm_skeletons[0])
	assert(visual.find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(visual.model.is_visible_in_tree())
	return visual

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._start_solo()
	game.set_physics_process(false)
	game.active_slots.assign([true, true, true, true])
	for slot in 4:
		var source: ATIPlayer = game.players[slot]
		source.set_physics_process(false)
		source.set_character_skin(&"sockling") # Keep this four-color Sockling clone fixture deterministic.
		source.set_slot_active(true)
		source.global_position = Vector3(-5 + slot * 2.5, -0.05, 3.5)
		source.network_controlled = true
		source.network_aim_forward = Vector3.RIGHT if slot % 2 == 0 else Vector3.FORWARD
		source._use_chaos_effect(&"decoy_double")
		var decoy: Node3D = get_nodes_in_group("chaos_decoy").back()
		decoy.set_physics_process(false)
		var visual = verify(decoy, source)
		assert(source.is_invisible() and not source.body_mesh.visible)
		assert(decoy.remaining == 4.0 and decoy.decoy_body.collision_layer == 0)
		assert(decoy.basis.z.dot(source.network_aim_forward) > 0.999, "Decoy faces away from its path")
		# Reconstruct exactly as a real client's temporary-effect path does.
		var replica := EFFECT.new()
		game.add_child(replica)
		game._disable_remote_item_physics(replica)
		replica.global_position = decoy.global_position
		replica.apply_state(decoy.network_state())
		var remote = verify(replica, source)
		assert(replica.decoy_body.collision_mask == 0 and replica.basis.z.dot(decoy.basis.z) > 0.999)
		var identity: int = remote.model.get_instance_id()
		for frame in 60:
			replica.global_position += Vector3.RIGHT * (6.2 / 60.0)
			remote._physics_process(1.0 / 60.0)
			remote._process(1.0 / 60.0)
		assert(remote.model.motion.gait > 0.9 and remote.model.arm_skeletons[0].get_bone_pose_rotation(1) != Quaternion.IDENTITY)
		replica.apply_state(decoy.network_state())
		assert(remote.model.get_instance_id() == identity, "Snapshot rebuilt the entire model")
		for frame in 120:
			remote._physics_process(1.0 / 60.0)
			remote._process(1.0 / 60.0)
		assert(remote.model.motion.gait < 0.01, "Stopped decoy kept running")
		remote.model.fleece.set_shader_parameter("stunned", 1.0)
		assert(source.body_mesh.get_node("Sockling").fleece.get_shader_parameter("stunned") != 1.0)
		assert(source.buddy_hide_time == 4.0, "Decoy animation changed the owner's ability timer")
		replica.queue_free()
		# Keep one pair for a real game-lighting comparison; restore owner only
		# in the staged inspection, never in the actual ability implementation.
		if slot == 3 and "--decoy-preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await preview(source, decoy, visual)
		decoy._physics_process(4.1)
		assert(decoy.is_queued_for_deletion(), "Decoy failed to expire")
		await process_frame
	game._prepare_session()
	for player in game.players:
		for audio_player in player.sfx_players: audio_player.stop()
	game.queue_free()
	await process_frame
	print("DECOY_SKIN PASS: four owner skins, rig/material isolation, full-size model, facing, invisibility, replica reconstruction, animation, stopped idle, expiry")
	quit()

func preview(source: ATIPlayer, decoy: Node3D, visual: Node3D) -> void:
	game.set_process(false)
	for layer in game.find_children("*", "CanvasLayer", true, false): layer.hide()
	for prop in game._sorted_obstacles():
		prop.freeze = true
		prop.hide()
	game.get_node("HUD").hide()
	game.get_node("Arena/IslandDisplay").hide()
	game.get_node("DistantScoreboards").hide()
	for player in game.players:
		player.visible = player == source
		source.name_label.hide()
		source.token_marker.hide()
	source.buddy_hide_time = 0
	source.set_local_visual_hidden(false)
	source.name_label.hide()
	source.token_marker.hide()
	source.global_position = Vector3(-0.9, -0.05, 3.3)
	source.body_mesh.rotation = Vector3.ZERO
	decoy.global_position = Vector3(0.9, -0.05, 3.3)
	decoy.rotation = Vector3.ZERO
	decoy.label.hide()
	visual.set_process(false)
	visual.set_physics_process(false)
	var original = source.body_mesh.get_node("Sockling")
	original.animation_enabled = false
	for model in [original, visual.model]:
		model.motion.reset()
		model.phase = 0
		model.motion.clock = 0
		for frame in 90: model.animate(1.0/60.0, 0, false, false, false)
	game.camera.set_process(false)
	game.camera.set_physics_process(false)
	game.camera.fov = 38
	game.camera.position = Vector3(0, 1.7, 8.0)
	game.camera.look_at(Vector3(0, 0.85, 3.3))
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/network-test/decoy-skin.png")
