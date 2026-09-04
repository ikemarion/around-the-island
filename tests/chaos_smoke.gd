extends SceneTree

const EFFECT = preload("res://scripts/chaos_effect.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	await process_frame
	main.set_physics_process(false)
	var source = main.players[0]
	var target = main.players[1]
	source.set_physics_process(false)
	target.set_physics_process(false)
	source.global_position = Vector3(-6, 0.05, 3)
	target.global_position = Vector3(-6, 0.05, -3)
	source.network_controlled = true
	source.network_aim_forward = Vector3.FORWARD
	var decoy = EFFECT.new()
	main.add_child(decoy)
	decoy.setup(&"decoy_double", source)
	decoy.set_physics_process(false)
	check(target._ai_visible_target() == decoy, "Bot did not take decoy bait")
	var before: Vector3 = decoy.global_position
	decoy._physics_process(0.016)
	check(decoy.global_position.z < before.z, "Decoy did not run forward")
	decoy.queue_free()
	await process_frame
	var magnet = EFFECT.new()
	main.add_child(magnet)
	magnet.setup(&"magnet_mayhem", source)
	magnet.set_physics_process(false)
	check(source.get_magnet_time() > 0.0, "Magnet second-use state missing")
	magnet._physics_process(0.1)
	magnet.release_magnet()
	check(magnet.spent, "Magnet did not release")
	await process_frame
	check(source.get_magnet_time() == 0.0, "Magnet state survived cleanup")
	var wall = EFFECT.new()
	main.add_child(wall)
	wall.setup(&"pocket_wall", source)
	wall.set_physics_process(false)
	check(wall.get_child(1) is StaticBody3D and wall.get_child(1).collision_layer == 1, "Wall is not solid on host")
	var replica = EFFECT.new()
	main.add_child(replica)
	replica.apply_state(wall.network_state())
	check(replica.replica and replica.get_child(1).collision_layer == 1, "Replica wall lacks prediction collision")
	wall._physics_process(6.0)
	check(wall.is_queued_for_deletion(), "Wall did not expire")
	replica.queue_free()
	var rope = EFFECT.new()
	main.add_child(rope)
	rope.setup(&"bungee_hook", source, target)
	rope.set_physics_process(false)
	source.velocity = Vector3.ZERO
	target.velocity = Vector3.ZERO
	rope._physics_process(0.1)
	check(source.velocity.z < 0 and target.velocity.z > 0, "Bungee did not pull both players together")
	rope.queue_free()
	var potato = EFFECT.new()
	main.add_child(potato)
	potato.setup(&"hot_potato", source, target)
	potato.set_physics_process(false)
	target.global_position = Vector3(-7.5, 0.05, 0)
	source.global_position = target.global_position + Vector3.RIGHT
	await physics_frame
	await physics_frame
	potato._physics_process(0.8)
	check(potato.target_slot == 0, "Potato did not pass on touch")
	source.velocity = Vector3.ZERO
	potato._physics_process(6.0)
	check(potato.spent and source.velocity.length() > 0.0, "Potato did not explode with knockback")
	await process_frame
	# Exercise generic client reconstruction and cleanup for every new kind.
	for kind in [&"decoy_double", &"magnet_mayhem", &"pocket_wall", &"hot_potato", &"bungee_hook"]:
		var effect = EFFECT.new()
		main.add_child(effect)
		effect.setup(kind, source, target)
		var states = main._temporary_item_states()
		main._apply_temporary_item_states(states)
		check(main.remote_temporary_items.has(str(effect.get_instance_id())), "Missing replicated effect: " + String(kind))
		main._apply_temporary_item_states([])
		effect.queue_free()
		await process_frame
	main.queue_free()
	await process_frame
	print("CHAOS_SMOKE failures=", failures)
	quit(1 if failures else 0)
