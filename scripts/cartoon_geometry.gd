@tool
extends RefCounted
## Shared, cached soft-edge silhouettes. Visual geometry only; collision stays unchanged.
static var cache: Dictionary = {}

static func rounded_box(size: Vector3) -> ArrayMesh:
	if cache.has(size):
		return cache[size]
	var half := size * 0.5
	var radius := minf(0.12, minf(size.x, minf(size.y, size.z)) * 0.22)
	var inner := half - Vector3.ONE * radius
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var us := [-half[u], -inner[u], inner[u], half[u]]
			var vs := [-half[v], -inner[v], inner[v], half[v]]
			for x in 3:
				for y in 3:
					var points: Array[Vector3] = []
					var normals: Array[Vector3] = []
					for corner in [Vector2i(x,y), Vector2i(x+1,y), Vector2i(x+1,y+1), Vector2i(x,y+1)]:
						var point := Vector3.ZERO
						point[axis] = half[axis] * sign_value
						point[u] = us[corner.x]
						point[v] = vs[corner.y]
						var core := point.clamp(-inner, inner)
						var normal := (point - core).normalized()
						points.append(core + normal * radius)
						normals.append(normal)
					var indices := [0,2,1,0,3,2] if sign_value > 0.0 else [0,1,2,0,2,3]
					for index in indices:
						surface.set_normal(normals[index])
						surface.add_vertex(points[index])
	var result := surface.commit()
	cache[size] = result
	return result
