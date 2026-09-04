extends Camera3D

## First-person is the default learning experiment. Press V to compare it with
## the previous radial view, where camera -> player -> island stays aligned.

@export_node_path("Node3D") var target_path: NodePath
@export_node_path("Node3D") var center_path: NodePath

@export_group("First Person")
@export var first_person_enabled: bool = true
@export var eye_height: float = 1.48
@export var mouse_sensitivity: float = 0.0024
@export var gamepad_look_speed: float = 2.2
@export var minimum_pitch_degrees: float = -75.0
@export var maximum_pitch_degrees: float = 75.0

@export_group("Radial View")
@export var follow_distance: float = 9.5
@export var follow_height: float = 11.5
@export var look_height: float = 0.8

var target: Node3D
var arena_center: Node3D
var last_outward_direction := Vector3.BACK
var yaw: float = 0.0
var pitch: float = 0.0
var gameplay_input_enabled := true


func set_follow_target(new_target: Node3D) -> void:
	target = new_target
	if first_person_enabled and is_instance_valid(arena_center):
		_set_first_person(true)


func set_gameplay_input_enabled(enabled: bool) -> void:
	gameplay_input_enabled = enabled
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled and first_person_enabled else Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	target = get_node_or_null(target_path)
	arena_center = get_node_or_null(center_path)
	if not is_instance_valid(target) or not is_instance_valid(arena_center):
		return

	global_position = target.global_position + Vector3.UP * eye_height
	look_at(arena_center.global_position + Vector3.UP * look_height, Vector3.UP)
	yaw = rotation.y
	pitch = rotation.x
	_set_first_person(first_person_enabled)


func _process(delta: float) -> void:
	if not gameplay_input_enabled or not is_instance_valid(target) or not is_instance_valid(arena_center):
		return

	if first_person_enabled:
		_read_gamepad_look(delta)
		_update_first_person_camera()
	else:
		_update_radial_camera()


func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_input_enabled:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		_set_first_person(not first_person_enabled)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed and first_person_enabled:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			get_viewport().set_input_as_handled()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event is InputEventMouseMotion and first_person_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_look(event.relative)


func _apply_mouse_look(relative: Vector2) -> void:
	yaw -= relative.x * mouse_sensitivity
	pitch -= relative.y * mouse_sensitivity
	pitch = clampf(pitch, deg_to_rad(minimum_pitch_degrees), deg_to_rad(maximum_pitch_degrees))


func _set_first_person(enabled: bool) -> void:
	first_person_enabled = enabled
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
	if target.has_method("set_local_visual_hidden"):
		if target.is_node_ready():
			target.set_local_visual_hidden(enabled)
		else:
			target.call_deferred("set_local_visual_hidden", enabled)

	if enabled:
		var toward_center := arena_center.global_position - target.global_position
		toward_center.y = 0.0
		if toward_center.length_squared() > 0.01:
			yaw = atan2(-toward_center.x, -toward_center.z)
		pitch = deg_to_rad(-8.0)
		_update_first_person_camera()
	else:
		_update_radial_camera()


func _update_first_person_camera() -> void:
	var applied_eye_height := eye_height
	if target.has_method("get_view_height"):
		applied_eye_height = target.get_view_height()
	global_position = target.global_position + Vector3.UP * applied_eye_height
	if target is ATIPlayer and target.client_predicted:
		global_position += target.camera_correction
	global_rotation = Vector3(pitch, yaw, 0.0)


func _update_radial_camera() -> void:
	var outward := target.global_position - arena_center.global_position
	outward.y = 0.0
	if outward.length_squared() > 0.01:
		last_outward_direction = outward.normalized()

	global_position = target.global_position + last_outward_direction * follow_distance + Vector3.UP * follow_height
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)


func _read_gamepad_look(delta: float) -> void:
	var joypads := Input.get_connected_joypads()
	if joypads.is_empty():
		return

	var device: int = joypads[0]
	var look := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	)
	if look.length() < 0.16:
		return

	yaw -= look.x * gamepad_look_speed * delta
	pitch -= look.y * gamepad_look_speed * delta
	pitch = clampf(pitch, deg_to_rad(minimum_pitch_degrees), deg_to_rad(maximum_pitch_degrees))
