extends Node3D

@export var lifetime: float = 10.0
@export var exit_offset: float = 1.25

@onready var entry: Area3D = $Entry
@onready var exit: Area3D = $Exit

var age: float = 0.0
var recent_bodies: Dictionary = {}


func _ready() -> void:
	entry.body_entered.connect(_on_door_entered.bind(exit))
	exit.body_entered.connect(_on_door_entered.bind(entry))


func setup(entry_position: Vector3, exit_position: Vector3) -> void:
	entry.global_position = entry_position + Vector3.UP * 1.05
	exit.global_position = exit_position + Vector3.UP * 1.05


func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	for body in recent_bodies.keys():
		if not is_instance_valid(body):
			recent_bodies.erase(body)
			continue
		recent_bodies[body] -= delta
		if recent_bodies[body] <= 0.0:
			recent_bodies.erase(body)


func _on_door_entered(body: Node3D, destination: Area3D) -> void:
	if recent_bodies.has(body):
		return
	if not (body is CharacterBody3D or body is RigidBody3D):
		return
	var outward := destination.global_position
	outward.y = 0.0
	if outward.length_squared() < 0.01:
		outward = Vector3.FORWARD
	outward = outward.normalized()
	var height := 0.05 if body is CharacterBody3D else maxf(0.45, body.global_position.y)
	body.global_position = Vector3(destination.global_position.x, height, destination.global_position.z) + outward * exit_offset
	recent_bodies[body] = 0.45
	if body.has_method("on_emergency_door_used"):
		body.motion_epoch += 1
		body._release_chair()
		body.on_emergency_door_used()
