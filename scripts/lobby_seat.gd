extends Control

var occupied := false
var player_color := Color.WHITE

func configure(active: bool, tint: Color) -> void:
	if occupied != active or player_color != tint:
		occupied = active
		player_color = tint
		queue_redraw()

func _draw() -> void:
	var ink := Color("214f39")
	var center := size.x * 0.5
	if occupied:
		var body := StyleBoxFlat.new()
		body.bg_color = player_color
		body.border_color = ink
		body.set_border_width_all(2)
		body.set_corner_radius_all(18)
		draw_style_box(body, Rect2(center - 25, 63, 50, 67))
		draw_circle(Vector2(center, 42), 22, ink)
		draw_circle(Vector2(center, 42), 20, player_color)
		draw_circle(Vector2(center - 6, 40), 2.3, ink)
		draw_circle(Vector2(center + 6, 40), 2.3, ink)
		draw_line(Vector2(center - 5, 50), Vector2(center + 5, 50), ink, 2)
	else:
		var chair := Color("8c9e85")
		draw_style_box(_chair_style(chair), Rect2(center - 22, 44, 44, 37))
		draw_line(Vector2(center - 26, 86), Vector2(center + 26, 86), chair, 5)
		draw_line(Vector2(center - 20, 86), Vector2(center - 23, 115), chair, 4)
		draw_line(Vector2(center + 20, 86), Vector2(center + 23, 115), chair, 4)

func _chair_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	return style
