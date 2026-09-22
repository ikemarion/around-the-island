extends RefCounted
## Tiny instanced fibre tips add a soft close-up silhouette. Cached per part;
## no individual Nodes, random gameplay state, simulation, or network traffic.
static var fields: Dictionary = {}
static var tip: ArrayMesh

static func tuft() -> ArrayMesh:
	if tip != null: return tip
	var points := [Vector3(0,0.004,0),Vector3(0,-0.0015,0),Vector3(0.002,0,0),Vector3(0,0,0.002),Vector3(-0.002,0,0),Vector3(0,0,-0.002)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 4:
		var a := index+2
		var b := (index+1)%4+2
		for vertex in [0,b,a,1,a,b]:
			surface.set_normal(points[vertex].normalized())
			surface.add_vertex(points[vertex])
	tip = surface.commit()
	return tip

static func attach(parent: MeshInstance3D, title: String, mat: Material) -> void:
	# Feet use their own smooth sock material; fibres remain on the gold/slot
	# fabric. Exclude the moving lip so no tips detach during the jaw morph.
	var count := 3600 if title == "Body" else 1100
	var key := str(parent.mesh.get_rid(),title)
	if not fields.has(key):
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var areas := PackedFloat32Array()
		var total := 0.0
		for surface in parent.mesh.get_surface_count():
			var material := parent.mesh.surface_get_material(surface)
			if material != null and "Mouth" in material.resource_name: continue
			var arrays := parent.mesh.surface_get_arrays(surface)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for offset in range(0,indices.size(),3):
				var a := indices[offset]
				var b := indices[offset+1]
				var c := indices[offset+2]
				var mid := (v[a]+v[b]+v[c])/3.0
				if title == "Body" and mid.y < 0.38 and mid.y > 0.025 and mid.z > -0.04: continue
				# Keep geometry fibres on the shoulder above the elbow morph.
				# The bending forearm/mitten retains its procedural fibre shading.
				if title.ends_with("Arm") and mid.y < -0.06: continue
				var area := (v[b]-v[a]).cross(v[c]-v[a]).length()*0.5
				if area < 0.0000001: continue
				total += area
				areas.append(total)
				for i in [a,b,c]:
					vertices.append(v[i])
					normals.append(n[i])
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = tuft()
		instances.instance_count = count
		var rng := RandomNumberGenerator.new()
		rng.seed = 5187
		for index in count:
			var slot := clampi(areas.bsearch(rng.randf()*total),0,areas.size()-1)*3
			var u := sqrt(rng.randf())
			var v := rng.randf()
			var weights := Vector3(1.0-u,u*(1-v),u*v)
			var at := Vector3.ZERO
			var normal := Vector3.ZERO
			for j in 3:
				at += vertices[slot+j]*weights[j]
				normal += normals[slot+j]*weights[j]
			normal = normal.normalized()
			var basis := Basis(Quaternion(Vector3.UP,normal)).scaled(Vector3.ONE*rng.randf_range(0.7,1.15))
			instances.set_instance_transform(index,Transform3D(basis,at-normal*0.0006))
		fields[key] = instances
	var nap := MultiMeshInstance3D.new()
	nap.name = "CloseUpFleece"
	nap.multimesh = fields[key]
	nap.material_override = mat
	nap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nap.visibility_range_end = 7.0
	parent.add_child(nap)
