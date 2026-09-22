extends SceneTree
## Baked garage art must retain the lighting and placement of its source meshes.
const ART = preload("res://scripts/garage_art.gd")
const SHARED = preload("res://scripts/house_prop_art.gd")
const PROPS = preload("res://scripts/garage_prop_art.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1,-1,0),Vector3(1,-1,0),Vector3(1,1,0),Vector3(-1,1,0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(0.1,0.2),Vector2(0.3,0.4),Vector2(0.5,0.6),Vector2(0.7,0.8)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED,Color.GREEN,Color.BLUE,Color.WHITE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1,0,3,2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func check_ellipsoid() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var scale := Vector3(0.075,0.065,0.035)
	var transform := Transform3D(Basis.from_euler(Vector3(0.2,-0.6,0.1)).scaled(scale),Vector3(2,1,-3))
	var original: Array = sphere.surface_get_arrays(0)
	var baked := ART._bake_surface(sphere,0,transform)
	var arrays: Array = baked.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var source_positions: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = original[Mesh.ARRAY_NORMAL]
	var normal_basis := transform.basis.inverse().transposed()
	var worst := 0.0
	for i in positions.size():
		check(positions[i].is_equal_approx(transform * source_positions[i]),"Baked ellipsoid vertex moved")
		worst = maxf(worst,normals[i].distance_to((normal_basis * source_normals[i]).normalized()))
	check(worst < 0.001,"Nonuniform ellipsoid normals were skewed by mesh batching")
	check(arrays[Mesh.ARRAY_INDEX] == original[Mesh.ARRAY_INDEX],"Positive determinant bake changed indices")
	print("GARAGE_BATCHING ellipsoid maximum_normal_error=",worst)

func check_channels() -> void:
	var source := _quad()
	var original: Array = source.surface_get_arrays(0)
	for mirrored in [false,true]:
		var scale := Vector3(-0.7 if mirrored else 0.7,1.6,0.45)
		var transform := Transform3D(Basis.from_euler(Vector3(0.4,0.2,-0.3)).scaled(scale),Vector3(-1,2,3))
		var baked := ART._bake_surface(source,0,transform)
		var arrays: Array = baked.surface_get_arrays(0)
		for channel in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
			check(arrays[channel] == original[channel],"Batch bake changed UVs or vertex colors")
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var expected := (transform.basis * Vector3.RIGHT).normalized()
		for i in 4:
			var actual := Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
			check(actual.distance_to(expected) < 0.001,"Baked tangent direction changed")
			check(absf(actual.dot(normals[i])) < 0.001,"Baked tangent is not perpendicular to its normal")
			check(tangents[i*4+3] == (-1.0 if mirrored else 1.0),"Mirrored tangent handedness was lost")
		var expected_indices := PackedInt32Array([0,1,2,0,2,3]) if mirrored else PackedInt32Array([0,2,1,0,3,2])
		check(arrays[Mesh.ARRAY_INDEX] == expected_indices,"Mirrored rasterizer winding was not preserved")
	check(source.surface_get_arrays(0) == original,"Baking mutated the cached source mesh")

func world_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var started := false
	for part in node.find_children("*","MeshInstance3D",true,false):
		for surface_index in part.mesh.get_surface_count():
			var arrays: Array = part.mesh.surface_get_arrays(surface_index)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = part.global_transform * vertex
				if not started:
					bounds = AABB(point,Vector3.ZERO)
					started = true
				else:
					bounds = bounds.expand(point)
	return bounds

func check_nested_batch() -> void:
	var art := Node3D.new()
	root.add_child(art)
	art.transform = Transform3D(Basis.from_euler(Vector3(0.1,0.4,0.2)).scaled(Vector3(1.2,0.8,1.1)),Vector3(3,2,-4))
	var nested := Node3D.new()
	nested.name = "Nested"
	nested.transform = Transform3D(Basis.from_euler(Vector3(0.3,-0.4,0.2)).scaled(Vector3(0.7,1.4,0.8)),Vector3(1,2,3))
	art.add_child(nested)
	var material := SHARED.material(Color("a38061"))
	var first := SHARED.ball(nested,Vector3(0.3,0.5,0.2),Vector3(-1,0.2,0),Color.WHITE,"BallA")
	first.material_override = material
	var second := SHARED.ball(nested,Vector3(0.6,0.4,0.5),Vector3(1,0.1,0),Color.WHITE,"BallB")
	second.material_override = material
	second.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var third := SHARED.box(nested,Vector3(0.3,0.2,0.6),Vector3(0,1,0),Color.WHITE,"Box")
	third.material_override = material
	# A local-coordinate shader remains its own instance, not just its material.
	var wood := ART.wood(nested,Vector3(0.4,0.1,0.3),Vector3(1,1,1),"LocalWood")
	var wood_id := wood.get_instance_id()
	var wood_transform := wood.transform
	var glass := SHARED.piece(nested,_quad(),Vector3(-0.5,1,1),Color.WHITE,"TransparentPane")
	var glass_material := StandardMaterial3D.new()
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.albedo_color = Color(0.8,0.9,1.0,0.4)
	glass.material_override = glass_material
	var expected := world_bounds(art)
	var anchor_transform := first.global_transform
	ART.finish(art)
	var actual := world_bounds(art)
	check(actual.position.distance_to(expected.position) < 0.001 and actual.size.distance_to(expected.size) < 0.001,"Nested batch changed world-space geometry bounds")
	check(art.get_node("Nested/BallA").global_transform.is_equal_approx(anchor_transform),"Named batch anchor lost its transform")
	check(wood.get_instance_id() == wood_id and wood.transform == wood_transform,"Object-space shader was baked or replaced")
	check(is_instance_valid(glass) and glass.material_override == glass_material,"Transparent surface lost independent sorting")
	var batches := art.find_children("MaterialBatch*","MeshInstance3D",true,false)
	check(batches.size() == 2,"Same material/shadow state failed to consolidate independently")
	var shadows := {}
	for batch in batches:
		check(batch.material_override == material,"Batch changed shared material identity")
		shadows[batch.cast_shadow] = true
	check(shadows.has(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF) and shadows.has(GeometryInstance3D.SHADOW_CASTING_SETTING_ON),"Decorative shadow-off state was lost")
	art.free()

func check_surface_materials() -> void:
	var art := Node3D.new()
	root.add_child(art)
	var source := _quad()
	var arrays: Array = source.surface_get_arrays(0)
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var red := SHARED.material(Color.RED)
	var blue := SHARED.material(Color.BLUE)
	source.surface_set_material(0,red)
	source.surface_set_material(1,blue)
	var part := MeshInstance3D.new()
	part.mesh = source
	art.add_child(part)
	ART.finish(art)
	var materials := []
	for batch in art.find_children("MaterialBatch*","MeshInstance3D",true,false):
		materials.append(batch.material_override)
		var baked: Array = batch.mesh.surface_get_arrays(0)
		check(baked[Mesh.ARRAY_TEX_UV] == arrays[Mesh.ARRAY_TEX_UV],"Final batch append dropped UVs")
		check(baked[Mesh.ARRAY_COLOR] == arrays[Mesh.ARRAY_COLOR],"Final batch append dropped vertex colors")
	check(materials.size() == 2 and red in materials and blue in materials,"Surface materials were merged without their identities")
	art.free()

func check_props() -> void:
	var total_before := 0
	var total_after := 0
	for make_prop: Callable in [PROPS.make_tire,PROPS.make_toolbox,PROPS.make_paint_can,PROPS.make_tool_cart]:
		var art := Node3D.new()
		root.add_child(art)
		make_prop.call(art)
		var expected := world_bounds(art)
		total_before += art.find_children("*","MeshInstance3D",true,false).size()
		ART.finish(art)
		total_after += art.find_children("*","MeshInstance3D",true,false).size()
		var actual := world_bounds(art)
		check(expected.position.distance_to(actual.position) < 0.001 and expected.size.distance_to(actual.size) < 0.001,"Prop batching changed its visible bounds")
		check(art.find_children("*","CollisionObject3D",true,false).is_empty(),"Prop batching created physics objects")
		art.free()
	check(total_after < total_before,"Garage prop hardware did not reduce mesh instances")
	print("GARAGE_BATCHING props before=",total_before," after=",total_after)

func run() -> void:
	check_ellipsoid()
	check_channels()
	check_nested_batch()
	check_surface_materials()
	check_props()
	print("GARAGE_BATCHING failures=",failures)
	quit(1 if failures else 0)
