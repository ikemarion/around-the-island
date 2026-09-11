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
const DESIGN = preload("res://scripts/collectible_design.gd")


func configure(new_item_type: StringName, color: Color) -> void:
	item_type = new_item_type
	if has_node("Core"):
		for legacy_name in ["Core", "Ring", "FinA", "FinB"]:
			(get_node(legacy_name) as Node3D).hide()
		_build_item_art(color)
	elif has_node("Body"):
		for legacy_name in ["Body", "Grip", "Charge"]:
			get_node(legacy_name).hide()
		_build_item_art(color)
	if has_node("Glow"):
		(get_node("Glow") as OmniLight3D).light_color = color
		if item_type in [&"swap_bell", &"invisibility", &"rewind_watch", &"air_horn"]:
			$Glow.light_color = Color("ffd68a")
			$Glow.light_energy = 0.25
			spin_speed = 0.65
			bob_height = 0.09
			base_height = 1.03
			position.y = base_height


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	result.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	result.roughness = 0.48
	result.emission_enabled = false
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
	var shape := preload("res://scripts/cartoon_geometry.gd").rounded_box(size)
	return _mesh(parent, shape, at, color, node_name)


func _ball(parent: Node3D, size: Vector3, at: Vector3, color: Color, node_name := "Ball") -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 24
	shape.rings = 12
	var result := _mesh(parent, shape, at, color, node_name)
	result.scale = size
	return result


func _capsule(parent: Node3D, size: Vector3, at: Vector3, color: Color, node_name := "Capsule") -> MeshInstance3D:
	var shape := CapsuleMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 20
	shape.rings = 8
	var result := _mesh(parent, shape, at, color, node_name)
	result.scale = size
	return result


func _cylinder(parent: Node3D, bottom: float, top: float, height: float, at: Vector3, color: Color, node_name := "Cylinder") -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 24
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
		&"stun_gun": _make_stun_gun(art, color)
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


func _make_stun_gun(art: Node3D, color: Color) -> void:
	_capsule(art, Vector3(0.72, 0.32, 0.32), Vector3.ZERO, Color("488e85"), "RayBody").rotation.z = PI / 2.0
	_box(art, Vector3(0.2, 0.37, 0.22), Vector3(-0.16, -0.23, 0), INK, "Grip")
	for x in [0.2, 0.32, 0.44]:
		_torus(art, 0.11, 0.17, Vector3(x, 0, 0), CREAM, "Coil").rotation.z = PI / 2.0
	_ball(art, Vector3.ONE * 0.24, Vector3(0.5, 0, 0), color, "ChargedTip")
	_ball(art, Vector3(0.09, 0.09, 0.04), Vector3(-0.12, 0.05, 0.17), color, "ChargeLamp")

func _make_ghost(art: Node3D, _color: Color) -> void:
	var porcelain := Color("f6ead5")
	var sheet := _mesh(art, DESIGN.ghost_sheet(), Vector3.ZERO, porcelain, "GhostSheet")
	sheet.material_override = DESIGN.material(porcelain,0.65)
	for side in [-1.0,1.0]:
		var arm := _ball(art,Vector3(0.18,0.42,0.16),Vector3(side*0.36,-0.01,0),porcelain,"GhostArm")
		arm.rotation.z = side * -0.75
		_ball(art,Vector3(0.095,0.235,0.045),Vector3(side*0.13,0.23,0.214),INK,"GhostEye")


func _make_pocket_watch(art: Node3D, _color: Color) -> void:
	var gold := DESIGN.material(Color("eab13e"),0.28)
	gold.metallic = 0.3
	var case_mesh := DESIGN.piece(art,"WatchCase",[Vector2(0,-0.1),Vector2(0.34,-0.1),Vector2(0.41,-0.075),Vector2(0.45,-0.02),Vector2(0.45,0.045),Vector2(0.42,0.11),Vector2(0.36,0.14),Vector2(0.33,0.13),Vector2(0.33,0.085),Vector2(0,0.085)],gold)
	case_mesh.rotation.x = PI/2.0
	var face := _cylinder(art,0.345,0.345,0.015,Vector3(0,0,0.1),Color("f4e6c8"),"WatchFace")
	face.rotation.x = PI/2.0
	for index in 12:
		var angle := TAU * index/12.0
		var tick := _box(art,Vector3(0.025,0.065,0.018),Vector3(sin(angle)*0.282,cos(angle)*0.282,0.118),INK,"HourTick")
		tick.rotation.z = -angle
	for values in [Vector2(-0.8,0.17),Vector2(0.85,0.23)]:
		var hand := _box(art,Vector3(0.045,values.y,0.026),Vector3(-sin(values.x)*values.y*0.45,cos(values.x)*values.y*0.45,0.14),Color("377d72"),"ClockHand")
		hand.rotation.z = values.x
	_ball(art,Vector3(0.075,0.075,0.035),Vector3(0,0,0.16),INK,"HandPivot")
	var crown := _cylinder(art,0.09,0.09,0.14,Vector3(0,0.46,0),Color("eab13e"),"WindingCrown")
	crown.material_override = gold
	for index in 10:
		var angle := TAU * index/10.0
		_box(art,Vector3(0.018,0.09,0.018),Vector3(sin(angle)*0.09,0.46,cos(angle)*0.09),Color("c38c28"),"CrownRidge")
	var loop := _torus(art,0.105,0.157,Vector3(0,0.63,0),Color("377d72"),"WatchLoop")
	loop.rotation.x = PI/2.0
	art.rotation.z = -0.12


func _make_bell(art: Node3D, _color: Color) -> void:
	var design = preload("res://scripts/collectible_design.gd")
	var gold := design.material(Color("efae28"), 0.24)
	gold.metallic = 0.35
	design.piece(art,"BellDome",[Vector2(0,-0.28),Vector2(0.36,-0.28),Vector2(0.395,-0.25),Vector2(0.38,-0.15),Vector2(0.35,0.04),Vector2(0.31,0.19),Vector2(0.25,0.29),Vector2(0.16,0.35),Vector2(0.06,0.38),Vector2(0,0.38)],gold)
	design.piece(art,"BellLip",[Vector2(0.34,-0.30),Vector2(0.44,-0.31),Vector2(0.48,-0.28),Vector2(0.49,-0.24),Vector2(0.46,-0.20),Vector2(0.39,-0.18),Vector2(0.35,-0.22),Vector2(0.34,-0.30)],gold)
	design.piece(art,"BellButton",[Vector2(0,0.39),Vector2(0.09,0.39),Vector2(0.10,0.44),Vector2(0.15,0.45),Vector2(0.17,0.48),Vector2(0.16,0.53),Vector2(0.12,0.55),Vector2(0,0.55)],gold)
	for side in [-1.0, 1.0]:
		var eye := _ball(art, Vector3(0.09, 0.22, 0.045), Vector3(side * 0.14, 0.055, 0.316), INK, "BellEye")
		eye.rotation.x = -0.22
		eye.material_override = design.material(Color("263631"),0.28)
	var clapper := _ball(art, Vector3(0.20, 0.20, 0.20), Vector3(0, -0.34, 0), CREAM, "Clapper")
	clapper.material_override = gold
	art.rotation.z = -0.10
	for side in [-1.0, 1.0]:
		var star := MeshInstance3D.new()
		star.name = "Sparkle"
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points := [Vector3(0,0.12,0),Vector3(0.025,0.025,0),Vector3(0.08,0,0),Vector3(0.025,-0.025,0),Vector3(0,-0.12,0),Vector3(-0.025,-0.025,0),Vector3(-0.08,0,0),Vector3(-0.025,0.025,0)]
		for index in 8:
			for vertex in [Vector3.ZERO,points[index],points[(index+1)%8]]:
				surface.add_vertex(vertex)
		star.mesh = surface.commit()
		var sparkle_material := design.material(Color("ffe3a0"))
		sparkle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sparkle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sparkle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		star.material_override = sparkle_material
		star.position = Vector3(side * 0.59,0.24 if side > 0 else -0.07,0)
		art.add_child(star)


func _make_air_horn(art: Node3D, _color: Color) -> void:
	var coral := Color("df7856")
	var teal := Color("377d72")
	var can := DESIGN.piece(art,"HornCan",[Vector2(0,-0.49),Vector2(0.16,-0.49),Vector2(0.20,-0.46),Vector2(0.215,-0.4),Vector2(0.20,0.05),Vector2(0.16,0.12),Vector2(0,0.13)],DESIGN.material(coral,0.42))
	can.position.x = -0.22
	for y in [-0.46,0.09]:
		_torus(art,0.16,0.217,Vector3(-0.22,y,0),teal,"CanRim")
	_cylinder(art,0.09,0.09,0.16,Vector3(-0.22,0.2,0),teal,"Valve")
	_ball(art,Vector3(0.27,0.23,0.24),Vector3(-0.22,0.29,0),teal,"ValveElbow")
	var trumpet := DESIGN.piece(art,"HornTrumpet",[Vector2(0.08,0),Vector2(0.09,0.13),Vector2(0.12,0.25),Vector2(0.20,0.40),Vector2(0.31,0.52),Vector2(0.34,0.54),Vector2(0.35,0.57),Vector2(0.33,0.59),Vector2(0.30,0.57),Vector2(0.27,0.52),Vector2(0.17,0.39),Vector2(0.09,0.23),Vector2(0.055,0.1),Vector2(0.045,0)],DESIGN.material(Color("f0dfba"),0.36))
	trumpet.position = Vector3(-0.14,0.3,0)
	trumpet.rotation.z = -PI/2.0
	var band := _cylinder(art,0.13,0.13,0.10,Vector3(-0.06,0.3,0),coral,"HornCollar")
	band.rotation.z = -PI/2.0
	var badge := _cylinder(art,0.13,0.13,0.012,Vector3(-0.22,-0.18,0.207),CREAM,"CanBadge")
	badge.rotation.x = PI/2.0
	for offset in [Vector2(0.018,0),Vector2(0.055,0.035),Vector2(0.055,-0.025)]:
		_ball(art,Vector3(0.07,0.07,0.012),Vector3(-0.22+offset.x,-0.18+offset.y,0.22),teal,"GustBadge")
	for y in [-0.04,0.005,0.05]:
		_box(art,Vector3(0.08,0.017,0.012),Vector3(-0.255,-0.18+y,0.221),teal,"GustLines")


func _make_door(art: Node3D, color: Color) -> void:
	_capsule(art, Vector3(0.82, 1.12, 0.24), Vector3.ZERO, INK, "DoorFrame")
	_capsule(art, Vector3(0.67, 0.96, 0.25), Vector3(0, -0.02, 0), color, "Door")
	for y in [-0.24, 0.22]:
		_ball(art, Vector3(0.43, 0.23, 0.06), Vector3(0, y, 0.14), color.darkened(0.16), "DoorPanel")
	_ball(art, Vector3.ONE * 0.10, Vector3(0.21, -0.02, 0.17), CREAM, "DoorKnob")


func _make_decoys(art: Node3D, color: Color) -> void:
	for side in [-1.0, 1.0]:
		_ball(art, Vector3(0.48, 0.58, 0.38), Vector3(side * 0.24, 0, 0), color, "Decoy")
		_ball(art, Vector3(0.09, 0.13, 0.06), Vector3(side * 0.24 - 0.09, 0.12, 0.21), INK, "DecoyEye")
		_ball(art, Vector3(0.09, 0.13, 0.06), Vector3(side * 0.24 + 0.09, 0.12, 0.21), INK, "DecoyEye")
	var equals_a := _capsule(art, Vector3(0.05, 0.28, 0.05), Vector3(0, 0.05, 0.33), CREAM, "Equals")
	equals_a.rotation.z = PI / 2.0 + 0.05
	var equals_b := _capsule(art, Vector3(0.05, 0.28, 0.05), Vector3(0, -0.06, 0.33), CREAM, "Equals")
	equals_b.rotation.z = PI / 2.0


func _make_magnet(art: Node3D, color: Color) -> void:
	for side in [-1.0, 1.0]:
		_capsule(art, Vector3(0.27, 0.78, 0.27), Vector3(side * 0.27, 0.05, 0), color, "MagnetArm")
		_ball(art, Vector3(0.3, 0.25, 0.3), Vector3(side * 0.27, 0.44, 0), CREAM, "MagnetPole")
	_ball(art, Vector3(0.82, 0.3, 0.28), Vector3(0, -0.32, 0), color, "MagnetBridge")
	_ball(art, Vector3(0.3, 0.3, 0.3), Vector3(-0.27, -0.32, 0), color, "MagnetCurve")
	_ball(art, Vector3(0.3, 0.3, 0.3), Vector3(0.27, -0.32, 0), color, "MagnetCurve")


func _make_wall(art: Node3D, color: Color) -> void:
	for row in 3:
		var offset := 0.16 if row % 2 else 0.0
		for column in 3:
			var x := -0.34 + column * 0.34 + offset
			if x > 0.48:
				continue
			_ball(art, Vector3(0.33, 0.25, 0.23), Vector3(x, -0.27 + row * 0.27, 0), color.lightened(row * 0.06), "Brick")


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
	var hook_stem := _capsule(art, Vector3(0.14, 0.44, 0.14), Vector3(0.34, 0.03, 0), CREAM, "HookStem")
	hook_stem.rotation.z = -0.12


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
