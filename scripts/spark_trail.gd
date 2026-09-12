extends CPUParticles3D
## Cosmetic on every peer: no particle traffic and no invisible-player reveal.
var previous_epoch := -1

func _ready() -> void:
	emitting = false
	amount = 28
	lifetime = 0.7
	local_coords = false
	position.y = 0.7
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.28
	direction = Vector3.UP
	spread = 65.0
	gravity = Vector3(0, 0.18, 0)
	initial_velocity_min = 0.08
	initial_velocity_max = 0.3
	scale_amount_min = 0.5
	scale_amount_max = 1.5
	var orb := SphereMesh.new()
	orb.radius = 0.045
	orb.height = 0.09
	orb.radial_segments = 8
	orb.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	orb.material = mat
	mesh = orb
	color_ramp = Gradient.new()
	color_ramp.colors = PackedColorArray([Color(1,0.78,0.22,0.3), Color(1,0.9,0.45,0)])

func _process(_delta: float) -> void:
	var player = get_parent()
	var game = get_tree().current_scene
	if game == null or not "round_running" in game:
		return
	var active: bool = game.round_running and player.has_token and not player.is_invisible() and player.simulation_enabled
	# Hiding also removes already-emitted motes immediately.
	visible = active
	if previous_epoch != player.motion_epoch or (active and not emitting):
		restart()
	previous_epoch = player.motion_epoch
	emitting = active
