extends Node3D
## Approved Score Ribbons: visual-only, fed by existing authoritative match state.
const ART = preload("res://scripts/collectible_design.gd")
const RIBBON = preload("res://art/scoreboards/score-ribbon.glb")
const TIMER = preload("res://art/scoreboards/score-timer.glb")
const CROWN = preload("res://art/scoreboards/score-crown.glb")
const BAR_HEIGHT := 4.40
const BAR_BOTTOM := 1.99
const ROW_SPACING := 3.15
const VALUE_Y := 7.13
const CROWN_Y := 8.18
const TIMER_Y := 10.90
const INK := Color("184d43")
const CREAM := Color("fff1d1")
const LOCATIONS := [Vector3(0,5,-28), Vector3(0,5,28), Vector3(-52,5,0), Vector3(52,5,0)]

var displays: Array = []
var bold_font: FontVariation
var age := 0.0
var bar_body_mesh: CylinderMesh
var bar_cap_mesh: SphereMesh


func _ready() -> void:
	bold_font = FontVariation.new()
	bold_font.base_font = preload("res://art/fonts/Fredoka-Variable.ttf")
	# Integer OpenType tags avoid alias differences between text-server backends.
	bold_font.variation_opentype = {0x77676874:650.0,0x77647468:100.0}
	# Three shared pieces keep the fill's end caps round at every score, including zero.
	bar_body_mesh = CylinderMesh.new()
	bar_body_mesh.top_radius = 0.5
	bar_body_mesh.bottom_radius = 0.5
	bar_body_mesh.height = 1.0
	bar_body_mesh.radial_segments = 32
	bar_cap_mesh = SphereMesh.new()
	bar_cap_mesh.radius = 0.5
	bar_cap_mesh.height = 1.0
	bar_cap_mesh.radial_segments = 32
	bar_cap_mesh.rings = 16
	for location in LOCATIONS:
		var board := Node3D.new()
		add_child(board)
		board.position = location
		board.look_at(Vector3(0,5,0), Vector3.UP, true)
		board.scale = Vector3.ONE * 1.85
		var rows: Array = []
		for slot in 4:
			var row: Node3D = RIBBON.instantiate()
			row.name = "Ribbon%d" % (slot+1)
			board.add_child(row)
			var color: Color = get_parent().PLAYER_COLORS[slot].darkened(0.12)
			var enamel := ART.material(color, 0.36)
			var badge := _mesh(row, "PlayerBadge", bar_cap_mesh, Vector3(0,1.14,0.35), Vector3(1.69,1.69,0.46), enamel)
			var rim := _mesh(row, "BadgeRim", bar_cap_mesh, Vector3(0,1.14,0.25), Vector3(1.80,1.80,0.27), ART.material(color.lightened(0.3),0.32))
			# Fill lies inside the sculpted recess, not in front of the ribbon's face.
			var bar := Node3D.new()
			bar.name = "ScoreFill"
			row.add_child(bar)
			var body := _mesh(bar,"Body",bar_body_mesh,Vector3.ZERO,Vector3.ONE,enamel)
			var bottom := _mesh(bar,"Bottom",bar_cap_mesh,Vector3.ZERO,Vector3.ONE,enamel)
			var top := _mesh(bar,"Top",bar_cap_mesh,Vector3.ZERO,Vector3.ONE,enamel)
			var name_label := _label(row,Vector3(0,1.14,0.605),52,CREAM)
			name_label.outline_size = 4
			name_label.outline_modulate = color.darkened(0.36)
			var value := _label(row,Vector3(0,VALUE_Y,0.275),82,INK)
			rows.append({"node":row,"bar":bar,"body":body,"bottom":bottom,"top":top,
				"name":name_label,"value":value,"badge":badge,"rim":rim,"height":0.0,"target_height":0.0})
		var timer: Node3D = TIMER.instantiate()
		board.add_child(timer)
		timer.position.y = TIMER_Y
		var title := _label(timer,Vector3(0,0.28,0.355),146,INK)
		var subtitle := _label(timer,Vector3(0,-0.75,0.355),37,INK)
		var crown := Node3D.new()
		board.add_child(crown)
		var crown_model: Node3D = CROWN.instantiate()
		crown.add_child(crown_model)
		crown_model.scale = Vector3.ONE * 1.27
		crown_model.rotation = Vector3(0.12,0,-0.06)
		for mesh in crown_model.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var rays: Array[MeshInstance3D] = []
		var ray_material := ART.material(Color("ffdc78"),0.4)
		ray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for side in [-1,1]:
			for i in 2:
				var ray := _mesh(crown,"Sparkle",bar_cap_mesh,Vector3(side*(1.12+0.04*i),0.31+0.44*i,0.22),Vector3(0.32,0.085,0.09),ray_material)
				ray.rotation.z = side * (-0.25 if i == 0 else 0.65)
				rays.append(ray)
		displays.append({"node":board,"rows":rows,"crown":crown,"crown_model":crown_model,
			"rays":rays,"timer":timer,"title":title,"subtitle":subtitle,"initialized":false})
	refresh()


func _mesh(parent: Node3D, node_name: String, shape: Mesh, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = shape
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.position = at
	mesh.scale = size
	return mesh


func _label(parent: Node3D, at: Vector3, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font = bold_font
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = color
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(label)
	label.position = at
	return label


func _set_fill(row: Dictionary, height: float) -> void:
	row.height = height
	row.bar.visible = height > 0.001
	# Small early scores are a round sliver; never scale the entire ribbon or label.
	var cap_height := minf(0.86,height)
	var stem_height := maxf(0.001,height-cap_height)
	row.body.visible = height > cap_height + 0.001
	row.body.position = Vector3(0,BAR_BOTTOM+height*0.5,0.075)
	row.body.scale = Vector3(0.86,stem_height,0.29)
	row.bottom.position = Vector3(0,BAR_BOTTOM+cap_height*0.5,0.075)
	row.top.position = Vector3(0,BAR_BOTTOM+height-cap_height*0.5,0.075)
	row.bottom.scale = Vector3(0.86,maxf(0.001,cap_height),0.29)
	row.top.scale = row.bottom.scale


func _process(delta: float) -> void:
	if not visible:
		return
	age += delta
	for display in displays:
		for row in display.rows:
			_set_fill(row,lerpf(row.height,row.target_height,1.0-exp(-10.0*delta)))
		display.crown.position.y = CROWN_Y + sin(age*2.0)*0.07
		# A small rocking motion keeps the crown's silhouette readable from the front.
		display.crown_model.rotation.y = sin(age*0.75)*0.18
		for i in display.rays.size():
			display.rays[i].visible = sin(age*2.8+i*0.65) > -0.45


func refresh() -> void:
	var game = get_parent()
	visible = not game.lobby.visible
	var leader: int = game._leading_slot()
	var tied: bool = leader < 0 or not game.active_slots[leader]
	var active_count: int = game.active_slots.count(true)
	var highest := 0.0
	for slot in 4:
		if game.active_slots[slot]:
			highest = maxf(highest,game.scores[slot])
			if slot != leader and leader >= 0 and absf(game.scores[slot]-game.scores[leader]) < 0.01:
				tied = true
	# One shared relative scale makes early-round leads readable, with some headroom.
	# The countdown alone measures round progress; point totals remain exact tenths.
	var score_ceiling := maxf(20.0,highest*1.1)
	var seconds_left := maxi(0,ceili(game.time_remaining))
	var countdown := "%02d:%02d" % [seconds_left/60,seconds_left%60]
	for display in displays:
		display.title.text = countdown if game.round_running else "00:00"
		display.subtitle.text = "TIME LEFT" if game.round_running else "FINAL SCORES"
		var active_index := 0
		for slot in 4:
			var row: Dictionary = display.rows[slot]
			var was_active: bool = row.node.visible
			row.node.visible = game.active_slots[slot]
			if game.active_slots[slot]:
				row.node.position.x = (active_index-(active_count-1)*0.5)*ROW_SPACING
				active_index += 1
			row.target_height = clampf(game.scores[slot]/score_ceiling,0,1)*BAR_HEIGHT
			if not display.initialized or not was_active or game.scores[slot] <= 0.0:
				_set_fill(row,row.target_height)
			row.name.text = "YOU" if slot == game.local_slot else "P%d" % (slot+1)
			row.value.text = "%.1f" % maxf(0.0,game.scores[slot])
		display.crown.visible = not tied
		if not tied:
			display.crown.position = Vector3(display.rows[leader].node.position.x,CROWN_Y,0.18)
		display.initialized = true
