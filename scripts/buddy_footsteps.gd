extends Node3D
## Peer-local visual reconstruction from replicated movement; never hides the buddy.
const LIFE := 1.4
var prints: Array[Node3D] = []
var ages: Array[float] = []
var previous := Vector3.ZERO
var distance := 0.0
var previous_epoch := -1
var next_print := 0
var left := false
var active := false

func _ready() -> void:
	name = "BuddyFootsteps"
	for i in 16:
		var foot := Node3D.new()
		add_child(foot)
		foot.set_as_top_level(true)
		for heel in [false,true]:
			var mesh := MeshInstance3D.new()
			mesh.mesh = preload("res://scripts/house_prop_art.gd").rounded(Vector3(0.105,0.09,0.09 if heel else 0.16),0.043)
			mesh.scale.y = 0.014/0.09
			mesh.position.z = 0.09 if heel else -0.065
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.65,1,0.88,0.8)
			mesh.material_override = mat
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			foot.add_child(mesh)
		foot.hide()
		prints.append(foot)
		ages.append(LIFE)

func clear() -> void:
	for i in prints.size():
		prints[i].hide()
		ages[i] = LIFE
	distance = 0.0
	active = false

func _physics_process(delta: float) -> void:
	var player = get_parent()
	var enabled: bool = player.buddy_hide_time > 0.0 and player.simulation_enabled and player.visible
	if not enabled or previous_epoch != player.motion_epoch:
		clear()
	previous_epoch = player.motion_epoch
	if not enabled:
		return
	if not active:
		previous = player.global_position
		active = true
	for i in prints.size():
		ages[i] += delta
		prints[i].visible = ages[i] < LIFE
		for part in prints[i].get_children():
			part.material_override.albedo_color.a = maxf(0.0,1.0-ages[i]/LIFE)*0.8
	var travel: Vector3 = player.global_position-previous
	previous = player.global_position
	travel.y = 0
	if travel.length() > 2.0:
		clear()
		return
	distance += travel.length()
	if distance < 0.48 or travel.length_squared() < 0.00001:
		return
	distance = 0.0
	var heading := travel.normalized()
	var at: Vector3 = player.global_position + heading.cross(Vector3.UP)*(0.12 if left else -0.12)
	var excluded: Array[RID] = []
	for other in get_tree().current_scene.players: excluded.append(other.get_rid())
	var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.20,at-Vector3.UP*0.23,3,excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var foot := prints[next_print]
	foot.global_position = hit.position+hit.normal*0.014
	var normal: Vector3 = hit.normal
	var forward := (heading-normal*heading.dot(normal)).normalized()
	if forward.length_squared() < 0.01: return
	foot.global_basis = Basis(forward.cross(normal),normal,-forward)
	ages[next_print] = 0.0
	foot.show()
	next_print = (next_print+1)%prints.size()
	left = not left
