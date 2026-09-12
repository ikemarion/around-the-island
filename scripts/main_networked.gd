extends Node3D

const SFX_LIBRARY := preload("res://scripts/sfx_library.gd")
const CHAOS_EFFECT := preload("res://scripts/chaos_effect.gd")
const EMERGENCY_DOORS_SCENE := preload("res://scenes/emergency_doors.tscn")
const SLIPPERY_PATCH_SCENE := preload("res://scenes/slippery_patch.tscn")
const ROUND_DURATION := 75.0
const TAG_DISTANCE := 1.22
const TAG_COOLDOWN := 0.85
const SCORE_TRACK_LENGTH := 6.6
const MAX_PLAYERS := 4
const PROTOCOL_VERSION := 13
const BUILD_VERSION := "0.44"
var network_diagnostics: Node
var report_transfer: Node
var obstacle_last_sent: Dictionary = {}
var restart_hold := 0.0
var restart_latched := false
var obstacle_hint: Label
const HOST_COMPUTER_NAME := "ISAACSPC"
const DEFAULT_LOBBY_ADDRESS := "jakarta-oki.tun.ply.gg:23862"
const STUN_BEAM_SCENE := preload("res://scenes/stun_beam.tscn")
var pending_peers: Dictionary = {}
var peer_input_sequences: Dictionary = {}
var peer_action_sequences: Dictionary = {}
var round_epoch := 0
var snapshot_sequence := 0
var last_match_sequence := -1
var last_player_sequences := [-1, -1, -1, -1]
var world_sequences: Dictionary = {}
var effect_ids: Dictionary = {}
var manifest_key := ""
var local_input_sequence := 0
var local_action_sequence := 0
var local_buttons := [false, false, false, false, false, false]
var last_input_send := 0

const SNAPSHOT_INTERVAL := 0.05
const PLAYER_COLORS: Array[Color] = [Color("4fc3f7"), Color("ff6b8a"), Color("55df7a"), Color("ffd34f")]
const PLAYER_SPAWNS: Array[Vector3] = [Vector3(-5.2, 0.05, 0), Vector3(5.2, 0.05, 0), Vector3(0, 0.05, -4.6), Vector3(0, 0.05, 4.6)]

@onready var network_session = $NetworkSession
@onready var camera: Camera3D = $Camera3D
@onready var winner_crown: Node3D = $Arena/IslandDisplay/WinnerCrown
@onready var status_label: Label = $HUD/Status
@onready var quick_item_panel: PanelContainer = $HUD/QuickItemPanel
@onready var quick_item_name: Label = $HUD/QuickItemPanel/Margin/VBox/Header/Name
@onready var quick_item_charge: ProgressBar = $HUD/QuickItemPanel/Margin/VBox/Charge
@onready var quick_item_state: Label = $HUD/QuickItemPanel/Margin/VBox/State
@onready var stun_crosshair: Control = $HUD/StunCrosshair
@onready var match_audio: AudioStreamPlayer = $MatchAudio
@onready var lobby: CanvasLayer = $Lobby
@onready var lobby_status: Label = $Lobby/Panel/Margin/VBox/Status
@onready var room_code_label: Label = $Lobby/Panel/Margin/VBox/RoomCode
@onready var copy_code_button: Button = $Lobby/Panel/Margin/VBox/CopyCode
@onready var code_input: LineEdit = $Lobby/Panel/Margin/VBox/CodeInput

var players: Array[ATIPlayer] = []
var score_bars: Array[MeshInstance3D] = []
var score_labels: Array[Label3D] = []
var active_slots: Array[bool] = [true, false, false, false]
var scores: Array[float] = [0.0, 0.0, 0.0, 0.0]
var peer_to_slot: Dictionary = {}
var local_slot := 0
var token_holder := 0
var time_remaining := ROUND_DURATION
var tag_cooldown_remaining := 0.0
var round_running := false
var celebrated_epoch := -1
var celebration: Control

func _can_roam() -> bool:
	return session_mode in [&"solo", &"host", &"client"] and not waiting_for_start and round_epoch > 0

func _celebrate_round() -> void:
	if celebrated_epoch == round_epoch:
		return
	celebrated_epoch = round_epoch
	if is_instance_valid(celebration):
		celebration.queue_free()
	celebration = preload("res://scripts/round_celebration.gd").new()
	celebration.result = _round_result_text()
	$HUD.add_child(celebration)
var session_mode: StringName = &"lobby"
var snapshot_time := 0.0
var obstacle_spawn_transforms: Dictionary = {}
var remote_temporary_items: Dictionary = {}
var hosted_room_code := ""
var waiting_for_start := false
var connection_started_ms := 0
var connection_stage := ""
var roster_sequence := 0
var received_roster_sequence := -1
var distant_scoreboards: Node3D
var session_menu: CanvasLayer
var menu_controls: Dictionary = {}
var kitchen_menu: VBoxContainer
var lobby_id := ""
var instance_guard: TCPServer
var instance_blocked := false
var start_requested_ms := 0


func _ready() -> void:
	network_diagnostics = preload("res://scripts/network_diagnostics.gd").new()
	network_diagnostics.name = "NetworkDiagnostics"
	network_diagnostics.game = self
	add_child(network_diagnostics)
	report_transfer = preload("res://scripts/report_transfer.gd").new()
	report_transfer.name = "ReportTransfer"
	report_transfer.game = self
	add_child(report_transfer)
	var spark_indicator := preload("res://scripts/spark_indicator.gd").new()
	spark_indicator.name = "SparkIndicator"
	spark_indicator.game = self
	$HUD.add_child(spark_indicator)
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Players.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	players = [$Players/PlayerOne, $Players/PlayerTwo, $Players/PlayerThree, $Players/PlayerFour]
	score_bars = [$Arena/IslandDisplay/YouScoreBar, $Arena/IslandDisplay/BotScoreBar, $Arena/IslandDisplay/PlayerThreeScoreBar, $Arena/IslandDisplay/PlayerFourScoreBar]
	score_labels = [$Arena/IslandDisplay/YouLabel, $Arena/IslandDisplay/BotLabel, $Arena/IslandDisplay/PlayerThreeLabel, $Arena/IslandDisplay/PlayerFourLabel]
	# Room scenes contribute pickup locations to the existing replicated spawner.
	# Keep a single authority-owned item source, regardless of the room count.
	for room in $Arena/Rooms.get_children():
		for marker in room.get_node("PickupSpawns").get_children():
			$Arena/PowerUpSpawner.spawn_locations.append(marker.global_position)
	for obstacle in get_tree().get_nodes_in_group("shoveable"):
		obstacle_spawn_transforms[obstacle] = obstacle.global_transform
	$Arena/KillBox.body_entered.connect(_on_kill_box_body_entered)
	for slot in MAX_PLAYERS:
		players[slot].configure(slot, -1, PLAYER_COLORS[slot], false)
		players[slot].quick_item_event.connect(_on_quick_item_event.bind(slot))
		players[slot].sound_event.connect(_on_player_sound.bind(slot))
		players[slot].beam_event.connect(_on_player_beam)
		players[slot].set_slot_active(slot == 0)
	$Lobby/Panel/Margin/VBox/Solo.pressed.connect(_start_solo)
	$Lobby/Panel/Margin/VBox/Host.pressed.connect(_host_default_lobby)
	$Lobby/Panel/Margin/VBox/Join.pressed.connect(_join_default_lobby)
	copy_code_button.pressed.connect(_copy_room_code)
	network_session.room_hosted.connect(_on_room_hosted)
	network_session.host_failed.connect(_on_network_error)
	network_session.joined_server.connect(_on_joined_server)
	network_session.join_failed.connect(_on_network_error)
	network_session.remote_player_connected.connect(_on_remote_player_connected)
	network_session.remote_player_disconnected.connect(_on_remote_player_disconnected)
	_setup_menu()
	distant_scoreboards = preload("res://scripts/distant_scoreboards.gd").new()
	distant_scoreboards.name = "DistantScoreboards"
	add_child(distant_scoreboards)
	add_child(preload("res://scripts/cartoon_art.gd").new())
	var command_args := OS.get_cmdline_user_args()
	# One normal game window per PC. Explicit test instances use separate peers.
	if not OS.get_cmdline_args().has("--script") and not command_args.has("--ati-test-instance"):
		instance_guard = TCPServer.new()
		instance_blocked = instance_guard.listen(27887, "127.0.0.1") != OK
		if instance_blocked:
			_enter_lobby("ATI is already open on this PC, or its local window-lock port is occupied. Use the existing ATI window; close this duplicate. No lobby was opened here.")
			print("ATI_INSTANCE_BLOCKED")
			return
	var join_argument := ""
	for argument in command_args:
		if argument.begins_with("--ati-join="):
			join_argument = argument
			break
	if "--ati-host" in command_args:
		_host_default_lobby()
	elif "--ati-host-local" in command_args:
		_host_online(false)
	elif not join_argument.is_empty():
		code_input.text = join_argument.trim_prefix("--ati-join=")
		_join_online()
	elif DisplayServer.get_name() == "headless":
		_start_solo()
	else:
		_enter_lobby()


func _physics_process(delta: float) -> void:
	for peer_id in pending_peers.keys():
		if Time.get_ticks_msec() - int(pending_peers[peer_id]) > 5000:
			network_diagnostics.record("join_handshake_timeout",{"peer":peer_id})
			pending_peers.erase(peer_id)
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	if session_mode in [&"lobby", &"hosting", &"joining"]:
		return
	if session_mode == &"client":
		if _can_roam():
			_send_local_input()
		_update_world_scoreboard()
		return
	if _can_roam():
		for slot in MAX_PLAYERS:
			if active_slots[slot] and players[slot].global_position.y < -3.0:
				_on_kill_box_body_entered(players[slot])
	if round_running:
		time_remaining = maxf(0.0, time_remaining - delta)
		if active_slots[token_holder]:
			scores[token_holder] += delta
		tag_cooldown_remaining = maxf(0.0, tag_cooldown_remaining - delta)
		if tag_cooldown_remaining <= 0.0:
			for slot in MAX_PLAYERS:
				if slot != token_holder and active_slots[slot] and players[token_holder].global_position.distance_to(players[slot].global_position) <= TAG_DISTANCE and can_touch_players(token_holder, slot):
					_transfer_token(slot)
					break
		if time_remaining <= 0.0:
			_end_round()
	if session_mode == &"host":
		snapshot_time += delta
		if snapshot_time >= SNAPSHOT_INTERVAL:
			snapshot_time = 0.0
			_broadcast_snapshot()
	_update_world_scoreboard()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R and session_mode in [&"solo", &"host"] and not session_menu.visible:
		reset_round()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and session_mode in [&"solo", &"host", &"client"] and not waiting_for_start:
		_set_session_menu(not session_menu.visible)
		get_viewport().set_input_as_handled()


func _set_session_menu(opened: bool) -> void:
	session_menu.visible = opened
	players[local_slot].input_suspended = opened
	camera.set_gameplay_input_enabled(not opened)
	if opened:
		players[local_slot]._release_chair()
		session_menu.get_node("Panel/Box/Leave").text = "Close room for everyone" if session_mode == &"host" else "Leave to main menu"
		session_menu.get_node("Panel/Box/Resume").grab_focus()


func _setup_session_menu(menu_theme: Theme) -> void:
	session_menu = CanvasLayer.new()
	session_menu.name = "SessionMenu"
	session_menu.layer = 12
	session_menu.visible = false
	add_child(session_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.85)
	session_menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme = menu_theme
	var panel_style: StyleBoxFlat = $Lobby/Panel.get_theme_stylebox("panel").duplicate()
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	session_menu.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -110
	panel.offset_bottom = 110
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var label := Label.new()
	label.text = "GAME MENU\nThe match keeps running."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var resume := Button.new()
	resume.name = "Resume"
	resume.text = "Resume"
	box.add_child(resume)
	resume.pressed.connect(func(): _set_session_menu(false))
	var diagnostics_button := Button.new()
	diagnostics_button.text = "Connection reports"
	box.add_child(diagnostics_button)
	diagnostics_button.pressed.connect(network_diagnostics.open_reports)
	var leave := Button.new()
	leave.name = "Leave"
	box.add_child(leave)
	leave.pressed.connect(func(): _enter_lobby("You left the room. Choose how to play."))


func _on_kill_box_body_entered(body: Node3D) -> void:
	if session_mode == &"client" or not _can_roam() or not body is ATIPlayer:
		return
	var slot := players.find(body)
	if slot < 0 or not active_slots[slot]:
		return
	players[slot].respawn_at(PLAYER_SPAWNS[slot])
	if not round_running:
		return
	status_label.text = "Player %d fell out and respawned!" % (slot + 1)
	if slot == token_holder:
		for offset in range(1, MAX_PLAYERS):
			var recipient := (slot + offset) % MAX_PLAYERS
			if active_slots[recipient]:
				_transfer_token(recipient)
				status_label.text = "Player %d forfeited the spark to Player %d!" % [slot + 1, recipient + 1]
				break


func _enter_lobby(message := "Host PC: choose Host lobby and stay in that window. Friends: choose Join lobby. No codes needed.") -> void:
	_prepare_session()
	session_mode = &"lobby"
	lobby.visible = true
	camera.set_gameplay_input_enabled(false)
	lobby_status.text = message
	room_code_label.text = ""
	copy_code_button.visible = false
	get_tree().paused = true
	print("ATI_MENU_READY v", BUILD_VERSION)


func _start_solo() -> void:
	if instance_blocked: return
	_prepare_session()
	session_mode = &"solo"
	local_slot = 0
	active_slots = [true, true, false, false]
	for slot in MAX_PLAYERS:
		players[slot].ai_controlled = slot == 1
		players[slot].network_controlled = false
		players[slot].set_slot_active(active_slots[slot], false)
	players[1].set_ai_target(players[0])
	players[0].set_ai_target(players[1])
	_set_local_camera(0)
	lobby.visible = false
	get_tree().paused = false
	reset_round()


func can_host_default_lobby() -> bool:
	return OS.get_environment("COMPUTERNAME").to_upper() == HOST_COMPUTER_NAME


func _host_default_lobby() -> void:
	if instance_blocked or session_mode != &"lobby": return
	if not can_host_default_lobby():
		lobby_status.text = "This build's tunnel goes to the configured host PC. Choose Join lobby; hosting on a different PC is not configured."
		return
	_host_online(false, DEFAULT_LOBBY_ADDRESS)


func _host_online(use_upnp: bool = true, tunnel_address: String = "") -> void:
	if instance_blocked: return
	_prepare_session()
	lobby_id = Crypto.new().generate_random_bytes(3).hex_encode().to_upper()
	session_mode = &"hosting"
	waiting_for_start = true
	connection_started_ms = Time.get_ticks_msec()
	connection_stage = "Opening lobby" if not use_upnp else "Opening room and checking router"
	lobby.visible = true
	get_tree().paused = true
	lobby_status.text = "Opening the lobby in this game window…"
	room_code_label.text = ""
	copy_code_button.visible = false
	peer_to_slot = {1: 0}
	active_slots = [true, false, false, false]
	network_session.host_room(27888, use_upnp, tunnel_address)


func _host_via_tunnel() -> void:
	var address: String = menu_controls.TunnelAddress.text.strip_edges()
	if network_session._decode_room_code(address).is_empty() or not address.contains(":"):
		lobby_status.text = "Enter your own tunnel's host:port. This must route to this computer's UDP 27888."
		return
	var settings := ConfigFile.new()
	settings.set_value("host", "tunnel", address)
	settings.save("user://hosting.cfg")
	_host_online(false, address)


func _join_default_lobby() -> void:
	if instance_blocked or session_mode != &"lobby":
		return
	if is_instance_valid(kitchen_menu) and kitchen_menu.direct_test.button_pressed:
		var decoded: Dictionary = network_session._decode_room_code(code_input.text.strip_edges())
		if decoded.is_empty() or not str(decoded.address).is_valid_ip_address():
			lobby_status.text = "For this bypass test, enter the host's numeric IP:port. Do not use the Playit address."
			return
		_join_online()
		return
	code_input.text = DEFAULT_LOBBY_ADDRESS
	_join_online()


func _join_online() -> void:
	if instance_blocked: return
	if code_input.text.strip_edges().is_empty():
		lobby_status.text = "Enter the host's room code first."
		return
	var address := code_input.text
	_prepare_session()
	code_input.text = address
	session_mode = &"joining"
	connection_started_ms = Time.get_ticks_msec()
	connection_stage = "Contacting host"
	network_diagnostics.record("connection_route",{"route":"default_tunnel" if address == DEFAULT_LOBBY_ADDRESS else "custom_address"})
	lobby.visible = true
	get_tree().paused = true
	lobby_status.text = "Connecting…"
	network_session.join_room(code_input.text)


func _on_room_hosted(code: String, detail: String) -> void:
	if lobby_id.is_empty(): lobby_id = Crypto.new().generate_random_bytes(3).hex_encode().to_upper()
	connection_started_ms = 0
	waiting_for_start = true
	lobby.visible = true
	camera.set_gameplay_input_enabled(false)
	get_tree().paused = true
	_set_simulation(false)
	hosted_room_code = code
	room_code_label.text = "LOBBY " + lobby_id
	copy_code_button.visible = true
	lobby_status.text = "Listening for players. You are the host in this window. Friends choose Join lobby. Keep this game and Playit running; internet reachability is not checked here."
	print("ATI_NETWORK HOST_READY ", code)


func _copy_room_code() -> void:
	DisplayServer.clipboard_set(hosted_room_code)
	lobby_status.text = "Room code copied. Waiting for players…"


func _on_joined_server() -> void:
	connection_stage = "Connected · checking game version"
	lobby_status.text = "Connected. Checking game version…"
	print("ATI_NETWORK CLIENT_CONNECTED")
	_submit_version.rpc_id(1, PROTOCOL_VERSION)


@rpc("any_peer", "call_remote", "reliable")
func _submit_version(version: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if session_mode not in [&"hosting", &"host"] or not pending_peers.has(peer_id):
		return
	pending_peers.erase(peer_id)
	if version != PROTOCOL_VERSION:
		network_diagnostics.record("version_rejected",{"peer":peer_id,"protocol":version})
		_reject_version.rpc_id(peer_id)
		get_tree().create_timer(0.5, true).timeout.connect(func():
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				network_diagnostics.record("disconnect_requested",{"peer":peer_id,"reason":"version_mismatch"})
				multiplayer.multiplayer_peer.disconnect_peer(peer_id))
		return
	_admit_player(peer_id)


@rpc("authority", "call_remote", "reliable")
func _reject_version() -> void:
	_enter_lobby("Different game versions. Everyone must download the latest ATI build.")

func _on_network_error(message: String) -> void:
	network_diagnostics.record("network_error",{"message":message})
	_enter_lobby(message)


func _on_remote_player_connected(peer_id: int) -> void:
	if session_mode in [&"hosting", &"host"] and multiplayer.is_server():
		pending_peers[peer_id] = Time.get_ticks_msec()


func _admit_player(peer_id: int) -> void:
	if session_mode not in [&"hosting", &"host"] or not multiplayer.is_server():
		return
	var slot := _first_open_slot()
	if slot < 0:
		return
	peer_to_slot[peer_id] = slot
	active_slots[slot] = true
	_cleanup_slot(slot)
	active_slots[slot] = true
	players[slot].ai_controlled = false
	players[slot].network_controlled = true
	players[slot].set_slot_active(true, false)
	players[slot].global_position = PLAYER_SPAWNS[slot]
	_assign_slot.rpc_id(peer_id, slot, lobby_id)
	_refresh_opponent_targets()
	if session_mode == &"hosting":
		waiting_for_start = true
		players[slot].simulation_enabled = false
		_broadcast_roster()
	else:
		status_label.text = "Player %d joined!" % (slot + 1)
		players[slot].simulation_enabled = _can_roam()
		_broadcast_snapshot(true)



func _on_remote_player_disconnected(peer_id: int) -> void:
	pending_peers.erase(peer_id)
	peer_input_sequences.erase(peer_id)
	peer_action_sequences.erase(peer_id)
	if multiplayer.is_server() and peer_to_slot.has(peer_id):
		var slot: int = peer_to_slot[peer_id]
		peer_to_slot.erase(peer_id)
		active_slots[slot] = false
		_cleanup_slot(slot)
		scores[slot] = 0.0
		if token_holder == slot:
			token_holder = 0
			_set_token_holder(0)
		_refresh_opponent_targets()
		# ENet is still removing peers while this signal runs. Broadcast after
		# polling finishes, so simultaneous departures aren't sent new packets.
		_sync_after_peer_left.call_deferred()


func _sync_after_peer_left() -> void:
	if not multiplayer.is_server(): return
	if session_mode == &"hosting":
		_broadcast_roster()
	elif session_mode == &"host":
		_broadcast_snapshot(true)


@rpc("authority", "call_remote", "reliable")
func _assign_slot(slot: int, room_id: String = "") -> void:
	local_slot = slot
	lobby_id = room_id
	session_mode = &"client"
	report_transfer.begin()
	_reset_input_tracking()
	for index in MAX_PLAYERS:
		players[index].ai_controlled = false
		players[index].reset_movement_state()
		players[index].network_controlled = index == slot
		players[index].client_predicted = index == slot
		players[index].set_slot_active(index == slot, true)
	for spawner in get_tree().get_nodes_in_group("item_spawner"):
		spawner.set_authoritative(false)
	connection_started_ms = 0
	waiting_for_start = true
	camera.set_follow_target(players[slot])
	camera.set_gameplay_input_enabled(false)
	lobby.visible = true
	get_tree().paused = true
	status_label.text = "You are Player %d." % (slot + 1)
	print("ATI_NETWORK SLOT_ASSIGNED ", slot)
	print("ATI_NETWORK LOBBY ", lobby_id)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _receive_remote_input(movement: Vector2, aim_forward: Vector3, _jump: bool, _crouch: bool, _interact: bool, _throw_item: bool, _quick_item: bool, sequence: int = 0, epoch: int = 0) -> void:
	if not multiplayer.is_server() or not _can_roam() or epoch != round_epoch:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not peer_to_slot.has(sender) or sequence <= int(peer_input_sequences.get(sender, -1)):
		return
	if not movement.is_finite() or not aim_forward.is_finite() or aim_forward.length_squared() < 0.001 or movement.length() > 2.0:
		return
	peer_input_sequences[sender] = sequence
	var player := players[int(peer_to_slot[sender])]
	player.input_sequence = sequence
	player.set_network_input(movement, aim_forward, false, player.network_crouch_pressed, player.network_interact_pressed, player.network_throw_pressed, false)


@rpc("any_peer", "call_remote", "reliable", 0)
func _receive_action_state(sequence: int, epoch: int, buttons: Array, aim: Vector3, edges: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not _can_roam() or epoch != round_epoch or not peer_to_slot.has(sender):
		return
	if sequence <= int(peer_action_sequences.get(sender, -1)) or buttons.size() != 6 or edges.size() > 4 or not aim.is_finite() or aim.length_squared() < 0.001:
		return
	peer_action_sequences[sender] = sequence
	var player := players[int(peer_to_slot[sender])]
	player.network_aim_forward = aim.normalized()
	player.network_crouch_pressed = bool(buttons[1])
	player.network_interact_pressed = bool(buttons[2])
	player.network_throw_pressed = bool(buttons[3])
	for edge in edges:
		if edge in ["jump", "throw", "quick", "pull"] and player.action_queue.size() < 16:
			player.action_queue.append({"kind": StringName(edge), "aim": aim.normalized()})


func _send_local_input() -> void:
	var player := players[local_slot]
	var aim := player.get_local_aim_forward()
	var pads := Input.get_connected_joypads()
	var pad := -1 if pads.is_empty() else pads[0]
	var raw := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if pad >= 0:
		var stick := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if stick.length() > 0.18:
			raw += stick
	raw = raw.limit_length(1.0)
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	var world := right.normalized() * raw.x + forward.normalized() * -raw.y
	var buttons := [Input.is_physical_key_pressed(KEY_SPACE), Input.is_physical_key_pressed(KEY_SHIFT), Input.is_physical_key_pressed(KEY_E), Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_physical_key_pressed(KEY_Q), Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)]
	if pad >= 0:
		buttons[0] = buttons[0] or Input.is_joy_button_pressed(pad, JOY_BUTTON_A)
		buttons[1] = buttons[1] or Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_STICK)
		buttons[2] = buttons[2] or Input.is_joy_button_pressed(pad, JOY_BUTTON_X)
		buttons[3] = buttons[3] or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		buttons[4] = buttons[4] or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER)
		buttons[5] = Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.5 or buttons[5]
	if (is_instance_valid(session_menu) and session_menu.visible) or (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless" and camera.first_person_enabled):
		raw = Vector2.ZERO
		world = Vector3.ZERO
		buttons = [false, false, false, false, false, false]
	var edges: Array = []
	for entry in [[0, "jump"], [3, "throw"], [4, "quick"], [5, "pull"]]:
		if buttons[entry[0]] and not local_buttons[entry[0]]:
			edges.append(entry[1])
	local_input_sequence += 1
	player.input_sequence = local_input_sequence
	player.set_network_input(Vector2(world.x, world.z), aim, false, buttons[1], buttons[2], false, false)
	for edge in edges:
		player.action_queue.append({"kind": StringName(edge), "aim": aim})
	if buttons != local_buttons or Time.get_ticks_msec() - last_input_send > 250:
		local_action_sequence += 1
		_receive_action_state.rpc_id(1, local_action_sequence, round_epoch, buttons, aim, edges)
		last_input_send = Time.get_ticks_msec()
	local_buttons = buttons
	_receive_remote_input.rpc_id(1, Vector2(world.x, world.z), aim, false, false, false, false, false, local_input_sequence, round_epoch)


func reset_round() -> void:
	if is_instance_valid(celebration):
		celebration.queue_free()
	waiting_for_start = false
	round_epoch += 1
	peer_input_sequences.clear()
	peer_action_sequences.clear()
	_reset_input_tracking()
	match_audio.stop()
	time_remaining = ROUND_DURATION
	for slot in MAX_PLAYERS:
		scores[slot] = 0.0
	var eligible: Array[int] = []
	for slot in MAX_PLAYERS:
		if active_slots[slot]: eligible.append(slot)
	token_holder = eligible.pick_random() if not eligible.is_empty() else 0
	tag_cooldown_remaining = 1.0
	round_running = true
	for slot in MAX_PLAYERS:
		players[slot].global_position = PLAYER_SPAWNS[slot]
		players[slot].reset_movement_state()
	for obstacle in obstacle_spawn_transforms:
		obstacle.freeze = false
		obstacle.holder = null
		obstacle.global_transform = obstacle_spawn_transforms[obstacle]
		obstacle.linear_velocity = Vector3.ZERO
		obstacle.angular_velocity = Vector3.ZERO
		obstacle.sleeping = false
	for temporary_item in get_tree().get_nodes_in_group("temporary_item"):
		temporary_item.queue_free()
	for spawner in get_tree().get_nodes_in_group("item_spawner"):
		spawner.set_authoritative(true)
		spawner.reset_spawner()
	_refresh_opponent_targets()
	_set_simulation(true)
	_set_token_holder(token_holder)
	status_label.text = "Player %d has the spark!" % (token_holder + 1)
	_update_world_scoreboard()
	if session_mode == &"host":
		_broadcast_snapshot(true)


func _transfer_token(new_holder: int) -> void:
	var previous_holder := token_holder
	token_holder = new_holder
	tag_cooldown_remaining = TAG_COOLDOWN
	_set_token_holder(token_holder)
	players[token_holder].receive_token_escape(players[previous_holder].global_position)
	status_label.text = "Player %d stole the spark!" % (token_holder + 1)
	_play_match_sfx("tag")


func _set_token_holder(holder: int) -> void:
	for slot in MAX_PLAYERS:
		players[slot].set_has_token(active_slots[slot] and slot == holder)


func _end_round() -> void:
	round_running = false
	_set_simulation(true)
	_celebrate_round()
	_play_match_sfx("round_end")
	status_label.text = _round_result_text()
	if session_mode == &"host":
		_broadcast_snapshot(true)


func _update_world_scoreboard() -> void:
	if is_instance_valid(distant_scoreboards):
		distant_scoreboards.refresh()
	var hud_player := players[local_slot]
	quick_item_name.text = hud_player.get_quick_item_name()
	quick_item_charge.value = hud_player.get_quick_item_readiness() * 100.0
	quick_item_state.text = hud_player.get_quick_item_state()
	stun_crosshair.visible = hud_player.has_stun_gun()
	quick_item_panel.modulate = hud_player.get_quick_item_color() if hud_player.has_spawn_item() or hud_player.is_invisible() else (Color.WHITE if hud_player.get_quick_item_cooldown() <= 0.0 else Color(0.62, 0.7, 0.72))
	var half_track := SCORE_TRACK_LENGTH * 0.5
	for slot in MAX_PLAYERS:
		var length := maxf(0.02, scores[slot] / ROUND_DURATION * SCORE_TRACK_LENGTH) if active_slots[slot] else 0.02
		score_bars[slot].visible = active_slots[slot]
		score_bars[slot].scale.x = length
		score_bars[slot].position.x = -half_track + length * 0.5
		score_labels[slot].visible = active_slots[slot]
		score_labels[slot].text = "YOU" if slot == local_slot else "P%d" % (slot + 1)
	var leader := _leading_slot()
	var tied := false
	for slot in MAX_PLAYERS:
		if slot != leader and active_slots[slot] and absf(scores[slot] - scores[leader]) < 0.01:
			tied = true
	if tied:
		winner_crown.visible = false
	else:
		var target := score_bars[leader].position
		if not winner_crown.visible:
			winner_crown.position = Vector3(target.x, winner_crown.position.y, target.z)
		winner_crown.visible = true
		winner_crown.position.x = lerpf(winner_crown.position.x, target.x, 0.18)
		winner_crown.position.z = lerpf(winner_crown.position.z, target.z, 0.18)


func _player_state(slot: int) -> Dictionary:
	var p := players[slot]
	return {"active": active_slots[slot], "position": p.global_position, "velocity": p.velocity, "crouched": p.crouched, "item": p.equipped_spawn_item, "invisibility": p.invisibility_time_remaining, "magnet": p.get_magnet_time(), "cooldown": p.quick_item_cooldown_remaining, "stun": p.stun_time_remaining, "slippery": p.slippery_time_remaining, "facing": p.body_mesh.rotation.y, "held": String(p.held_chair.name) if is_instance_valid(p.held_chair) else "", "ack": p.simulated_sequence, "motion_epoch": p.motion_epoch, "chase_charge": p.chase_charge}


func _broadcast_snapshot(reliable_state := false) -> void:
	if session_mode != &"host" or multiplayer.get_peers().is_empty():
		return
	snapshot_sequence += 1
	var states: Array = []
	for slot in MAX_PLAYERS:
		states.append(_player_state(slot))
	var spawners := get_tree().get_nodes_in_group("item_spawner")
	var spawn_state: Dictionary = spawners[0].get_network_state() if not spawners.is_empty() else {}
	if reliable_state:
		_receive_round_snapshot.rpc(states, scores, time_remaining, token_holder, spawn_state, round_running, round_epoch, snapshot_sequence)
	else:
		_receive_match_state.rpc(scores, time_remaining, token_holder, spawn_state, round_running, round_epoch, snapshot_sequence)
		for slot in MAX_PLAYERS:
			_receive_player_state.rpc(slot, states[slot], round_epoch, snapshot_sequence)
	var obstacle_batch: Array = []
	for obstacle in _sorted_obstacles():
		var state := {"name": obstacle.name, "transform": obstacle.global_transform, "linear": obstacle.linear_velocity, "angular": obstacle.angular_velocity, "holder": obstacle.holder.player_index if is_instance_valid(obstacle.holder) else -1}
		# Repeat a full keyframe each second so packet loss cannot leave a prop stale.
		if not reliable_state and snapshot_sequence % 20 != 0 and obstacle_last_sent.get(obstacle.name) == state:
			continue
		if not obstacle_batch.is_empty() and var_to_bytes(obstacle_batch + [state]).size() > 900:
			_send_obstacle_batch(obstacle_batch)
			obstacle_batch = []
		obstacle_batch.append(state)
		obstacle_last_sent[obstacle.name] = state
	if not obstacle_batch.is_empty():
		_send_obstacle_batch(obstacle_batch)
	var temporary := _temporary_item_states()
	var key := str(temporary.map(func(state): return state.id))
	if reliable_state or key != manifest_key:
		manifest_key = key
		_receive_effect_manifest.rpc(temporary, round_epoch, snapshot_sequence)
	for state in temporary:
		_receive_effect_state.rpc(state, round_epoch, snapshot_sequence)


func _send_obstacle_batch(batch: Array) -> void:
	_receive_obstacle_batch.rpc(batch,round_epoch,snapshot_sequence)
	network_diagnostics.sent(batch)

@rpc("authority","call_remote","unreliable",2)
func _receive_obstacle_batch(batch: Array, epoch: int, sequence: int) -> void:
	for state in batch:
		_receive_obstacle_state(state,epoch,sequence)

func _accept_epoch(epoch: int) -> bool:
	if session_mode != &"client" or epoch < round_epoch:
		return false
	if epoch > round_epoch:
		round_epoch = epoch
		last_match_sequence = -1
		last_player_sequences = [-1, -1, -1, -1]
		world_sequences.clear()
		effect_ids.clear()
		_reset_input_tracking()
		# A new round may first arrive on any snapshot channel. Retire the old
		# round now, rather than waiting for its reliable effect manifest.
		for item in remote_temporary_items.values():
			if is_instance_valid(item):
				_retire_round_replica(item)
		remote_temporary_items.clear()
		for player in players:
			# Keeps local/remote role flags; fresh snapshots restore host state.
			player.reset_movement_state()
	return true


func _retire_round_replica(item: Node3D) -> void:
	item.hide()
	item.process_mode = Node.PROCESS_MODE_DISABLED
	item.remove_from_group("temporary_item")
	var bodies := item.find_children("*", "CollisionObject3D", true, false)
	if item is CollisionObject3D:
		bodies.append(item)
	for body in bodies:
		# queue_free is deferred: remove collision before new-round prediction.
		body.collision_layer = 0
		body.collision_mask = 0
	item.queue_free()


@rpc("authority", "call_remote", "reliable", 0)
func _receive_round_snapshot(states: Array, new_scores: Array, time: float, holder: int, spawn: Dictionary, running: bool, epoch: int, sequence: int) -> void:
	_receive_snapshot(states, new_scores, time, holder, spawn, running, epoch, sequence)


func _receive_snapshot(states: Array, new_scores: Array, time: float, holder: int, spawn: Dictionary, running: bool, epoch: int = 0, sequence: int = 0) -> void:
	_receive_match_state(new_scores, time, holder, spawn, running, epoch, sequence)
	for slot in mini(states.size(), MAX_PLAYERS):
		_receive_player_state(slot, states[slot], epoch, sequence)


@rpc("authority", "call_remote", "unreliable", 2)
func _receive_match_state(new_scores: Array, time: float, holder: int, spawn: Dictionary, running: bool, epoch: int, sequence: int) -> void:
	if not _accept_epoch(epoch) or sequence <= last_match_sequence:
		return
	last_match_sequence = sequence
	network_diagnostics.received_snapshot()
	time_remaining = time
	token_holder = holder
	round_running = running
	if epoch > 0 and waiting_for_start:
		waiting_for_start = false
		lobby.visible = false
		get_tree().paused = false
		_set_local_camera(local_slot)
	for slot in MAX_PLAYERS:
		scores[slot] = float(new_scores[slot])
	_set_simulation(_can_roam())
	if running and is_instance_valid(celebration):
		celebration.queue_free()
	if not spawn.is_empty():
		var spawners := get_tree().get_nodes_in_group("item_spawner")
		if not spawners.is_empty():
			spawners[0].apply_network_state(spawn)
	if not running:
		status_label.text = _round_result_text()
		if _can_roam():
			_celebrate_round()
	_update_world_scoreboard()


@rpc("authority", "call_remote", "unreliable", 2)
func _receive_player_state(slot: int, state: Dictionary, epoch: int, sequence: int) -> void:
	if not _accept_epoch(epoch) or slot < 0 or slot >= MAX_PLAYERS or sequence <= int(last_player_sequences[slot]):
		return
	last_player_sequences[slot] = sequence
	active_slots[slot] = state.active
	var p := players[slot]
	p.set_slot_active(state.active, true)
	p.client_predicted = slot == local_slot
	p.network_controlled = slot == local_slot
	p.simulation_enabled = state.active and _can_roam()
	if not _can_roam():
		p.replica_target_ready = false
	p.apply_authoritative_motion(state)
	p.equipped_spawn_item = state.item
	p.set_network_invisibility(float(state.invisibility))
	p.remote_magnet_time = float(state.get("magnet", 0.0))
	p.quick_item_cooldown_remaining = float(state.get("cooldown", 0.0))
	p.stun_time_remaining = float(state.get("stun", 0.0))
	p.slippery_time_remaining = float(state.get("slippery", 0.0))
	p.chase_charge = float(state.get("chase_charge", 0.0))
	p.remote_held_name = str(state.get("held", ""))
	if not p.client_predicted:
		p.body_mesh.rotation.y = float(state.get("facing", 0.0))
	p._set_crouched(state.crouched)
	if not round_running and not waiting_for_start:
		status_label.text = _round_result_text()
	_set_token_holder(token_holder)


@rpc("authority", "call_remote", "unreliable", 2)
func _receive_obstacle_state(state: Dictionary, epoch: int, sequence: int) -> void:
	if not _accept_epoch(epoch):
		return
	var key := "chair:" + str(state.name)
	if sequence <= int(world_sequences.get(key, -1)):
		return
	world_sequences[key] = sequence
	for obstacle in _sorted_obstacles():
		if obstacle.name == state.name:
			obstacle.freeze = true
			obstacle.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			obstacle.global_transform = state.transform
			obstacle.linear_velocity = state.linear
			obstacle.angular_velocity = state.angular
			var holder := int(state.get("holder", -1))
			for player in players:
				if player.player_index == holder:
					player.add_collision_exception_with(obstacle)
				else:
					player.remove_collision_exception_with(obstacle)
			obstacle.holder = players[holder] if holder >= 0 and holder < MAX_PLAYERS else null


@rpc("authority", "call_remote", "reliable", 0)
func _receive_effect_manifest(states: Array, epoch: int, sequence: int) -> void:
	if not _accept_epoch(epoch) or sequence <= int(world_sequences.get("manifest", -1)):
		return
	world_sequences["manifest"] = sequence
	effect_ids.clear()
	for state in states:
		effect_ids[str(state.id)] = true
	_apply_temporary_item_states(states, sequence)


@rpc("authority", "call_remote", "unreliable", 2)
func _receive_effect_state(state: Dictionary, epoch: int, sequence: int) -> void:
	if not _accept_epoch(epoch):
		return
	var id := str(state.id)
	if not effect_ids.has(id) or not remote_temporary_items.has(id) or sequence <= int(world_sequences.get(id, -1)):
		return
	world_sequences[id] = sequence
	var item = remote_temporary_items[id]
	if not is_instance_valid(item):
		return
	item.global_position = state.position
	if state.has("chaos"):
		item.apply_state(state.chaos)
	elif state.has("entry"):
		item.get_node("Entry").global_position = state.entry
		item.get_node("Exit").global_position = state.exit


func _temporary_item_states() -> Array:
	var states: Array = []
	for item in get_tree().get_nodes_in_group("temporary_item"):
		if item.is_queued_for_deletion():
			continue
		var state := {"id": item.get_instance_id(), "kind": item.name, "position": item.global_position}
		if item.has_method("network_state"):
			state["chaos"] = item.network_state()
		if item.has_node("Entry"):
			state["entry"] = item.get_node("Entry").global_position
			state["exit"] = item.get_node("Exit").global_position
		states.append(state)
	return states


func _apply_temporary_item_states(states: Array, sequence: int = -1) -> void:
	var wanted: Dictionary = {}
	for state in states:
		var id := str(state.id)
		wanted[id] = true
		if sequence >= 0 and remote_temporary_items.has(id) and is_instance_valid(remote_temporary_items[id]) and int(world_sequences.get(id, -1)) > sequence:
			continue
		if sequence >= 0:
			world_sequences[id] = sequence
		if not remote_temporary_items.has(id):
			var item = CHAOS_EFFECT.new() if state.has("chaos") else (EMERGENCY_DOORS_SCENE.instantiate() if String(state.kind).begins_with("EmergencyDoors") else SLIPPERY_PATCH_SCENE.instantiate())
			add_child(item)
			remote_temporary_items[id] = item
			_disable_remote_item_physics(item)
		var remote_item = remote_temporary_items[id]
		if state.has("chaos"):
			remote_item.global_position = state.position
			remote_item.apply_state(state.chaos)
		if state.has("entry"):
			remote_item.get_node("Entry").global_position = state.entry
			remote_item.get_node("Exit").global_position = state.exit
		else:
			remote_item.global_position = state.position
	for id in remote_temporary_items.keys():
		if not wanted.has(id):
			if is_instance_valid(remote_temporary_items[id]):
				remote_temporary_items[id].queue_free()
			remote_temporary_items.erase(id)


func _disable_remote_item_physics(item: Node) -> void:
	item.set_process(false)
	item.set_physics_process(false)
	if item is Area3D:
		item.monitoring = false
	for child in item.get_children():
		if child is Area3D:
			child.monitoring = false


func _set_local_camera(slot: int) -> void:
	for index in MAX_PLAYERS:
		players[index].set_local_visual_hidden(index == slot)
	camera.set_follow_target(players[slot])
	camera.set_gameplay_input_enabled(true)


func _refresh_opponent_targets() -> void:
	for slot in MAX_PLAYERS:
		players[slot].set_ai_target(null)
		if active_slots[slot]:
			for candidate in MAX_PLAYERS:
				if candidate != slot and active_slots[candidate]:
					players[slot].set_ai_target(players[candidate])
					break


func _first_open_slot() -> int:
	for slot in range(1, MAX_PLAYERS):
		if not active_slots[slot]:
			return slot
	return -1


func _first_active_slot() -> int:
	for slot in MAX_PLAYERS:
		if active_slots[slot]:
			return slot
	return 0


func _leading_slot() -> int:
	var leader := _first_active_slot()
	for slot in MAX_PLAYERS:
		if active_slots[slot] and scores[slot] > scores[leader]:
			leader = slot
	return leader


func _round_result_text() -> String:
	var best := scores[_leading_slot()]
	var winners: Array[String] = []
	for slot in MAX_PLAYERS:
		if active_slots[slot] and absf(scores[slot] - best) < 0.01:
			winners.append("P%d" % (slot + 1))
	return "Tie: %s!" % " & ".join(winners) if winners.size() > 1 else "Player %d wins!" % (_leading_slot() + 1)


func can_touch_players(first: int, second: int) -> bool:
	var a := players[first]
	var b := players[second]
	var query := PhysicsRayQueryParameters3D.create(a.global_position + Vector3.UP * 0.6, b.global_position + Vector3.UP * 0.6, 3, [a.get_rid(), b.get_rid()])
	return a.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _sorted_obstacles() -> Array:
	var obstacles := get_tree().get_nodes_in_group("shoveable")
	obstacles.sort_custom(func(a: Node, b: Node) -> bool: return a.name < b.name)
	return obstacles


func _on_quick_item_event(message: String, slot: int) -> void:
	if slot == local_slot or session_mode in [&"solo", &"host"]:
		status_label.text = message
	if session_mode == &"host":
		_show_item_event.rpc(message, slot)


@rpc("authority", "call_remote", "reliable")
func _show_item_event(message: String, slot: int) -> void:
	if session_mode == &"client":
		status_label.text = ("YOU: " if slot == local_slot else "P%d: " % (slot + 1)) + message


func _play_match_sfx(effect_name: String) -> void:
	if session_mode == &"host":
		_receive_sound.rpc(-1, effect_name)
	match_audio.stream = SFX_LIBRARY.get_effect(effect_name)
	match_audio.play()


func _reset_input_tracking() -> void:
	local_input_sequence = 0
	local_action_sequence = 0
	local_buttons = [false, false, false, false, false, false]
	last_input_send = 0


func _cleanup_slot(slot: int) -> void:
	players[slot].reset_movement_state()
	players[slot].client_predicted = false
	players[slot].network_controlled = false
	players[slot].ai_controlled = false
	players[slot].set_slot_active(false)
	for item in get_tree().get_nodes_in_group("temporary_item"):
		if not item.has_method("network_state"):
			continue
		if item.kind == &"hot_potato":
			if item.target_slot == slot:
				item.queue_free()
		elif item.owner_slot == slot or item.target_slot == slot:
			item.queue_free()


func _prepare_session() -> void:
	if is_instance_valid(report_transfer): report_transfer.reset()
	if is_instance_valid(network_diagnostics):
		network_diagnostics.record("session_teardown_requested",{"previous_mode":str(session_mode)})
	celebrated_epoch = -1
	if is_instance_valid(celebration):
		celebration.queue_free()
	obstacle_last_sent.clear()
	network_diagnostics.reset_session()
	lobby_id = ""
	start_requested_ms = 0
	if is_instance_valid(session_menu):
		session_menu.visible = false
	for player in players:
		player.input_suspended = false
	waiting_for_start = false
	connection_started_ms = 0
	hosted_room_code = ""
	roster_sequence = 0
	received_roster_sequence = -1
	session_mode = &"lobby"
	network_session.close_session()
	peer_to_slot.clear()
	pending_peers.clear()
	peer_input_sequences.clear()
	peer_action_sequences.clear()
	round_running = false
	round_epoch = 0
	snapshot_sequence = 0
	last_match_sequence = -1
	last_player_sequences = [-1, -1, -1, -1]
	world_sequences.clear()
	effect_ids.clear()
	manifest_key = ""
	_reset_input_tracking()
	for slot in MAX_PLAYERS:
		_cleanup_slot(slot)
		players[slot].simulation_enabled = false
		players[slot].name_label.text = "P%d" % (slot + 1)
	active_slots = [true, false, false, false]
	local_slot = 0
	players[0].set_slot_active(true, false)
	players[0].joypad_id = Input.get_connected_joypads()[0] if not Input.get_connected_joypads().is_empty() else -1
	for obstacle in obstacle_spawn_transforms:
		for player in players:
			player.remove_collision_exception_with(obstacle)
		obstacle.holder = null
		obstacle.freeze = false
		obstacle.launch_time = 0.0
		obstacle.global_transform = obstacle_spawn_transforms[obstacle]
		obstacle.linear_velocity = Vector3.ZERO
		obstacle.angular_velocity = Vector3.ZERO
	for item in get_tree().get_nodes_in_group("temporary_item"):
		item.remove_from_group("temporary_item")
		item.queue_free()
	remote_temporary_items.clear()
	for spawner in get_tree().get_nodes_in_group("item_spawner"):
		spawner.set_authoritative(false)
	camera.set_gameplay_input_enabled(false)


func _set_simulation(enabled: bool) -> void:
	if session_mode != &"client":
		for obstacle in _sorted_obstacles():
			obstacle.freeze = not enabled
	for slot in MAX_PLAYERS:
		players[slot].simulation_enabled = enabled and active_slots[slot]
	for item in get_tree().get_nodes_in_group("temporary_item"):
		item.set_physics_process(enabled and session_mode != &"client")
		item.set_process(enabled and session_mode != &"client")
	for spawner in get_tree().get_nodes_in_group("item_spawner"):
		spawner.respawn_timer.paused = not enabled


func _on_player_sound(effect: String, slot: int) -> void:
	if session_mode == &"host":
		_receive_sound.rpc(slot, effect)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_sound(slot: int, effect: String) -> void:
	if session_mode != &"client":
		return
	if slot >= 0 and slot < MAX_PLAYERS:
		players[slot].play_local_sfx(effect)
	else:
		match_audio.stream = SFX_LIBRARY.get_effect(effect)
		match_audio.play()


func _on_player_beam(origin: Vector3, end: Vector3, hit: bool) -> void:
	if session_mode == &"host":
		_receive_beam.rpc(origin, end, hit)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_beam(origin: Vector3, end: Vector3, hit: bool) -> void:
	if session_mode != &"client":
		return
	var beam := STUN_BEAM_SCENE.instantiate()
	add_child(beam)
	beam.setup(origin, end, hit)

func _start_from_lobby() -> void:
	if session_mode == &"hosting":
		_start_hosted_game()
	elif session_mode == &"client" and waiting_for_start and round_epoch == 0 and active_slots.count(true) >= 2:
		if start_requested_ms != 0: return
		start_requested_ms = Time.get_ticks_msec()
		_request_match_start.rpc_id(1)
		lobby_status.text = "Asking the host to start the match…"


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_match_start() -> void:
	if not multiplayer.is_server() or session_mode != &"hosting":
		return
	var sender := multiplayer.get_remote_sender_id()
	if not peer_to_slot.has(sender):
		return
	_start_hosted_game()


func _start_hosted_game() -> void:
	if session_mode != &"hosting" or active_slots.count(true) < 2 or connection_started_ms != 0:
		return
	session_mode = &"host"
	waiting_for_start = false
	local_slot = 0
	lobby.visible = false
	get_tree().paused = false
	_set_local_camera(0)
	reset_round()


func _broadcast_roster() -> void:
	roster_sequence += 1
	if not multiplayer.get_peers().is_empty():
		_receive_roster.rpc(active_slots, roster_sequence)


@rpc("authority", "call_remote", "reliable")
func _receive_roster(slots: Array, sequence: int) -> void:
	if session_mode != &"client" or round_epoch > 0 or sequence <= received_roster_sequence:
		return
	received_roster_sequence = sequence
	active_slots.assign(slots)
	waiting_for_start = true
	lobby.visible = true
	camera.set_gameplay_input_enabled(false)
	get_tree().paused = true
	lobby_status.text = "You're connected. Anyone at the table can start once everyone is here."


func _setup_menu() -> void:
	var box := $Lobby/Panel/Margin/VBox
	for control in box.get_children():
		menu_controls[String(control.name)] = control
	menu_controls.Start.pressed.connect(_start_from_lobby)
	menu_controls.Back.pressed.connect(func(): _enter_lobby("Lobby closed." if session_mode == &"hosting" else "You left the lobby."))
	code_input.text_submitted.connect(func(_text):
		if session_mode == &"lobby": _join_default_lobby())
	kitchen_menu = preload("res://scripts/kitchen_menu.gd").new()
	kitchen_menu.name = "KitchenMenu"
	$Lobby/Panel/Margin.add_child(kitchen_menu)
	kitchen_menu.build(self, menu_controls)
	box.hide()
	_setup_session_menu(kitchen_menu.theme_resource)


func _process(_delta: float) -> void:
	if not is_instance_valid(obstacle_hint):
		obstacle_hint = Label.new()
		$HUD.add_child(obstacle_hint)
		obstacle_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		obstacle_hint.position += Vector2(-260, -100)
		obstacle_hint.size = Vector2(520, 70)
		obstacle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		obstacle_hint.add_theme_font_size_override("font_size", 22)
		obstacle_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pads := Input.get_connected_joypads()
	var restart_pressed := not pads.is_empty() and Input.is_joy_button_pressed(pads[0], JOY_BUTTON_Y)
	var can_restart := session_mode in [&"solo", &"host"] and not lobby.visible and not session_menu.visible and DisplayServer.window_is_focused()
	if restart_pressed and can_restart:
		restart_hold += _delta
		if restart_hold >= 1.0 and not restart_latched:
			restart_latched = true
			reset_round()
	else:
		restart_hold = 0.0
		restart_latched = false
	obstacle_hint.text = ""
	if local_slot >= 0 and local_slot < players.size():
		var p = players[local_slot]
		if is_instance_valid(p.held_chair) or not p.remote_held_name.is_empty():
			if p.charging_throw:
				obstacle_hint.text = "THROW POWER  %d%%" % int(100.0 * p.throw_charge / p.throw_charge_seconds)
	if restart_hold > 0.0:
		obstacle_hint.text = "Restarting: %d%%" % mini(100, int(restart_hold * 100.0))
	if is_instance_valid(distant_scoreboards):
		distant_scoreboards.visible = not lobby.visible
	$HUD.visible = not lobby.visible and not session_menu.visible
	if not lobby.visible:
		return
	if start_requested_ms != 0 and Time.get_ticks_msec() - start_requested_ms > 5000:
		start_requested_ms = 0
		lobby_status.text = "Still waiting for the host to start. You can try Start match again or leave."
	if connection_started_ms != 0:
		var elapsed := (Time.get_ticks_msec() - connection_started_ms) / 1000.0
		menu_controls.Progress.text = "%s%s  %.0fs" % [connection_stage, ".".repeat(int(elapsed * 2) % 4), elapsed]
		if session_mode == &"hosting" and elapsed > 8:
			lobby_status.text = "The router is taking longer than usual. You can cancel and try again."
		if session_mode == &"joining" and elapsed > 15:
			_enter_lobby("Join timed out. The lobby may be offline or full. Ask the host to choose Host lobby and keep Playit running, then retry.")
	kitchen_menu.refresh()
