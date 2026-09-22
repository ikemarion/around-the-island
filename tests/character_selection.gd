extends SceneTree
const CATALOG := preload("res://scripts/character_catalog.gd")

func _initialize() -> void:
	call_deferred("run")
	create_timer(25.0).timeout.connect(func():
		push_error("CHARACTER_SELECTION timeout")
		quit(1))

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._enter_lobby()
	assert(game.preferred_character == &"sockling" and not game._character_settings_enabled())
	assert(CATALOG.sanitize(&"../../bad") == &"sockling")
	var actor: ATIPlayer = game.players[0]
	var collider := actor.collision_shape.shape
	var speed := actor.max_speed
	game.choose_character(&"not_a_character")
	assert(actor.character_id == &"sockling")
	for id in CATALOG.IDS:
		game.choose_character(id)
		assert(actor.character_id == id and game.preferred_character == id)
		assert(actor.character_model().name == CATALOG.display_name(id))
		assert(actor.collision_shape.shape == collider and actor.max_speed == speed)
		assert(actor.character_model().find_children("*", "CollisionObject3D", true, false).is_empty())
		var model_id: int = actor.character_model().get_instance_id()
		actor.set_character_skin(id)
		assert(actor.character_model().get_instance_id() == model_id, "Repeated snapshots rebuilt the skin")
		game.kitchen_menu.refresh()
		assert(game.kitchen_menu.seats[0].character.text == CATALOG.display_name(id))
		assert(game.kitchen_menu.skin_buttons[CATALOG.IDS.find(id)].button_pressed)
		assert(game._player_state(0).character == id)
		# Every decoy stores character identity and a private copy of its material.
		var effect = load("res://scripts/chaos_effect.gd").new()
		game.add_child(effect)
		effect.setup(&"decoy_double", actor)
		var state: Dictionary = effect.network_state()
		assert(state.character == id)
		var replica = load("res://scripts/chaos_effect.gd").new()
		game.add_child(replica)
		replica.apply_state(state)
		var decoy = replica.decoy_body.get_node("DecoyCharacter").model
		assert(decoy.get_script() == actor.character_model().get_script())
		assert(decoy.fleece != actor.character_model().fleece)
		assert(decoy.fleece.get_shader_parameter("fleece_color") == actor.character_model().fleece.get_shader_parameter("fleece_color"))
		assert(decoy.actor == null)
		effect.queue_free()
		replica.queue_free()
	game._start_solo()
	assert(actor.character_id == &"looper" and game.players[1].ai_controlled and CATALOG.valid(game.players[1].character_id))
	game.choose_character(&"sockling")
	assert(actor.character_id == &"looper", "Selection changed during the match")
	game.reset_round()
	assert(actor.character_id == &"looper")
	game._enter_lobby()
	assert(actor.character_id == &"looper", "Leaving discarded the local preference")
	game.session_mode = &"hosting"
	game.peer_to_slot = {1: 0, 77: 1}
	game.active_slots[1] = true
	assert(not game._apply_peer_character(1, &"looper"), "Remote selector can mutate the host slot")
	assert(not game._apply_peer_character(99, &"looper"), "Unadmitted peer can select")
	assert(not game._apply_peer_character(77, &"bad"), "Unvalidated character accepted")
	assert(game._apply_peer_character(77, &"looper"))
	assert(game.players[1].character_id == &"looper")
	game.round_epoch = 1
	assert(not game._apply_peer_character(77, &"sockling"), "Host accepted a mid-match skin change")
	game._prepare_session()
	game.session_mode = &"client"
	game.local_slot = 2
	game._receive_roster([true, false, true, false], 1, [&"looper", &"bad", &"looper", &"sockling"])
	assert(game.players[0].character_id == &"looper" and game.players[1].character_id == &"sockling" and game.players[2].character_id == &"looper")
	game._receive_roster([true, false, true, false], 0, [&"sockling"])
	assert(game.players[0].character_id == &"looper", "Stale roster changed the selected skin")
	game._receive_roster([true, false, true, false], 2)
	assert(game.players[0].character_id == &"sockling", "Old missing field did not use Sockling")
	game._prepare_session()
	game.queue_free()
	await process_frame
	print("CHARACTER_SELECTION PASS: both models, identical physics, selector, identity snapshots, decoys, preference/reset, ownership/ID/match validation, ordered lobby roster")
	quit()
