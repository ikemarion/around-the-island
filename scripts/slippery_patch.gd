class_name ATISlipperyPatch
extends Area3D

@export var lifetime: float = 8.0
@export var slippery_refresh_duration: float = 0.22

var time_remaining: float


func _ready() -> void:
	time_remaining = lifetime


func _physics_process(delta: float) -> void:
	time_remaining -= delta
	for body in get_overlapping_bodies():
		if body.has_method("apply_slippery"):
			body.apply_slippery(slippery_refresh_duration)

	# A small pulse communicates that the patch is active without obscuring it.
	var pulse := 1.0 + sin(time_remaining * 5.0) * 0.035
	$Visual.scale = Vector3(pulse, 1.0, pulse)
	if time_remaining <= 0.0:
		queue_free()
