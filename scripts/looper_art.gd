extends "res://scripts/sockling_art.gd"
## Same cosmetic movement/visibility contract, a distinct closed-mouth plush
## sculpt and fine velvet material. No player simulation lives in this model.
const LOOPER_SCULPT := preload("res://art/characters/looper/looper-sculpt.glb")
var top_loop: MeshInstance3D
var loop_pivot: Node3D
var loop_spring := Vector2.ZERO
var cream_material: ShaderMaterial

func _init() -> void:
	preview_color = Color("88749e")

func cloth(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/looper_velvet.gdshader")
	mat.set_shader_parameter("fleece_color",color)
	return mat

func looper_part(parent: Node3D, source: Node3D, title: String) -> MeshInstance3D:
	var original := source.get_node(title) as MeshInstance3D
	var part := MeshInstance3D.new()
	part.name = title
	part.mesh = original.mesh
	part.transform = original.transform
	parent.add_child(part)
	for surface in part.mesh.get_surface_count():
		var original_material := part.mesh.surface_get_material(surface)
		var material_name := original_material.resource_name if original_material != null else ""
		if "Cuff" in material_name:
			part.set_surface_override_material(surface,cream_material)
		elif "Ivory" in material_name:
			part.set_surface_override_material(surface,ART.material(Color("ecddbe"),0.86))
		elif "Ink" in material_name:
			part.set_surface_override_material(surface,ART.material(Color("28252c"),0.85))
		else:
			part.set_surface_override_material(surface,fleece)
	if title in ["Body","TopLoop","LeftArm","RightArm"]:
		preload("res://scripts/looper_nap.gd").attach(part,title,fleece)
	return part

func _ready() -> void:
	name = "Looper"
	fleece = cloth(preview_color)
	cream_material = cloth(Color("e4d3af"))
	skin_materials.append(fleece)
	skin_materials.append(cream_material)
	chest = group(self,"Puppet")
	head = group(chest,"Head")
	var source := LOOPER_SCULPT.instantiate()
	sculpt_body = looper_part(head,source,"Body")
	loop_pivot = group(head,"LoopPivot",Vector3(0,0.73,0.025))
	top_loop = looper_part(loop_pivot,source,"TopLoop")
	top_loop.position -= loop_pivot.position
	looper_part(head,source,"Smile")
	for side in [-1,1]:
		var suffix := "Left" if side == -1 else "Right"
		var eye_mesh := source.get_node("Eye"+suffix) as MeshInstance3D
		var eye_center := eye_mesh.transform * eye_mesh.mesh.get_aabb().get_center()
		var eye := group(head,"Eye"+suffix,eye_center)
		eyes.append(eye)
		for mesh_name in ["Eye"+suffix,"Pupil"+suffix,"Lid"+suffix]:
			var part := looper_part(eye,source,mesh_name)
			part.position -= eye_center
		var arm := group(chest,suffix+"Arm",Vector3(side*0.235,0.105,-0.01))
		arms.append(arm)
		arm_meshes.append(looper_part(arm,source,suffix+"Arm"))
		arm_skeletons.append(preload("res://scripts/sockling_arm_rig.gd").attach(arm,arm_meshes[-1],side))
		var leg := group(self,suffix+"Leg",Vector3(side*0.14,-0.41,-0.015))
		legs.append(leg)
		leg_meshes.append(looper_part(leg,source,suffix+"Leg"))
	source.free()
	motion = preload("res://scripts/sockling_motion.gd").new(self)
	blink_offset = 1.0+float(actor.player_index)*0.71 if is_instance_valid(actor) else 1.0
	if is_instance_valid(actor): last_position = actor.global_position

func animate(delta: float, speed: float, holding: bool, airborne: bool, stunned: bool, vertical_speed := 0.0, crouched := false, sliding := false, turn_rate := 0.0) -> void:
	if not motion.initialized:
		loop_spring = Vector2.ZERO
		loop_pivot.rotation = Vector3.ZERO
	super.animate(delta,speed,holding,airborne,stunned,vertical_speed,crouched,sliding,turn_rate)
	# Keep the closed smirk readable, and give the soft loop a restrained lag.
	var target: float = sin(phase-0.3)*0.045*gait-clampf(turn_rate,-4,4)*0.02
	loop_spring = motion.spring(loop_spring,target,12.0,minf(delta,0.1))
	loop_pivot.rotation.z = loop_spring.x
