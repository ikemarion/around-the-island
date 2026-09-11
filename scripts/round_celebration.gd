extends Control
## Local presentation, triggered once per completed round on every peer.
var result := ""
var age := 0.0
var pieces: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.position.y = 80
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = result
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color("fff1cf"))
	label.add_theme_color_override("font_outline_color", Color("184d48"))
	label.add_theme_constant_override("outline_size", 8)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 140:
		var left := i % 2 == 0
		pieces.append({"p":Vector2(0 if left else size.x,size.y*0.8), "v":Vector2(rng.randf_range(180,650)*(1 if left else -1),rng.randf_range(-850,-400)), "r":rng.randf_range(0,TAU), "c":[Color("ffca52"),Color("ff788a"),Color("56d8df"),Color("a88bea")][i%4]})

func _process(delta: float) -> void:
	age += delta
	if age > 7:
		queue_free()
		return
	modulate.a = minf(1.0,(7.0-age)/1.5)
	for piece in pieces:
		piece.v.y += 480*delta
		piece.p += piece.v*delta
		piece.r += delta*4
	queue_redraw()

func _draw() -> void:
	for piece in pieces:
		draw_set_transform(piece.p,piece.r)
		draw_rect(Rect2(-4,-7,8,14),piece.c)
	draw_set_transform(Vector2.ZERO)
