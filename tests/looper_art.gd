extends SceneTree
## Real player model checks and native engine captures; no generated/rendered
## replacement artwork. --looper-preview saves poses and reference comparison.
## --looper-animation-preview saves 270 actual frames for a nine-second clip.
const COLORS := [Color("88749e"), Color("9980a7"), Color("79729e"), Color("a5809e")]
var game: Node3D
var art: Node3D
var done := false

func _initialize() -> void:
	call_deferred("run")
	var preview_requested := "--looper-preview" in OS.get_cmdline_user_args() or "--looper-animation-preview" in OS.get_cmdline_user_args()
	create_timer(90.0 if preview_requested else 35.0).timeout.connect(func():
		if not done:
			push_error("LOOPER_ART watchdog: test or capture did not finish")
			quit(1))

func pose(seconds: float, speed := 0.0, holding := false, airborne := false, stunned := false, vertical := 0.0, crouched := false, sliding := false) -> void:
	for frame in maxi(1, roundi(seconds * 60)):
		art.animate(1.0 / 60.0, speed, holding, airborne, stunned, vertical, crouched, sliding)

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
	game.active_slots.assign([true, true, true, true])
	var materials: Array = []
	var geometry_counts: Array[int] = []
	for slot in 4:
		var player: ATIPlayer = game.players[slot]
		player.set_physics_process(false)
		player.set_slot_active(true)
		player.set_local_visual_hidden(false)
		# Both choices remain valid; Looper is an added skin, not a Sockling replacement.
		player.set_character_skin(&"sockling")
		assert(player.character_model().get_script() == load("res://scripts/sockling_art.gd"))
		var original_collider: Shape3D = player.collision_shape.shape
		var original_collider_transform := player.collision_shape.transform
		player.set_character_skin(&"looper")
		art = player.character_model()
		assert(art.get_script() == load("res://scripts/looper_art.gd"))
		art.animation_enabled = false
		assert(player.body_mesh.mesh == null)
		assert(player.body_mesh.position == Vector3(0, 0.85, 0))
		assert(player.collision_shape.shape == original_collider and player.collision_shape.transform == original_collider_transform, "Character selection changed the collider")
		assert(is_equal_approx(player.collision_shape.shape.radius, 0.45) and is_equal_approx(player.collision_shape.shape.height, 1.6))
		assert(art.find_children("*", "CollisionObject3D", true, false).is_empty(), "Cosmetic character added physics bodies")
		assert(art.fleece.get_shader_parameter("fleece_color") == COLORS[slot], "Looper lost the soft violet family palette")
		assert(not materials.has(art.fleece), "Player skin materials are shared mutable state")
		materials.append(art.fleece)
		assert(art.skin_materials.size() >= 2)
		assert(art.eyes.size() == 2 and art.arm_skeletons.size() == 2 and art.leg_meshes.size() == 2)
		for limb in art.arm_meshes:
			assert(limb.skin != null and limb.skin.get_bind_count() == 3, "Looper arms need elbow and wrist skinning")
			assert(limb.mesh.get_blend_shape_count() == 0)
			assert(limb.get_node(limb.skeleton) is Skeleton3D)
		for limb in art.leg_meshes:
			assert(limb.mesh.get_blend_shape_count() == 1 and limb.mesh.get_blend_shape_name(0) == "KneeFlex")
		var triangles := check_geometry(art)
		geometry_counts.append(triangles)
		assert(triangles < 100000, "Looper exceeds the base geometry budget")
		# Actual open top loop, not a painted dark circle or solid head crest.
		check_open_loop()
		check_face_and_ankles()
		player.set_network_invisibility(5.0)
		assert(not art.is_visible_in_tree())
		player.set_network_invisibility(0)
		player.set_local_visual_hidden(true)
		assert(not art.is_visible_in_tree())
		player.set_local_visual_hidden(false)
		player.buddy_hide_time = 4
		player._refresh_character_visuals()
		assert(not art.is_visible_in_tree())
		player.buddy_hide_time = 0
		player._refresh_character_visuals()
		assert(art.is_visible_in_tree())
		player.global_position = Vector3((slot - 1.5) * 1.55, 0, 3.3)
		player.body_mesh.rotation = Vector3.ZERO
		reset_pose()
		pose(0.15, 7, false, false, true)
		for material in art.skin_materials:
			assert(material.get_shader_parameter("stunned") == 1.0)
		pose(0.15)
		for material in art.skin_materials:
			assert(material.get_shader_parameter("stunned") == 0.0)
	await process_frame # Retired character nodes from skin switching must free.
	for player in game.players:
		assert(player.body_mesh.get_child_count() == 1, "Switching skins left duplicate character models")
	check_shared_caches()
	await process_frame
	var featured: ATIPlayer = game.players[0]
	art = featured.character_model()
	featured.global_position = Vector3(0, 0, 3.3)
	await check_motion(featured)
	if DisplayServer.get_name() != "headless":
		if "--looper-preview" in OS.get_cmdline_user_args(): await preview(featured)
		if "--looper-animation-preview" in OS.get_cmdline_user_args(): await animation_preview(featured)
	game._prepare_session()
	game.queue_free()
	await process_frame
	done = true
	print("LOOPER_ART PASS: 4 selectable palettes; retained Sockling; real open loop; sleepy eyes/smile/cream ankles; finite geometry ", geometry_counts, "; shared arm/fibre caches across clones and skin switches; GPU arms; KneeFlex legs; walk/run/carry/jump/crouch/slide/stun; hiding and replica resets; unchanged physics")
	quit()

func check_shared_caches() -> void:
	var original: Node3D = game.players[0].character_model()
	var meshes := [original.arm_meshes[0].mesh, original.arm_meshes[1].mesh]
	var fibres := {}
	for nap in original.find_children("*", "MultiMeshInstance3D", true, false):
		fibres[original.get_path_to(nap)] = nap.multimesh
	assert(not fibres.is_empty(), "Looper has no close-up velvet fibres")
	var rig = load("res://scripts/sockling_arm_rig.gd")
	var nap_cache = load("res://scripts/looper_nap.gd")
	var weighted_before: int = rig.weighted_meshes.size()
	var fibres_before: int = nap_cache.fields.size()
	var comparisons: Array = []
	for player in game.players: comparisons.append(player.character_model())
	# Standalone models exercise the exact catalog path used by Decoy Double.
	for iteration in 3:
		var clone: Node3D = load("res://scripts/character_catalog.gd").create(&"looper")
		clone.animation_enabled = false
		game.add_child(clone)
		clone.hide()
		comparisons.append(clone)
	for model in comparisons:
		for index in 2:
			assert(model.arm_meshes[index].mesh == meshes[index], "Looper reloaded a source arm instead of reusing weighted geometry")
		for path in fibres:
			assert(model.get_node(path).multimesh == fibres[path], "Looper rebuilt a shared velvet fibre field")
		if model != original:
			assert(model.arm_skeletons[0] != original.arm_skeletons[0] and model.fleece != original.fleece, "Shared geometry must not share poses or materials")
	for model in comparisons:
		if model.actor == null: model.free()
	var player: ATIPlayer = game.players[0]
	player.set_character_skin(&"sockling")
	player.set_character_skin(&"looper")
	var replacement: Node3D = player.character_model()
	replacement.animation_enabled = false
	assert(replacement.arm_meshes[0].mesh == meshes[0] and replacement.arm_meshes[1].mesh == meshes[1], "Skin switching rebuilt cached arms")
	for path in fibres:
		assert(replacement.get_node(path).multimesh == fibres[path], "Skin switching rebuilt velvet fibres")
	assert(rig.weighted_meshes.size() == weighted_before and nap_cache.fields.size() == fibres_before, "Repeated Looper creation grew the immutable geometry caches")

func check_geometry(model: Node3D) -> int:
	var triangles := 0
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		assert(mesh.mesh != null and mesh.mesh.get_aabb().size.is_finite())
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			assert(not vertices.is_empty())
			for point in vertices: assert(point.is_finite())
			triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else vertices.size()) / 3
	return triangles

func check_open_loop() -> void:
	var loop: MeshInstance3D = art.top_loop if art.top_loop is MeshInstance3D else art.top_loop.find_children("*", "MeshInstance3D", true, false)[0]
	var bounds: AABB = loop.mesh.get_aabb()
	assert(bounds.size.x > 0.2 and bounds.size.y > 0.2 and bounds.size.z > 0.03, "Head loop lost its volumetric silhouette")
	var center := bounds.get_center()
	assert(not ray_hits_mesh(loop.mesh, center), "Loop aperture is filled by triangles")
	var rim_hits := 0
	for horizontal in [-0.45, -0.40, -0.35, 0.35, 0.40, 0.45]:
		if ray_hits_mesh(loop.mesh, center + Vector3.RIGHT * bounds.size.x * horizontal): rim_hits += 1
	assert(rim_hits >= 2, "Loop aperture has no enclosing sides")

func ray_hits_mesh(mesh: Mesh, xy: Vector3) -> bool:
	var origin := Vector3(xy.x, xy.y, mesh.get_aabb().end.z + 1.0)
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var total := indices.size() if not indices.is_empty() else points.size()
		for index in range(0, total, 3):
			var a := indices[index] if not indices.is_empty() else index
			var b := indices[index + 1] if not indices.is_empty() else index + 1
			var c := indices[index + 2] if not indices.is_empty() else index + 2
			if Geometry3D.ray_intersects_triangle(origin, Vector3.FORWARD, points[a], points[b], points[c]) != null: return true
	return false

func check_face_and_ankles() -> void:
	assert(art.find_children("*Lid*", "MeshInstance3D", true, false).size() >= 2, "Missing heavy sleepy eyelids")
	assert(not art.find_children("*Smile*", "MeshInstance3D", true, false).is_empty(), "Missing relaxed smiling mouth")
	var ankle_surfaces := 0
	for leg in art.leg_meshes:
		for surface in leg.mesh.get_surface_count():
			var source_material: Material = leg.mesh.surface_get_material(surface)
			if source_material == null or not "Cuff" in source_material.resource_name: continue
			ankle_surfaces += 1
			var material: Material = leg.get_active_material(surface)
			var color: Color = material.get_shader_parameter("fleece_color") if material is ShaderMaterial else material.albedo_color
			assert(color.r > 0.65 and color.g > 0.6 and color.r > color.b, "Ankle material lost the warm cream color")
	assert(ankle_surfaces >= 2, "Looper needs contrasting cream sock ankles")

func check_motion(player: ATIPlayer) -> void:
	var original_position := player.global_position
	var original_velocity := player.velocity
	var collider_height: float = player.collision_shape.shape.height
	reset_pose()
	pose(0.5)
	assert(art.motion.state == &"idle" and art.motion.gait < 0.001)
	pose(1.0, 3)
	assert(art.motion.state == &"walk" and art.motion.gait > 0.9)
	var old_phase: float = art.phase
	pose(0.1, 3)
	assert(not is_equal_approx(art.phase, old_phase))
	pose(0.75, 10)
	assert(art.motion.state == &"run" and art.chest.rotation.x > 0.05)
	for frame in 180:
		pose(1.0 / 60.0, 6)
		for leg in 2:
			var floor_y: float = art.legs[leg].position.y + art.motion.foot_bottom(leg, art.legs[leg].basis, art.leg_meshes[leg].get_blend_shape_value(0))
			assert(floor_y >= -0.821, "Stride drove foot under the visual sole plane")
	pose(0.7, 5, true)
	assert(art.arms[0].rotation.x < -0.7 and art.arm_skeletons[0].get_bone_pose_rotation(1).get_euler().x < -0.75)
	pose(0.7, 3, false, false, false, 0, true)
	assert(art.motion.state == &"crouch")
	pose(0.5, 7, false, false, false, 0, true, true)
	assert(art.motion.state == &"slide" and art.legs[0].rotation.x < -0.7)
	reset_pose()
	pose(0.2)
	pose(0.1, 5, false, true, false, 7)
	assert(art.motion.state == &"rise" and art.motion.launch > 0)
	pose(0.3, 5, false, true, false, 0)
	assert(art.motion.was_airborne and art.motion.landing == 0, "Jump apex was mistaken for landing")
	pose(0.3, 5, false, true, false, -8)
	assert(art.motion.state == &"fall")
	pose(0.1, 3)
	assert(art.motion.state == &"land" and art.scale.y < 0.95)
	pose(0.6)
	assert(art.motion.landing == 0 and is_equal_approx(art.scale.y, 1))
	pose(0.5, 0, false, false, true)
	assert(art.motion.state == &"stun")
	assert(player.global_position == original_position and player.velocity == original_velocity)
	assert(player.collision_shape.shape.height == collider_height, "Animation modified collision")
	reset_pose()
	for frame in 60: art.animate(1.0 / 30.0, 6, false, false, false)
	var at_30: float = art.phase
	reset_pose()
	for frame in 288: art.animate(1.0 / 144.0, 6, false, false, false)
	assert(absf(angle_difference(at_30, art.phase)) < 0.35, "Stride is frame-rate dependent")
	player.network_replica = true
	player.client_predicted = false
	player.simulation_enabled = true
	player.velocity = Vector3.ZERO
	await physics_frame
	assert(art.supported(), "Replica cannot detect floor support")
	player.global_position.y = 1.2
	assert(not art.supported(), "Replica jump apex is incorrectly grounded")
	art.animation_enabled = true
	art._physics_process(1.0 / 60.0)
	art._process(1.0 / 60.0)
	assert(art.sampled_airborne)
	player.global_position.y = 0
	player.motion_epoch += 1
	art._physics_process(1.0 / 60.0)
	art._process(1.0 / 60.0)
	assert(art.motion.landing == 0 and art.sampled_speed == 0, "Teleport created a fake landing or stride")
	player.set_network_invisibility(3)
	art._physics_process(1.0 / 60.0)
	assert(not art.tracking and not art.is_visible_in_tree())
	player.set_network_invisibility(0)
	art._physics_process(1.0 / 60.0)
	assert(art.tracking)
	art.animation_enabled = false
	reset_pose()

func stage(player: ATIPlayer) -> void:
	for layer in game.find_children("*", "CanvasLayer", true, false): layer.hide()
	for prop in game._sorted_obstacles():
		prop.freeze = true
		prop.hide()
	game.get_node("Arena/IslandDisplay").hide()
	game.get_node("DistantScoreboards").hide()
	player.set_has_token(false)
	for other in game.players:
		other.visible = other == player
		other.name_label.hide()
		other.token_marker.hide()
	player.global_position = Vector3(0, -0.05, 3.3)
	player.body_mesh.rotation = Vector3.ZERO
	game.camera.fov = 34
	DirAccess.make_dir_recursive_absolute("res://build/network-test")
	reset_pose()
	pose(1.5)

func preview(player: ATIPlayer) -> void:
	stage(player)
	game.camera.position = Vector3(-1.8, 1.62, 7.5)
	game.camera.look_at(Vector3(0, 0.95, 3.3))
	await capture("looper-reference-angle")
	await reference_comparison()
	game.camera.position = Vector3(0, 1.2, 7.5)
	game.camera.look_at(Vector3(0, 0.95, 3.3))
	await capture("looper-front")
	game.camera.position = Vector3(-3.4, 1.4, 4.4)
	game.camera.look_at(Vector3(0, 0.95, 3.3))
	await capture("looper-side")
	game.camera.position = Vector3(2.4, 1.7, 7.0)
	game.camera.look_at(Vector3(0, 0.95, 3.3))
	await capture("looper-three-quarter")
	pose(0.8, 0, true)
	await capture("looper-holding")
	reset_pose()
	pose(1.5, 8)
	await capture("looper-run")
	for slot in 4:
		var other: ATIPlayer = game.players[slot]
		other.visible = true
		other.global_position = Vector3((slot - 1.5) * 1.45, -0.05, 3.3)
		other.character_model().motion.reset()
		for frame in 90: other.character_model().animate(1.0 / 60.0, 0, false, false, false)
	game.camera.fov = 68
	game.camera.position = Vector3(0, 1.6, 6.1)
	game.camera.look_at(Vector3(0, 0.95, 3.3))
	await capture("looper-lineup")

func capture(title: String) -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://build/network-test/" + title + ".png")
	assert(result == OK, "Failed to save native Looper capture")

func reference_comparison() -> void:
	var sheet := CanvasLayer.new()
	root.add_child(sheet)
	var paper := ColorRect.new()
	paper.color = Color("efe4d3")
	paper.size = Vector2(584, 720)
	sheet.add_child(paper)
	var title_bar := ColorRect.new()
	title_bar.color = paper.color
	title_bar.size = Vector2(1280, 105)
	sheet.add_child(title_bar)
	var reference := TextureRect.new()
	var crop := AtlasTexture.new()
	crop.atlas = load("res://docs/art/socklings/approved-roster.png")
	crop.region = Rect2(1030, 550, 496, 441)
	reference.texture = crop
	reference.position = Vector2(16, 121)
	reference.size = Vector2(552, 492)
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sheet.add_child(reference)
	for entry in [["APPROVED LOOPER CONCEPT", Vector2(25, 52)], ["CURRENT GODOT MODEL", Vector2(655, 52)]]:
		var label := Label.new()
		label.text = entry[0]
		label.position = entry[1]
		label.add_theme_font_size_override("font_size", 25)
		label.add_theme_color_override("font_color", Color("203b33"))
		sheet.add_child(label)
	var note := Label.new()
	note.text = "Actual game mesh, materials and lighting. No paint-over."
	note.position = Vector2(605, 665)
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", Color("203b33"))
	sheet.add_child(note)
	game.camera.h_offset = -1.04
	await capture("looper-reference-comparison")
	game.camera.h_offset = 0
	sheet.queue_free()
	await process_frame

func animation_preview(player: ATIPlayer) -> void:
	stage(player)
	game.camera.fov = 40
	game.camera.position = Vector3(3.4, 2.5, 7.5)
	game.camera.look_at(Vector3(0, 1.55, 3.3))
	DirAccess.make_dir_recursive_absolute("res://build/network-test/looper-animation-frames")
	for frame in 270:
		var t := frame / 30.0
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
			var jump_t := t - 4
			flying = true
			speed = 6
			vertical = 8.5 - jump_t * 24
			player.position.y = -0.05 + maxf(0, 8.5 * jump_t - 12 * jump_t * jump_t)
		if t >= 5.3 and t < 6.3:
			holding = true
			speed = 3
		if t >= 6.3 and t < 7:
			crouched = true
			speed = 2
		if t >= 7 and t < 7.6:
			crouched = true
			sliding = true
			speed = 7
		player._set_crouched(crouched)
		art.animate(1.0 / 30.0, speed, holding, flying, t >= 8, vertical, crouched, sliding)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://build/network-test/looper-animation-frames/frame-%03d.png" % frame) == OK)
	player._set_crouched(false)
