class_name ATIItemPickup
extends Area3D

signal collected

const INK := Color("203b3b")
const CREAM := Color("fff0c4")

@export var item_type: StringName = &"stun_gun"
@export var bob_height: float = 0.16
@export var bob_speed: float = 2.7
@export var spin_speed: float = 1.8

var base_height: float
var age: float = 0.0
var claimed: bool = false
var materials: Dictionary = {}


func configure(new_item_type: StringName, color: Color) -> void:
	item_type = new_item_type
	if has_node("Core"):
		for legacy_name in ["Core", "Ring", "FinA", "FinB"]:
			(get_node(legacy_name) as Node3D).hide()
		_build_item_art(color)
	if has_node("Glow"):
		(get_node("Glow") as OmniLight3D).light_color = color


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	result.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	result.roughness = 1.0
	result.emission_enabled = true
	result.emission = color.darkened(0.58)
	result.emission_energy_multiplier = 0.65
	materials[key] = result
	return result


func _mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color, node_name := "Piece") -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = node_name
	result.mesh = shape
	result.material_override = _material(color)
	parent.add_child(result)
	result.position = at
	return result


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, node_name := "Box") -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, at, color, node_name)


func _ball(parent: Node3D, size: Vector3, at: Vector3, color: Color, node_name := "Ball") -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 8
	var result := _mesh(parent, shape, at, color, node_name)
	result.scale = size
	return result


func _cylinder(parent: Node3D, bottom: float, top: float, height: float, at: Vector3, color: Color, node_name := "Cylinder") -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 18
	return _mesh(parent, shape, at, color, node_name)


func _torus(parent: Node3D, inner: float, outer: float, at: Vector3, color: Color, node_name := "Ring") -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = inner
	shape.outer_radius = outer
	shape.rings = 20
	shape.ring_segments = 8
	return _mesh(parent, shape, at, color, node_name)


func _build_item_art(color: Color) -> void:
	var previous := get_node_or_null("IconArt")
	if is_instance_valid(previous):
		previous.queue_free()
	var art := Node3D.new()
	art.name = "IconArt"
	art.set_meta("item_type", String(item_type))
	add_child(art)
	match item_type:
		&"air_horn": _make_air_horn(art, color)
		&"swap_bell": _make_bell(art, color)
		&"invisibility": _make_ghost(art, color)
		&"rewind_watch": _make_pocket_watch(art, color)
		&"emergency_door": _make_door(art, color)
		&"decoy_double": _make_decoys(art, color)
		&"magnet_mayhem": _make_magnet(art, color)
		&"pocket_wall": _make_wall(art, color)
		&"hot_potato": _make_potato(art, color)
		&"bungee_hook": _make_bungee(art, color)
		_: _ball(art, Vector3.ONE * 0.55, Vector3.ZERO, color, "Fallback")


func _make_ghost(art: Node3D, color: Color) -> void:
	_ball(art, Vector3(0.72, 0.72, 0.44), Vector3(0, 0.15, 0), color, "GhostBody")
	_box(art, Vector3(0.72, 0.38, 0.42), Vector3(0, -0.16, 0), color, "GhostRobe")
	for side in [-1.0, 0.0, 1.0]:
		_ball(art, Vector3(0.29, 0.28, 0.34), Vector3(side * 0.25, -0.38, 0), color, "GhostHem")
	for side in [-1.0, 1.0]:
		_ball(art, Vector3(0.12, 0.17, 0.08), Vector3(side * 0.17, 0.22, 0.23), INK, "GhostEye")
	_ball(art, Vector3(0.13, 0.10, 0.06), Vector3(0, 0.02, 0.24), INK, "GhostMouth")


func _make_pocket_watch(art: Node3D, color: Color) -> void:
	var body := _cylinder(art, 0.39, 0.39, 0.18, Vector3(0, -0.05, 0), INK, "WatchCase")
	body.rotation.x = PI / 2.0
	var face := _cylinder(art, 0.33, 0.33, 0.19, Vector3(0, -0.05, 0), CREAM, "WatchFace")
	face.rotation.x = PI / 2.0
	var hand_a := _box(art, Vector3(0.045, 0.25, 0.035), Vector3(0, 0.03, 0.11), color, "MinuteHand")
	hand_a.rotation.z = -0.55
	var hand_b := _box(art, Vector3(0.18, 0.045, 0.035), Vector3(0.07, -0.06, 0.112), color, "HourHand")
	hand_b.rotation.z = 0.2
	_cylinder(art, 0.11, 0.11, 0.14, Vector3(0, 0.38, 0), color, "WatchCrown")
	var loop := _torus(art, 0.105, 0.16, Vector3(0, 0.53, 0), color, "WatchLoop")
	loop.rotation.x = PI / 2.0


func _make_bell(art: Node3D, color: Color) -> void:
	_cylinder(art, 0.38, 0.15, 0.52, Vector3(0, -0.05, 0), color, "Bell")
	_cylinder(art, 0.41, 0.41, 0.08, Vector3(0, -0.32, 0), INK, "BellRim")
	_ball(art, Vector3.ONE * 0.16, Vector3(0, -0.43, 0), INK, "Clapper")
	_cylinder(art, 0.09, 0.09, 0.22, Vector3(0, 0.32, 0), INK, "HandleStem")
	_ball(art, Vector3(0.28, 0.18, 0.28), Vector3(0, 0.49, 0), color.lightened(0.22), "Handle")


func _make_air_horn(art: Node3D, color: Color) -> void:
	var can := _cylinder(art, 0.2, 0.2, 0.54, Vector3(-0.24, -0.12, 0), color, "HornCan")
	can.rotation.z = PI / 2.0
	var trumpet := _cylinder(art, 0.12, 0.37, 0.52, Vector3(0.24, 0.1, 0), CREAM, "HornTrumpet")
	trumpet.rotation.z = PI / 2.0
	var rim := _cylinder(art, 0.39, 0.39, 0.07, Vector3(0.51, 0.1, 0), INK, "HornRim")
	rim.rotation.z = PI / 2.0
	_box(art, Vector3(0.12, 0.18, 0.16), Vector3(-0.02, 0.22, 0), INK, "HornTrigger")


func _make_door(art: Node3D, color: Color) -> void:
	_box(art, Vector3(0.74, 1.02, 0.16), Vector3.ZERO, INK, "DoorFrame")
	_box(art, Vector3(0.61, 0.89, 0.18), Vector3(0, -0.02, 0), color, "Door")
	for y in [-0.24, 0.22]:
		_box(art, Vector3(0.42, 0.28, 0.025), Vector3(0, y, 0.105), color.darkened(0.16), "DoorPanel")
	_ball(art, Vector3.ONE * 0.10, Vector3(0.21, -0.02, 0.17), CREAM, "DoorKnob")


func _make_decoys(art: Node3D, color: Color) -> void:
	for side in [-1.0, 1.0]:
		_ball(art, Vector3(0.48, 0.58, 0.38), Vector3(side * 0.24, 0, 0), color, "Decoy")
		_ball(art, Vector3(0.09, 0.13, 0.06), Vector3(side * 0.24 - 0.09, 0.12, 0.21), INK, "DecoyEye")
		_ball(art, Vector3(0.09, 0.13, 0.06), Vector3(side * 0.24 + 0.09, 0.12, 0.21), INK, "DecoyEye")
	var equals_a := _box(art, Vector3(0.28, 0.045, 0.04), Vector3(0, 0.05, 0.33), CREAM, "Equals")
	equals_a.rotation.z = 0.05
	_box(art, Vector3(0.28, 0.045, 0.04), Vector3(0, -0.06, 0.33), CREAM, "Equals")


func _make_magnet(art: Node3D, color: Color) -> void:
	for side in [-1.0, 1.0]:
		_box(art, Vector3(0.25, 0.72, 0.25), Vector3(side * 0.27, 0.05, 0), color, "MagnetArm")
		_box(art, Vector3(0.27, 0.22, 0.27), Vector3(side * 0.27, 0.44, 0), CREAM, "MagnetPole")
	_box(art, Vector3(0.79, 0.25, 0.25), Vector3(0, -0.32, 0), color, "MagnetBridge")
	_ball(art, Vector3(0.3, 0.3, 0.3), Vector3(-0.27, -0.32, 0), color, "MagnetCurve")
	_ball(art, Vector3(0.3, 0.3, 0.3), Vector3(0.27, -0.32, 0), color, "MagnetCurve")


func _make_wall(art: Node3D, color: Color) -> void:
	for row in 3:
		var offset := 0.16 if row % 2 else 0.0
		for column in 3:
			var x := -0.34 + column * 0.34 + offset
			if x > 0.48:
				continue
			_box(art, Vector3(0.31, 0.24, 0.22), Vector3(x, -0.27 + row * 0.27, 0), color.lightened(row * 0.06), "Brick")


func _make_potato(art: Node3D, color: Color) -> void:
	var potato := _ball(art, Vector3(0.86, 0.64, 0.54), Vector3(0, -0.06, 0), color, "Potato")
	potato.rotation.z = -0.18
	for spot in [Vector3(-0.2, 0.08, 0.27), Vector3(0.19, -0.13, 0.27), Vector3(0.15, 0.19, 0.24)]:
		_ball(art, Vector3(0.07, 0.05, 0.035), spot, INK, "PotatoEye")
	var sprout_a := _cylinder(art, 0.035, 0.035, 0.32, Vector3(-0.08, 0.4, 0), Color("55df7a"), "Sprout")
	sprout_a.rotation.z = -0.38
	var sprout_b := _cylinder(art, 0.035, 0.035, 0.25, Vector3(0.08, 0.41, 0), Color("55df7a"), "Sprout")
	sprout_b.rotation.z = 0.48


func _make_bungee(art: Node3D, color: Color) -> void:
	var cord := _cylinder(art, 0.045, 0.045, 0.78, Vector3(-0.19, 0.15, 0), color, "BungeeCord")
	cord.rotation.z = -0.42
	_ball(art, Vector3.ONE * 0.09, Vector3(-0.36, 0.5, 0), CREAM, "CordCap")
	var hook_curve := _torus(art, 0.16, 0.25, Vector3(0.18, -0.24, 0), CREAM, "HookCurve")
	hook_curve.rotation.x = PI / 2.0
	_box(art, Vector3(0.16, 0.42, 0.14), Vector3(0.34, 0.03, 0), CREAM, "HookStem")


func _ready() -> void:
	base_height = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	age += delta
	rotation.y += spin_speed * delta
	position.y = base_height + sin(age * bob_speed) * bob_height


func _on_body_entered(body: Node3D) -> void:
	if claimed or not body.has_method("try_pickup_item"):
		return
	if body.try_pickup_item(item_type):
		claimed = true
		collected.emit()
		queue_free()
