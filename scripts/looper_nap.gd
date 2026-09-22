extends RefCounted
## Short, sparse close-up fabric fibres; shared GPU meshes, no physics or RNG
## from gameplay. Shader carries the dense pile between these silhouette tips.
static var fields: Dictionary = {}
static var fibre: ArrayMesh

static func fibre_mesh() -> ArrayMesh:
	if fibre != null: return fibre
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 2:
		var along := Vector3.RIGHT if axis == 0 else Vector3.FORWARD
		for triangle in [[0,1,2],[0,2,3]]:
			var points := [along*-0.0006,along*0.0006,along*0.0004+Vector3.UP*0.0026,along*-0.0004+Vector3.UP*0.0023]
			for index in triangle:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(points[index])
	fibre = surface.commit()
	return fibre

static func attach(part: MeshInstance3D, title: String, material: Material) -> void:
	var count := 2500 if title == "Body" else (700 if title == "TopLoop" else 350)
	var key := str(part.mesh.get_rid(),title)
	if not fields.has(key):
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var cumulative := PackedFloat32Array()
		var area := 0.0
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var dirs: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for offset in range(0, indices.size(), 3):
				var a := indices[offset]
				var b := indices[offset+1]
				var c := indices[offset+2]
				if title.ends_with("Arm") and (points[a].y+points[b].y+points[c].y)/3.0 < -0.06: continue
				var weight := (points[b]-points[a]).cross(points[c]-points[a]).length()*0.5
				if weight < 0.0000001: continue
				area += weight
				cumulative.append(area)
				for index in [a,b,c]:
					vertices.append(points[index])
					normals.append(dirs[index])
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = fibre_mesh()
		multimesh.instance_count = count if area > 0 else 0
		var random := RandomNumberGenerator.new()
		random.seed = title.hash()
		for index in multimesh.instance_count:
			var triangle := mini(cumulative.bsearch(random.randf()*area), cumulative.size()-1)*3
			var u := sqrt(random.randf())
			var v := random.randf()
			var weights := Vector3(1-u,u*(1-v),u*v)
			var at := vertices[triangle]*weights.x+vertices[triangle+1]*weights.y+vertices[triangle+2]*weights.z
			var normal := (normals[triangle]*weights.x+normals[triangle+1]*weights.y+normals[triangle+2]*weights.z).normalized()
			var tangent := normal.cross(Vector3.FORWARD if absf(normal.z) < 0.95 else Vector3.RIGHT).normalized()
			var basis := Basis(tangent,normal,tangent.cross(normal)).scaled(Vector3.ONE*random.randf_range(0.75,1.15))
			multimesh.set_instance_transform(index,Transform3D(basis,at-normal*0.00025))
		fields[key] = multimesh
	var nap := MultiMeshInstance3D.new()
	nap.name = "CloseUpVelvet"
	nap.multimesh = fields[key]
	nap.material_override = material
	nap.visibility_range_end = 6.0
	nap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.add_child(nap)
