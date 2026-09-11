extends Control
## Local-only presentation, driven by the replicated holder rather than input guesses.
var game: Node
var caption: Label
var detail: Label
var carrying := false
var previous_holder := -1
var change_time := 0.0
var age := 0.0
const GOLD := Color("ffda67")
const INK := Color("203b3b")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption = Label.new()
	detail = Label.new()
	for label in [caption, detail]:
		add_child(label)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 22)
	detail.add_theme_font_size_override("font_size", 14)

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	visible = not game.lobby.visible and not game.session_menu.visible
	age += delta
	change_time = maxf(0.0, change_time - delta)
	carrying = game.local_slot == game.token_holder
	if previous_holder != game.token_holder:
		change_time = 2.0 if previous_holder >= 0 else 0.0
		previous_holder = game.token_holder
	caption.text = "YOU HAVE THE SPARK" if carrying else "CHASE THE SPARK"
	detail.text = "KEEP MOVING • YOUR SCORE IS GROWING" if carrying else "PLAYER %d HAS IT • TAG THEM TO STEAL IT" % (game.token_holder + 1)
	if not game.round_running:
		detail.text = "ROUND COMPLETE"
	elif change_time > 0.0:
		detail.text = "SPARK ACQUIRED! KEEP IT AWAY FROM THEM" if carrying else "SPARK CHANGED HANDS — GET IT BACK!"
	caption.position = Vector2(size.x * 0.5 - 166, 24)
	caption.size = Vector2(354, 30)
	detail.position = Vector2(size.x * 0.5 - 220, 57)
	detail.size = Vector2(440, 24)
	caption.add_theme_color_override("font_color", INK if carrying else GOLD)
	detail.add_theme_color_override("font_color", INK if carrying else Color("fff0c4"))
	caption.add_theme_constant_override("outline_size", 0)
	detail.add_theme_constant_override("outline_size", 0)
	queue_redraw()

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GOLD if carrying else Color("203b3bee")
	style.border_color = Color("fff0c4")
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	draw_style_box(style, Rect2(size.x * 0.5 - 230, 16, 460, 72))
	var center := Vector2(size.x * 0.5 - 197, 40)
	var bolt := PackedVector2Array([Vector2(2,-15),Vector2(-10,2),Vector2(-1,2),Vector2(-5,16),Vector2(12,-3),Vector2(3,-3)])
	for index in bolt.size():
		bolt[index] += center
	draw_colored_polygon(bolt, INK if carrying else GOLD)
	if carrying:
		var color := GOLD
		color.a = 0.4 + 0.12 * sin(age * 2.0)
		for x in [18.0, size.x - 18.0]:
			var direction := 1.0 if x < size.x * 0.5 else -1.0
			for y in [110.0, size.y - 35.0]:
				var vertical := 1.0 if y < size.y * 0.5 else -1.0
				draw_polyline(PackedVector2Array([Vector2(x + direction * 60,y),Vector2(x,y),Vector2(x,y + vertical * 70)]), color, 5.0, true)
