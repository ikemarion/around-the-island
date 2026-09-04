class_name ATIItemPickup
extends Area3D

signal collected

@export var item_type: StringName = &"stun_gun"
@export var bob_height: float = 0.16
@export var bob_speed: float = 2.7
@export var spin_speed: float = 1.8

var base_height: float
var age: float = 0.0
var claimed: bool = false


func configure(new_item_type: StringName, color: Color) -> void:
	item_type = new_item_type
	if has_node("Core"):
		var core := get_node("Core") as MeshInstance3D
		var material := core.get_active_material(0).duplicate() as StandardMaterial3D
		material.albedo_color = color
		material.emission = color.darkened(0.35)
		for child in get_children():
			if child is MeshInstance3D:
				child.material_override = material
	if has_node("Glow"):
		(get_node("Glow") as OmniLight3D).light_color = color


func _ready() -> void:
	base_height = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	age += delta
	rotation.y += spin_speed * delta
	position.y = base_height + sin(age * bob_speed) * bob_height


func _on_body_entered(body: Node3D) -> void:
	if claimed or not body.has_method("try_pickup_item"):
		return
	if body.try_pickup_item(item_type):
		claimed = true
		collected.emit()
		queue_free()
