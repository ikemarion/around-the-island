extends RefCounted
## Tiny GPU-skinned arm chain. Mesh weights are built/cached once per sculpt;
## per-frame work is only two bone rotations, never CPU vertex deformation.
## Godot skeleton/skin API: https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html
static var weighted_meshes: Dictionary = {}

static func elbow(side: float) -> Vector3:
	return Vector3(side * 0.135, -0.30, -0.025)

static func wrist(side: float) -> Vector3:
	return Vector3(side * 0.16, -0.575, 0.055)

static func weighted_mesh(source: Mesh) -> ArrayMesh:
	var key := source.get_rid()
	if weighted_meshes.has(key):
		return weighted_meshes[key]
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(vertices.size() * 4)
		weights.resize(vertices.size() * 4)
		for i in vertices.size():
			var depth := -vertices[i].y
			var lower := smoothstep(0.225, 0.375, depth)
			var hand := smoothstep(0.515, 0.625, depth)
			bones[i * 4] = 0
			bones[i * 4 + 1] = 1
			bones[i * 4 + 2] = 2
			weights[i * 4] = 1.0 - lower
			weights[i * 4 + 1] = lower * (1.0 - hand)
			weights[i * 4 + 2] = lower * hand
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, source.surface_get_material(surface))
	weighted_meshes[key] = result
	return result

static func attach(arm: Node3D, mesh: MeshInstance3D, side: float) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = "ArmSkeleton"
	arm.add_child(skeleton)
	for bone in ["Shoulder", "Elbow", "Wrist"]:
		skeleton.add_bone(bone)
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_parent(2, 1)
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)
	skeleton.set_bone_rest(1, Transform3D(Basis.IDENTITY, elbow(side)))
	skeleton.set_bone_rest(2, Transform3D(Basis.IDENTITY, wrist(side) - elbow(side)))
	skeleton.reset_bone_poses()
	var skin := Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	skin.add_bind(1, Transform3D(Basis.IDENTITY, elbow(side)).affine_inverse())
	skin.add_bind(2, Transform3D(Basis.IDENTITY, wrist(side)).affine_inverse())
	mesh.mesh = weighted_mesh(mesh.mesh)
	mesh.skin = skin
	mesh.skeleton = mesh.get_path_to(skeleton)
	# Include every folded/swinging pose, not only the hanging bind silhouette.
	mesh.custom_aabb = AABB(Vector3(-0.65, -0.90, -0.85), Vector3(1.30, 1.80, 1.70))
	return skeleton
