extends Node3D

@export var lifetime: float = 10.0
@export var exit_offset: float = 1.25

@onready var entry: Area3D = $Entry
@onready var exit: Area3D = $Exit

var age: float = 0.0
var recent_bodies: Dictionary = {}


func _ready() -> void:
	for portal in [entry,exit]:
		for child in portal.get_children():
			if child is MeshInstance3D or child is Light3D:
				child.queue_free()
		var art := preload("res://scripts/emergency_door_art.gd").new()
		art.position.y = -1.05
		portal.add_child(art)
	entry.body_entered.connect(_on_door_entered.bind(exit))
	exit.body_entered.connect(_on_door_entered.bind(entry))


func setup(entry_position: Vector3, exit_position: Vector3, entry_inward := Vector3.BACK, exit_inward := Vector3.FORWARD) -> void:
	entry.global_position = entry_position + Vector3.UP * 1.05
	exit.global_position = exit_position + Vector3.UP * 1.05
	entry.rotation.y = atan2(entry_inward.x,entry_inward.z)
	exit.rotation.y = atan2(exit_inward.x,exit_inward.z)


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
	var outward := destination.global_basis.z.normalized()
	var height := 0.05 if body is CharacterBody3D else maxf(0.45, body.global_position.y)
	var landing := Vector3(destination.global_position.x, height, destination.global_position.z) + outward * exit_offset
	var navigation = get_tree().current_scene.get_node_or_null("Arena/HouseNavigation")
	if navigation != null and navigation.is_navigation_ready():
		# The outward offset can cross a wall or floor edge even when the door
		# itself was placed safely. Resolve the actual arrival, in either direction.
		var safe: Vector3 = navigation.nearest_safe_position(landing)
		if not safe.is_finite():
			return
		landing = Vector3(safe.x, height, safe.z)
	body.global_position = landing
	recent_bodies[body] = 0.45
	if body.has_method("on_emergency_door_used"):
		body.motion_epoch += 1
		body._release_chair()
		body.on_emergency_door_used()
