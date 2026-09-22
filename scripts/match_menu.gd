extends CanvasLayer
## Presentation only; session ownership, pausing and input stay with the game.

func build(game: Node, menu_theme: Theme) -> void:
	layer = 12
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.85)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme = menu_theme
	var style: StyleBoxFlat = game.get_node("Lobby/Panel").get_theme_stylebox("panel").duplicate()
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -130
	panel.offset_bottom = 130
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var label := Label.new()
	label.text = "GAME MENU\nThe match keeps running."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var resume := Button.new()
	resume.name = "Resume"
	resume.text = "Resume"
	box.add_child(resume)
	resume.pressed.connect(func(): game._set_session_menu(false))
	var reports := Button.new()
	reports.text = "Connection reports"
	box.add_child(reports)
	reports.pressed.connect(game.network_diagnostics.open_reports)
	var leave := Button.new()
	leave.name = "Leave"
	box.add_child(leave)
	leave.pressed.connect(func(): game._enter_lobby("You left the room. Choose how to play."))
