extends RefCounted
## Revolved profiles give ceramics and the bell continuous, rounded silhouettes.
static func lathe(profile: Array[Vector2], segments: int = 64) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in profile.size() - 1:
		for segment in segments:
			for corner in [Vector2i(row,segment),Vector2i(row+1,segment+1),Vector2i(row+1,segment),Vector2i(row,segment),Vector2i(row,segment+1),Vector2i(row+1,segment+1)]:
				var p := profile[corner.x]
				var tangent := profile[mini(profile.size()-1,corner.x+1)] - profile[maxi(0,corner.x-1)]
				var angle: float = TAU * corner.y / segments
				surface.set_normal(Vector3(tangent.y*cos(angle), -tangent.x, tangent.y*sin(angle)).normalized())
				surface.add_vertex(Vector3(p.x*cos(angle),p.y,p.x*sin(angle)))
	return surface.commit()

static func material(color: Color, roughness: float = 0.35) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic_specular = 0.65
	return mat

static func ghost_sheet() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2] = [Vector2(0.44,-0.39),Vector2(0.43,-0.34),Vector2(0.39,-0.19),Vector2(0.35,0.02),Vector2(0.32,0.23),Vector2(0.27,0.39),Vector2(0.18,0.51),Vector2(0.08,0.57),Vector2(0,0.59)]
	for row in profile.size()-1:
		for segment in 64:
			for corner in [Vector2i(row,segment),Vector2i(row+1,segment+1),Vector2i(row+1,segment),Vector2i(row,segment),Vector2i(row,segment+1),Vector2i(row+1,segment+1)]:
				var p := profile[corner.x]
				var angle: float = TAU * corner.y / 64.0
				var tangent := profile[mini(profile.size()-1,corner.x+1)] - profile[maxi(0,corner.x-1)]
				var fade := pow(1.0-float(corner.x)/(profile.size()-1),3)
				var radius := p.x + 0.025*cos(angle*7.0)*fade
				surface.set_normal(Vector3(tangent.y*cos(angle),-tangent.x,tangent.y*sin(angle)/0.72).normalized())
				surface.add_vertex(Vector3(radius*cos(angle),p.y+0.06*cos(angle*7.0)*fade,radius*sin(angle)*0.72))
	return surface.commit()

static func piece(parent: Node3D, name_value: String, profile: Array[Vector2], mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_value
	node.mesh = lathe(profile)
	node.material_override = mat
	parent.add_child(node)
	return node
