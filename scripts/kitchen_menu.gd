extends VBoxContainer

const INK := Color("214f39")
const CREAM := Color("f7efd9")
const PAPER := Color("fffaf0")
const LINE := Color("b9bea4")
var game: Node
var controls: Dictionary
var seats: Array = []
var home_actions: VBoxContainer
var room_actions: VBoxContainer
var room_heading: Label
var room_hint: Label
var count_label: Label
var grid: GridContainer
var body: BoxContainer
var aside: VBoxContainer
var theme_resource: Theme

func build(main: Node, existing: Dictionary) -> void:
	game = main
	controls = existing
	theme_resource = _make_theme()
	theme = theme_resource
	game.get_node("Lobby/Panel").theme = theme_resource
	game.get_node("Lobby/Panel").add_theme_stylebox_override("panel", _style(CREAM, LINE, 16))
	game.get_node("Lobby/Shade").color = Color("e7e1cb")
	add_theme_constant_override("separation", 22)
	var header := HBoxContainer.new()
	add_child(header)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	_label(brand, "AROUND THE ISLAND", 15)
	_label(brand, "Kitchen club", 38)
	var greeting := _label(header, "PULL UP A CHAIR", 14)
	greeting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	greeting.text = "v" + game.BUILD_VERSION + " · PULL UP A CHAIR"
	var diagnostics := Button.new()
	diagnostics.text = "Connection reports"
	header.add_child(diagnostics)
	diagnostics.pressed.connect(game.network_diagnostics.open_reports)
	var privacy := Label.new()
	privacy.text = "Joining shares saved ATI connection reports with this host. No other files are sent."
	privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	privacy.add_theme_font_size_override("font_size",14)
	add_child(privacy)
	_line(self)
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	add_child(body)
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", 18)
	body.add_child(table)
	var table_header := HBoxContainer.new()
	table.add_child(table_header)
	_label(table_header, "Your table", 25).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label = _label(table_header, "", 14)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	table.add_child(grid)
	for slot in 4:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(115, 206)
		var style := _style(PAPER, LINE, 12)
		style.corner_radius_top_left = 48
		style.corner_radius_top_right = 48
		style.content_margin_bottom = 16
		card.add_theme_stylebox_override("panel", style)
		grid.add_child(card)
		var contents := VBoxContainer.new()
		card.add_child(contents)
		var portrait := preload("res://scripts/lobby_seat.gd").new()
		portrait.custom_minimum_size = Vector2(100, 140)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(portrait)
		var name_label := _label(contents, "", 17)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var role := _label(contents, "", 13)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seats.append({"portrait": portrait, "name": name_label, "role": role})
	_line(table)
	_take("Progress", table)
	controls.Progress.add_theme_color_override("font_color", INK)
	controls.Progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_take("Status", table)
	controls.Status.add_theme_color_override("font_color", Color("48634d"))
	controls.Status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	controls.Status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	controls.Status.custom_minimum_size = Vector2(0, 82)
	aside = VBoxContainer.new()
	aside.custom_minimum_size.x = 310
	aside.add_theme_constant_override("separation", 14)
	body.add_child(aside)
	room_heading = _label(aside, "", 27)
	room_hint = _label(aside, "", 14)
	room_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	home_actions = VBoxContainer.new()
	home_actions.add_theme_constant_override("separation", 10)
	aside.add_child(home_actions)
	_take("CodeInput", home_actions)
	controls.CodeInput.placeholder_text = "Friend's room address or code"
	_take("Host", home_actions)
	controls.Host.text = "Host lobby"
	_take("Join", home_actions)
	controls.Join.text = "Join lobby"
	_primary(controls.Join)
	_take("Solo", home_actions)
	controls.Solo.text = "Practice with a bot"
	room_actions = VBoxContainer.new()
	room_actions.add_theme_constant_override("separation", 12)
	aside.add_child(room_actions)
	_take("RoomCode", room_actions)
	controls.RoomCode.add_theme_color_override("font_color", INK)
	controls.RoomCode.add_theme_font_size_override("font_size", 18)
	controls.RoomCode.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_take("CopyCode", room_actions)
	controls.CopyCode.text = "Copy room address"
	_take("Start", room_actions)
	_primary(controls.Start)
	_take("Back", room_actions)
	_line(self)
	var footer := _label(self, "75 seconds. One spark. No manners.", 15)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", CREAM)
	var footer_style := _style(INK, INK, 8)
	footer_style.content_margin_top = 12
	footer_style.content_margin_bottom = 12
	footer.add_theme_stylebox_override("normal", footer_style)
	refresh()

func refresh() -> void:
	var home: bool = game.session_mode == &"lobby"
	var busy: bool = game.connection_started_ms != 0
	var hosting: bool = game.session_mode == &"hosting"
	var count: int = game.active_slots.count(true)
	home_actions.visible = home
	room_actions.visible = not home
	controls.CodeInput.visible = false
	controls.Join.visible = true
	controls.Join.disabled = busy or not home or game.instance_blocked
	controls.Host.disabled = game.instance_blocked or not game.can_host_default_lobby()
	controls.Host.text = "Host lobby" if game.can_host_default_lobby() else "Host: configured PC only"
	controls.Host.tooltip_text = "Open the lobby here. Stay in this window to play as Player 1."
	controls.Solo.disabled = game.instance_blocked
	controls.RoomCode.visible = not game.lobby_id.is_empty()
	controls.RoomCode.text = "LOBBY " + game.lobby_id
	controls.CopyCode.visible = false
	controls.Start.visible = not busy and (hosting or (game.session_mode == &"client" and game.waiting_for_start and game.round_epoch == 0))
	controls.Start.disabled = count < 2 or game.start_requested_ms != 0
	controls.Start.text = "Starting…" if game.start_requested_ms != 0 else ("Start match →" if count >= 2 else "Waiting for a friend")
	controls.Back.visible = not home
	controls.Back.text = "Cancel connection" if busy else ("Close lobby for everyone" if hosting else "Leave lobby")
	controls.Progress.visible = busy
	room_heading.text = "Play with friends" if home else ("Connecting…" if busy else ("You are hosting" if hosting else "You joined the lobby"))
	room_hint.text = "One host PC. Friends join its lobby. No codes or extra server windows." if home else ("You can cancel while we connect." if busy else "Anyone can start. Wait until your crew is here.")
	if game.instance_blocked:
		room_heading.text = "Already open"
		room_hint.text = "Close this duplicate window and use the existing ATI game."
	count_label.text = "Room for four" if home or game.session_mode == &"joining" else "%d / 4 seats filled" % count
	for slot in 4:
		var active: bool = (slot == 0) if home or game.session_mode == &"joining" else game.active_slots[slot]
		seats[slot].portrait.configure(active, game.PLAYER_COLORS[slot])
		seats[slot].name.text = ("You" if slot == game.local_slot else "Player %d" % (slot + 1)) if active else "Empty seat"
		seats[slot].role.text = ("Not connected" if home or game.session_mode == &"joining" else ("Host" if slot == 0 else "Connected")) if active else "Room for a friend"
	var width: float = game.get_viewport().get_visible_rect().size.x
	grid.columns = 4
	aside.custom_minimum_size.x = 260 if width < 950 else 310
	var panel: Control = game.get_node("Lobby/Panel")
	panel.size = Vector2(minf(1110, width - 40), 0)
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var fit_scale := minf(1.0, minf((viewport_size.x - 32) / panel.size.x, (viewport_size.y - 32) / panel.size.y))
	panel.scale = Vector2.ONE * fit_scale
	panel.position = (viewport_size - panel.size * fit_scale) * 0.5

func _take(key: String, destination: Node) -> void:
	controls[key].reparent(destination)
	controls[key].visible = true
	if controls[key] is Label:
		controls[key].add_theme_color_override("font_color", INK)
	if controls[key] is Button or controls[key] is LineEdit:
		controls[key].custom_minimum_size.y = 44

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _line(parent: Node) -> void:
	var line := HSeparator.new()
	parent.add_child(line)

func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _primary(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style := _style(INK if state == "normal" else Color("356849"), INK, 8)
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color, CREAM)

func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill := PAPER if state == "normal" else Color("e2e8d4")
		var style := _style(fill, LINE, 8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = INK
			style.set_border_width_all(2)
		result.set_stylebox(state, "Button", style)
		result.set_stylebox(state, "LineEdit", style)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(color, "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("77856e"))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", Color("647359"))
	result.set_color("caret_color", "LineEdit", INK)
	var separator := StyleBoxLine.new()
	separator.color = LINE
	result.set_stylebox("separator", "HSeparator", separator)
	return result
