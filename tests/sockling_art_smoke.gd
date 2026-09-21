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
		assert(art.has_node("Puppet/Head/LowerJaw/Tongue"))
		assert(art.has_node("Puppet/KnittedWaistband/RibbedCuff"))
		assert(not materials.has(art.fleece))
		assert(art.find_children("*","MeshInstance3D",true,false).size() < 70)
		materials.append(art.fleece)
		for mesh in art.find_children("*","MeshInstance3D",true,false):
			assert(mesh.mesh != null and mesh.mesh.get_aabb().size.is_finite())
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
		art.animate(0.15,7.0,true,false,false)
		assert(art.arms[0].rotation.x < -0.9)
		assert(art.fleece.get_shader_parameter("stunned") == 0.0)
		art.animate(0.2,4.0,false,false,false)
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
		main.camera.position = Vector3(2.4,1.6,6.6)
		main.camera.look_at(Vector3(0,0.9,3.3))
		await capture("sockling-gold")
		main.camera.position = Vector3(-2.9,1.4,4.6)
		main.camera.look_at(Vector3(0,0.9,3.3))
		await capture("sockling-side")
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
