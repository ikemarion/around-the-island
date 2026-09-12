class_name ATIPlayer
extends CharacterBody3D

const SLIPPERY_PATCH_SCENE := preload("res://scenes/slippery_patch.tscn")
const STUN_BEAM_SCENE := preload("res://scenes/stun_beam.tscn")
const EMERGENCY_DOORS_SCENE := preload("res://scenes/emergency_doors.tscn")
const SFX_LIBRARY := preload("res://scripts/sfx_library.gd")
const CHAOS_EFFECT := preload("res://scripts/chaos_effect.gd")
const CHAOS_NAMES := {&"decoy_double": "DECOY DOUBLE", &"magnet_mayhem": "MAGNET MAYHEM", &"pocket_wall": "POCKET WALL", &"hot_potato": "HOT POTATO", &"bungee_hook": "BUNGEE HOOK"}
var magnet_effect
var remote_magnet_time := 0.0

signal quick_item_event(message: String)
signal sound_event(effect_name: String)
signal beam_event(origin: Vector3, end: Vector3, hit: bool)
var simulation_enabled := true
var client_predicted := false
var motion_epoch := 0
var input_sequence := 0
var simulated_sequence := 0
var last_input_ms := 0
var action_queue: Array = []
var action_aim := Vector3.ZERO
var input_suspended := false
var action_jump := false
var action_throw := false
var action_quick := false
var prediction_history: Dictionary = {}
var camera_correction := Vector3.ZERO
var replica_target := Vector3.ZERO
var replica_target_ready := false
var remote_held_name := ""


## Learning note: CharacterBody3D is controlled explicitly. We calculate a desired
## horizontal velocity, apply gravity, then ask Godot to move and resolve collisions.

@export var max_speed: float = 6.2
@export var acceleration: float = 25.0
@export var reverse_acceleration: float = 11.0
@export var braking: float = 20.0
@export var push_force: float = 42.0
@export var ai_reaction_time: float = 0.14

@export_group("Traversal")
@export var jump_velocity: float = 8.5
@export var crouch_speed: float = 3.8
@export var slide_minimum_speed: float = 4.2
@export var slide_initial_speed: float = 9.0
@export var slide_duration: float = 0.7
@export var slide_friction: float = 6.5
@export var slide_steering: float = 2.0
@export var standing_height: float = 1.6
@export var crouching_height: float = 0.95
@export var standing_view_height: float = 1.48
@export var crouching_view_height: float = 0.82

@export_group("Interaction")
@export var grab_reach: float = 4.2
@export var grab_minimum_aim_dot: float = 0.5
@export var grab_hold_distance: float = 1.6
@export var grab_hold_drop: float = 0.58
@export var grab_spring_strength: float = 105.0
@export var grab_spring_damping: float = 22.0
@export var grab_maximum_force: float = 300.0
@export var grab_break_distance: float = 4.8
@export var chair_throw_impulse: float = 7.5
@export var chair_throw_lift: float = 0.16
@export var throw_charge_seconds: float = 1.0
@export var charged_throw_multiplier: float = 2.5
@export var obstacle_shove_impulse: float = 15.0
var action_pull := false
var pull_was_pressed := false
var throw_charge := 0.0
var charging_throw := false

@export_group("Quick Item")
@export var slippery_item_cooldown: float = 4.0
@export var slippery_steering_factor: float = 0.2
@export var slippery_braking_factor: float = 0.08
@export var slippery_slide_friction: float = 1.4
@export var stun_gun_range: float = 15.0
@export var stun_duration: float = 1.05
@export var air_horn_range: float = 4.2
@export var air_horn_impulse: float = 75.0
@export var invisibility_duration: float = 5.0
@export var ai_jump_check_distance: float = 1.3
@export var ai_jump_cooldown: float = 0.85

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var token_marker: Node3D = $TokenMarker
@onready var name_label: Label3D = $NameLabel
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var player_index: int = 0
var joypad_id: int = -1
var has_token: bool = false
var ai_controlled: bool = false
var network_controlled: bool = false
var network_replica: bool = false
var network_movement_input := Vector2.ZERO
var network_aim_forward := Vector3.FORWARD
var network_jump_pressed: bool = false
var network_crouch_pressed: bool = false
var network_interact_pressed: bool = false
var network_throw_pressed: bool = false
var network_quick_item_pressed: bool = false
var network_stun_fire_was_pressed: bool = false
var ai_target: ATIPlayer
var ai_think_remaining: float = 0.0
var ai_cached_direction := Vector2.ZERO
var ai_jump_cooldown_remaining: float = 0.0
var local_visual_hidden: bool = false
var crouched: bool = false
var crouch_was_pressed: bool = false
var jump_was_pressed: bool = false
var slide_time_remaining: float = 0.0
var slide_direction := Vector2.ZERO
var current_view_height: float = standing_view_height
var interact_was_pressed: bool = false
var throw_was_pressed: bool = false
var quick_item_was_pressed: bool = false
var held_chair: ATIShoveable
var highlighted_chair: ATIShoveable
var slippery_time_remaining: float = 0.0
var quick_item_cooldown_remaining: float = 0.0
var equipped_spawn_item: StringName = &""
var stun_time_remaining: float = 0.0
var invisibility_time_remaining: float = 0.0
var sfx_players: Array[AudioStreamPlayer3D] = []
var body_material: StandardMaterial3D
var body_color := Color.WHITE
var movement_history: Array[Dictionary] = []
var history_sample_time: float = 0.0
var chase_charge := 0.0

# Startup fallback while the modular house builds its navigation grid. These
# bounds include player clearance around the 7.5 x 3.2 meter kitchen island.
const ISLAND_HALF_EXTENTS := Vector2(4.18, 2.03)
const ROUTE_CORNERS: Array[Vector2] = [
	Vector2(-4.45, -2.3),
	Vector2(4.45, -2.3),
	Vector2(4.45, 2.3),
	Vector2(-4.45, 2.3),
]
const FLEE_POINTS: Array[Vector2] = [
	Vector2(-6.8, -4.4),
	Vector2(0.0, -4.6),
	Vector2(6.8, -4.4),
	Vector2(6.8, 4.4),
	Vector2(0.0, 4.6),
	Vector2(-6.8, 4.4),
]


func _ready() -> void:
	add_child(preload("res://scripts/spark_trail.gd").new())
	# Each player gets an independent shape resource before stance changes resize
	# it; otherwise crouching Player 1 would also shrink the bot's collider.
	collision_shape.shape = collision_shape.shape.duplicate()
	for _index in 4:
		var audio_player := AudioStreamPlayer3D.new()
		audio_player.max_distance = 24.0
		audio_player.unit_size = 3.0
		add_child(audio_player)
		sfx_players.append(audio_player)


func configure(index: int, assigned_joypad: int, color: Color, controlled_by_ai: bool = false) -> void:
	player_index = index
	joypad_id = assigned_joypad
	ai_controlled = controlled_by_ai
	name_label.text = "BOT" if ai_controlled else "P%d" % (index + 1)

	body_color = color
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = color
	body_material.roughness = 0.7
	body_mesh.material_override = body_material


func set_ai_target(target: ATIPlayer) -> void:
	ai_target = target


func set_network_input(movement: Vector2, aim_forward: Vector3, jump: bool, crouch: bool, interact: bool, throw_item: bool, quick_item: bool) -> void:
	if not movement.is_finite() or not aim_forward.is_finite() or aim_forward.length_squared() < 0.001:
		return
	last_input_ms = Time.get_ticks_msec()
	network_movement_input = movement.limit_length(1.0)
	network_aim_forward = aim_forward.normalized()
	network_jump_pressed = jump
	network_crouch_pressed = crouch
	network_interact_pressed = interact
	network_throw_pressed = throw_item
	network_quick_item_pressed = quick_item


func set_slot_active(value: bool, replica: bool = false) -> void:
	if not value and visible:
		reset_movement_state()
	visible = value
	network_replica = replica or not value
	collision_layer = 1 if value else 0
	collision_mask = 3 if value else 0
	if not value:
		velocity = Vector3.ZERO


func set_has_token(value: bool) -> void:
	if value != has_token:
		chase_charge = 0.0
	has_token = value
	_refresh_character_visuals()


func set_local_visual_hidden(value: bool) -> void:
	local_visual_hidden = value
	_refresh_character_visuals()


func set_network_invisibility(time_left: float) -> void:
	invisibility_time_remaining = maxf(0.0, time_left)
	_refresh_character_visuals()


func is_invisible() -> bool:
	return invisibility_time_remaining > 0.0


func _refresh_character_visuals() -> void:
	var hidden := local_visual_hidden or is_invisible()
	body_mesh.visible = not hidden
	name_label.visible = not hidden
	token_marker.visible = has_token and not hidden


func get_view_height() -> float:
	return current_view_height


func get_quick_item_cooldown() -> float:
	return quick_item_cooldown_remaining


func get_quick_item_name() -> String:
	if get_magnet_time() > 0.0:
		return "MAGNET MAYHEM"
	if CHAOS_NAMES.has(equipped_spawn_item):
		return CHAOS_NAMES[equipped_spawn_item]
	match equipped_spawn_item:
		&"stun_gun": return "STUN GUN"
		&"air_horn": return "AIR HORN"
		&"swap_bell": return "SWAP BELL"
		&"invisibility": return "INVISIBILITY"
		&"rewind_watch": return "REWIND WATCH"
		&"emergency_door": return "EMERGENCY DOOR"
		_: return "INVISIBLE" if is_invisible() else "NO POWER-UP"


func get_quick_item_state() -> String:
	if get_magnet_time() > 0.0:
		return "FARTHEST RIVAL MAGNETIZED %.1fs" % get_magnet_time()
	if CHAOS_NAMES.has(equipped_spawn_item):
		return "AIM AT PLAYER + Q" if equipped_spawn_item in [&"hot_potato", &"bungee_hook"] else "USE WITH Q"
	match equipped_spawn_item:
		&"stun_gun": return "ONE SHOT — AIM + M1 / Q"
		&"air_horn": return "ONE SHOT — AIM + Q"
		&"swap_bell": return "ONE SHOT — SWAP WITH Q"
		&"invisibility": return "ONE SHOT — VANISH WITH Q"
		&"rewind_watch": return "ONE SHOT — REWIND WITH Q"
		&"emergency_door": return "ONE SHOT — OPEN WITH Q"
	if is_invisible():
		return "HIDDEN  %.1fs" % invisibility_time_remaining
	return "FIND A PICKUP"


func get_quick_item_color() -> Color:
	if CHAOS_NAMES.has(equipped_spawn_item) or get_magnet_time() > 0.0:
		return Color("ff9cdd")
	match equipped_spawn_item:
		&"stun_gun": return Color("ffe56b")
		&"air_horn": return Color("ff8a45")
		&"swap_bell": return Color("57d6ff")
		&"invisibility": return Color("a78bfa")
		&"rewind_watch": return Color("cd78ff")
		&"emergency_door": return Color("62fff0")
		_: return Color("a78bfa") if is_invisible() else Color.WHITE


func get_quick_item_readiness() -> float:
	if get_magnet_time() > 0.0:
		return get_magnet_time() / 5.0
	if has_spawn_item():
		return 1.0
	if is_invisible():
		return clampf(invisibility_time_remaining / invisibility_duration, 0.0, 1.0)
	return 0.0


func has_spawn_item() -> bool:
	return equipped_spawn_item != &""


func has_stun_gun() -> bool:
	return equipped_spawn_item == &"stun_gun"


func try_pickup_item(item_type: StringName) -> bool:
	if item_type in [&"bungee_hook", &"slick_trap"]:
		return false
	if ai_controlled or has_spawn_item():
		return false
	equipped_spawn_item = item_type
	_play_sfx("pickup")
	quick_item_event.emit("%s loaded — press Q to use it!" % get_quick_item_name().capitalize())
	return true


func apply_stun(duration: float) -> void:
	stun_time_remaining = maxf(stun_time_remaining, duration)
	velocity.x *= 0.2
	velocity.z *= 0.2
	_release_chair()
	_play_sfx("stunned")


func apply_knockback(impulse: Vector3) -> void:
	velocity += impulse


func apply_launch(force: float) -> void:
	velocity.y = maxf(velocity.y, force)
	slide_time_remaining = 0.0
	_play_sfx("spring")


func on_emergency_door_used() -> void:
	_play_sfx("door")


func apply_slippery(duration: float) -> void:
	if slippery_time_remaining <= 0.0:
		_play_sfx("slip")
	slippery_time_remaining = maxf(slippery_time_remaining, duration)


func reset_movement_state() -> void:
	chase_charge = 0.0
	_set_highlighted_chair(null)
	network_movement_input = Vector2.ZERO
	network_aim_forward = Vector3.FORWARD
	network_jump_pressed = false
	network_crouch_pressed = false
	network_interact_pressed = false
	network_throw_pressed = false
	network_quick_item_pressed = false
	action_queue.clear()
	action_aim = Vector3.ZERO
	action_jump = false
	action_throw = false
	action_quick = false
	prediction_history.clear()
	camera_correction = Vector3.ZERO
	replica_target_ready = false
	remote_held_name = ""
	input_sequence = 0
	simulated_sequence = 0
	ai_target = null
	motion_epoch += 1
	if is_instance_valid(magnet_effect):
		magnet_effect.queue_free()
	magnet_effect = null
	remote_magnet_time = 0.0
	_release_chair()
	velocity = Vector3.ZERO
	slide_time_remaining = 0.0
	slide_direction = Vector2.ZERO
	crouch_was_pressed = false
	jump_was_pressed = false
	interact_was_pressed = false
	pull_was_pressed = false
	action_pull = false
	throw_was_pressed = false
	quick_item_was_pressed = false
	network_stun_fire_was_pressed = false
	slippery_time_remaining = 0.0
	quick_item_cooldown_remaining = 0.0
	equipped_spawn_item = &""
	stun_time_remaining = 0.0
	invisibility_time_remaining = 0.0
	ai_jump_cooldown_remaining = 0.0
	movement_history.clear()
	history_sample_time = 0.0
	for audio_player in sfx_players:
		audio_player.stop()
	_set_crouched(false)
	current_view_height = standing_view_height
	_refresh_character_visuals()


func respawn_at(spawn_position: Vector3) -> void:
	chase_charge = 0.0
	motion_epoch += 1
	movement_history.clear()
	_release_chair()
	global_position = spawn_position
	velocity = Vector3.ZERO
	slide_time_remaining = 0.0
	slide_direction = Vector2.ZERO
	stun_time_remaining = 0.0
	slippery_time_remaining = 0.0
	_set_crouched(false)


func receive_token_escape(from_position: Vector3) -> void:
	# A small burst prevents immediate re-tagging and makes a transfer readable.
	var away := global_position - from_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.RIGHT
	velocity += away.normalized() * 3.2


func _physics_process(delta: float) -> void:
	camera_correction = camera_correction.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
	if not simulation_enabled:
		_update_presentation(delta)
		return
	if network_replica and not client_predicted:
		if replica_target_ready:
			global_position = global_position.lerp(replica_target, 1.0 - exp(-22.0 * delta))
		_update_presentation(delta)
		return
	if network_controlled and not client_predicted and Time.get_ticks_msec() - last_input_ms > 500:
		network_movement_input = Vector2.ZERO
		network_crouch_pressed = false
		network_interact_pressed = false
		action_queue.clear()
		_release_chair()
	action_jump = false
	action_throw = false
	action_quick = false
	action_aim = Vector3.ZERO
	action_pull = false
	if not action_queue.is_empty():
		var queued = action_queue.pop_front()
		var action: StringName = queued.kind if queued is Dictionary else StringName(queued)
		if queued is Dictionary:
			action_aim = queued.aim
		action_jump = action == &"jump"
		action_throw = action == &"throw"
		action_quick = action == &"quick"
		action_pull = action == &"pull"
	slippery_time_remaining = maxf(0.0, slippery_time_remaining - delta)
	stun_time_remaining = maxf(0.0, stun_time_remaining - delta)
	var was_invisible := is_invisible()
	invisibility_time_remaining = maxf(0.0, invisibility_time_remaining - delta)
	if was_invisible != is_invisible():
		_refresh_character_visuals()
	ai_jump_cooldown_remaining = maxf(0.0, ai_jump_cooldown_remaining - delta)
	var is_stunned := stun_time_remaining > 0.0
	var previous_item_cooldown := quick_item_cooldown_remaining
	quick_item_cooldown_remaining = maxf(0.0, quick_item_cooldown_remaining - delta)
	if previous_item_cooldown > 0.0 and quick_item_cooldown_remaining <= 0.0:
		_play_sfx("ready")
	var input_direction := Vector2.ZERO if is_stunned else _read_movement_input(delta)
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	var crouch_pressed := _is_crouch_pressed()
	var jump_pressed := _is_jump_pressed()
	var crouch_just_pressed := crouch_pressed and not crouch_was_pressed
	var jump_just_pressed := action_jump if network_controlled else (jump_pressed and not jump_was_pressed)
	crouch_was_pressed = crouch_pressed
	jump_was_pressed = jump_pressed
	var jumped_this_frame := false

	if not is_stunned and not ai_controlled and crouch_just_pressed and is_on_floor() and horizontal_velocity.length() >= slide_minimum_speed:
		slide_time_remaining = slide_duration
		slide_direction = horizontal_velocity.normalized()
		horizontal_velocity = slide_direction * maxf(slide_initial_speed, horizontal_velocity.length())
		_play_sfx("slide")

	if not is_stunned and jump_just_pressed and is_on_floor():
		velocity.y = jump_velocity
		jumped_this_frame = true
		slide_time_remaining = 0.0
		if ai_controlled:
			ai_jump_cooldown_remaining = ai_jump_cooldown
		_play_sfx("jump")

	var should_crouch := not is_stunned and not ai_controlled and (crouch_pressed or slide_time_remaining > 0.0)
	_set_crouched(should_crouch)
	_update_chase_charge(delta, input_direction.length_squared() > 0.1 and not should_crouch and not is_stunned)

	if slide_time_remaining > 0.0:
		slide_time_remaining = maxf(0.0, slide_time_remaining - delta)
		if input_direction.length_squared() > 0.01:
			slide_direction = slide_direction.lerp(input_direction.normalized(), slide_steering * delta).normalized()
		var applied_slide_friction := slippery_slide_friction if slippery_time_remaining > 0.0 else slide_friction
		var slide_speed := maxf(crouch_speed, horizontal_velocity.length() - applied_slide_friction * delta)
		horizontal_velocity = slide_direction * slide_speed
	else:
		var movement_speed := crouch_speed if crouched else max_speed
		movement_speed *= _chase_speed_multiplier()
		var desired_velocity := input_direction * movement_speed
		if input_direction.length_squared() > 0.01:
			var traction := slippery_steering_factor if slippery_time_remaining > 0.0 else 1.0
			var applied_acceleration := acceleration * traction
			if horizontal_velocity.length() > 0.5:
				var moving_direction := horizontal_velocity.normalized()
				if moving_direction.dot(input_direction) < -0.25:
					applied_acceleration = reverse_acceleration * traction
			horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, applied_acceleration * delta)
		else:
			var applied_braking := braking * (slippery_braking_factor if slippery_time_remaining > 0.0 else 1.0)
			horizontal_velocity = horizontal_velocity.move_toward(Vector2.ZERO, applied_braking * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.y

	if jumped_this_frame:
		pass
	elif not is_on_floor() or velocity.y > 0.0:
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.5

	move_and_slide()
	if client_predicted:
		prediction_history[input_sequence] = {"position": global_position, "velocity": velocity}
		while prediction_history.size() > 120:
			prediction_history.erase(prediction_history.keys()[0])
		_update_client_highlight()
		_update_presentation(delta)
		action_aim = Vector3.ZERO
		return
	simulated_sequence = input_sequence
	_push_rigid_bodies()
	if is_stunned:
		_release_chair()
		_set_highlighted_chair(null)
	else:
		var chair_was_held := is_instance_valid(held_chair)
		_update_chair_interaction()
		_update_quick_item(chair_was_held)
	action_aim = Vector3.ZERO
	if is_instance_valid(body_material):
		if is_stunned:
			body_material.albedo_color = Color("fff06a")
		else:
			body_material.albedo_color = body_color

	if horizontal_velocity.length() > 0.2:
		var facing := Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.y)
		body_mesh.rotation.y = lerp_angle(body_mesh.rotation.y, atan2(facing.x, facing.z), 12.0 * delta)

	_update_presentation(delta)
	_record_movement_history(delta)


func _update_chase_charge(delta: float, running: bool) -> void:
	var game = get_tree().current_scene
	if game == null or not "round_running" in game or not game.round_running or has_token:
		chase_charge = 0.0
	else:
		chase_charge = move_toward(chase_charge, 1.0 if running else 0.0, delta / (6.0 if running else 2.0))


func _chase_speed_multiplier() -> float:
	var game = get_tree().current_scene
	if game == null or not "round_running" in game or not game.round_running:
		return 1.0
	return 0.93 if has_token else (1.0 + 0.15 * chase_charge if not crouched else 1.0)


func _update_presentation(delta: float) -> void:
	var desired := crouching_view_height if crouched else standing_view_height
	current_view_height = lerpf(current_view_height, desired, 1.0 - exp(-14.0 * delta))
	if is_instance_valid(body_material):
		body_material.albedo_color = Color("fff06a") if stun_time_remaining > 0.0 else body_color


func apply_authoritative_motion(state: Dictionary) -> void:
	var epoch := int(state.get("motion_epoch", 0))
	var changed := epoch != motion_epoch or not replica_target_ready
	replica_target_ready = true
	replica_target = state.position
	motion_epoch = epoch
	if client_predicted:
		var ack := int(state.get("ack", 0))
		if changed:
			global_position = state.position
			velocity = state.velocity
			prediction_history.clear()
			camera_correction = Vector3.ZERO
			slide_time_remaining = 0.0
		elif prediction_history.has(ack):
			var error: Vector3 = state.position - prediction_history[ack].position
			var velocity_error: Vector3 = state.velocity - prediction_history[ack].velocity
			global_position += error
			velocity += velocity_error
			for sequence in prediction_history.keys():
				if sequence > ack:
					prediction_history[sequence].position += error
					prediction_history[sequence].velocity += velocity_error
			if error.length() < 3.0:
				camera_correction -= error
			else:
				camera_correction = Vector3.ZERO
		else:
			# The server may repeat an ack or outlive our bounded history during loss.
			# Rebase at its known-safe position instead of ignoring the correction.
			global_position = state.position
			velocity = state.velocity
			prediction_history.clear()
			camera_correction = Vector3.ZERO
			slide_time_remaining = 0.0
		for sequence in prediction_history.keys():
			if sequence <= ack:
				prediction_history.erase(sequence)
	else:
		velocity = state.velocity
		if changed or global_position.distance_to(replica_target) > 3.0:
			global_position = replica_target


func _update_client_highlight() -> void:
	_set_highlighted_chair(_find_grabbable_chair() if remote_held_name.is_empty() else null)
	charging_throw = not remote_held_name.is_empty() and _is_throw_pressed()
	throw_charge = minf(throw_charge_seconds, throw_charge + get_physics_process_delta_time()) if charging_throw else 0.0


func _set_crouched(value: bool) -> void:
	if crouched == value:
		return
	crouched = value
	var capsule := collision_shape.shape as CapsuleShape3D
	var target_height := crouching_height if crouched else standing_height
	capsule.height = target_height
	collision_shape.position.y = 0.05 + target_height * 0.5
	body_mesh.position.y = collision_shape.position.y
	body_mesh.scale.y = target_height / standing_height
	token_marker.position.y = target_height + 0.25
	name_label.position.y = target_height + 0.65


func _is_jump_pressed() -> bool:
	if input_suspended:
		return false
	if network_controlled:
		return network_jump_pressed
	if ai_controlled:
		return _should_ai_jump()
	var pressed := Input.is_physical_key_pressed(KEY_SPACE)
	if joypad_id >= 0:
		pressed = pressed or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_A)
	return pressed


func _should_ai_jump() -> bool:
	if not is_on_floor() or ai_jump_cooldown_remaining > 0.0 or ai_cached_direction.length_squared() < 0.25:
		return false
	var direction := Vector3(ai_cached_direction.x, 0.0, ai_cached_direction.y).normalized()
	var origin := global_position + Vector3.UP * 0.42
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * ai_jump_check_distance)
	var exclusions: Array[RID] = [get_rid()]
	if is_instance_valid(ai_target):
		exclusions.append(ai_target.get_rid())
	query.exclude = exclusions
	query.collision_mask = 1
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var collider := result.get("collider") as Node
	return collider != null and collider.is_in_group("shoveable")


func _is_crouch_pressed() -> bool:
	if input_suspended:
		return false
	if network_controlled:
		return network_crouch_pressed
	if ai_controlled:
		return false
	var pressed := Input.is_physical_key_pressed(KEY_SHIFT)
	if joypad_id >= 0:
		pressed = pressed or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_LEFT_STICK)
	return pressed


func _is_interact_pressed() -> bool:
	if input_suspended:
		return false
	if network_controlled:
		return network_interact_pressed
	if ai_controlled:
		return false
	var pressed := Input.is_physical_key_pressed(KEY_E)
	if joypad_id >= 0:
		pressed = pressed or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_X)
	return pressed


func _is_throw_pressed() -> bool:
	if input_suspended:
		return false
	if network_controlled:
		return network_throw_pressed
	if ai_controlled:
		return false
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if joypad_id >= 0:
		pressed = pressed or Input.get_joy_axis(joypad_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	return pressed


func _is_quick_item_pressed() -> bool:
	if input_suspended:
		return false
	if network_controlled:
		return network_quick_item_pressed
	if ai_controlled:
		return false
	var pressed := Input.is_physical_key_pressed(KEY_Q)
	if joypad_id >= 0:
		pressed = pressed or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_RIGHT_SHOULDER)
	return pressed


func _update_chair_interaction() -> void:
	if ai_controlled:
		return

	var interact_pressed := _is_interact_pressed()
	var interact_just_pressed := interact_pressed and not interact_was_pressed
	interact_was_pressed = interact_pressed
	var throw_pressed := _is_throw_pressed()
	var throw_just_pressed := action_throw if network_controlled else (throw_pressed and not throw_was_pressed)
	throw_was_pressed = throw_pressed
	var pull_pressed := not input_suspended and (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (joypad_id >= 0 and Input.get_joy_axis(joypad_id, JOY_AXIS_TRIGGER_LEFT) > 0.5))
	var pull_just_pressed := action_pull if network_controlled else (pull_pressed and not pull_was_pressed)
	pull_was_pressed = pull_pressed

	if is_instance_valid(held_chair):
		_set_highlighted_chair(null)
		if throw_just_pressed:
			charging_throw = true
		if charging_throw and not throw_pressed:
			_throw_chair()
			return
		if not interact_pressed or global_position.distance_to(held_chair.global_position) > grab_break_distance:
			_release_chair()
			return
		if charging_throw:
			throw_charge = minf(throw_charge_seconds, throw_charge + get_physics_process_delta_time())
		_apply_grab_spring()
		return

	var candidate := _find_grabbable_chair()
	_set_highlighted_chair(candidate)
	if interact_just_pressed and is_instance_valid(candidate):
		_grab_chair(candidate)
	elif throw_just_pressed and not has_stun_gun() and is_instance_valid(candidate):
		candidate.launch((_get_aim_forward() + Vector3.UP * 0.12).normalized() * obstacle_shove_impulse)
		_play_sfx("throw")
	elif pull_just_pressed and is_instance_valid(candidate):
		candidate.launch((global_position + Vector3.UP * 0.8 - candidate.global_position).normalized() * obstacle_shove_impulse)
		_play_sfx("grab")


func _find_grabbable_chair() -> ATIShoveable:
	var origin := _get_aim_origin()
	var forward := _get_aim_forward()
	var best_chair: ATIShoveable
	var best_score := -INF

	for node in get_tree().get_nodes_in_group("shoveable"):
		if not node is ATIShoveable:
			continue
		var chair := node as ATIShoveable
		if is_instance_valid(chair.holder) and chair.holder != self:
			continue
		var offset := chair.global_position - origin
		var distance := offset.length()
		if distance <= 0.01 or distance > grab_reach:
			continue
		var aim_dot := forward.dot(offset / distance)
		if aim_dot < grab_minimum_aim_dot:
			continue
		if not _has_clear_grab_line(origin, chair):
			continue

		var score := aim_dot * 2.0 - distance * 0.12
		if chair == highlighted_chair:
			score += 0.15 # Prevent flickering between nearby targets.
		if score > best_score:
			best_score = score
			best_chair = chair

	return best_chair


func _has_clear_grab_line(origin: Vector3, chair: ATIShoveable) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, chair.global_position)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.get("collider") == chair


func _grab_chair(chair: ATIShoveable) -> void:
	if not chair.try_claim(self):
		return
	held_chair = chair
	_set_highlighted_chair(null)
	add_collision_exception_with(chair)
	chair.add_collision_exception_with(self)
	chair.sleeping = false
	_play_sfx("grab")


func _release_chair() -> void:
	throw_charge = 0.0
	charging_throw = false
	if is_instance_valid(held_chair):
		held_chair.release_claim(self)
		remove_collision_exception_with(held_chair)
		held_chair.remove_collision_exception_with(self)
	held_chair = null


func _throw_chair() -> void:
	if not is_instance_valid(held_chair):
		return
	var thrown_chair := held_chair
	var strength := lerpf(chair_throw_impulse, chair_throw_impulse * charged_throw_multiplier, clampf(throw_charge / throw_charge_seconds, 0.0, 1.0))
	var throw_direction := (_get_aim_forward() + Vector3.UP * chair_throw_lift).normalized()
	_release_chair()
	thrown_chair.launch(throw_direction * strength)
	_play_sfx("throw")


func _set_highlighted_chair(chair: ATIShoveable) -> void:
	if network_controlled and not client_predicted and chair != null:
		return
	if highlighted_chair == chair:
		return
	if is_instance_valid(highlighted_chair):
		highlighted_chair.set_highlighted(false)
	highlighted_chair = chair
	if is_instance_valid(highlighted_chair):
		highlighted_chair.set_highlighted(true)


func _apply_grab_spring() -> void:
	var forward := _get_aim_forward()
	var target_position := _get_aim_origin() + forward * grab_hold_distance + Vector3.DOWN * grab_hold_drop
	# Keep the carry anchor on this side of walls instead of dragging through them.
	var query := PhysicsRayQueryParameters3D.create(_get_aim_origin(), target_position)
	query.exclude = [get_rid(), held_chair.get_rid()]
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target_position = hit.position + hit.normal * 0.65
	var position_error := target_position - held_chair.global_position
	var target_velocity := velocity
	var force := position_error * grab_spring_strength + (target_velocity - held_chair.linear_velocity) * grab_spring_damping
	force += Vector3.UP * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * held_chair.mass * held_chair.gravity_scale
	if force.length() > grab_maximum_force:
		force = force.normalized() * grab_maximum_force
	held_chair.apply_central_force(force)


func _update_quick_item(chair_was_held: bool = false) -> void:
	if ai_controlled:
		return
	var quick_item_pressed := _is_quick_item_pressed()
	var quick_item_just_pressed := action_quick if network_controlled else (quick_item_pressed and not quick_item_was_pressed)
	quick_item_was_pressed = quick_item_pressed
	var network_stun_fire_pressed := (network_controlled and action_throw) or (not network_controlled and joypad_id >= 0 and Input.get_joy_axis(joypad_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5)
	var network_stun_fire_just_pressed := network_stun_fire_pressed and (network_controlled or not network_stun_fire_was_pressed) and has_stun_gun() and not chair_was_held
	network_stun_fire_was_pressed = network_stun_fire_pressed

	if not quick_item_just_pressed and not network_stun_fire_just_pressed:
		return
	# Magnet Mayhem is now a committed timed sabotage effect. Extra presses must
	# not end it early or accidentally deploy the default slick trap underneath it.
	if quick_item_just_pressed and is_instance_valid(magnet_effect) and not magnet_effect.spent:
		return
	if has_spawn_item():
		_use_equipped_spawn_item()
		return
	# Empty hands no longer deploy a default slick trap.


func _unhandled_input(event: InputEvent) -> void:
	if input_suspended or not simulation_enabled or stun_time_remaining > 0.0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or network_controlled or network_replica or ai_controlled or equipped_spawn_item != &"stun_gun" or is_instance_valid(held_chair):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_use_stun_gun()


func _use_stun_gun() -> void:
	if not simulation_enabled or stun_time_remaining > 0.0 or equipped_spawn_item != &"stun_gun":
		return
	_fire_stun_gun()
	equipped_spawn_item = &""


func _use_equipped_spawn_item() -> void:
	var item_type := equipped_spawn_item
	equipped_spawn_item = &""
	match item_type:
		&"stun_gun": _fire_stun_gun()
		&"air_horn": _use_air_horn()
		&"swap_bell": _use_swap_bell()
		&"invisibility": _use_invisibility()
		&"rewind_watch": _use_rewind_watch()
		&"emergency_door": _deploy_emergency_doors()
		&"decoy_double", &"magnet_mayhem", &"pocket_wall", &"hot_potato": _use_chaos_effect(item_type)


func get_magnet_time() -> float:
	if network_replica:
		return remote_magnet_time
	return maxf(magnet_effect.remaining, 0.0) if is_instance_valid(magnet_effect) and not magnet_effect.spent else 0.0


func _use_chaos_effect(kind: StringName) -> void:
	var target = null
	if kind == &"magnet_mayhem":
		target = _find_farthest_active_opponent()
		if target == null:
			equipped_spawn_item = kind
			quick_item_event.emit("No active opponent to magnetize — item kept.")
			return
	if kind in [&"hot_potato", &"bungee_hook"]:
		var best_dot := 0.65
		for candidate in get_tree().current_scene.players:
			if candidate == self or not candidate.visible or candidate.is_invisible():
				continue
			var offset: Vector3 = candidate.global_position + Vector3.UP - _get_aim_origin()
			if offset.length() > 10.0 or offset.length() < 0.01:
				continue
			var aim_dot := _get_aim_forward().dot(offset.normalized())
			var ray := PhysicsRayQueryParameters3D.create(_get_aim_origin(), candidate.global_position + Vector3.UP, 3, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if aim_dot > best_dot and (hit.is_empty() or hit.collider == candidate):
				best_dot = aim_dot
				target = candidate
		if target == null:
			equipped_spawn_item = kind
			quick_item_event.emit("Aim at a visible player within ten meters — item kept.")
			return
	if kind == &"pocket_wall":
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.8, 2.0, 0.3)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		var forward := _get_flat_aim_direction()
		query.transform = Transform3D(Basis(Vector3.UP, atan2(forward.x, forward.z)), global_position - forward * 1.8 + Vector3.UP * 1.05)
		query.collision_mask = 3
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			equipped_spawn_item = kind
			quick_item_event.emit("No room behind you for the wall — item kept.")
			return
	var effect := CHAOS_EFFECT.new()
	get_tree().current_scene.add_child(effect)
	effect.setup(kind, self, target)
	_play_sfx("deploy")
	if kind == &"magnet_mayhem":
		quick_item_event.emit("MAGNET MAYHEM! P%d is attracting every loose prop." % (target.player_index + 1))
	else:
		quick_item_event.emit("%s activated!" % CHAOS_NAMES[kind])


func _find_farthest_active_opponent():
	var farthest = null
	var farthest_distance := -1.0
	for candidate in get_tree().current_scene.players:
		var candidate_slot: int = candidate.player_index
		if candidate == self or candidate_slot < 0 or candidate_slot >= get_tree().current_scene.active_slots.size() or not get_tree().current_scene.active_slots[candidate_slot]:
			continue
		var candidate_distance := global_position.distance_squared_to(candidate.global_position)
		if candidate_distance > farthest_distance:
			farthest_distance = candidate_distance
			farthest = candidate
	return farthest


func _use_air_horn() -> void:
	var forward := _get_flat_aim_direction()
	var gust := CHAOS_EFFECT.new()
	get_tree().current_scene.add_child(gust)
	gust.setup(&"air_horn_gust", self)
	var shape := SphereShape3D.new()
	shape.radius = air_horn_range * 0.62
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.8 + forward * air_horn_range * 0.52)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 32)
	var affected: Dictionary = {}
	for hit in hits:
		var collider := hit.get("collider") as Node3D
		if collider == null or affected.has(collider):
			continue
		var offset := collider.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() < 0.01 or forward.dot(offset.normalized()) < 0.3:
			continue
		affected[collider] = true
		var impulse := (forward + Vector3.UP * 0.16).normalized() * air_horn_impulse
		if collider is RigidBody3D:
			if collider.has_method("launch"):
				collider.launch(impulse)
			else:
				collider.apply_central_impulse(impulse)
		elif collider.has_method("apply_knockback"):
			collider.apply_knockback(impulse)
	_play_sfx("air_horn")
	quick_item_event.emit("BWAAAP! Players and chairs caught in front were blasted.")


func _use_swap_bell() -> void:
	var target = _find_farthest_active_opponent()
	if target == null:
		equipped_spawn_item = &"swap_bell"
		quick_item_event.emit("No opponent available — item kept.")
		return
	var our_position := global_position
	var our_velocity := velocity
	_release_chair()
	target._release_chair()
	global_position = target.global_position
	velocity = target.velocity
	target.global_position = our_position
	target.velocity = our_velocity
	motion_epoch += 1
	target.motion_epoch += 1
	_play_sfx("swap_bell")
	quick_item_event.emit("DING! Swapped with Player %d." % (target.player_index + 1))


func _find_aimed_player():
	var target = null
	var best_dot := 0.65
	var scene = get_tree().current_scene
	for candidate in scene.players:
		if candidate == self or not scene.active_slots[candidate.player_index] or candidate.is_invisible():
			continue
		var offset: Vector3 = candidate.global_position + Vector3.UP - _get_aim_origin()
		if offset.length() > 10.0 or offset.length() < 0.01:
			continue
		var aim_dot := _get_aim_forward().dot(offset.normalized())
		var ray := PhysicsRayQueryParameters3D.create(_get_aim_origin(), candidate.global_position + Vector3.UP, 3, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if aim_dot > best_dot and (hit.is_empty() or hit.collider == candidate):
			best_dot = aim_dot
			target = candidate
	return target


func _use_invisibility() -> void:
	invisibility_time_remaining = invisibility_duration
	_refresh_character_visuals()
	_play_sfx("invisibility")
	quick_item_event.emit("Poof! Invisible for five seconds.")


func _use_rewind_watch() -> void:
	if movement_history.is_empty():
		quick_item_event.emit("The rewind watch had no history yet!")
		return
	var target_index := maxi(0, movement_history.size() - 20)
	var snapshot := movement_history[target_index]
	_release_chair()
	global_position = snapshot.position
	motion_epoch += 1
	velocity = snapshot.velocity
	movement_history.clear()
	_play_sfx("rewind")
	quick_item_event.emit("Rewound roughly two seconds!")


func _deploy_emergency_doors() -> void:
	var forward := _get_flat_aim_direction()
	var entry_position := global_position + forward * 1.7
	entry_position.y = 0.0
	var exit_position := Vector3(-entry_position.x, 0.0, -entry_position.z)
	var navigation = _house_navigation()
	if navigation != null:
		entry_position = navigation.nearest_safe_position(entry_position)
		exit_position = navigation.nearest_safe_position(exit_position)
		if not entry_position.is_finite() or not exit_position.is_finite():
			equipped_spawn_item = &"emergency_door"
			quick_item_event.emit("No clear floor for the doors — item kept.")
			return
	else:
		exit_position.x = clampf(exit_position.x, -7.2, 7.2)
		exit_position.z = clampf(exit_position.z, -4.7, 4.7)
	var doors := EMERGENCY_DOORS_SCENE.instantiate()
	get_tree().current_scene.add_child(doors)
	doors.setup(entry_position, exit_position)
	_play_sfx("door_open")
	quick_item_event.emit("Emergency doors open for ten seconds — chairs fit too!")


func _get_flat_aim_direction() -> Vector3:
	var forward := _get_aim_forward()
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.01 else Vector3.FORWARD


func _get_aim_origin() -> Vector3:
	return global_position + Vector3.UP * current_view_height


func _get_aim_forward() -> Vector3:
	if action_aim.length_squared() > 0.001:
		return action_aim.normalized()
	if network_controlled:
		return network_aim_forward.normalized()
	return get_local_aim_forward()


func get_local_aim_forward() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return -global_basis.z.normalized()
	var end := camera.global_position - camera.global_basis.z * stun_gun_range
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, end, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.position if not hit.is_empty() else end
	var offset := target - _get_aim_origin()
	return offset.normalized() if offset.length_squared() > 0.001 else -camera.global_basis.z.normalized()


func _record_movement_history(delta: float) -> void:
	history_sample_time += delta
	if history_sample_time < 0.1:
		return
	history_sample_time = 0.0
	movement_history.append({"position": global_position, "velocity": velocity})
	while movement_history.size() > 30:
		movement_history.pop_front()


func _fire_stun_gun() -> void:
	var origin := _get_aim_origin()
	var end := origin + _get_aim_forward() * stun_gun_range
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_player := false
	if not result.is_empty():
		end = result.position
		var collider := result.collider as Node
		if collider != null and collider.has_method("apply_stun"):
			collider.apply_stun(stun_duration)
			hit_player = true

	var beam := STUN_BEAM_SCENE.instantiate()
	get_tree().current_scene.add_child(beam)
	beam.setup(origin, end, hit_player)
	beam_event.emit(origin, end, hit_player)
	_play_sfx("stun_shot")
	quick_item_event.emit("Direct hit — player stunned!" if hit_player else "Stun shot missed — gun spent!")


func _play_sfx(effect_name: String) -> void:
	if client_predicted:
		return
	sound_event.emit(effect_name)
	play_local_sfx(effect_name)


func play_local_sfx(effect_name: String) -> void:
	if sfx_players.is_empty():
		return
	var selected := sfx_players[0]
	for audio_player in sfx_players:
		if not audio_player.playing:
			selected = audio_player
			break
	selected.stream = SFX_LIBRARY.get_effect(effect_name)
	selected.play()


func _read_movement_input(delta: float) -> Vector2:
	if input_suspended:
		return Vector2.ZERO
	if network_controlled:
		return network_movement_input
	if ai_controlled:
		if _ai_visible_target() == null:
			ai_cached_direction = Vector2.ZERO
			ai_think_remaining = 0.0
			return Vector2.ZERO
		ai_think_remaining -= delta
		if ai_think_remaining <= 0.0:
			ai_think_remaining = ai_reaction_time
			ai_cached_direction = _calculate_ai_direction()
		return ai_cached_direction

	var direction := Vector2.ZERO

	if player_index == 0:
		direction.x += float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		direction.y += float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	else:
		direction.x += float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
		direction.y += float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))

	if joypad_id >= 0:
		var stick := Vector2(
			Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_Y)
		)
		if stick.length() > 0.18:
			direction += stick

	return _make_input_camera_relative(direction.limit_length(1.0))


func _make_input_camera_relative(input: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or input.length_squared() < 0.01:
		return input

	var camera_right := camera.global_basis.x
	var camera_forward := -camera.global_basis.z
	camera_right.y = 0.0
	camera_forward.y = 0.0
	camera_right = camera_right.normalized()
	camera_forward = camera_forward.normalized()

	# Input Y is positive toward the bottom of the screen, hence the minus.
	var world_direction := camera_right * input.x + camera_forward * -input.y
	return Vector2(world_direction.x, world_direction.z).limit_length(1.0)


func _ai_visible_target():
	if not is_instance_valid(ai_target):
		return null
	for lure in get_tree().get_nodes_in_group("chaos_decoy"):
		if lure.owner_slot == ai_target.player_index and lure.remaining > 0.0 and not lure.is_queued_for_deletion():
			return lure
	return null if ai_target.is_invisible() else ai_target


func _calculate_ai_direction() -> Vector2:
	var visible_target = _ai_visible_target()
	if visible_target == null:
		return Vector2.ZERO
	var navigation = _house_navigation()
	if navigation != null:
		var destination: Vector3 = visible_target.global_position
		if has_token:
			destination = navigation.choose_flee_position(global_position, destination)
		var waypoint: Vector3 = navigation.next_waypoint(global_position, destination)
		return Vector2(waypoint.x - global_position.x, waypoint.z - global_position.z).normalized()

	var current := Vector2(global_position.x, global_position.z)
	var opponent := Vector2(visible_target.global_position.x, visible_target.global_position.z)
	var goal := opponent

	# The spark holder runs; everyone else chases. Choosing from broad flee
	# points makes the bot circle the island instead of backing into one wall.
	if has_token:
		goal = _choose_flee_point(current, opponent)

	var next_point := _next_route_point(current, goal)
	return (next_point - current).normalized()


func _house_navigation():
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var navigation = scene.get_node_or_null("Arena/HouseNavigation")
	return navigation if navigation != null and navigation.is_navigation_ready() else null


func _choose_flee_point(current: Vector2, opponent: Vector2) -> Vector2:
	var best_point := FLEE_POINTS[0]
	var best_score := -INF
	for point in FLEE_POINTS:
		# Distance from the opponent matters most; a modest travel penalty keeps
		# the bot from constantly switching to the opposite end of the room.
		var score := point.distance_to(opponent) - current.distance_to(point) * 0.18
		if score > best_score:
			best_score = score
			best_point = point
	return best_point


func _next_route_point(start: Vector2, goal: Vector2) -> Vector2:
	if not _segment_crosses_island(start, goal):
		return goal

	# A tiny visibility graph gives the bot both clockwise and counterclockwise
	# routes without introducing navigation meshes before the arena needs them.
	var nodes: Array[Vector2] = [start]
	nodes.append_array(ROUTE_CORNERS)
	nodes.append(goal)
	var node_count := nodes.size()
	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	distances.resize(node_count)
	previous.resize(node_count)
	visited.resize(node_count)

	for index in node_count:
		distances[index] = INF
		previous[index] = -1
		visited[index] = false
	distances[0] = 0.0

	for _step in node_count:
		var current_index := -1
		for index in node_count:
			if not visited[index] and (current_index == -1 or distances[index] < distances[current_index]):
				current_index = index

		if current_index == -1 or distances[current_index] == INF:
			break
		visited[current_index] = true

		for neighbor in node_count:
			if neighbor == current_index or visited[neighbor]:
				continue
			if _segment_crosses_island(nodes[current_index], nodes[neighbor]):
				continue
			var candidate := distances[current_index] + nodes[current_index].distance_to(nodes[neighbor])
			if candidate < distances[neighbor]:
				distances[neighbor] = candidate
				previous[neighbor] = current_index

	var route_index := node_count - 1
	if previous[route_index] == -1:
		return goal
	while previous[route_index] > 0:
		route_index = previous[route_index]
	return nodes[route_index]


func _segment_crosses_island(from: Vector2, to: Vector2) -> bool:
	# Sampling is sufficient for this six-node graph and easier to inspect than
	# a general line/rectangle intersection during the learning prototype.
	for step in range(1, 32):
		var sample := from.lerp(to, float(step) / 32.0)
		if absf(sample.x) < ISLAND_HALF_EXTENTS.x and absf(sample.y) < ISLAND_HALF_EXTENTS.y:
			return true
	return false


func _push_rigid_bodies() -> void:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var collider := collision.get_collider()
		if collider is RigidBody3D:
			var collision_normal := collision.get_normal()
			# A positive Y normal means the chair is acting as a floor. Applying
			# horizontal force through that contact fed the chair's platform velocity
			# back into the player, producing runaway acceleration.
			if collision_normal.y > 0.45:
				continue

			var horizontal := Vector3(velocity.x, 0.0, velocity.z)
			var push_direction := Vector3(-collision_normal.x, 0.0, -collision_normal.z).normalized()
			var impact_speed := maxf(0.0, horizontal.dot(push_direction))
			if impact_speed > 0.2:
				collider.apply_central_force(push_direction * push_force * impact_speed)
