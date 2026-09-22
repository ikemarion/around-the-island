@tool
extends RefCounted
## Deterministic visual-only workshop kit. All collisions belong to room_module.
const ART = preload("res://scripts/house_prop_art.gd")
const TEAL := Color("52796b")
const PANEL := Color("628a79")
const DARK := Color("304c43")
const CREAM := Color("e1d2aa")
const WOOD := Color("af7947")
const CORAL := Color("ba6250")
const BRASS := Color("b99a61")
const STEEL := Color("96a49a")
static var _wood: ShaderMaterial
static var _floor: ShaderMaterial
static var _pegs: ShaderMaterial
static var _boxes: Dictionary = {}

static func root(parent: Node3D, title: String) -> Node3D:
	var result := Node3D.new()
	result.name = title
	parent.add_child(result)
	return result

static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, title: String, radius := 0.035) -> MeshInstance3D:
	# Two smooth bevel segments are sufficient at workshop-detail scale, versus
	# the hero car's denser sculpt. Cached and later merged by material.
	var key := str(size, radius)
	if not _boxes.has(key):
		var half := size * 0.5
		var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.98)
		var inner := half - Vector3.ONE * r
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for axis in 3:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var us: Array[float] = []
			var vs: Array[float] = []
			for t in [-1.0, -0.70710678, 0.0]:
				us.append(-inner[u] + t * r)
				vs.append(-inner[v] + t * r)
			for t in [0.0, 0.70710678, 1.0]:
				us.append(inner[u] + t * r)
				vs.append(inner[v] + t * r)
			for side in [-1.0, 1.0]:
				for x in us.size() - 1:
					for y in vs.size() - 1:
						var points: Array[Vector3] = []
						var normals: Array[Vector3] = []
						for corner in [Vector2i(x,y), Vector2i(x+1,y), Vector2i(x+1,y+1), Vector2i(x,y+1)]:
							var p := Vector3.ZERO
							p[axis] = half[axis] * side
							p[u] = us[corner.x]
							p[v] = vs[corner.y]
							var center := p.clamp(-inner, inner)
							var normal := (p - center).normalized()
							points.append(center + normal * r)
							normals.append(normal)
						for i in ([0,2,1,0,3,2] if side > 0 else [0,1,2,0,2,3]):
							surface.set_normal(normals[i])
							surface.add_vertex(points[i])
		_boxes[key] = surface.commit()
	return ART.piece(parent, _boxes[key], at, color, title, 0.65)

static func detail(parent: Node3D, size: Vector3, at: Vector3, color: Color, title: String, radius := 0.018) -> MeshInstance3D:
	var part := box(parent, size, at, color, title, radius)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part

static func wood(parent: Node3D, size: Vector3, at: Vector3, title: String, radius := 0.045) -> MeshInstance3D:
	if _wood == null:
		_wood = ShaderMaterial.new()
		_wood.shader = preload("res://scripts/garage_wood.gdshader")
	var part := box(parent, size, at, WOOD, title, radius)
	part.material_override = _wood
	return part

static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color, title: String) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24
	return ART.piece(parent, shape, at, color, title, 0.62)

static func arc(parent: Node3D, at: Vector3, radius: float, tube: float, start: float, end: float, color: Color, title: String) -> void:
	var curve := root(parent, title)
	for i in 16:
		var a := lerpf(start, end, float(i) / 16)
		var b := lerpf(start, end, float(i + 1) / 16)
		ART.rod(curve, at + Vector3(cos(a), sin(a), 0) * radius, at + Vector3(cos(b), sin(b), 0) * radius, tube, color, "Curve%d" % i)

static func handle(parent: Node3D, at: Vector3, width: float, title: String) -> void:
	for side in [-1, 1]:
		ART.ball(parent, Vector3(0.075, 0.065, 0.035), at + Vector3(side * width * 0.5, 0, 0), BRASS, title + "Mount%d" % side)
	ART.rod(parent, at + Vector3(-width * 0.5, 0, 0.045), at + Vector3(width * 0.5, 0, 0.045), 0.028, BRASS, title)

static func make_floor(floor_body: Node3D, floor_art: Node3D) -> void:
	if _floor == null:
		_floor = ShaderMaterial.new()
		_floor.shader = preload("res://scripts/garage_floor.gdshader")
	floor_body.get_node("MeshInstance3D").material_override = _floor
	# All markings are flush, with no new catch points for sliding players.
	for side in [-1, 1]:
		detail(floor_art, Vector3(17.6, 0.009, 0.16), Vector3(0, 0.006, side * 5.64), WOOD, "PerimeterStripe%d" % side)
		for end in [-1, 1]:
			detail(floor_art, Vector3(1.3, 0.008, 0.08), Vector3(end * 2.8, 0.009, side * 1.83), BRASS, "ParkingEdge%d_%d" % [side,end])
			detail(floor_art, Vector3(0.08, 0.008, 0.6), Vector3(end * 3.41, 0.009, side * 1.57), BRASS, "ParkingCorner%d_%d" % [side,end])
	var mat := box(floor_art, Vector3(4.3, 0.03, 2.4), Vector3(0, -0.009, 0), DARK, "ServiceMat", 0.01)
	mat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A few restrained utility grooves, not a slippery hazard or particle clutter.
	for i in 6:
		detail(floor_art, Vector3(3.9, 0.005, 0.013), Vector3(0, 0.009, -0.95 + i * 0.38), TEAL, "MatGroove%d" % i, 0.002)
	finish(floor_art)

static func dress_boundaries(geometry: Node3D, entrance_side: String) -> void:
	var boundary := root(geometry, "GarageBoundaryArt")
	for wall_name in ["NorthWall", "SouthWall", "OuterWall", "Divider0", "Divider1", "Divider2"]:
		var body: Node3D = geometry.get_node(wall_name)
		body.get_node("MeshInstance3D").material_override = ART.material(TEAL, 0.82)
	for side in [-1, 1]:
		wood(boundary, Vector3(17.8, 0.085, 0.40), Vector3(0, 0.675, side * 6), "WallCap%d" % side)
		detail(boundary, Vector3(17.8, 0.095, 0.06), Vector3(0, 0.1, side * 5.815), DARK, "WallPlinth%d" % side)
		for i in 18:
			detail(boundary, Vector3(0.92, 0.43, 0.018), Vector3(-8.5 + i, 0.38, side * 5.819), PANEL, "WallInset%d_%d" % [side,i], 0.008)
	var entrance_x := -8.85 if entrance_side == "west" else 8.85
	wood(boundary, Vector3(0.40, 0.085, 11.95), Vector3(-entrance_x, 0.675, 0), "EndWallCap")
	for i in 3:
		var length: float = [1.0, 4.0, 1.0][i]
		var z: float = [-5.5, 0, 5.5][i]
		# Shallow cream plaster/wood trim on existing divider only; no doorway text.
		var inward := -signf(entrance_x)
		detail(boundary, Vector3(0.028, 1.36, length - 0.035), Vector3(entrance_x + inward * 0.158, 1.6, z), CREAM, "DividerPlaster%d" % i, 0.007)
		wood(boundary, Vector3(0.04, 0.085, length), Vector3(entrance_x + inward * 0.17, 0.87, z), "DividerRail%d" % i, 0.017)
	for i in 2:
		var doorway: Node3D = geometry.get_node("Doorway%d" % (i + 1))
		for part in doorway.find_children("*", "MeshInstance3D", true, false):
			part.material_override = ART.material(WOOD, 0.67)
	# A bounded, shadow-free bounce fill keeps the cream/glass readable on the
	# car's shaded side without changing the rest of the house's lighting.
	var fill := OmniLight3D.new()
	fill.name = "WorkshopBounceLight"
	fill.position = Vector3(1.2, 3.0, 2.0)
	fill.light_color = Color("f5e3ca")
	fill.light_energy = 0.32
	fill.omni_range = 8.0
	fill.omni_attenuation = 1.4
	fill.shadow_enabled = false
	boundary.add_child(fill)
	finish(boundary)

static func make_workbench(body: Node3D) -> void:
	var art := root(body, "WorkbenchArt")
	box(art, Vector3(5.42, 0.82, 1.03), Vector3(0, 0.01, 0), DARK, "Carcass", 0.08)
	box(art, Vector3(5.25, 0.10, 0.94), Vector3(0, -0.43, 0), DARK, "RecessedToeKick")
	wood(art, Vector3(5.68, 0.135, 1.20), Vector3(0, 0.53, 0), "ButcherBlockTop", 0.065)
	for i in 4:
		var x := -1.995 + i * 1.33
		var front := root(art, "Cabinet%d" % i)
		front.position = Vector3(x, 0, 0.53)
		detail(front, Vector3(1.25, 0.28, 0.055), Vector3(0, 0.25, 0), CORAL if i == 0 else PANEL, "UpperDrawer", 0.025)
		handle(front, Vector3(0, 0.25, 0.05), 0.34, "UpperPull")
		if i == 1 or i == 2:
			for drawer in 2:
				detail(front, Vector3(1.25, 0.22, 0.055), Vector3(0, -0.05 - drawer * 0.255, 0), PANEL, "Drawer%d" % drawer)
				handle(front, Vector3(0, -0.05 - drawer * 0.255, 0.055), 0.34, "Pull%d" % drawer)
		else:
			detail(front, Vector3(1.25, 0.48, 0.055), Vector3(0, -0.19, 0), PANEL, "LowerDoor")
			detail(front, Vector3(1.06, 0.32, 0.02), Vector3(0, -0.19, 0.034), TEAL, "RecessedDoorPanel")
			handle(front, Vector3(0.32, -0.075, 0.055), 0.19, "DoorPull")
	# Bench vise: substantial rounded casting with a functioning-looking screw.
	var vise := root(art, "BenchVise")
	vise.position = Vector3(-2.02, 0.60, 0.10)
	box(vise, Vector3(0.57, 0.09, 0.48), Vector3(0, 0.045, 0), DARK, "Foot")
	box(vise, Vector3(0.34, 0.22, 0.32), Vector3(0, 0.17, 0), TEAL, "Casting", 0.08)
	for side in [-1, 1]:
		box(vise, Vector3(0.20, 0.18, 0.37), Vector3(side * 0.18, 0.27, 0), TEAL, "Jaw%d" % side)
		detail(vise, Vector3(0.032, 0.06, 0.35), Vector3(side * 0.11, 0.34, 0), STEEL, "JawPad%d" % side)
	ART.rod(vise, Vector3(-0.4, 0.19, 0), Vector3(0.4, 0.19, 0), 0.032, STEEL, "Spindle")
	ART.rod(vise, Vector3(0.42, 0.02, 0), Vector3(0.42, 0.36, 0), 0.022, BRASS, "TBar")
	for y in [0.02, 0.36]: ART.ball(vise, Vector3.ONE * 0.065, Vector3(0.42, y, 0), BRASS, "HandleEnd")
	# Work surface clutter stays entirely on the original blocked bench.
	box(art, Vector3(0.83, 0.025, 0.54), Vector3(0.50, 0.61, 0.08), DARK, "RepairMat", 0.011)
	var tape := cylinder(art, 0.14, 0.08, Vector3(0.57, 0.66, 0.04), BRASS, "TapeRoll")
	cylinder(art, 0.055, 0.084, tape.position + Vector3.UP * 0.003, DARK, "TapeCore")
	var mug := cylinder(art, 0.115, 0.20, Vector3(1.85, 0.71, -0.17), CREAM, "BrushPot")
	cylinder(art, 0.096, 0.012, mug.position + Vector3.UP * 0.1, DARK, "BrushPotInside")
	for i in 3:
		var a := Vector3(1.81 + i * 0.04, 0.74, -0.16)
		var b := a + Vector3((i - 1) * 0.045, 0.32, 0.025)
		ART.rod(art, a, b, 0.017, WOOD, "BrushHandle%d" % i)
		box(art, Vector3(0.042, 0.085, 0.035), b + Vector3.UP * 0.03, CORAL if i == 0 else CREAM, "BrushBristles%d" % i, 0.012)
	box(art, Vector3(0.60, 0.025, 0.38), Vector3(-0.42, 0.62, 0.02), CREAM, "FoldedShopCloth", 0.01)
	for x in [-0.6, -0.52]: detail(art, Vector3(0.025, 0.003, 0.35), Vector3(x, 0.635, 0.02), CORAL, "ClothStripe", 0.001)
	finish(art)

static func make_toolboard(body: Node3D) -> void:
	var art := root(body, "ToolBoardArt")
	wood(art, Vector3(5.6, 1.55, 0.18), Vector3.ZERO, "RoundedFrame", 0.065)
	var panel := box(art, Vector3(5.39, 1.34, 0.028), Vector3(0, 0, 0.103), WOOD, "PerforatedPanel", 0.01)
	if _pegs == null:
		_pegs = ShaderMaterial.new()
		_pegs.shader = preload("res://scripts/garage_pegboard.gdshader")
	panel.material_override = _pegs
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Distinct tools with real negative spaces rather than circle-on-a-stick icons.
	for i in 5:
		var tool := root(art, "HangingTool%d" % i)
		tool.position = Vector3(-2.14 + i * 0.84, 0.07, 0.18)
		ART.rod(tool, Vector3(0, 0.40, -0.05), Vector3(0, 0.40, 0.065), 0.022, BRASS, "Peg")
		match i:
			0:
				box(tool, Vector3(0.11, 0.59, 0.10), Vector3(0, -0.02, 0), WOOD, "HammerHandle", 0.045)
				box(tool, Vector3(0.43, 0.16, 0.15), Vector3(0, 0.29, 0), STEEL, "HammerHead", 0.055)
				box(tool, Vector3(0.13, 0.19, 0.18), Vector3(-0.20, 0.29, 0), DARK, "StrikingFace")
			1:
				box(tool, Vector3(0.10, 0.49, 0.075), Vector3(0, -0.05, 0), STEEL, "WrenchShaft")
				arc(tool, Vector3(0, 0.28, 0), 0.13, 0.046, 0.3 * PI, 2.7 * PI / 1.5, STEEL, "OpenWrenchJaw")
				arc(tool, Vector3(0, -0.31, 0), 0.072, 0.025, 0, TAU, STEEL, "RingEnd")
			2:
				box(tool, Vector3(0.11, 0.31, 0.10), Vector3(0, -0.15, 0), CORAL, "ScrewdriverGrip", 0.045)
				ART.rod(tool, Vector3(0, 0, 0), Vector3(0, 0.34, 0), 0.022, STEEL, "ScrewdriverShaft")
				box(tool, Vector3(0.055, 0.065, 0.026), Vector3(0, 0.37, 0), STEEL, "FlatTip", 0.008)
			3:
				for side in [-1, 1]:
					ART.rod(tool, Vector3(side * 0.11, -0.32, 0), Vector3(side * 0.028, 0.05, 0), 0.043, CORAL, "PliersGrip%d" % side)
					ART.rod(tool, Vector3(side * 0.028, 0.05, 0), Vector3(side * 0.105, 0.24, 0), 0.031, STEEL, "PliersJaw%d" % side)
				ART.ball(tool, Vector3(0.105, 0.105, 0.055), Vector3(0, 0.025, 0.025), BRASS, "Pivot")
			4:
				box(tool, Vector3(0.49, 0.29, 0.14), Vector3(0, 0.04, 0), CORAL, "TapeMeasure", 0.095)
				var disk := cylinder(tool, 0.083, 0.017, Vector3(0, 0.05, 0.078), CREAM, "TapeBadge")
				disk.rotation.x = PI / 2
	# Shallow bins, shelf and fasteners finish the bench without filling routes.
	wood(art, Vector3(5.55, 0.075, 0.42), Vector3(0, -0.65, 0.22), "AccessoryLedge", 0.032)
	for i in 3:
		var at := Vector3(1.28 + i * 0.40, -0.43, 0.24)
		box(art, Vector3(0.34, 0.29, 0.24), at, TEAL if i != 1 else CORAL, "PartsBin%d" % i)
		detail(art, Vector3(0.27, 0.018, 0.15), at + Vector3(0, 0.149, -0.005), DARK, "BinOpening%d" % i, 0.003)
		detail(art, Vector3(0.13, 0.075, 0.009), at + Vector3(0, 0.01, 0.125), CREAM, "BinLabel%d" % i, 0.004)
	for side in [-1, 1]:
		for top in [-1, 1]:
			ART.ball(art, Vector3(0.05, 0.05, 0.018), Vector3(side * 2.68, top * 0.66, 0.13), BRASS, "FrameScrew")
	# A little enamel task light echoes the reference kitchen's green shades.
	var lamp := root(art, "EnamelTaskLamp")
	lamp.position = Vector3(2.2, 0.43, 0.12)
	ART.ball(lamp, Vector3(0.14, 0.14, 0.055), Vector3.ZERO, BRASS, "WallMount")
	ART.rod(lamp, Vector3(0, 0, 0), Vector3(0, 0.20, 0.26), 0.024, BRASS, "BentArm")
	ART.rod(lamp, Vector3(0, 0.20, 0.26), Vector3(-0.18, 0.20, 0.38), 0.024, BRASS, "Arm")
	var shade_profile: Array[Vector2] = [Vector2(0,0.12), Vector2(0.065,0.12), Vector2(0.13,0.07), Vector2(0.205,-0.08), Vector2(0.20,-0.11), Vector2(0.174,-0.08), Vector2(0.095,0.065), Vector2(0,0.08)]
	ART.piece(lamp, preload("res://scripts/collectible_design.gd").lathe(shade_profile, 32), Vector3(-0.18, 0.10, 0.38), TEAL, "RoundedShade", 0.32)
	var diffuser := cylinder(lamp, 0.171, 0.012, Vector3(-0.18, 0.02, 0.38), CREAM, "CreamDiffuser")
	diffuser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	finish(art)

static func make_shutter(body: Node3D, entrance_side: String) -> void:
	var art := root(body, "GarageDoorArt")
	art.rotation.y = PI / 2 if entrance_side == "east" else -PI / 2
	box(art, Vector3(4.0, 2.9, 0.15), Vector3.ZERO, DARK, "DoorRecess", 0.055)
	for i in 5:
		var y := -1.155 + i * 0.55
		box(art, Vector3(3.74, 0.515, 0.052), Vector3(0, y, 0.09), TEAL, "Section%d" % i, 0.045)
		for j in 3:
			var x := -1.22 + j * 1.22
			detail(art, Vector3(1.08, 0.355, 0.022), Vector3(x, y, 0.123), PANEL, "RaisedPanel%d_%d" % [i,j], 0.011)
	for side in [-1, 1]:
		wood(art, Vector3(0.14, 2.92, 0.24), Vector3(side * 1.97, 0, 0.025), "DoorJamb%d" % side)
		for y in [-0.89, -0.34, 0.21]:
			detail(art, Vector3(0.12, 0.17, 0.014), Vector3(side * 1.73, y, 0.132), STEEL, "Hinge")
	wood(art, Vector3(4.08, 0.13, 0.24), Vector3(0, 1.43, 0.025), "Header", 0.04)
	# Small rounded window row integrated in the original shutter envelope.
	for i in 4:
		var x := -1.39 + i * 0.925
		box(art, Vector3(0.80, 0.40, 0.06), Vector3(x, 1.02, 0.13), CREAM, "WindowGasket%d" % i, 0.055)
		var glass := box(art, Vector3(0.69, 0.29, 0.018), Vector3(x, 1.02, 0.165), Color("719c93"), "WindowGlass%d" % i, 0.009)
		glass.material_override = ART.material(Color("719c93"), 0.20)
		var glint := detail(art, Vector3(0.038, 0.20, 0.003), Vector3(x - 0.20, 1.025, 0.177), Color("acbdae"), "WindowGlint%d" % i, 0.001)
		glint.rotation.z = -0.45
	handle(art, Vector3(0, -0.60, 0.17), 0.39, "DoorLiftHandle")
	detail(art, Vector3(3.84, 0.08, 0.07), Vector3(0, -1.4, 0.10), DARK, "RubberSweep")
	finish(art)

static func _bake_surface(mesh: Mesh, surface_index: int, transform: Transform3D) -> ArrayMesh:
	# SurfaceTool.append_from applies the position basis to normals too. That
	# skews lighting on the nonuniform spheres used for mounts and knobs. Bake
	# explicitly, then append at identity, preserving all other vertex channels.
	var arrays: Array = mesh.surface_get_arrays(surface_index).duplicate(true)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = transform * vertices[i]
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var normal_basis := transform.basis.inverse().transposed()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in normals.size():
			normals[i] = (normal_basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	var mirrored := transform.basis.determinant() < 0.0
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in range(0, tangents.size(), 4):
			var tangent := (transform.basis * Vector3(tangents[i], tangents[i+1], tangents[i+2])).normalized()
			tangents[i] = tangent.x
			tangents[i+1] = tangent.y
			tangents[i+2] = tangent.z
			if mirrored: tangents[i+3] = -tangents[i+3]
		arrays[Mesh.ARRAY_TANGENT] = tangents
	if mirrored:
		# A node's mirrored transform normally flips rasterizer winding. The
		# batch is identity, so flip the baked indices instead (not its normals).
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for i in vertices.size(): indices[i] = i
		for i in range(0, indices.size(), 3):
			var previous := indices[i+1]
			indices[i+1] = indices[i+2]
			indices[i+2] = previous
		arrays[Mesh.ARRAY_INDEX] = indices
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return baked

static func finish(art: Node3D) -> void:
	# Static detail is merged per material/shadow state, so rivets and trim don't
	# each require a draw call. Keep named anchors for editor inspection/tests.
	var batches: Dictionary = {}
	var anchor_index := 0
	for part: MeshInstance3D in art.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null or part.material_override is ShaderMaterial:
			continue # Object-space wood grain/peg holes need their own coordinates.
		var keep_separate := false
		for surface_index in part.mesh.get_surface_count():
			var active_material := part.get_active_material(surface_index)
			keep_separate = keep_separate or active_material is ShaderMaterial
			if active_material is BaseMaterial3D and active_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				keep_separate = true # Transparent objects need individual sorting.
		if keep_separate: continue
		var relative := part.transform
		var ancestor := part.get_parent()
		while ancestor != art:
			relative = ancestor.transform * relative
			ancestor = ancestor.get_parent()
		if is_zero_approx(relative.basis.determinant()): continue
		for surface_index in part.mesh.get_surface_count():
			var material := part.get_active_material(surface_index)
			var key := str(material.get_instance_id() if material != null else 0, ":", part.cast_shadow)
			if not batches.has(key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[key] = [surface, material, part.cast_shadow]
			batches[key][0].append_from(_bake_surface(part.mesh, surface_index, relative), 0, Transform3D.IDENTITY)
		var anchor := Node3D.new()
		# Godot's unnamed-duplicate fallback embeds a process-global instance ID.
		# Stable helper anchors are easier to inspect across editor rebuilds.
		anchor.name = "Detail%03d" % anchor_index if str(part.name).begins_with("@") else str(part.name)
		anchor_index += 1
		anchor.transform = part.transform
		var parent := part.get_parent()
		parent.remove_child(part)
		parent.add_child(anchor)
		part.free()
	var index := 0
	for key in batches:
		var batch := MeshInstance3D.new()
		batch.name = "MaterialBatch%d" % index
		batch.mesh = batches[key][0].commit()
		batch.material_override = batches[key][1]
		batch.cast_shadow = batches[key][2]
		art.add_child(batch)
		index += 1
