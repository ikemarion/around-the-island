extends Node3D
## Pure presentation. BodyMesh parent owns facing/crouching/invisibility.
## No animation drives physics, and remote movement uses observed displacement.
const ART = preload("res://scripts/house_prop_art.gd")
const DESIGN = preload("res://scripts/collectible_design.gd")
const COLORS := [Color("65abc3"),Color("d88578"),Color("72a18b"),Color("dca632")]
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
var preview_color := Color("dca632")
static var upper_head_mesh: ArrayMesh
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

static func dome() -> ArrayMesh:
	if upper_head_mesh != null: return upper_head_mesh
	# Upper puppet muzzle with a flat underside; no closed sphere filling mouth.
	var profile: Array[Vector2] = [Vector2(0,-0.008),Vector2(0.28,-0.008),Vector2(0.325,0.003),Vector2(0.348,0.025)]
	for index in 1+16:
		var angle := index*PI/32.0
		profile.append(Vector2(cos(angle)*0.35,0.045+sin(angle)*0.22))
	upper_head_mesh = DESIGN.lathe(profile,48)
	return upper_head_mesh

static func mouth_bowl() -> ArrayMesh:
	# Concave dark oral cavity, recessed behind the lips rather than a black ball.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 12:
		for segment in 48:
			for corner in [Vector2i(row,segment),Vector2i(row+1,segment),Vector2i(row+1,segment+1),Vector2i(row,segment),Vector2i(row+1,segment+1),Vector2i(row,segment+1)]:
				var theta: float = corner.x*PI/24.0
				var a: float = corner.y*TAU/48.0
				surface.set_normal(Vector3(-sin(theta)*cos(a)/0.285,-sin(theta)*sin(a)/0.13,cos(theta)/0.39).normalized())
				var rim_z: float = 0.18+0.18*absf(sin(a))
				surface.add_vertex(Vector3(0.27*sin(theta)*cos(a),0.245+0.115*sin(theta)*sin(a),0.145+(rim_z-0.145)*(1.0-cos(theta))))
	return surface.commit()

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
				surface.set_normal(Vector3(tangent.y*cos(a),-tangent.x,tangent.y*sin(a)/0.88).normalized())
				surface.add_vertex(Vector3(radius*cos(a),p.y,radius*sin(a)*0.88))
	cuff_mesh = surface.commit()
	return cuff_mesh

func noodle(parent: Node3D, points: Array[Vector3], radius: float, title: String) -> void:
	var path := Curve3D.new()
	for i in points.size():
		var tangent := (points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)])*0.16
		path.add_point(points[i],-tangent,tangent)
	path.bake_interval = 0.035
	var samples := path.get_baked_points()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in samples.size()-1:
		for segment in 12:
			for corner in [Vector2i(i,segment),Vector2i(i+1,segment+1),Vector2i(i+1,segment),Vector2i(i,segment),Vector2i(i,segment+1),Vector2i(i+1,segment+1)]:
				var tangent := (samples[mini(corner.x+1,samples.size()-1)]-samples[maxi(0,corner.x-1)]).normalized()
				var right := tangent.cross(Vector3.FORWARD).normalized()
				var normal := right*cos(TAU*corner.y/12.0)+tangent.cross(right)*sin(TAU*corner.y/12.0)
				surface.set_normal(normal)
				surface.add_vertex(samples[corner.x]+normal*radius)
	var part := ART.piece(parent,surface.commit(),Vector3.ZERO,Color.WHITE,title)
	part.material_override = fleece
	soft(parent,Vector3.ONE*radius*2,points[0],title+"Root")
	soft(parent,Vector3.ONE*radius*2,points[-1],title+"End")

func _ready() -> void:
	name = "Sockling"
	fleece = cloth(COLORS[actor.player_index] if is_instance_valid(actor) else preview_color)
	chest = group(self,"Puppet")
	var body_profile: Array[Vector2] = [Vector2(0,-0.49),Vector2(0.15,-0.475),Vector2(0.215,-0.40),Vector2(0.235,-0.23),Vector2(0.229,0.04),Vector2(0.211,0.20),Vector2(0.155,0.285),Vector2(0,0.31)]
	var body := ART.piece(chest,DESIGN.lathe(body_profile,48),Vector3(0,0,-0.045),Color.WHITE,"FleeceTorso")
	body.scale.z = 0.88
	body.material_override = fleece
	var waist := group(chest,"KnittedWaistband",Vector3(0,-0.33,-0.045))
	var yarn := cloth(CREAM)
	yarn.set_shader_parameter("striped_cuff",true)
	var cuff := ART.piece(waist,knitted_cuff(),Vector3.ZERO,CREAM,"RibbedCuff")
	cuff.material_override = yarn
	head = group(chest,"Head",Vector3(0,0.0,0.015))
	var upper := ART.piece(head,dome(),Vector3(0,0.31,0.065),Color.WHITE,"UpperMuzzle")
	upper.scale.z = 1.05
	upper.material_override = fleece
	# Rear neck fills only the hinge side of the open mouth.
	soft(head,Vector3(0.45,0.40,0.22),Vector3(0,0.24,-0.12),"MouthHinge")
	var interior := ART.piece(head,mouth_bowl(),Vector3.ZERO,Color("46251e"),"DeepMouth",0.98)
	var mouth_mat := ART.material(Color("46251e"),0.98).duplicate()
	mouth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	interior.material_override = mouth_mat
	jaw = group(head,"LowerJaw",Vector3(0,0.115,-0.09))
	soft(jaw,Vector3(0.62,0.195,0.53),Vector3(0,0,0.20),"LowerLip")
	soft(jaw,Vector3(0.50,0.034,0.36),Vector3(0,0.084,0.235),"MouthLining",ART.material(Color("76382b"),0.98))
	soft(jaw,Vector3(0.23,0.036,0.14),Vector3(0,0.103,0.32),"Tongue",ART.material(Color("af5c4b"),0.92))
	for side in [-1,1]:
		var eye := group(head,"EyeLeft" if side == -1 else "EyeRight",Vector3(side*0.166,0.583,0.08))
		soft(eye,Vector3(0.22,0.255,0.22),Vector3.ZERO,"IvoryEye",ART.material(CREAM,0.48))
		soft(eye,Vector3(0.080,0.12,0.043),Vector3(0.021,0.005,0.103),"Pupil",ART.material(Color("28251d"),0.32))
		soft(eye,Vector3.ONE*0.022,Vector3(0.007,0.043,0.126),"EyeGlint",ART.material(Color.WHITE,0.3))
		var arm := group(chest,"LeftArm" if side == -1 else "RightArm",Vector3(side*0.23,0.12,-0.03))
		arms.append(arm)
		noodle(arm,[Vector3.ZERO,Vector3(side*0.19,-0.06,0),Vector3(side*0.30,-0.20,0.055),Vector3(side*0.32,-0.34,0.11)],0.068,"FloppyArm")
		var hand := group(arm,"Hand",Vector3(side*0.32,-0.36,0.11))
		soft(hand,Vector3(0.18,0.18,0.12),Vector3.ZERO,"Palm")
		for finger in 3:
			soft(hand,Vector3(0.065,0.13,0.085),Vector3((finger-1)*0.063,-0.09,0.009),"Finger%d" % finger)
		soft(hand,Vector3(0.12,0.075,0.087),Vector3(-side*0.092,-0.005,0.025),"Thumb")
		var leg := group(self,"LeftLeg" if side == -1 else "RightLeg",Vector3(side*0.14,-0.41,-0.015))
		legs.append(leg)
		noodle(leg,[Vector3.ZERO,Vector3(side*0.042,-0.12,-0.035),Vector3(side*0.055,-0.24,0.02)],0.078,"SoftLeg")
		soft(leg,Vector3(0.245,0.17,0.345),Vector3(side*0.045,-0.30,0.08),"CoralFoot",cloth(CORAL))
	if is_instance_valid(actor): last_position = actor.global_position

func animate(delta: float, speed: float, holding: bool, airborne: bool, stunned: bool) -> void:
	gait = move_toward(gait,clampf(speed/5.5,0,1),delta*7)
	phase += delta*(3.5+speed*1.4)
	chest.position.y = absf(sin(phase))*0.025*gait
	chest.rotation.z = sin(phase)*0.055*gait
	head.rotation.z = sin(phase-0.4)*0.05*gait
	jaw.rotation.x = 0.08+0.07*sin(phase*0.5)
	for index in 2:
		var swing := sin(phase+index*PI)*gait
		legs[index].rotation.x = swing*0.55 if not airborne else -0.25
		arms[index].rotation.x = -0.95 if holding else (-swing*0.62 if not airborne else -0.7)
		arms[index].rotation.z = (-0.12 if index == 0 else 0.22)*(1+gait)
	fleece.set_shader_parameter("stunned",1.0 if stunned else 0.0)

func _process(delta: float) -> void:
	if not animation_enabled or not is_instance_valid(actor): return
	var distance := actor.global_position.distance_to(last_position)
	last_position = actor.global_position
	if not is_visible_in_tree(): return
	var speed := minf(distance/maxf(delta,0.001),12.0) if distance < 1.0 else 0.0
	var holding := is_instance_valid(actor.held_chair) or not actor.remote_held_name.is_empty()
	animate(delta,speed,holding,absf(actor.velocity.y)>1.5,actor.stun_time_remaining>0)
