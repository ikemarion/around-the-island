extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	await process_frame
	await physics_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	main.active_slots.assign([true,true,true,true])
	var materials: Array = []
	for index in 4:
		var player: ATIPlayer = main.players[index]
		player.set_physics_process(false)
		player.set_slot_active(true)
		player.set_local_visual_hidden(false)
		player.global_position = Vector3((index-1.5)*1.55,-0.05,3.3)
		player.body_mesh.rotation = Vector3.ZERO
		var art = player.body_mesh.get_node("Sockling")
		art.animation_enabled = false
		assert(player.body_mesh.mesh == null)
		assert(is_equal_approx(player.collision_shape.shape.radius,0.45))
		assert(is_equal_approx(player.collision_shape.shape.height,1.6))
		assert(art.find_children("*","CollisionObject3D",true,false).is_empty())
		assert(art.has_node("Puppet/Head/UpperMuzzle"))
		assert(art.sculpt_body.mesh.get_blend_shape_count() == 1)
		assert(art.sculpt_body.mesh.get_blend_shape_name(0) == "JawOpen")
		assert(art.sculpt_body.mesh.get_aabb().size.x > 0.63,"Keep the broad reference muzzle")
		assert(art.eyes[0].get_node("IvoryEye").scale.x < 0.15,"Eyes should be small and embedded, not stalk-like")
		assert(art.arm_meshes[0].mesh.get_aabb().size.y > 0.70,"Keep long soft arms in their relaxed hanging bind pose")
		assert(art.arm_meshes[0].mesh.get_aabb().size.x < 0.42,"Arms should not be sculpted into a permanent wide reach")
		assert(art.sculpt_body.has_node("CloseUpFleece"))
		assert(art.sculpt_body.get_node("CloseUpFleece").visibility_range_end == 7.0)
		assert(art.skin_materials.size() == 3)
		for limb in art.arm_meshes:
			assert(limb.skin != null and limb.skin.get_bind_count() == 3)
			assert(limb.mesh.get_blend_shape_count() == 0,"Arms now use fixed-length skeletal bends")
		for limb in art.leg_meshes:
			assert(limb.mesh.get_blend_shape_name(0) == "KneeFlex")
		assert(art.has_node("Puppet/Head/LowerJaw/Tongue"))
		assert(art.has_node("Puppet/KnittedWaistband/RibbedCuff"))
		assert(not materials.has(art.fleece))
		assert(art.find_children("*","MeshInstance3D",true,false).size() < 70)
		materials.append(art.fleece)
		var triangles := 0
		for mesh in art.find_children("*","MeshInstance3D",true,false):
			assert(mesh.mesh != null and mesh.mesh.get_aabb().size.is_finite())
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
		assert(triangles < 100000,"Base sculpt should stay within its geometry budget")
		var tips := 0
		for nap in art.find_children("*","MultiMeshInstance3D",true,false):
			tips += nap.multimesh.instance_count
		assert(tips == 5800)
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
		player._set_crouched(true)
		assert(player.body_mesh.scale.y < 1)
		player._set_crouched(false)
		assert(player.body_mesh.scale.y == 1)
		art.animate(0.15,7.0,false,false,true)
		assert(art.fleece.get_shader_parameter("stunned") == 1.0)
		for skin in art.skin_materials:
			assert(skin.get_shader_parameter("stunned") == 1.0)
		for frame in 45: art.animate(1.0/60.0,7.0,true,false,false)
		assert(art.arms[0].rotation.x < -0.7)
		assert(art.arm_skeletons[0].get_bone_pose_rotation(1).get_euler().x < -0.75)
		assert(art.fleece.get_shader_parameter("stunned") == 0.0)
		art.animate(0.2,4.0,false,false,false)
		assert(art.sculpt_body.get_blend_shape_value(0) > 0.0)
	if DisplayServer.get_name() != "headless":
		# Staged model captures in the actual level; keep nearby loose boxes
		# from rolling into the character showcase while physics is suspended.
		for prop in main._sorted_obstacles():
			prop.freeze = true
			prop.hide()
		main.get_node("HUD").hide()
		main.get_node("Arena/IslandDisplay").hide()
		main.get_node("DistantScoreboards").hide()
		main.camera.fov = 34
		for player in main.players:
			player.name_label.hide()
			player.token_marker.hide()
			player.visible = player.player_index == 3
		var gold: ATIPlayer = main.players[3]
		gold.position = Vector3(0,-0.05,3.3)
		if "--reference-preview" in OS.get_cmdline_user_args():
			var reference_puppet = gold.body_mesh.get_node("Sockling")
			reference_puppet.motion.reset()
			reference_puppet.phase = 0
			for frame in 90: reference_puppet.animate(1.0/60.0,0,false,false,false)
			main.camera.position = Vector3(-1.8,1.52,7.1)
			main.camera.look_at(Vector3(0,0.83,3.3))
			await capture("sockling-reference-angle")
			await reference_comparison(main)
			main.camera.position = Vector3(0,1.2,7.4)
			main.camera.look_at(Vector3(0,0.83,3.3))
			await capture("sockling-front")
		main.camera.position = Vector3(2.4,1.6,6.6)
		main.camera.look_at(Vector3(0,0.9,3.3))
		await capture("sockling-gold")
		main.camera.position = Vector3(-2.9,1.4,4.6)
		main.camera.look_at(Vector3(0,0.9,3.3))
		await capture("sockling-side")
		var puppet = gold.body_mesh.get_node("Sockling")
		puppet.phase = 0.1
		for frame in 60: puppet.animate(1.0/60.0,0,true,false,false)
		await capture("sockling-holding")
		main.camera.position = Vector3(2.4,1.6,6.6)
		main.camera.look_at(Vector3(0,0.9,3.3))
		puppet.phase = 0.5
		for frame in 90: puppet.animate(1.0/60.0,6.2,false,false,false)
		await capture("sockling-run")
		for index in 4:
			var player: ATIPlayer = main.players[index]
			player.visible = true
			player.position = Vector3((index-1.5)*1.5,-0.05,3.3)
		main.camera.fov = 75
		main.camera.position = Vector3(0,1.45,5.7)
		main.camera.look_at(Vector3(0,0.95,3.3))
		await capture("sockling-lineup")
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("SOCKLING_ART PASS: 4 colors, finite meshes, unchanged collision, invisible/first-person/buddy hiding, crouch, stun, hold/run animation")
	quit()

func capture(title: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/network-test/"+title+".png")

func reference_comparison(main: Node3D) -> void:
	# A native Godot UI beside the actual 3D viewport, not a retouched render.
	var sheet := CanvasLayer.new()
	root.add_child(sheet)
	var paper := ColorRect.new()
	paper.color = Color("efe4d3")
	paper.size = Vector2(584,720)
	sheet.add_child(paper)
	var title_bar := ColorRect.new()
	title_bar.color = Color("efe4d3")
	title_bar.size = Vector2(1280,105)
	sheet.add_child(title_bar)
	var reference := TextureRect.new()
	var crop := AtlasTexture.new()
	crop.atlas = load("res://docs/art/socklings/approved-roster.png")
	crop.region = Rect2(529,120,472,412)
	reference.texture = crop
	reference.position = Vector2(16,121)
	reference.size = Vector2(552,462)
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sheet.add_child(reference)
	for entry in [["APPROVED CONCEPT",Vector2(35,52)],["CURRENT GODOT MODEL",Vector2(655,52)]]:
		var label := Label.new()
		label.text = entry[0]
		label.position = entry[1]
		label.add_theme_font_size_override("font_size",26)
		label.add_theme_color_override("font_color",Color("203b33"))
		sheet.add_child(label)
	var note := Label.new()
	note.text = "Same in-game mesh, materials and idle pose. No lighting or paint-over added."
	note.position = Vector2(595,665)
	note.add_theme_font_size_override("font_size",15)
	note.add_theme_color_override("font_color",Color("203b33"))
	sheet.add_child(note)
	main.camera.h_offset = -0.94
	await capture("sockling-reference-comparison")
	main.camera.h_offset = 0
	sheet.queue_free()
	await process_frame
