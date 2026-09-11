class_name ATIShoveable
extends RigidBody3D

## Defensive physics limit: chairs remain rideable and pushable, but a contact
## feedback edge case cannot accelerate them to absurd speeds.

@export var maximum_horizontal_speed: float = 12.0

var grab_prompt: Label3D
var holder: Node
var launch_time := 0.0

func try_claim(player: Node) -> bool:
	if is_instance_valid(holder) and holder != player:
		return false
	holder = player
	return true

func release_claim(player: Node) -> void:
	if holder == player:
		holder = null

func launch(impulse: Vector3) -> void:
	launch_time = 1.5
	sleeping = false
	apply_central_impulse(impulse)


func _ready() -> void:
	grab_prompt = Label3D.new()
	grab_prompt.position = Vector3(0.0, 1.0, 0.0)
	grab_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	grab_prompt.no_depth_test = true
	grab_prompt.text = ""
	grab_prompt.font_size = 42
	grab_prompt.outline_size = 12
	grab_prompt.modulate = Color(1.0, 0.86, 0.2)
	grab_prompt.visible = false
	add_child(grab_prompt)


func set_highlighted(value: bool) -> void:
	if is_instance_valid(grab_prompt):
		grab_prompt.visible = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	launch_time = maxf(0.0, launch_time - state.step)
	var speed_limit := 90.0 if launch_time > 0.0 else maximum_horizontal_speed
	var horizontal := Vector2(state.linear_velocity.x, state.linear_velocity.z)
	if horizontal.length() <= speed_limit:
		return

	horizontal = horizontal.normalized() * speed_limit
	var limited_velocity := state.linear_velocity
	limited_velocity.x = horizontal.x
	limited_velocity.z = horizontal.y
	state.linear_velocity = limited_velocity
