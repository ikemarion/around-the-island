extends Node3D
## Shared miniature/deployed toy door, front is +Z, base is Y=0.
const GEO = preload("res://scripts/cartoon_geometry.gd")
const CREAM := Color("fff0cc")
const CORAL := Color("e66d55")
const TEAL := Color("468f80")
const GOLD := Color("eebd4a")
var age := 0.0
var stars: Array[Node3D] = []

func _ready() -> void:
	var frame := MeshInstance3D.new()
	frame.mesh = rounded_frame()
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = CREAM
	frame_mat.roughness = 0.45
	frame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	frame.material_override = frame_mat
	add_child(frame)
	for x in [-0.82,0.82]:
		box(self,Vector3(0.47,0.28,0.58),Vector3(x,0.14,0.04),CREAM)
	box(self,Vector3(1.7,0.13,0.5),Vector3(0,0.065,0.02),CREAM)
	for x in [-0.645,0.645]:
		box(self,Vector3(0.085,1.97,0.19),Vector3(x,1.1,0.05),TEAL)
	box(self,Vector3(1.35,0.085,0.19),Vector3(0,2.045,0.05),TEAL)
	box(self,Vector3(0.78,0.29,0.09),Vector3(0,2.25,0.235),TEAL)
	var label := Label3D.new()
	label.text = "EXIT"
	label.font_size = 64
	label.pixel_size = 0.003
	label.outline_size = 0
	label.modulate = CREAM
	label.position = Vector3(0,2.25,0.29)
	add_child(label)
	var hinge := Node3D.new()
	add_child(hinge)
	hinge.position = Vector3(-0.61,0.13,0.13)
	hinge.rotation.y = deg_to_rad(-68)
	box(hinge,Vector3(1.24,1.89,0.18),Vector3(0.62,0.945,0),CORAL)
	box(hinge,Vector3(0.96,1.52,0.045),Vector3(0.62,0.97,0.105),CORAL.darkened(0.15))
	box(hinge,Vector3(0.84,1.39,0.05),Vector3(0.62,0.97,0.132),CORAL)
	for y in [0.45,1.5]:
		box(hinge,Vector3(0.13,0.26,0.18),Vector3(0.02,y,0.12),GOLD)
	ball(hinge,Vector3(0.17,0.17,0.06),Vector3(1.05,0.9,0.13),GOLD.darkened(0.12))
	ball(hinge,Vector3(0.145,0.145,0.13),Vector3(1.05,0.9,0.24),GOLD)
	var portal := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(1.24,1.88)
	portal.mesh = plane
	portal.position = Vector3(0,1.08,0)
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://scripts/door_passage.gdshader")
	portal.material_override = shader
	add_child(portal)
	for i in 7:
		var star := Node3D.new()
		add_child(star)
		box(star,Vector3(0.045,0.14,0.035),Vector3.ZERO,GOLD.lightened(0.3))
		box(star,Vector3(0.11,0.04,0.035),Vector3.ZERO,GOLD.lightened(0.3))
		stars.append(star)

func _process(delta: float) -> void:
	age += delta
	for i in stars.size():
		var phase := fmod(age*0.22+float(i)/stars.size(),1.0)
		stars[i].position = Vector3(sin(i*4.2+age*0.7)*0.45,0.2+phase*1.7,0.08)
		stars[i].scale = Vector3.ONE*sin(phase*PI)*0.8
		stars[i].rotation.z = sin(age+i)*0.2

static func box(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = GEO.rounded_box(Vector3(1,1,0.5))
	part.scale = Vector3(size.x,size.y,size.z*2)
	part.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	mat.metallic = 0.45 if color == GOLD else 0.0
	part.material_override = mat
	parent.add_child(part)
	return part

static func outline(size: Vector2, radius: float, height: float, depth: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for corner in 4:
		var signs := [Vector2(1,1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,-1)][corner] as Vector2
		var center := signs * (size*0.5-Vector2.ONE*radius)
		for step in 9:
			var angle := (float(corner)+float(step)/8.0)*PI/2.0
			var point := center + Vector2(cos(angle),sin(angle))*radius
			points.append(Vector3(point.x,point.y+height,depth))
	return points

static func rounded_frame() -> ArrayMesh:
	# Closed beveled frame cross-section, with a true hole through its middle.
	var rings := [outline(Vector2(1.78,2.26),0.24,1.21,0.22),outline(Vector2(1.94,2.42),0.32,1.21,0.14),outline(Vector2(1.94,2.42),0.32,1.21,-0.14),outline(Vector2(1.78,2.26),0.24,1.21,-0.22),outline(Vector2(1.46,2.06),0.20,1.10,-0.22),outline(Vector2(1.30,1.90),0.12,1.10,-0.14),outline(Vector2(1.30,1.90),0.12,1.10,0.14),outline(Vector2(1.46,2.06),0.20,1.10,0.22)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for ring in rings.size():
		var next := (ring+1)%rings.size()
		for i in rings[ring].size():
			var j: int = (i+1)%rings[ring].size()
			for p in [rings[ring][i],rings[next][i],rings[next][j],rings[ring][i],rings[next][j],rings[ring][j]]:
				surface.add_vertex(p)
	surface.index()
	surface.generate_normals()
	return surface.commit()

static func ball(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	part.mesh = sphere
	part.scale = size
	part.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.55
	mat.roughness = 0.24
	part.material_override = mat
	parent.add_child(part)
