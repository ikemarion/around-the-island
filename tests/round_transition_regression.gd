extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._enter_lobby()
	main._assign_slot(1)
	main.round_epoch = 1
	var p = main.players[1]
	p.action_queue.append({"kind": &"jump", "aim": Vector3.FORWARD})
	p.network_crouch_pressed = true
	p.crouch_was_pressed = true
	p.interact_was_pressed = true
	p.slide_time_remaining = 0.5
	var wall = load("res://scripts/chaos_effect.gd").new()
	main.add_child(wall)
	wall.setup(&"pocket_wall", main.players[0])
	var state := {"id": 999, "kind": "ChaosEffect", "position": wall.global_position, "chaos": wall.network_state()}
	wall.queue_free()
	await process_frame
	main._receive_effect_manifest([state], 1, 20)
	var replica = main.remote_temporary_items["999"]
	var collider = replica.find_children("*", "CollisionObject3D", true, false)[0]
	assert(collider.collision_layer == 1)
	# Player state beats the new-round match state and effect manifest.
	var fresh = main._player_state(1)
	fresh.active = true
	fresh.position = Vector3(6, 0.05, 0)
	fresh.velocity = Vector3.ZERO
	fresh.motion_epoch += 1
	fresh.item = &"air_horn"
	main._receive_player_state(1, fresh, 2, 30)
	assert(p.action_queue.is_empty())
	assert(not p.network_crouch_pressed and not p.crouch_was_pressed and not p.interact_was_pressed)
	assert(p.slide_time_remaining == 0)
	assert(p.client_predicted and p.network_controlled and p.network_replica)
	assert(p.global_position == fresh.position and p.equipped_spawn_item == &"air_horn")
	assert(main.remote_temporary_items.is_empty())
	assert(replica.is_queued_for_deletion() and not replica.visible)
	assert(collider.collision_layer == 0 and collider.collision_mask == 0)
	# Delayed previous-round messages must not revive effects or reset players.
	main._receive_effect_manifest([state], 1, 40)
	main._receive_effect_state(state, 1, 41)
	assert(main.remote_temporary_items.is_empty())
	p.action_queue.append({"kind": &"quick", "aim": Vector3.FORWARD})
	main._receive_effect_manifest([], 2, 31)
	assert(p.action_queue.size() == 1 and p.equipped_spawn_item == &"air_horn")
	await process_frame
	assert(not is_instance_valid(replica))
	# The manifest can also be first: keep its new-round effect afterward.
	main._receive_effect_manifest([state], 3, 50)
	var next_replica = main.remote_temporary_items["999"]
	assert(p.action_queue.is_empty())
	main._receive_player_state(1, fresh, 3, 51)
	assert(is_instance_valid(next_replica) and not next_replica.is_queued_for_deletion())
	assert(main.remote_temporary_items.size() == 1)
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("ROUND_TRANSITION passed: input reset, immediate collision retirement, reordered channels, stale rejection, role preservation")
	quit()
