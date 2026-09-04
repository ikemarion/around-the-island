extends Node3D
## Visual-only kit. No bodies, colliders, gameplay groups or network IDs.
const INK := Color("203b3b")
const CREAM := Color("fff0c4")
const TEAL := Color("488e85")
const ORANGE := Color("e8a047")
var game: Node
var horn: Node3D
var materials := {}

func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	materials[key] = mat
	return mat

func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material(color)
	parent.add_child(node)
	node.position = at
	return node

func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, at, color)

func ball(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 8
	var node := mesh(parent, shape, at, color)
	node.scale = size
	return node

func cylinder(parent: Node3D, bottom: float, top: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 20
	return mesh(parent, shape, at, color)

func _ready() -> void:
	game = get_parent()
	name = "CartoonArt"
	var env: Environment = game.get_node("WorldEnvironment").environment
	env.background_color = Color("a6d3cd")
	env.ambient_light_color = CREAM
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	game.get_node("DirectionalLight3D").light_energy = 0.65
	game.get_node("Arena/Floor/MeshInstance3D").material_override = material(Color("d4b87c"))
	# Tile seams are drawn into one shader, rather than hundreds of meshes.
	var tiles := ShaderMaterial.new()
	tiles.shader = preload("res://scripts/cartoon_tiles.gdshader")
	game.get_node("Arena/Floor/MeshInstance3D").material_override = tiles
	var island: Node3D = game.get_node("Arena/Island")
	island.get_node("MeshInstance3D").hide()
	box(island, Vector3(7.45,0.78,3.15),Vector3(0,-0.04,0),TEAL)
	box(island, Vector3(7.5,0.03,3.2),Vector3(0,0.37,0),INK)
	box(island, Vector3(7.5,0.09,3.2),Vector3(0,0.43,0),CREAM)
	box(island, Vector3(7.48,0.12,3.18),Vector3(0,-0.4,0),INK)
	for side in [-1,1]:
		for index in 6:
			var x := -3.1 + index*1.24
			box(island,Vector3(1.13,0.64,0.025),Vector3(x,-0.01,side*1.602),INK)
			box(island,Vector3(1.07,0.58,0.026),Vector3(x,-0.01,side*1.617),TEAL.lightened(0.08))
			box(island,Vector3(0.3,0.055,0.07),Vector3(x,0.19,side*1.645),CREAM)
	for wall_name in ["NorthWall","SouthWall","EastWall","WestWall"]:
		game.get_node("Arena/"+wall_name+"/MeshInstance3D").material_override = material(TEAL)
	for obstacle in get_tree().get_nodes_in_group("shoveable"):
		obstacle.get_node("MeshInstance3D").hide()
		var art := Node3D.new()
		art.name = "CartoonProp"
		obstacle.add_child(art)
		if "Chair" in String(obstacle.name): make_chair(art)
		else: make_box(art)
	for player in game.players: make_character(player)
	horn = Node3D.new()
	horn.name = "CartoonAirHorn"
	game.camera.add_child(horn)
	horn.position = Vector3(0.32,-0.26,-0.62)
	horn.scale = Vector3.ONE * 0.45
	make_horn(horn)
	for label in game.get_node("HUD").find_children("*", "Label", true, false):
		label.add_theme_color_override("font_outline_color", INK)
		label.add_theme_constant_override("outline_size", 4)

func make_chair(parent: Node3D) -> void:
	# Stay within the original 0.9m collision envelope, including the back.
	box(parent,Vector3(0.84,0.14,0.82),Vector3(0,-0.04,0),INK)
	box(parent,Vector3(0.79,0.1,0.77),Vector3(0,0.02,0),ORANGE)
	for x in [-0.32,0.32]:
		for z in [-0.3,0.3]:
			box(parent,Vector3(0.1,0.35,0.1),Vector3(x,-0.265,z),INK)
		box(parent,Vector3(0.08,0.37,0.08),Vector3(x,0.22,0.34),INK)
	box(parent,Vector3(0.84,0.31,0.11),Vector3(0,0.29,0.34),INK)
	box(parent,Vector3(0.75,0.24,0.035),Vector3(0,0.29,0.273),ORANGE)
	for x in [-0.2,0.2]: ball(parent,Vector3.ONE*0.045,Vector3(x,0.29,0.245),CREAM)

func make_box(parent: Node3D) -> void:
	box(parent,Vector3.ONE*0.9,Vector3.ZERO,INK)
	box(parent,Vector3(0.868,0.91,0.868),Vector3.ZERO,Color("c99651"))
	box(parent,Vector3(0.91,0.868,0.868),Vector3.ZERO,Color("dbae68"))
	box(parent,Vector3(0.868,0.868,0.91),Vector3.ZERO,Color("dbae68"))
	box(parent,Vector3(0.17,0.914,0.914),Vector3.ZERO,CREAM)
	for side in [-1,1]:
		box(parent,Vector3(0.22,0.06,0.008),Vector3(-0.23,-0.26,side*0.46),INK)
		box(parent,Vector3(0.045,0.2,0.008),Vector3(-0.23,-0.19,side*0.46),INK)

func make_character(player: ATIPlayer) -> void:
	var body: MeshInstance3D = player.body_mesh
	player.body_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	player.body_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://scripts/cartoon_outline.gdshader")
	player.body_material.next_pass = outline
	# Children of BodyMesh inherit facing, crouch, local hiding and invisibility.
	for side in [-1,1]:
		ball(body,Vector3(0.19,0.26,0.10),Vector3(side*0.16,0.26,0.412),CREAM)
		ball(body,Vector3(0.065,0.13,0.045),Vector3(side*0.16,0.25,0.472),INK)
		var brow := box(body,Vector3(0.2,0.045,0.055),Vector3(side*0.16,0.44,0.40),INK)
		brow.rotation.z = side * -0.16
		var hand := ball(body,Vector3(0.22,0.3,0.23),Vector3(side*0.47,-0.08,0),player.body_color)
		hand.material_override = player.body_material
		var shoe := ball(body,Vector3(0.29,0.19,0.39),Vector3(side*0.23,-0.7,0.10),INK)
		shoe.rotation.y = side*0.15
	ball(body,Vector3(0.25,0.19,0.07),Vector3(0,-0.05,0.454),INK)
	box(body,Vector3(0.15,0.055,0.025),Vector3(0,0.004,0.494),CREAM)

func make_horn(parent: Node3D) -> void:
	ball(parent,Vector3(0.42,0.58,0.4),Vector3(0,-0.08,0.12),Color("4298c3"))
	cylinder(parent,0.22,0.22,0.08,Vector3(0,0.16,0.12),CREAM)
	cylinder(parent,0.18,0.18,0.07,Vector3(0,0.25,0.12),INK)
	var bell := cylinder(parent,0.09,0.25,0.4,Vector3(0,0.2,-0.13),Color("ffed91"))
	bell.rotation.x = -PI/2
	var mouth := cylinder(parent,0.27,0.27,0.05,Vector3(0,0.2,-0.35),INK)
	mouth.rotation.x = PI/2
	var inner := cylinder(parent,0.21,0.21,0.055,Vector3(0,0.2,-0.38),Color("ff744d"))
	inner.rotation.x = PI/2
	ball(parent,Vector3(0.2,0.19,0.2),Vector3(0.16,0.3,0.08),Color("ff744d"))
	for side in [-1,1]: ball(parent,Vector3(0.065,0.12,0.045),Vector3(side*0.09,-0.05,-0.09),INK)

func _process(_delta: float) -> void:
	if not is_instance_valid(horn): return
	var player: ATIPlayer = game.players[game.local_slot]
	horn.visible = not game.lobby.visible and not game.session_menu.visible and game.camera.first_person_enabled and player.equipped_spawn_item == &"air_horn" and not is_instance_valid(player.held_chair) and player.remote_held_name.is_empty()
