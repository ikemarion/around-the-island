@tool
extends Node3D
## One deterministic 18 x 12 room tile. Move/rotate an instance to extend the house.
## Door centers are z = +/-3.5; floor top is y = 0. Generated art has no RNG.
## Use a unique room_id for each instance: movable prop names are network keys.

@export_enum("living_room", "garage") var theme: String = "living_room":
	set(value):
		theme = value
		_schedule_editor_rebuild()
@export_enum("west", "east") var entrance_side: String = "west":
	set(value):
		entrance_side = value
		_schedule_editor_rebuild()
@export var room_id: String = "Living":
	set(value):
		room_id = value
		_schedule_editor_rebuild()

const SHOVEABLE = preload("res://scripts/shoveable.gd")
const INK := Color("203b3b")
const CREAM := Color("fff0c4")
const TEAL := Color("488e85")
const CORAL := Color("ed795c")
const GOLD := Color("e8b45c")
var _materials: Dictionary = {}
var _rebuild_pending := false

func _schedule_editor_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree() and not _rebuild_pending:
		_rebuild_pending = true
		_rebuild_preview.call_deferred()

func _rebuild_preview() -> void:
	_rebuild_pending = false
	for child_name in ["Geometry", "PickupSpawns"]:
		var child := get_node_or_null(child_name)
		if child != null:
			remove_child(child)
			child.queue_free()
	_build_room()

func _enter_tree() -> void:
	if not has_node("Geometry"):
		_build_room()

func _node(parent: Node, node: Node, node_name: String) -> Node:
	node.name = node_name
	parent.add_child(node)
	# Keep generated preview children unsaved. Every load recreates identical
	# geometry and runtime prop groups from the module's exported configuration.
	return node

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	result.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	result.roughness = 0.85
	_materials[key] = result
	return result

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, mesh_name: String = "Detail") -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = _material(color)
	result.position = at
	_node(parent, result, mesh_name)
	return result

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, mesh_name: String = "Panel") -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, at, color, mesh_name)

func _ball(parent: Node3D, size: Vector3, at: Vector3, color: Color, mesh_name: String = "RoundDetail") -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 8
	var result := _mesh(parent, shape, at, color, mesh_name)
	result.scale = size
	return result

func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color, mesh_name: String = "RoundDetail") -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 20
	return _mesh(parent, shape, at, color, mesh_name)

func _solid(parent: Node3D, solid_name: String, size: Vector3, at: Vector3, color: Color, visible_mesh: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	_node(parent, body, solid_name)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	_node(body, collision, "CollisionShape3D")
	if visible_mesh:
		_box(body, size, Vector3.ZERO, color, "MeshInstance3D")
	return body

func _label(parent: Node3D, message: String, at: Vector3, rotation_y: float = 0.0) -> void:
	var label := Label3D.new()
	label.text = message
	label.font_size = 64
	label.pixel_size = 0.006
	label.modulate = CREAM
	label.outline_modulate = INK
	label.outline_size = 8
	label.position = at
	label.rotation.y = rotation_y
	_node(parent, label, "RoomLabel")

func _build_room() -> void:
	var geometry := Node3D.new()
	_node(self, geometry, "Geometry")
	var floor_color := Color("c5a071") if theme == "living_room" else Color("82948c")
	var floor_body := _solid(geometry, "Floor", Vector3(18, 0.2, 12), Vector3(0, -0.1, 0), floor_color)
	floor_body.add_to_group("house_floor")
	var floor_art := Node3D.new()
	_node(geometry, floor_art, "FloorArt")
	if theme == "living_room":
		for index in 11:
			_box(floor_art, Vector3(18, 0.004, 0.026), Vector3(0, 0.003, -5.5 + index), Color("a2815c"))
		for index in 7:
			_box(floor_art, Vector3(0.022, 0.004, 12), Vector3(-7.5 + index * 2.5, 0.003, 0), Color("b38e62"))
	else:
		for x in [-6.0, 0.0, 6.0]:
			_box(floor_art, Vector3(0.028, 0.004, 12), Vector3(x, 0.003, 0), Color("6b8079"))
		_box(floor_art, Vector3(18, 0.004, 0.028), Vector3(0, 0.003, 0), Color("6b8079"))
	_build_boundary(geometry)
	if theme == "garage":
		_build_garage(geometry)
	else:
		_build_living_room(geometry)
	var spawns := Node3D.new()
	_node(self, spawns, "PickupSpawns")
	# Clear of doorway throats, furniture and initial movable-prop positions.
	for index in 4:
		var marker := Marker3D.new()
		marker.position = [Vector3(-5.8, 0, -3.5), Vector3(5.8, 0, -3.5), Vector3(-5.8, 0, 3.5), Vector3(5.8, 0, 3.5)][index]
		_node(spawns, marker, "Spawn%d" % (index + 1))

func _build_boundary(parent: Node3D) -> void:
	var accent := CORAL if theme == "living_room" else TEAL
	_solid(parent, "NorthWall", Vector3(18, 0.7, 0.35), Vector3(0, 0.35, -6), accent)
	_solid(parent, "SouthWall", Vector3(18, 0.7, 0.35), Vector3(0, 0.35, 6), accent)
	var entrance_x := -8.85 if entrance_side == "west" else 8.85
	_solid(parent, "OuterWall", Vector3(0.35, 0.7, 12), Vector3(-entrance_x, 0.35, 0), accent)
	# Paired passage openings match the kitchen module's divider.
	for index in 3:
		var length: float = [1.0, 4.0, 1.0][index]
		var z: float = [-5.5, 0.0, 5.5][index]
		var wall := _solid(parent, "Divider%d" % index, Vector3(0.3, 2.3, length), Vector3(entrance_x, 1.15, z), accent)
		_box(wall, Vector3(0.36, 0.12, length), Vector3(0, 1.16, 0), CREAM, "TopTrim")
	for index in 2:
		var z: float = [-3.5, 3.5][index]
		var doorway := Node3D.new()
		doorway.position = Vector3(entrance_x, 0, z)
		_node(parent, doorway, "Doorway%d" % (index + 1))
		# Trim lies inside the divider, preserving the entire 3m clear opening.
		for side in [-1, 1]:
			_box(doorway, Vector3(0.42, 2.4, 0.1), Vector3(0, 1.2, side * 1.56), CREAM, "DoorTrim")
		_solid(doorway, "Header", Vector3(0.42, 0.22, 3.22), Vector3(0, 2.51, 0), CREAM)
		_box(doorway, Vector3(0.65, 0.01, 3.0), Vector3(0, 0.006, 0), GOLD, "Threshold")
		var title := "LIVING ROOM" if theme == "living_room" else "GARAGE"
		var facing := PI / 2.0 if entrance_side == "west" else -PI / 2.0
		_label(doorway, title, Vector3(-0.24 if entrance_side == "west" else 0.24, 2.78, 0), -facing)
		_label(doorway, "KITCHEN", Vector3(0.24 if entrance_side == "west" else -0.24, 2.78, 0), facing)

func _prop(parent: Node3D, suffix: String, at: Vector3) -> Node3D:
	var body := RigidBody3D.new()
	body.set_script(SHOVEABLE)
	body.position = at
	body.mass = 0.9
	body.linear_damp = 3.2
	body.angular_damp = 5.0
	body.axis_lock_angular_x = true
	body.axis_lock_angular_z = true
	if not Engine.is_editor_hint():
		body.add_to_group("shoveable")
	_node(parent, body, room_id + suffix)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 0.9
	collision.shape = shape
	_node(body, collision, "CollisionShape3D")
	var dummy := MeshInstance3D.new()
	dummy.visible = false
	_node(body, dummy, "MeshInstance3D")
	var art := Node3D.new()
	_node(body, art, "CartoonProp")
	return art

func _build_living_room(parent: Node3D) -> void:
	var rug := _box(parent, Vector3(8.4, 0.018, 5.0), Vector3(0, 0.014, 0.0), Color("cb725c"), "Rug")
	_box(rug, Vector3(7.9, 0.008, 4.5), Vector3(0, 0.012, 0), Color("eac798"), "RugBorder")
	_box(rug, Vector3(7.5, 0.008, 4.1), Vector3(0, 0.018, 0), Color("6caaa0"), "RugCenter")
	var couch := _solid(parent, "Couch", Vector3(5.0, 1.45, 1.55), Vector3(0, 0.725, 0.85), CORAL, false)
	_box(couch, Vector3(4.8, 0.45, 1.35), Vector3(0, -0.17, 0), INK, "SofaBase")
	_ball(couch, Vector3(4.75, 1.05, 0.62), Vector3(0, 0.12, 0.55), CORAL, "SofaBack")
	for index in 3:
		_ball(couch, Vector3(1.45, 0.48, 1.2), Vector3(-1.48 + index * 1.48, -0.0, -0.06), Color("f09372"), "SeatCushion")
	for side in [-1, 1]:
		_ball(couch, Vector3(0.62, 1.05, 1.55), Vector3(side * 2.15, -0.04, 0), CORAL, "SofaArm")
		_ball(couch, Vector3(0.72, 0.63, 0.3), Vector3(side * 1.5, 0.35, 0.23), GOLD, "ThrowPillow")
	var table := _solid(parent, "CoffeeTable", Vector3(2.9, 0.65, 1.15), Vector3(0, 0.325, -1.45), GOLD, false)
	_ball(table, Vector3(3.0, 0.23, 1.3), Vector3(0, 0.22, 0), GOLD, "TableTop")
	for x in [-1.0, 1.0]:
		for z in [-0.3, 0.3]:
			_cylinder(table, 0.075, 0.54, Vector3(x, -0.03, z), INK, "TableLeg")
	_box(table, Vector3(0.48, 0.035, 0.38), Vector3(-0.4, 0.35, 0.02), CORAL, "Magazine")
	_cylinder(table, 0.12, 0.19, Vector3(0.56, 0.41, 0), CREAM, "Mug")
	var tv := _solid(parent, "TVConsole", Vector3(3.6, 0.75, 0.9), Vector3(0, 0.375, -5.08), GOLD)
	for side in [-1, 1]:
		_box(tv, Vector3(1.55, 0.54, 0.035), Vector3(side * 0.88, 0.03, 0.46), TEAL, "CabinetDoor")
		_ball(tv, Vector3.ONE * 0.12, Vector3(side * 0.23, 0.08, 0.49), CREAM, "CabinetKnob")
	_solid(parent, "Television", Vector3(2.5, 1.25, 0.3), Vector3(0, 1.38, -5.15), INK)
	_ball(parent, Vector3(2.28, 1.08, 0.07), Vector3(0, 1.39, -4.975), Color("96cbca"), "TVScreen")
	_label(parent, "TOON TIME", Vector3(0, 1.37, -4.92))
	var ottoman := _prop(parent, "Ottoman", Vector3(-3.65, 0.55, 1.05))
	_ball(ottoman, Vector3(0.9, 0.75, 0.9), Vector3(0, -0.075, 0), CORAL, "Upholstery")
	_ball(ottoman, Vector3(0.83, 0.27, 0.83), Vector3(0, 0.28, 0), Color("f09372"), "Cushion")
	var cushion := _prop(parent, "Cushion", Vector3(3.65, 0.55, 1.3))
	_ball(cushion, Vector3(0.9, 0.62, 0.9), Vector3(0, -0.1, 0), GOLD, "Pillow")
	_ball(cushion, Vector3(0.11, 0.035, 0.11), Vector3(0, 0.22, 0), CORAL, "Button")
	var toy := _prop(parent, "Toy", Vector3(5.0, 0.55, -1.6))
	_ball(toy, Vector3(0.7, 0.62, 0.55), Vector3(0, -0.13, 0), TEAL, "ToyBody")
	_ball(toy, Vector3(0.51, 0.47, 0.48), Vector3(0, 0.2, -0.06), TEAL, "ToyHead")
	for side in [-1, 1]:
		_ball(toy, Vector3.ONE * 0.22, Vector3(side * 0.21, 0.32, -0.05), GOLD, "ToyEar")
		_ball(toy, Vector3(0.06, 0.09, 0.04), Vector3(side * 0.12, 0.24, -0.29), INK, "ToyEye")
	var stool := _prop(parent, "SideStool", Vector3(4.5, 0.55, 4.65))
	_cylinder(stool, 0.44, 0.14, Vector3(0, 0.31, 0), GOLD, "Seat")
	for x in [-0.25, 0.25]:
		for z in [-0.25, 0.25]:
			_cylinder(stool, 0.055, 0.7, Vector3(x, -0.1, z), TEAL, "Leg")

func _build_garage(parent: Node3D) -> void:
	for side in [-1, 1]:
		_box(parent, Vector3(6.6, 0.01, 0.08), Vector3(0, 0.009, side * 1.8), GOLD, "ParkingStripe")
	var car := _solid(parent, "ProjectCar", Vector3(5.4, 1.65, 2.55), Vector3(0, 0.825, 0), CORAL, false)
	_ball(car, Vector3(5.4, 1.15, 2.5), Vector3(0, -0.2, 0), CORAL, "CarBody")
	_ball(car, Vector3(2.6, 1.3, 2.1), Vector3(-0.25, 0.35, 0), Color("f09372"), "CarRoof")
	for side in [-1, 1]:
		_ball(car, Vector3(2.1, 0.74, 0.1), Vector3(-0.25, 0.41, side * 0.98), Color("b2deda"), "CarWindow")
		for x in [-1.7, 1.7]:
			var wheel := _cylinder(car, 0.47, 0.17, Vector3(x, -0.32, side * 1.2), INK, "Wheel")
			wheel.rotation.x = PI / 2.0
			var hub := _cylinder(car, 0.22, 0.18, Vector3(x, -0.32, side * 1.27), CREAM, "Hubcap")
			hub.rotation.x = PI / 2.0
		_ball(car, Vector3(0.12, 0.29, 0.47), Vector3(2.57, -0.14, side * 0.72), CREAM, "Headlight")
	_box(car, Vector3(0.12, 0.18, 1.75), Vector3(2.65, -0.38, 0), TEAL, "Bumper")
	var bench := _solid(parent, "Workbench", Vector3(5.5, 1.0, 1.1), Vector3(0, 0.5, -5.15), TEAL)
	_box(bench, Vector3(5.7, 0.13, 1.2), Vector3(0, 0.53, 0), GOLD, "WoodTop")
	for index in 4:
		_box(bench, Vector3(1.2, 0.32, 0.035), Vector3(-1.98 + index * 1.32, 0.11, 0.56), CORAL, "Drawer")
		_box(bench, Vector3(0.32, 0.06, 0.07), Vector3(-1.98 + index * 1.32, 0.14, 0.6), CREAM, "DrawerHandle")
	var board := _solid(parent, "ToolBoard", Vector3(5.6, 1.55, 0.18), Vector3(0, 1.91, -5.65), GOLD)
	for index in 7:
		var x := -2.1 + index * 0.7
		_box(board, Vector3(0.09, 0.56, 0.09), Vector3(x, -0.08, 0.16), INK, "ToolHandle")
		if index % 2 == 0:
			_box(board, Vector3(0.38, 0.15, 0.14), Vector3(x, 0.26, 0.16), TEAL, "HammerHead")
		else:
			_cylinder(board, 0.15, 0.07, Vector3(x, 0.3, 0.16), CREAM, "WrenchHead").rotation.x = PI / 2.0
	var shutter_x := -8.72 if entrance_side == "east" else 8.72
	var shutter := _solid(parent, "GarageShutter", Vector3(0.15, 2.9, 4.0), Vector3(shutter_x, 1.45, 0), Color("71877e"))
	for index in 7:
		_box(shutter, Vector3(0.17, 0.035, 3.85), Vector3(0, -1.2 + index * 0.4, 0), INK, "ShutterSeam")
	var tire := _prop(parent, "Tire", Vector3(-4.0, 0.55, 1.4))
	var tire_shape := TorusMesh.new()
	tire_shape.inner_radius = 0.22
	tire_shape.outer_radius = 0.43
	tire_shape.rings = 20
	tire_shape.ring_segments = 12
	var tire_mesh := _mesh(tire, tire_shape, Vector3.ZERO, INK, "RubberTire")
	tire_mesh.rotation.x = PI / 2.0
	var toolbox := _prop(parent, "Toolbox", Vector3(3.8, 0.55, -1.5))
	_box(toolbox, Vector3(0.84, 0.57, 0.65), Vector3(0, -0.13, 0), CORAL, "ToolboxBody")
	_ball(toolbox, Vector3(0.87, 0.24, 0.68), Vector3(0, 0.18, 0), Color("f09372"), "RoundedLid")
	for side in [-1, 1]:
		_box(toolbox, Vector3(0.07, 0.18, 0.08), Vector3(side * 0.17, 0.32, 0), INK, "HandleUpright")
	_box(toolbox, Vector3(0.4, 0.07, 0.08), Vector3(0, 0.41, 0), INK, "Handle")
	_box(toolbox, Vector3(0.13, 0.15, 0.025), Vector3(0, 0.03, -0.34), CREAM, "Latch")
	var paint := _prop(parent, "PaintCan", Vector3(-5.4, 0.55, -1.8))
	_cylinder(paint, 0.36, 0.76, Vector3(0, -0.03, 0), CREAM, "PaintCanBody")
	_cylinder(paint, 0.365, 0.38, Vector3(0, -0.07, 0), TEAL, "PaintLabel")
	_cylinder(paint, 0.39, 0.045, Vector3(0, 0.37, 0), INK, "Lid")
	_ball(paint, Vector3(0.45, 0.035, 0.41), Vector3(0, 0.4, 0), CORAL, "PaintSplash")
	var cart := _prop(parent, "ToolCart", Vector3(4.9, 0.55, 4.65))
	_box(cart, Vector3(0.82, 0.67, 0.67), Vector3(0, -0.02, 0), TEAL, "CartBody")
	_box(cart, Vector3(0.87, 0.08, 0.72), Vector3(0, 0.34, 0), INK, "CartTop")
	for index in 3:
		_box(cart, Vector3(0.67, 0.14, 0.025), Vector3(0, -0.2 + index * 0.18, -0.35), GOLD, "Drawer")
	for x in [-0.28, 0.28]:
		for z in [-0.24, 0.24]:
			_ball(cart, Vector3.ONE * 0.17, Vector3(x, -0.37, z), INK, "Caster")
