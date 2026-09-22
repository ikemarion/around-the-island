extends Node3D
## Independent presentation for a moving decoy. Runs on host and replicas even
## when the parent effect's simulation is disabled on the joining player's PC.
var character_id: StringName = &"sockling"
var skin_color := Color.WHITE
var model: Node3D
var body: CharacterBody3D
var sample_anchor := Vector3.ZERO
var sample_elapsed := 0.0
var sampled_speed := 0.0
var sampled_vertical := 0.0
var sampled_airborne := false

func _ready() -> void:
	name = "DecoyCharacter"
	position.y = 0.85 # Same standing BodyMesh height and unit scale as players.
	body = get_parent() as CharacterBody3D
	model = load("res://scripts/character_catalog.gd").create(character_id, null, skin_color)
	model.animation_enabled = false
	add_child(model)
	sample_anchor = body.global_position

func _physics_process(delta: float) -> void:
	sample_elapsed += delta
	var displacement := body.global_position - sample_anchor
	if displacement.length() > 3.0:
		# A late snapshot/teleport must not kick the puppet into a huge stride.
		model.motion.reset()
		model.phase = 0.0
		sampled_speed = 0.0
		sampled_vertical = 0.0
		sample_elapsed = 0.0
		sample_anchor = body.global_position
	elif sample_elapsed >= 0.10:
		# Average over a few snapshots instead of alternating sprint/stop on
		# frames between network updates. Obstructed decoys settle into idle.
		sampled_speed = minf(Vector2(displacement.x, displacement.z).length() / sample_elapsed, 6.2)
		sampled_vertical = displacement.y / sample_elapsed
		sample_elapsed = 0.0
		sample_anchor = body.global_position
	var query := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP * 0.15,
		body.global_position - Vector3.UP * 0.22, 3, [body.get_rid()])
	sampled_airborne = get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _process(delta: float) -> void:
	# No reference to the real player's visibility, held item, input or stun.
	model.animate(delta, sampled_speed, false, sampled_airborne, false, sampled_vertical)
