extends SceneTree
## Seeded cosmetic selection, independent from match/item RNG and human choices.
const CATALOG := preload("res://scripts/character_catalog.gd")
const EFFECT := preload("res://scripts/chaos_effect.gd")
var game: Node3D
var expected_rng := RandomNumberGenerator.new()
var checked_decoys := {}

func _initialize() -> void:
	call_deferred("run")
	create_timer(35.0, true).timeout.connect(func():
		push_error("BOT_SKIN_RANDOMIZATION timeout")
		quit(1))

func next_expected() -> StringName:
	return CATALOG.IDS[expected_rng.randi_range(0, CATALOG.IDS.size() - 1)]

func freeze_players() -> void:
	game.set_process(false)
	game.set_physics_process(false)
	for player in game.players:
		player.set_physics_process(false)

func assert_roll(expected: StringName) -> void:
	assert(game.players[1].character_id == expected, "Bot did not use the seeded cosmetic pool draw")
	assert(game.bot_skin_rng.state == expected_rng.state, "Bot selection consumed extra cosmetic random draws")
	assert(game.players[0].character_id == &"looper" and game.preferred_character == &"looper", "Bot roll changed the human's selected skin")
	assert(CATALOG.valid(game.players[1].character_id))
	if not checked_decoys.has(expected):
		check_bot_decoy(game.players[1])
		checked_decoys[expected] = true

func check_bot_decoy(bot: ATIPlayer) -> void:
	bot._use_chaos_effect(&"decoy_double")
	var effect = get_nodes_in_group("chaos_decoy").back()
	effect.set_physics_process(false)
	var state: Dictionary = effect.network_state()
	assert(state.character == bot.character_id)
	var replica := EFFECT.new()
	game.add_child(replica)
	game._disable_remote_item_physics(replica)
	replica.global_position = effect.global_position
	replica.apply_state(state)
	for clone in [effect, replica]:
		var model = clone.decoy_body.get_node("DecoyCharacter").model
		assert(model.get_script() == bot.character_model().get_script(), "Randomized bot decoy used another skin")
		assert(model.fleece.get_shader_parameter("fleece_color") == bot.character_model().fleece.get_shader_parameter("fleece_color"))
		assert(model.fleece != bot.character_model().fleece and model.actor == null)
		assert(model.is_visible_in_tree() and not bot.body_mesh.visible)
		clone.queue_free()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._enter_lobby()
	game.choose_character(&"looper")
	assert(not game._character_settings_enabled(), "Fixture must not read or alter real player preferences")
	game.bot_skin_rng.seed = 570123
	expected_rng.seed = 570123
	var expected := next_expected()
	game._start_solo()
	freeze_players()
	assert_roll(expected)
	var first_model: int = game.players[1].character_model().get_instance_id()
	var stable_rng_state: int = game.bot_skin_rng.state
	for frame in 30:
		game._physics_process(1.0 / 60.0)
		await physics_frame
		assert(game.players[1].character_id == expected and game.players[1].character_model().get_instance_id() == first_model, "Bot changed appearance during a round")
		assert(game.bot_skin_rng.state == stable_rng_state, "Running gameplay consumed cosmetic skin RNG")
	# Restart draws, rather than always toggling, are compared against a second
	# isolated RNG. The fixed sequence also exercises both currently allowed skins.
	var sequence: Array[StringName] = [expected]
	for round_index in 15:
		expected = next_expected()
		game.reset_round()
		freeze_players()
		assert_roll(expected)
		sequence.append(expected)
		await process_frame
	assert(checked_decoys.size() == CATALOG.IDS.size(), "Seeded practice rounds did not cover every character/decoy skin")
	game._enter_lobby()
	expected = next_expected()
	game._start_solo()
	freeze_players()
	assert_roll(expected)
	# Even a stale AI flag must not randomize the local player, a real opponent,
	# or an inactive slot. Only slot 3 is an eligible bot in this fixture.
	game.active_slots.assign([true, true, false, true])
	for slot in 4:
		game.players[slot].set_slot_active(game.active_slots[slot])
		game.players[slot].ai_controlled = slot != 1
	game.players[0].set_character_skin(&"looper")
	game.players[1].set_character_skin(&"sockling")
	game.players[2].set_character_skin(&"looper")
	var preserved: Array = []
	for slot in 3:
		preserved.append([game.players[slot].character_id, game.players[slot].character_model().get_instance_id()])
	expected = next_expected()
	# Isolate this call from reset_round(), which correctly does use gameplay RNG
	# for choosing the initial spark and spawning pickups.
	seed(871991)
	var next_gameplay_random := randi()
	seed(871991)
	game._randomize_bot_characters()
	assert(randi() == next_gameplay_random, "Cosmetic bot selection polluted the shared gameplay RNG")
	assert(game.players[3].character_id == expected and game.bot_skin_rng.state == expected_rng.state)
	for slot in 3:
		assert(game.players[slot].character_id == preserved[slot][0] and game.players[slot].character_model().get_instance_id() == preserved[slot][1], "Bot roll touched a human, local or inactive slot")
	assert(game.preferred_character == &"looper")
	# The same helper is called by round resets, but must be inert online and
	# outside practice. Preserve both model identities and generator state.
	var all_ids: Array = []
	for player in game.players: all_ids.append(player.character_model().get_instance_id())
	stable_rng_state = game.bot_skin_rng.state
	for mode in [&"lobby", &"hosting", &"host", &"joining", &"client"]:
		game.session_mode = mode
		game._randomize_bot_characters()
		assert(game.bot_skin_rng.state == stable_rng_state, "Non-practice mode consumed a bot skin draw")
		for slot in 4:
			assert(game.players[slot].character_model().get_instance_id() == all_ids[slot], "Non-practice mode randomized an online skin")
	game.session_mode = &"host"
	game.reset_round()
	assert(game.bot_skin_rng.state == stable_rng_state, "Online match restart rerolled cosmetic bot RNG")
	for slot in 4:
		assert(game.players[slot].character_model().get_instance_id() == all_ids[slot], "Online match restart changed a human-selected skin")
	game._prepare_session()
	for player in game.players:
		for audio_player in player.sfx_players: audio_player.stop()
	game.queue_free()
	await process_frame
	print("BOT_SKIN_RANDOMIZATION PASS: seeded pool draws ", sequence, "; stable rounds; restart/new practice rerolls; both bot decoy skins; no local/human/inactive/network changes; isolated gameplay RNG; preference preserved")
	quit()
