extends Node3D
## Ceramic score shelves. Presentation only; scores still come from match state.
const ART = preload("res://scripts/collectible_design.gd")
const GEO = preload("res://scripts/cartoon_geometry.gd")
const BAR_HEIGHT := 8.0
var displays: Array = []
var soft_mesh: ArrayMesh

func _ready() -> void:
	soft_mesh = ART.lathe([Vector2(0,-0.5),Vector2(0.3,-0.5),Vector2(0.41,-0.47),Vector2(0.48,-0.4),Vector2(0.5,-0.3),Vector2(0.5,0.3),Vector2(0.48,0.4),Vector2(0.41,0.47),Vector2(0.3,0.5),Vector2(0,0.5)])
	var cream := ART.material(Color("fff1cf"))
	var teal := ART.material(Color("267b70"))
	var gold := ART.material(Color("eeb849"), 0.25)
	gold.metallic = 0.4
	for location in [Vector3(0,9,-28), Vector3(0,9,28), Vector3(-52,9,0), Vector3(52,9,0)]:
		var board := Node3D.new()
		add_child(board)
		board.position = location
		board.look_at(Vector3(0,9,0), Vector3.UP, true)
		board.scale = Vector3.ONE * 1.8
		var shelf := _box(board, Vector3(13,0.9,2.1), Vector3(0,-0.5,0), cream)
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.5
		capsule.height = 6.2
		shelf.mesh = capsule
		shelf.rotation.z = PI*0.5
		shelf.scale = Vector3(0.9,2.1,2.1)
		_box(board, Vector3(13.1,0.16,2.15), Vector3(0,-0.93,0), gold)
		_box(board, Vector3(12.2,0.5,1.7), Vector3(0,-1.15,0), teal)
		for i in 9:
			var scallop := _box(board, Vector3(1.35,0.7,0.5), Vector3((i-4)*1.37,-1.15,0.85), teal)
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			scallop.mesh = sphere
			# Unit rounded mesh gives soft, glazed medallion-like scallops.
			scallop.rotation.z = 0.0
		var rows: Array = []
		for slot in 4:
			var row := Node3D.new()
			board.add_child(row)
			row.position.x = (slot-1.5)*3.0
			_box(row, Vector3(2.5,0.15,1.5), Vector3(0,0.02,0), gold)
			var bar := _box(row, Vector3(2.2,1,1.25), Vector3(0,0.6,0), ART.material(get_parent().PLAYER_COLORS[slot],0.23))
			bar.mesh = soft_mesh
			_box(row, Vector3(1.5,0.58,0.15), Vector3(0,-0.49,1.09), gold)
			_box(row, Vector3(1.36,0.46,0.13), Vector3(0,-0.49,1.18), cream)
			var badge := _label(row, Vector3(0,-0.49,1.27), 48)
			var value := _label(row, Vector3(0,1.5,0.15), 76)
			rows.append({"node":row,"bar":bar,"name":badge,"value":value})
		var crown = preload("res://scenes/winner_crown.tscn").instantiate()
		board.add_child(crown)
		crown.scale = Vector3.ONE * 2.2
		crown.spin_speed = 0.6
		var title := _label(board, Vector3(0,-2.05,0.1), 56)
		displays.append({"node":board,"rows":rows,"crown":crown,"title":title})

func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = GEO.rounded_box(Vector3.ONE)
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.position = at
	mesh.scale = size
	return mesh

func _label(parent: Node3D, at: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = Color("184d48")
	label.outline_modulate = Color("fff1cf")
	label.outline_size = 3
	label.shaded = false
	parent.add_child(label)
	label.position = at
	return label

func refresh() -> void:
	var game = get_parent()
	visible = not game.lobby.visible
	var leader: int = game._leading_slot()
	var tied := leader < 0
	if leader >= 0:
		for slot in 4:
			if slot != leader and game.active_slots[slot] and absf(game.scores[slot]-game.scores[leader]) < 0.01:
				tied = true
	for display in displays:
		display.title.text = "%02ds LEFT" % maxi(0, ceili(game.time_remaining)) if game.round_running else "FINAL SCORES"
		for slot in 4:
			var row: Dictionary = display.rows[slot]
			row.node.visible = game.active_slots[slot]
			var height := maxf(0.08, clampf(game.scores[slot]/game.ROUND_DURATION,0,1)*BAR_HEIGHT)
			row.bar.scale.y = height
			row.bar.position.y = 0.1 + height*0.5
			row.value.position.y = height + 0.65
			row.name.text = "YOU" if slot == game.local_slot else "P%d" % (slot+1)
			row.value.text = "%.1f" % game.scores[slot]
		display.crown.visible = not tied
		if not tied:
			var row: Dictionary = display.rows[leader]
			display.crown.position = Vector3(row.node.position.x,row.value.position.y+1.0,0)
