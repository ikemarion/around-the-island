extends Node3D
## Pure presentation. BodyMesh parent owns facing/crouching/invisibility.
## No animation drives physics, and remote movement uses observed displacement.
const ART = preload("res://scripts/house_prop_art.gd")
const SCULPT = preload("res://art/characters/sockling/sockling-sculpt.glb")
const COLORS := [Color("65abc3"),Color("d88578"),Color("72a18b"),Color("c89936")]
const CREAM := Color("eddfbd")
const CORAL := Color("bc6558")
var actor: ATIPlayer
var fleece: ShaderMaterial
var chest: Node3D
var head: Node3D
var jaw: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var phase := 0.0
var gait := 0.0
var last_position := Vector3.ZERO
var animation_enabled := true
var preview_color := Color("c89936")
var skin_materials: Array[ShaderMaterial] = []
var sculpt_body: MeshInstance3D
static var cuff_mesh: ArrayMesh

func cloth(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/sockling_fleece.gdshader")
	mat.set_shader_parameter("fleece_color",color)
	return mat

func group(parent: Node3D, title: String, at := Vector3.ZERO) -> Node3D:
	var part := Node3D.new()
	part.name = title
	parent.add_child(part)
	part.position = at
	return part

func soft(parent: Node3D, size: Vector3, at: Vector3, title: String, mat: Material = null) -> MeshInstance3D:
	var part := ART.ball(parent,size,at,Color.WHITE,title)
	part.material_override = fleece if mat == null else mat
	return part

func sculpt_part(parent: Node3D, source: Node3D, mesh_name: String, title: String, mat: Material = null) -> MeshInstance3D:
	var model := source.get_node(mesh_name) as MeshInstance3D
	var part := MeshInstance3D.new()
	part.name = title
	part.mesh = model.mesh
	part.transform = model.transform
	parent.add_child(part)
	var leg_material: ShaderMaterial
	if mesh_name.ends_with("Leg"):
		leg_material = cloth(COLORS[actor.player_index] if is_instance_valid(actor) else preview_color)
		leg_material.set_shader_parameter("sock_foot",true)
		skin_materials.append(leg_material)
	for surface in part.mesh.get_surface_count():
		var original := part.mesh.surface_get_material(surface)
		var is_mouth := original != null and "Mouth" in original.resource_name
		var is_foot := original != null and "SockFoot" in original.resource_name
		if is_mouth:
			var inside := ShaderMaterial.new()
			inside.shader = preload("res://scripts/sockling_mouth.gdshader")
			part.set_surface_override_material(surface,inside)
		else:
			part.set_surface_override_material(surface,leg_material if leg_material != null else (cloth(CORAL) if is_foot else (fleece if mat == null else mat)))
	if mesh_name == "Body" or mesh_name.ends_with("Arm"):
		preload("res://scripts/sockling_nap.gd").attach(part,mesh_name,fleece)
	return part

static func knitted_cuff() -> ArrayMesh:
	if cuff_mesh != null: return cuff_mesh
	var profile: Array[Vector2] = [Vector2(0,-0.125),Vector2(0.233,-0.125),Vector2(0.250,-0.111),Vector2(0.256,-0.09),Vector2(0.256,0.09),Vector2(0.250,0.111),Vector2(0.233,0.125),Vector2(0,0.125)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in profile.size()-1:
		for segment in 240:
			for corner in [Vector2i(row,segment),Vector2i(row+1,segment+1),Vector2i(row+1,segment),Vector2i(row,segment),Vector2i(row,segment+1),Vector2i(row+1,segment+1)]:
				var p := profile[corner.x]
				var a: float = corner.y*TAU/240.0
				var radius: float = p.x+(0.005*cos(a*40) if p.x > 0.23 else 0.0)
				var tangent := profile[mini(profile.size()-1,corner.x+1)]-profile[maxi(0,corner.x-1)]
				var slope: float = -0.005*40*sin(a*40)/maxf(radius,0.01)
				surface.set_normal(Vector3(tangent.y*(cos(a)+slope*sin(a)),-tangent.x,tangent.y*(sin(a)-slope*cos(a))/0.88).normalized())
				surface.add_vertex(Vector3(radius*cos(a),p.y,radius*sin(a)*0.88))
	cuff_mesh = surface.commit()
	return cuff_mesh

func _ready() -> void:
	name = "Sockling"
	fleece = cloth(COLORS[actor.player_index] if is_instance_valid(actor) else preview_color)
	skin_materials.append(fleece)
	chest = group(self,"Puppet")
	var source := SCULPT.instantiate()
	var waist := group(chest,"KnittedWaistband",Vector3(0,-0.33,-0.045))
	var yarn := cloth(CREAM)
	yarn.set_shader_parameter("striped_cuff",true)
	var cuff := ART.piece(waist,knitted_cuff(),Vector3.ZERO,CREAM,"RibbedCuff")
	cuff.scale.y = 1.20
	cuff.material_override = yarn
	head = group(chest,"Head",Vector3(0,0.0,0.015))
	sculpt_body = sculpt_part(head,source,"Body","UpperMuzzle")
	jaw = group(head,"LowerJaw",Vector3(0,0.248,0.13))
	soft(jaw,Vector3(0.205,0.030,0.16),Vector3(0,0,0.10),"Tongue",ART.material(Color("a85241"),0.99))
	for side in [-1,1]:
		var eye := group(head,"EyeLeft" if side == -1 else "EyeRight",Vector3(side*0.118,0.700,0.115))
		soft(eye,Vector3(0.164,0.184,0.164),Vector3.ZERO,"IvoryEye",ART.material(CREAM,0.48))
		soft(eye,Vector3(0.052,0.074,0.027),Vector3(0.022,0.000,0.079),"Pupil",ART.material(Color("28251d"),0.32))
		soft(eye,Vector3.ONE*0.013,Vector3(0.014,0.022,0.093),"EyeGlint",ART.material(Color.WHITE,0.3))
		var arm := group(chest,"LeftArm" if side == -1 else "RightArm",Vector3(side*0.23,0.12,-0.03))
		arms.append(arm)
		sculpt_part(arm,source,"LeftArm" if side == -1 else "RightArm","FabricArmAndHand")
		var leg := group(self,"LeftLeg" if side == -1 else "RightLeg",Vector3(side*0.14,-0.41,-0.015))
		legs.append(leg)
		sculpt_part(leg,source,"LeftLeg" if side == -1 else "RightLeg","SoftLegAndFoot")
	source.free()
	if is_instance_valid(actor): last_position = actor.global_position

func animate(delta: float, speed: float, holding: bool, airborne: bool, stunned: bool) -> void:
	gait = move_toward(gait,clampf(speed/5.5,0,1),delta*7)
	phase += delta*(3.5+speed*1.4)
	chest.position.y = absf(sin(phase))*0.025*gait
	chest.rotation.z = -0.07+sin(phase)*0.055*gait
	head.rotation.z = sin(phase-0.4)*0.05*gait
	var opening := 0.15+0.22*(sin(phase*0.5)*0.5+0.5)
	sculpt_body.set_blend_shape_value(0,opening)
	jaw.rotation.x = opening*0.24
	for index in 2:
		var swing := sin(phase+index*PI)*gait
		legs[index].rotation.x = swing*0.55 if not airborne else -0.25
		arms[index].rotation.x = -0.95 if holding else (-swing*0.62 if not airborne else -0.7)
		arms[index].rotation.z = (-0.12 if index == 0 else 0.22)*(1+gait)
	for skin in skin_materials:
		skin.set_shader_parameter("stunned",1.0 if stunned else 0.0)

func _process(delta: float) -> void:
	if not animation_enabled or not is_instance_valid(actor): return
	var distance := actor.global_position.distance_to(last_position)
	last_position = actor.global_position
	if not is_visible_in_tree(): return
	var speed := minf(distance/maxf(delta,0.001),12.0) if distance < 1.0 else 0.0
	var holding := is_instance_valid(actor.held_chair) or not actor.remote_held_name.is_empty()
	animate(delta,speed,holding,absf(actor.velocity.y)>1.5,actor.stun_time_remaining>0)
