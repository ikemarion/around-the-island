extends Node3D

# Presentation only: every peer reads the same scores as the island display.
const BAR_WIDTH := 10.0
var displays: Array = []

func _ready() -> void:
	for location in [Vector3(0, 9, -28), Vector3(0, 9, 28), Vector3(-32, 9, 0), Vector3(32, 9, 0)]:
		var board := Node3D.new()
		add_child(board)
		board.position = location
		board.look_at(Vector3(0, 9, 0), Vector3.UP, true)
		board.scale = Vector3.ONE * 1.8
		_quad(board, Vector2(17.4, 7.6), Vector3(0, 0, -0.04), Color(0.025, 0.09, 0.13, 0.78))
		_quad(board, Vector2(17.4, 0.035), Vector3(0, 3.8, 0), Color("65edc2"))
		var title := _label(board, Vector3(0, 2.8, 0.04), 76, Color("bcece9"))
		var rows: Array = []
		for slot in 4:
			var y := 1.35 - slot * 1.22
			var color: Color = get_parent().PLAYER_COLORS[slot]
			var row := Node3D.new()
			board.add_child(row)
			row.position.y = y
			_quad(row, Vector2(BAR_WIDTH, 0.52), Vector3(0, 0, 0), Color(0.16, 0.27, 0.32, 0.7))
			var bar := _quad(row, Vector2(1, 0.52), Vector3(-5, 0, 0.02), color)
			var name_label := _label(row, Vector3(-6.55, 0, 0.05), 64, color)
			var value := _label(row, Vector3(6.6, 0, 0.05), 60, color)
			rows.append({"node": row, "bar": bar, "name": name_label, "value": value})
		displays.append({"title": title, "rows": rows})

func _quad(parent: Node3D, dimensions: Vector2, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = dimensions
	mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.render_priority = -10
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.position = at
	return mesh

func _label(parent: Node3D, at: Vector3, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = color
	label.shaded = false
	label.render_priority = 5
	label.outline_size = 8
	label.no_depth_test = false
	parent.add_child(label)
	label.position = at
	return label

func refresh() -> void:
	var match_state = get_parent()
	visible = not match_state.lobby.visible
	var leader: int = match_state._leading_slot()
	var tied := false
	for slot in 4:
		if slot != leader and match_state.active_slots[slot] and absf(match_state.scores[slot] - match_state.scores[leader]) < 0.01:
			tied = true
	for display in displays:
		display.title.text = "SPARK TIME  /  %02ds LEFT" % ceili(match_state.time_remaining) if match_state.round_running else "FINAL SCORES"
		for slot in 4:
			var row: Dictionary = display.rows[slot]
			row.node.visible = match_state.active_slots[slot]
			var length := maxf(0.025, clampf(match_state.scores[slot] / match_state.ROUND_DURATION, 0, 1) * BAR_WIDTH)
			row.bar.scale.x = length
			row.bar.position.x = -BAR_WIDTH * 0.5 + length * 0.5
			row.name.text = "YOU" if slot == match_state.local_slot else "P%d" % (slot + 1)
			row.value.text = "%.1fs%s" % [match_state.scores[slot], " •" if slot == leader and not tied else ""]
