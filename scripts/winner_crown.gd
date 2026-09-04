extends Node3D

@export var spin_speed: float = 1.65
@export var bob_height: float = 0.08
@export var bob_speed: float = 2.6

@onready var visual: Node3D = $Visual

var age: float = 0.0


func _process(delta: float) -> void:
	age += delta
	visual.rotation.y += spin_speed * delta
	visual.position.y = sin(age * bob_speed) * bob_height
