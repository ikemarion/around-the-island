extends Node3D
## Pure presentation. BodyMesh parent owns facing/crouching/invisibility.
## No animation drives physics, and remote movement uses observed displacement.
const ART = preload("res://scripts/house_prop_art.gd")
const SCULPT = preload("res://art/characters/sockling/sockling-sculpt.glb")
const COLORS := [Color("65abc3"),Color("d88578"),Color("72a18b"),Color("ba8e50")]
const CREAM := Color("dfd0b2")
const CORAL := Color("b16b5e")
var actor: ATIPlayer
var fleece: ShaderMaterial
var chest: Node3D
var head: Node3D
var jaw: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var arm_meshes: Array[MeshInstance3D] = []
var leg_meshes: Array[MeshInstance3D] = []
var eyes: Array[Node3D] = []
var blink_offset := 1.0
var motion: RefCounted
var sampled_speed := 0.0
var sampled_airborne := false
var sampled_turn := 0.0
var last_facing := 0.0
var last_epoch := -1
var tracking := false
var phase := 0.0
var gait := 0.0
var last_position := Vector3.ZERO
var animation_enabled := true
var preview_color := Color("ba8e50")
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
				var radius: float = p.x+(0.0075*cos(a*28) if p.x > 0.23 else 0.0)
				var tangent := profile[mini(profile.size()-1,corner.x+1)]-profile[maxi(0,corner.x-1)]
				var slope: float = -0.0075*28*sin(a*28)/maxf(radius,0.01)
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
	jaw = group(head,"LowerJaw",Vector3(0,0.334,0.12))
	var tongue := soft(jaw,Vector3(0.210,0.025,0.250),Vector3(0.012,0,0.13),"Tongue",ART.material(Color("a65742"),0.99))
	tongue.rotation.x = -0.22
	for side in [-1,1]:
		var eye := group(head,"EyeLeft" if side == -1 else "EyeRight",Vector3(side*0.132,0.671,0.172))
		eyes.append(eye)
		soft(eye,Vector3(0.142,0.160,0.145),Vector3.ZERO,"IvoryEye",ART.material(CREAM,0.90))
		soft(eye,Vector3(0.043,0.062,0.019),Vector3(0.022,0.000,0.068),"Pupil",ART.material(Color("29251f"),0.70))
		soft(eye,Vector3.ONE*0.008,Vector3(0.017,0.018,0.078),"EyeGlint",ART.material(Color("efe4ce"),0.8))
		var arm := group(chest,"LeftArm" if side == -1 else "RightArm",Vector3(side*0.23,0.12,-0.03))
		arms.append(arm)
		arm_meshes.append(sculpt_part(arm,source,"LeftArm" if side == -1 else "RightArm","FabricArmAndHand"))
		var leg := group(self,"LeftLeg" if side == -1 else "RightLeg",Vector3(side*0.21,-0.41,-0.015))
		legs.append(leg)
		leg_meshes.append(sculpt_part(leg,source,"LeftLeg" if side == -1 else "RightLeg","SoftLegAndFoot"))
	source.free()
	motion = preload("res://scripts/sockling_motion.gd").new(self)
	blink_offset = 1.0+float(actor.player_index)*0.71 if is_instance_valid(actor) else 1.0
	if is_instance_valid(actor): last_position = actor.global_position

func animate(delta: float, speed: float, holding: bool, airborne: bool, stunned: bool, vertical_speed := 0.0, crouched := false, sliding := false, turn_rate := 0.0) -> void:
	motion.stride_phase = phase
	motion.update(delta,speed,holding,airborne,stunned,vertical_speed,crouched,sliding,turn_rate)
	phase = motion.stride_phase
	gait = motion.gait

func supported() -> bool:
	if not actor.simulation_enabled: return true
	if not actor.network_replica or actor.client_predicted: return actor.is_on_floor()
	# Replicas don't run move_and_slide, so is_on_floor is stale/false.
	# A short support query keeps the airborne pose through the jump apex.
	if actor.velocity.y > 1.0: return false
	var query := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*0.15,actor.global_position-Vector3.UP*0.22,3,[actor.get_rid()])
	return not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
	if not animation_enabled or not is_instance_valid(actor): return
	var displacement := actor.global_position-last_position
	last_position = actor.global_position
	var shown := is_visible_in_tree() and actor.visible
	var reset_needed := not tracking or last_epoch != actor.motion_epoch or displacement.length() > 3.0
	last_epoch = actor.motion_epoch
	if not shown:
		tracking = false
		return
	if reset_needed:
		motion.reset()
		phase = 0.0
		sampled_speed = 0.0
		sampled_turn = 0.0
	else:
		sampled_speed = minf(Vector2(displacement.x,displacement.z).length()/maxf(delta,0.001),22.0)
		sampled_turn = wrapf(actor.body_mesh.rotation.y-last_facing,-PI,PI)/maxf(delta,0.001)
	last_facing = actor.body_mesh.rotation.y
	sampled_airborne = not supported()
	tracking = true

func _process(delta: float) -> void:
	if not animation_enabled or not is_instance_valid(actor): return
	if not is_visible_in_tree() or not tracking: return
	var holding := is_instance_valid(actor.held_chair) or not actor.remote_held_name.is_empty()
	var sliding := actor.slide_time_remaining > 0.0
	if actor.network_replica and not actor.client_predicted:
		sliding = actor.crouched and sampled_speed > actor.crouch_speed*actor._chase_speed_multiplier()+0.6 and not sampled_airborne
	animate(delta,sampled_speed,holding,sampled_airborne,actor.stun_time_remaining>0,actor.velocity.y,actor.crouched,sliding,sampled_turn)
