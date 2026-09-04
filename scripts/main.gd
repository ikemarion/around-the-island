extends Node3D

const SFX_LIBRARY := preload("res://scripts/sfx_library.gd")

## This script owns match rules. Player movement stays in player.gd so each
## script has one clear responsibility.

const ROUND_DURATION: float = 75.0
const TAG_DISTANCE: float = 1.22
const TAG_COOLDOWN: float = 0.85
const SCORE_TRACK_LENGTH: float = 6.6

@onready var player_one: ATIPlayer = $Players/PlayerOne
@onready var player_two: ATIPlayer = $Players/PlayerTwo
@onready var countdown_label: Label3D = $Arena/IslandDisplay/Countdown
@onready var you_score_bar: MeshInstance3D = $Arena/IslandDisplay/YouScoreBar
@onready var bot_score_bar: MeshInstance3D = $Arena/IslandDisplay/BotScoreBar
@onready var winner_crown: Node3D = $Arena/IslandDisplay/WinnerCrown
@onready var status_label: Label = $HUD/Status
@onready var quick_item_panel: PanelContainer = $HUD/QuickItemPanel
@onready var quick_item_name: Label = $HUD/QuickItemPanel/Margin/VBox/Header/Name
@onready var quick_item_charge: ProgressBar = $HUD/QuickItemPanel/Margin/VBox/Charge
@onready var quick_item_state: Label = $HUD/QuickItemPanel/Margin/VBox/State
@onready var stun_crosshair: Control = $HUD/StunCrosshair
@onready var match_audio: AudioStreamPlayer = $MatchAudio

var players: Array[ATIPlayer]
var scores: Array[float] = [0.0, 0.0]
var token_holder: int = 0
var time_remaining: float = ROUND_DURATION
var tag_cooldown_remaining: float = 0.0
var round_running: bool = true
var obstacle_spawn_transforms: Dictionary = {}


func _ready() -> void:
	players = [player_one, player_two]
	for obstacle in get_tree().get_nodes_in_group("shoveable"):
		obstacle_spawn_transforms[obstacle] = obstacle.global_transform
	var joypads := Input.get_connected_joypads()
	player_one.configure(0, joypads[0] if joypads.size() > 0 else -1, Color("4fc3f7"))
	player_two.configure(1, -1, Color("ff6b8a"), true)
	player_one.set_ai_target(player_two)
	player_two.set_ai_target(player_one)
	player_one.quick_item_event.connect(_on_quick_item_event)
	reset_round()


func _physics_process(delta: float) -> void:
	if not round_running:
		_update_world_scoreboard()
		return

	time_remaining = maxf(0.0, time_remaining - delta)
	scores[token_holder] += delta
	tag_cooldown_remaining = maxf(0.0, tag_cooldown_remaining - delta)

	if tag_cooldown_remaining <= 0.0:
		var separation := players[0].global_position.distance_to(players[1].global_position)
		if separation <= TAG_DISTANCE:
			_transfer_token()

	if time_remaining <= 0.0:
		_end_round()

	_update_world_scoreboard()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			reset_round()


func reset_round() -> void:
	match_audio.stop()
	time_remaining = ROUND_DURATION
	scores = [0.0, 0.0]
	token_holder = 0
	tag_cooldown_remaining = 1.0
	round_running = true

	player_one.global_position = Vector3(-5.2, 0.05, 0.0)
	player_two.global_position = Vector3(5.2, 0.05, 0.0)
	player_one.reset_movement_state()
	player_two.reset_movement_state()
	for obstacle in obstacle_spawn_transforms:
		obstacle.global_transform = obstacle_spawn_transforms[obstacle]
		obstacle.linear_velocity = Vector3.ZERO
		obstacle.angular_velocity = Vector3.ZERO
		obstacle.sleeping = false
	for spawner in get_tree().get_nodes_in_group("item_spawner"):
		spawner.reset_spawner()
	for temporary_item in get_tree().get_nodes_in_group("temporary_item"):
		temporary_item.queue_free()

	_set_token_holder(token_holder)
	status_label.text = "You have the spark — the bot is chasing!"
	_update_world_scoreboard()


func _transfer_token() -> void:
	var previous_holder := token_holder
	token_holder = 1 - token_holder
	tag_cooldown_remaining = TAG_COOLDOWN
	_set_token_holder(token_holder)
	players[token_holder].receive_token_escape(players[previous_holder].global_position)
	status_label.text = "The bot stole the spark — chase it!" if token_holder == 1 else "You stole the spark — run!"
	_play_match_sfx("tag")


func _set_token_holder(holder: int) -> void:
	for index in players.size():
		players[index].set_has_token(index == holder)


func _end_round() -> void:
	round_running = false
	_play_match_sfx("round_end")
	if absf(scores[0] - scores[1]) < 0.05:
		status_label.text = "Draw! Press R for a rematch"
	else:
		var winner := 0 if scores[0] > scores[1] else 1
		status_label.text = "%s wins! Press R for a rematch" % ("YOU" if winner == 0 else "BOT")


func _update_world_scoreboard() -> void:
	countdown_label.text = "%02d" % ceili(time_remaining)
	var has_stun_gun := player_one.has_stun_gun()
	quick_item_name.text = player_one.get_quick_item_name()
	quick_item_charge.value = player_one.get_quick_item_readiness() * 100.0
	quick_item_state.text = player_one.get_quick_item_state()
	stun_crosshair.visible = has_stun_gun
	if player_one.has_spawn_item() or player_one.is_invisible():
		quick_item_panel.modulate = player_one.get_quick_item_color()
	else:
		quick_item_panel.modulate = Color.WHITE if player_one.get_quick_item_cooldown() <= 0.0 else Color(0.62, 0.7, 0.72)

	# Total possession time is shared, so these opposing lines approach one
	# another throughout the round and meet at the final score split.
	var you_length := maxf(0.02, scores[0] / ROUND_DURATION * SCORE_TRACK_LENGTH)
	var bot_length := maxf(0.02, scores[1] / ROUND_DURATION * SCORE_TRACK_LENGTH)
	var half_track := SCORE_TRACK_LENGTH * 0.5

	you_score_bar.scale.x = you_length
	you_score_bar.position.x = -half_track + you_length * 0.5
	bot_score_bar.scale.x = bot_length
	bot_score_bar.position.x = half_track - bot_length * 0.5

	if absf(scores[0] - scores[1]) < 0.01:
		winner_crown.visible = false
	else:
		var leading_bar := you_score_bar if scores[0] > scores[1] else bot_score_bar
		var target_x := leading_bar.position.x
		if not winner_crown.visible:
			winner_crown.position.x = target_x
		winner_crown.visible = true
		winner_crown.position.x = lerpf(winner_crown.position.x, target_x, 0.18)


func _play_match_sfx(effect_name: String) -> void:
	match_audio.stream = SFX_LIBRARY.get_effect(effect_name)
	match_audio.play()


func _on_quick_item_event(message: String) -> void:
	status_label.text = message
