extends Node3D

@onready var beam: MeshInstance3D = $Beam


func setup(from: Vector3, to: Vector3, hit: bool) -> void:
	global_position = (from + to) * 0.5
	var distance := from.distance_to(to)
	beam.scale.z = distance
	look_at(to, Vector3.UP)
	var material := beam.material_override as StandardMaterial3D
	material = material.duplicate()
	material.albedo_color = Color("fff47a") if hit else Color("75dfff")
	material.emission = material.albedo_color
	beam.material_override = material
	var tween := create_tween()
	tween.tween_property(beam, "transparency", 1.0, 0.16)
	tween.tween_callback(queue_free)
