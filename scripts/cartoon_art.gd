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
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.roughness = 0.72
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
	var shape := preload("res://scripts/cartoon_geometry.gd").rounded_box(size)
	return mesh(parent, shape, at, color)

func ball(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 24
	shape.rings = 12
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
	# Neutral fill lets cream/wood read as materials rather than yellow light.
	env.ambient_light_color = Color("e8edf0")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	game.get_node("DirectionalLight3D").light_color = Color("fff5e7")
	game.get_node("DirectionalLight3D").light_energy = 0.48
	game.get_node("Arena/Floor/MeshInstance3D").material_override = material(Color("d4b87c"))
	# Tile seams are drawn into one shader, rather than hundreds of meshes.
	var tiles := ShaderMaterial.new()
	tiles.shader = preload("res://scripts/cartoon_tiles.gdshader")
	game.get_node("Arena/Floor/MeshInstance3D").material_override = tiles
	var island: Node3D = game.get_node("Arena/Island")
	island.get_node("MeshInstance3D").hide()
	preload("res://scripts/kitchen_art.gd").make_island(island)
	for wall_name in ["NorthWall","SouthWall","EastWall","WestWall"]:
		for part in game.get_node("Arena/"+wall_name).find_children("*", "MeshInstance3D", true, false):
			part.material_override = material(Color("54847a"))
	preload("res://scripts/kitchen_art.gd").dress_boundaries(game.get_node("Arena"))
	for obstacle in get_tree().get_nodes_in_group("shoveable"):
		if obstacle.has_node("CartoonProp"):
			continue
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
	preload("res://scripts/kitchen_art.gd").make_chair(parent)

func make_box(parent: Node3D) -> void:
	preload("res://scripts/house_prop_art.gd").make_box(parent)

func make_character(player: ATIPlayer) -> void:
	# Keep BodyMesh as the visibility/facing/stance root, replacing its old capsule.
	player.body_mesh.mesh = null
	var character := preload("res://scripts/sockling_art.gd").new()
	character.actor = player
	player.body_mesh.add_child(character)

func make_horn(parent: Node3D) -> void:
	var model := Node3D.new()
	parent.add_child(model)
	model.rotation.y = PI/2.0
	model.position = Vector3(0,0,0.05)
	var builder := preload("res://scripts/item_pickup.gd").new()
	builder._make_air_horn(model, Color("df7856"))
	builder.free()

func _legacy_horn(parent: Node3D) -> void:
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
