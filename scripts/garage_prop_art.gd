@tool
extends RefCounted
## Movable garage toys. Local origin is the existing .9m rigid-body center.
## This kit deliberately owns no collisions, scripts, randomness, or gameplay.
const Art = preload("res://scripts/house_prop_art.gd")
const CREAM := Color("e7d9b9")
const CORAL := Color("be7561")
const TEAL := Color("668780")
const BRASS := Color("b79a65")
const INK := Color("34473f")
const RUBBER := Color("3d443e")
static var meshes: Dictionary = {}

static func _part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, title: String, roughness := 0.6, metal := 0.0, trim := false) -> MeshInstance3D:
	var part := Art.piece(parent, mesh, at, color, title, roughness, metal)
	if trim:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part

static func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, title: String, radius := 0.025, trim := false) -> MeshInstance3D:
	return _part(parent, Art.rounded(size, radius), at, color, title, 0.53, 0.0, trim)

static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var key := "cylinder:%s:%s" % [radius, height]
	if meshes.has(key): return meshes[key]
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 40
	meshes[key] = shape
	return shape

static func _ring(radius: float, thickness: float) -> TorusMesh:
	var key := "ring:%s:%s" % [radius, thickness]
	if meshes.has(key): return meshes[key]
	var shape := TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 40
	shape.ring_segments = 8
	meshes[key] = shape
	return shape

static func _tube(points: PackedVector3Array, radius: float, cache_key: String) -> ArrayMesh:
	if meshes.has(cache_key): return meshes[cache_key]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var tangent := (points[i + 1] - points[i]).normalized()
		var side := tangent.cross(Vector3.BACK).normalized()
		for j in 8:
			for corner in [Vector2i(0,j), Vector2i(1,j+1), Vector2i(1,j), Vector2i(0,j), Vector2i(0,j+1), Vector2i(1,j+1)]:
				var angle: float = TAU * corner.y / 8.0
				var normal := side * cos(angle) + Vector3.BACK * sin(angle)
				surface.set_normal(normal)
				surface.add_vertex(points[i + corner.x] + normal * radius)
	var shape := surface.commit()
	meshes[cache_key] = shape
	return shape

static func _tire_body() -> ArrayMesh:
	if meshes.has("tire_body"): return meshes.tire_body
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Elliptical tire section makes a substantial sidewall without filling the hub.
	for ring in 48:
		for section in 20:
			for corner in [Vector2i(0,0), Vector2i(1,1), Vector2i(1,0), Vector2i(0,0), Vector2i(0,1), Vector2i(1,1)]:
				var a: float = TAU * (ring + corner.x) / 48.0
				var b: float = TAU * (section + corner.y) / 20.0
				var radius := 0.327 + cos(b) * 0.11
				var normal := Vector3(cos(a) * cos(b) / 0.11, sin(a) * cos(b) / 0.11, sin(b) / 0.174).normalized()
				surface.set_normal(normal)
				surface.add_vertex(Vector3(cos(a) * radius, sin(a) * radius, sin(b) * 0.174))
	var shape := surface.commit()
	meshes.tire_body = shape
	return shape

static func _tire_tread() -> ArrayMesh:
	if meshes.has("tire_tread"): return meshes.tire_tread
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# One batched mesh for the quiet chevron grooves, not dozens of shadow casters.
	for tread in 20:
		for segment in 8:
			for corner in [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(0,0), Vector2i(1,1), Vector2i(0,1)]:
				var z := lerpf(-0.135, 0.135, (segment + corner.x) / 8.0)
				var a: float = TAU * tread / 20.0 + absf(z) * 0.48 + (corner.y - 0.5) * 0.025
				var radius := 0.329 + 0.11 * sqrt(maxf(0.0, 1.0 - pow(z / 0.174, 2)))
				surface.set_normal(Vector3(cos(a), sin(a), z * 2).normalized())
				surface.add_vertex(Vector3(cos(a) * radius, sin(a) * radius, z))
	var shape := surface.commit()
	meshes.tire_tread = shape
	return shape

static func make_tire(parent: Node3D) -> void:
	_part(parent, _tire_body(), Vector3(0,-0.010,0), RUBBER, "SculptedRubber", 0.91)
	_part(parent, _tire_tread(), Vector3(0,-0.010,0), RUBBER.darkened(0.23), "ChevronTread", 0.97, 0.0, true)
	for side in [-1,1]:
		var ridge := _part(parent, _ring(0.327,0.006), Vector3(0,-0.010,side * 0.174), RUBBER.lightened(0.10), "SidewallMolding", 0.85, 0.0, true)
		ridge.rotation.x = PI / 2
		var bead := _part(parent, _ring(0.225,0.007), Vector3(0,-0.010,side * 0.059), RUBBER.darkened(0.14), "InnerBead", 0.95, 0.0, true)
		bead.rotation.x = PI / 2

static func make_toolbox(parent: Node3D) -> void:
	_box(parent, Vector3(0.82,0.62,0.62), Vector3(0,-0.11,0), CORAL, "EnamelBody", 0.075)
	_box(parent, Vector3(0.834,0.016,0.635), Vector3(0,0.125,0), CORAL.darkened(0.24), "LidGasket", 0.007, true)
	_box(parent, Vector3(0.85,0.20,0.65), Vector3(0,0.22,0), CORAL.lightened(0.07), "RoundedLid", 0.085)
	_box(parent, Vector3(0.35,0.012,0.145), Vector3(0,0.319,0), CORAL.darkened(0.28), "HandleRecess", 0.005, true)
	for side in [-1,1]:
		_box(parent, Vector3(0.045,0.085,0.062), Vector3(side * 0.132,0.364,0), BRASS.darkened(0.10), "HandlePivot", 0.022, true)
		_box(parent, Vector3(0.097,0.12,0.031), Vector3(side * 0.235,0.092,-0.327), BRASS, "Latch", 0.014, true)
		_box(parent, Vector3(0.054,0.045,0.013), Vector3(side * 0.235,0.084,-0.348), BRASS.lightened(0.13), "LatchTab", 0.006, true)
		_box(parent, Vector3(0.012,0.016,0.005), Vector3(side * 0.235,0.066,-0.357), INK, "LatchInset", 0.002, true)
		var hinge := _part(parent, _cylinder(0.024,0.12), Vector3(side * 0.225,0.13,0.322), BRASS.darkened(0.04), "HingeBarrel", 0.43, 0.25, true)
		hinge.rotation.z = PI / 2
		for z in [-0.22,0.22]:
			_box(parent, Vector3(0.12,0.04,0.09), Vector3(side * 0.29,-0.43,z), INK, "RubberFoot", 0.017)
	_box(parent, Vector3(0.30,0.06,0.072), Vector3(0,0.407,0), INK.lightened(0.07), "RecessedCarryGrip", 0.029)
	# A small raised blank badge supplies scale without unreadable placeholder text.
	_box(parent, Vector3(0.19,0.055,0.007), Vector3(0,-0.19,-0.311), CREAM.darkened(0.08), "MakerBadge", 0.003, true)

static func _paint_label(drips := false) -> ArrayMesh:
	var key := "paint_drips" if drips else "paint_label"
	if meshes.has(key): return meshes[key]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 128:
		for corner in [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(0,0), Vector2i(1,1), Vector2i(0,1)]:
			var t: float = (segment + corner.x) / 128.0
			var angle := lerpf(-PI * 0.96, PI * 0.96, t)
			var low := -0.33
			if drips:
				low = 0.006
				for drop in [Vector3(-1.65,0.10,0.13), Vector3(-0.42,0.17,0.11), Vector3(0.36,0.095,0.16), Vector3(1.53,0.13,0.10)]:
					low -= drop.y * exp(-pow((angle - drop.x) / drop.z, 2))
			var radius := 0.315 if not drips else 0.317
			surface.set_normal(Vector3(sin(angle),0,-cos(angle)))
			surface.add_vertex(Vector3(sin(angle) * radius, lerpf(low,0.105,float(corner.y)), -cos(angle) * radius))
	var shape := surface.commit()
	meshes[key] = shape
	return shape

static func make_paint_can(parent: Node3D) -> void:
	_part(parent, _cylinder(0.309,0.58), Vector3(0,-0.13,0), TEAL.darkened(0.06), "PaintTin", 0.56, 0.12)
	_part(parent, _paint_label(), Vector3.ZERO, CREAM, "PaperLabel", 0.89, 0.0, true)
	_part(parent, _paint_label(true), Vector3.ZERO, TEAL, "DrippyPaintLabel", 0.67, 0.0, true)
	for y in [-0.423,0.163]:
		_part(parent, _ring(0.308,0.018), Vector3(0,y,0), BRASS.lightened(0.20), "RolledTinLip", 0.39, 0.28)
	_part(parent, _cylinder(0.293,0.015), Vector3(0,0.154,0), CREAM.darkened(0.11), "RecessedLid", 0.42, 0.15)
	_part(parent, _ring(0.263,0.005), Vector3(0,0.165,0), BRASS.darkened(0.10), "LidPressing", 0.44, 0.20, true)
	for side in [-1,1]:
		var pivot := _part(parent, _cylinder(0.035,0.016), Vector3(side * 0.315,0.09,0), BRASS, "BailRivet", 0.40, 0.28, true)
		pivot.rotation.z = PI / 2
	var points := PackedVector3Array()
	for step in 33:
		var angle := PI * step / 32.0
		points.append(Vector3(cos(angle) * 0.337,0.09 + sin(angle) * 0.337,0))
	_part(parent, _tube(points,0.012,"paint_bail"), Vector3.ZERO, BRASS, "WireBail", 0.37, 0.35)
	_box(parent, Vector3(0.15,0.032,0.045), Vector3(0,0.427,0), CREAM.darkened(0.11), "BailGrip", 0.015)

static func make_tool_cart(parent: Node3D) -> void:
	_box(parent, Vector3(0.78,0.63,0.59), Vector3(0,-0.012,0), TEAL, "EnamelCabinet", 0.062)
	_box(parent, Vector3(0.715,0.54,0.014), Vector3(0,-0.01,-0.298), TEAL.darkened(0.28), "DrawerRecess", 0.006, true)
	for y in [-0.19,-0.015,0.16]:
		_box(parent, Vector3(0.672,0.157,0.035), Vector3(0,y,-0.311), TEAL.lightened(0.045), "InsetDrawer", 0.017)
		for side in [-1,1]:
			_box(parent, Vector3(0.027,0.032,0.027), Vector3(side * 0.11,y + 0.012,-0.339), BRASS.darkened(0.09), "PullMount", 0.01, true)
		_box(parent, Vector3(0.244,0.025,0.031), Vector3(0,y + 0.012,-0.36), BRASS, "RoundedDrawerPull", 0.012, true)
	_box(parent, Vector3(0.81,0.044,0.63), Vector3(0,0.319,0), TEAL.darkened(0.12), "InsetTray", 0.021)
	for side in [-1,1]:
		_box(parent, Vector3(0.045,0.055,0.65), Vector3(side * 0.398,0.353,0), TEAL.lightened(0.13), "TraySideRail", 0.022)
		_box(parent, Vector3(0.76,0.055,0.043), Vector3(0,0.353,side * 0.306), TEAL.lightened(0.13), "TrayEndRail", 0.02)
		for z in [-0.214,0.214]:
			_box(parent, Vector3(0.057,0.071,0.084), Vector3(side * 0.296,-0.337,z), BRASS.darkened(0.19), "CasterFork", 0.016, true)
			var wheel := _part(parent, _cylinder(0.075,0.053), Vector3(side * 0.307,-0.375,z), RUBBER, "CasterTire", 0.87)
			wheel.rotation.z = PI / 2
			var hub := _part(parent, _cylinder(0.029,0.059), Vector3(side * 0.309,-0.375,z), CREAM.darkened(0.12), "CasterHub", 0.53, 0.12, true)
			hub.rotation.z = PI / 2
	# Folded side push grip fits the original cube footprint.
	for z in [-0.17,0.17]:
		_box(parent, Vector3(0.065,0.031,0.031), Vector3(0.412,0.205,z), BRASS, "PushGripMount", 0.015, true)
	_box(parent, Vector3(0.039,0.042,0.37), Vector3(0.435,0.205,0), CREAM.darkened(0.12), "SidePushGrip", 0.019)
