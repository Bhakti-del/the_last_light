class_name Hud
extends CanvasLayer


## All 2D interface: objective, notices, room titles, torch meter, journal,
## document reader, pause, title and death screens. Built in code so the scene
## file stays empty and the whole UI is one readable file.

signal resume_requested()
signal restart_requested()
signal title_finished()

const INK := Color(0.90, 0.87, 0.80)
const DIM := Color(0.62, 0.60, 0.56)
const PAPER := Color(0.86, 0.83, 0.75)
const WARN := Color(0.92, 0.55, 0.30)

## Kid mode scales every piece of interface text rather than shipping a second
## set of layouts: same screens, bigger words.
const KID_FONT_SCALE := 1.42
const BUTTON_SIZE := Vector2(280, 44)
const BUTTON_SIZE_KID := Vector2(340, 62)

const KEYS := "WASD move   SHIFT run   CTRL crouch   E interact   F torch   TAB journal   ESC pause"
## Kid mode leads with the arrow keys: no mouse needed, and one obvious verb per
## key. Crouch still matters (the creature hunts by what it hears), so it stays.
const KEYS_KID := "ARROW KEYS or WASD move   ARROW KEYS look   E use   F torch   CTRL hide   ESC pause"

var _root: Control
var _crosshair: Control
var _objective: Label
var _notice: Label
var _room_title: Label
var _torch_label: Label
var _torch_bar: ColorRect
var _torch_fill: ColorRect
var _keys_label: Label
var _kid_toggle: CheckButton
var _compass: Label

var _journal: PanelContainer
var _journal_list: VBoxContainer
var _reader: PanelContainer
var _reader_title: Label
var _reader_body: Label

var _pause: Control
var _title: Control
var _death: Control
var _end: Control
var _end_body: Label

## Every control whose font size is ours to scale, with the size it uses at 1x.
var _fonts: Array = []
var _buttons: Array[Button] = []
var _font_scale: float = 1.0

var _notice_time: float = 0.0
var _title_time: float = 0.0
var _journal_open: bool = false
var _reader_open: bool = false
var _pause_open: bool = false
var _active_overlay: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.notice.connect(show_notice)
	GameState.chapter_changed.connect(show_room_title)
	GameState.open_document.connect(open_reader)
	GameState.kid_mode_changed.connect(_on_kid_mode_changed)
	_on_objective_changed(GameState.objective)
	_on_kid_mode_changed(GameState.kid_mode)
	set_process(true)


func is_blocking() -> bool:
	return _active_overlay


# ============================================================ kid mode

## Registered instead of calling add_theme_font_size_override directly, so one
## multiplier can resize the whole interface at runtime.
func _font(node: Control, size: int) -> void:
	node.add_theme_font_size_override("font_size", size)
	_fonts.append([node, size])


func apply_kid_mode(on: bool) -> void:
	_font_scale = KID_FONT_SCALE if on else 1.0
	for f in _fonts:
		var node: Control = f[0]
		if is_instance_valid(node):
			node.add_theme_font_size_override("font_size", int(round(float(f[1]) * _font_scale)))
	for b in _buttons:
		if is_instance_valid(b):
			b.custom_minimum_size = BUTTON_SIZE_KID if on else BUTTON_SIZE
	_rebuild_crosshair(on)
	if _kid_toggle != null and is_instance_valid(_kid_toggle):
		_kid_toggle.set_pressed_no_signal(GameState.kid_mode)
		_kid_toggle.custom_minimum_size = Vector2(BUTTON_SIZE.x, 40.0 * _font_scale)
	if _keys_label != null and is_instance_valid(_keys_label):
		_keys_label.text = KEYS_KID if on else KEYS
	if _journal_open:
		_rebuild_journal()


func _on_kid_mode_changed(on: bool) -> void:
	apply_kid_mode(on)


func _rebuild_crosshair(kid: bool) -> void:
	if _crosshair == null or not is_instance_valid(_crosshair):
		return
	for c in _crosshair.get_children():
		c.queue_free()
	var arm: float = 11.0 if kid else 7.0
	var thick: float = 2.0 if kid else 1.0
	for d in [Vector2(arm, thick), Vector2(thick, arm)]:
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.55 if kid else 0.42)
		r.size = d
		r.position = -d * 0.5
		_crosshair.add_child(r)



# ============================================================ construction

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_crosshair()
	_build_objective()
	_build_torch()
	_build_notice()
	_build_compass()
	_build_room_title()
	_build_journal()
	_build_reader()
	_build_title()
	_build_pause()
	_build_death()
	_build_end()


func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)
	_rebuild_crosshair(GameState.kid_mode)


func _build_objective() -> void:
	_objective = Label.new()
	_objective.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_objective.position = Vector2(30, 26)
	_font(_objective, 19)
	_objective.add_theme_color_override("font_color", INK)
	_objective.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_objective.add_theme_constant_override("outline_size", 6)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(520, 0)
	_objective.visible = false
	_root.add_child(_objective)


func _build_torch() -> void:
	_torch_label = Label.new()
	_torch_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_torch_label.position = Vector2(30, -46)
	_font(_torch_label, 15)
	_torch_label.add_theme_color_override("font_color", DIM)
	_torch_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_torch_label.add_theme_constant_override("outline_size", 5)
	_torch_label.text = "LIGHT"
	_torch_label.visible = false
	_root.add_child(_torch_label)


	_torch_bar = ColorRect.new()
	_torch_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_torch_bar.position = Vector2(30, -30)
	_torch_bar.size = Vector2(168, 7)
	_torch_bar.color = Color(0, 0, 0, 0.55)
	_torch_bar.visible = false
	_root.add_child(_torch_bar)

	_torch_fill = ColorRect.new()
	_torch_fill.position = Vector2(1, 1)
	_torch_fill.size = Vector2(166, 5)
	_torch_fill.color = PAPER
	_torch_bar.add_child(_torch_fill)


func _build_notice() -> void:
	_notice = Label.new()
	_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice.position = Vector2(0, -128)
	_notice.size = Vector2(0, 0)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_font(_notice, 21)
	_notice.add_theme_color_override("font_color", INK)
	_notice.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_notice.add_theme_constant_override("outline_size", 8)
	_notice.modulate.a = 0.0
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_notice)


func _build_room_title() -> void:
	_room_title = Label.new()
	_room_title.set_anchors_preset(Control.PRESET_CENTER)
	_room_title.position = Vector2(0, -160)
	_room_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_font(_room_title, 26)
	_room_title.add_theme_color_override("font_color", Color(0.80, 0.77, 0.70))
	_room_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_room_title.add_theme_constant_override("outline_size", 8)
	_room_title.modulate.a = 0.0
	_room_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_room_title)




func _build_compass() -> void:
	_compass = Label.new()
	_compass.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_compass.position = Vector2(-180, 26)
	_font(_compass, 15)
	_compass.add_theme_color_override("font_color", DIM)
	_compass.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_compass.add_theme_constant_override("outline_size", 5)
	_compass.text = "N  E  S  W"
	_compass.visible = true
	_root.add_child(_compass)


func _build_journal() -> void:
	_journal = _paper_panel()
	_journal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_journal.visible = false

	var head := Label.new()
	head.text = "HOUSE BOOK"
	_font(head, 30)
	head.add_theme_color_override("font_color", Color(0.14, 0.12, 0.11))
	_journal.add_child(head)

	var rule := ColorRect.new()
	rule.color = Color(0.16, 0.13, 0.12, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	_journal.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_journal.add_child(scroll)

	_journal_list = VBoxContainer.new()
	_journal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_list.add_theme_constant_override("separation", 18)
	scroll.add_child(_journal_list)

	var foot := Label.new()
	foot.text = "[TAB] close"
	_font(foot, 16)
	foot.add_theme_color_override("font_color", Color(0.35, 0.31, 0.28))
	_journal.add_child(foot)
	_root.add_child(_journal)


func _build_reader() -> void:
	_reader = _paper_panel()
	_reader.set_anchors_preset(Control.PRESET_CENTER)
	_reader.visible = false

	_reader_title = Label.new()
	_font(_reader_title, 24)
	_reader_title.add_theme_color_override("font_color", Color(0.13, 0.11, 0.10))
	_reader.add_child(_reader_title)

	var rule := ColorRect.new()
	rule.color = Color(0.16, 0.13, 0.12, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	_reader.add_child(rule)

	_reader_body = Label.new()
	_reader_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_font(_reader_body, 18)
	_reader_body.add_theme_color_override("font_color", Color(0.20, 0.17, 0.15))
	_reader_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader.add_child(_reader_body)

	var foot := Label.new()
	foot.text = "[E] / [ESC] put it down"
	_font(foot, 16)
	foot.add_theme_color_override("font_color", Color(0.35, 0.31, 0.28))
	_reader.add_child(foot)
	_root.add_child(_reader)


func _paper_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.90, 0.87, 0.79, 0.97)
	sb.border_color = Color(0.30, 0.25, 0.21, 0.85)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(34)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _build_title() -> void:
	_title = _dim_layer(0.90)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	_title.add_child(box)

	var t := Label.new()
	t.text = "THE LAST LIGHT"
	_font(t, 54)
	t.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	t.add_theme_constant_override("outline_size", 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	var s := Label.new()
	s.text = "light  ·  comic  ·  twist"
	_font(s, 19)
	s.add_theme_color_override("font_color", Color(0.66, 0.63, 0.58))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)

	var go := Label.new()
	go.name = "GoLabel"
	go.text = "press ENTER to wake up"
	_font(go, 18)
	go.add_theme_color_override("font_color", Color(0.82, 0.79, 0.72))
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(go)

	_keys_label = Label.new()
	_keys_label.text = KEYS
	_font(_keys_label, 15)
	_keys_label.add_theme_color_override("font_color", Color(0.52, 0.50, 0.46))
	_keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_keys_label)

	_root.add_child(_title)
	_title.visible = true


func _build_pause() -> void:
	_pause = _dim_layer(0.80)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_pause.add_child(box)

	var t := Label.new()
	t.text = "PAUSED"
	_font(t, 40)
	t.add_theme_color_override("font_color", Color(0.90, 0.87, 0.80))
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	t.add_theme_constant_override("outline_size", 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	box.add_child(_menu_button("Resume", func() -> void: resume_requested.emit()))

	# Off by default: the shipped game plays exactly as designed. Flipping this
	# takes effect immediately, mid-run, without restarting the attempt.
	_kid_toggle = CheckButton.new()
	_kid_toggle.text = "Kid mode"
	_font(_kid_toggle, 20)
	_kid_toggle.custom_minimum_size = Vector2(BUTTON_SIZE.x, 40.0)
	_kid_toggle.set_pressed_no_signal(GameState.kid_mode)
	_kid_toggle.tooltip_text = "Bigger text, arrow-key looking, longer reach, " \
		+ "a slower-draining torch, and puzzles that spell themselves out."
	_kid_toggle.toggled.connect(_on_kid_toggled)
	var kid_note := Label.new()
	kid_note.text = "kid mode: bigger text, easier puzzles, arrow keys to look"
	_font(kid_note, 14)
	kid_note.add_theme_color_override("font_color", Color(0.56, 0.54, 0.50))
	kid_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var kid_box := VBoxContainer.new()
	kid_box.add_theme_constant_override("separation", 2)
	kid_box.add_child(_kid_toggle)
	kid_box.add_child(kid_note)
	box.add_child(kid_box)

	box.add_child(_menu_button("Restart attempt", func() -> void: restart_requested.emit()))
	box.add_child(_menu_button("Quit", func() -> void: get_tree().quit()))

	_pause.visible = false
	_root.add_child(_pause)


func _on_kid_toggled(on: bool) -> void:
	GameState.set_kid_mode(on)


func _build_death() -> void:
	_death = _dim_layer(0.0)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_death.add_child(box)

	var t := Label.new()
	t.text = "IT FOUND YOU"
	_font(t, 46)
	t.add_theme_color_override("font_color", Color(0.80, 0.14, 0.10))
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	t.add_theme_constant_override("outline_size", 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	box.add_child(_menu_button("Wake up again", func() -> void: restart_requested.emit()))
	box.add_child(_menu_button("Quit", func() -> void: get_tree().quit()))
	_death.visible = false
	_root.add_child(_death)


func _build_end() -> void:
	_end = _dim_layer(0.97)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	_end.add_child(box)

	var t := Label.new()
	t.text = "OUT"
	_font(t, 50)
	t.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	t.add_theme_constant_override("outline_size", 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	_end_body = Label.new()
	_font(_end_body, 18)
	_end_body.add_theme_color_override("font_color", Color(0.72, 0.69, 0.63))
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_body)

	box.add_child(_menu_button("Begin again", func() -> void: restart_requested.emit()))
	box.add_child(_menu_button("Quit", func() -> void: get_tree().quit()))
	_end.visible = false
	_root.add_child(_end)


func _dim_layer(alpha: float) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.03, alpha)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	c.add_child(bg)
	return c


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	_font(b, 20)
	b.pressed.connect(cb)
	_buttons.append(b)
	return b


# ============================================================ live updates

func _on_objective_changed(text: String) -> void:
	_objective.text = ("▸  " + text) if text != "" else ""
	_objective.visible = text != ""


func show_notice(text: String, duration: float) -> void:
	_notice.text = text
	_notice_time = duration


func show_room_title(chapter: String) -> void:
	var title := str(Story.ROOM_TITLES.get(chapter, ""))
	if title == "":
		return
	_room_title.text = title
	_title_time = 2.6


func set_torch(battery: float, has_flashlight: bool) -> void:
	_torch_label.visible = has_flashlight
	_torch_bar.visible = has_flashlight
	if not has_flashlight:
		return
	var f := clampf(battery / 100.0, 0.0, 1.0)
	_torch_fill.size.x = 166.0 * f
	if battery <= 0.5:
		_torch_fill.color = Color(0.55, 0.12, 0.10)
	elif battery <= 25.0:
		_torch_fill.color = WARN
	else:
		_torch_fill.color = PAPER
	_torch_label.text = "LIGHT  %d%%" % int(round(battery))


func set_reticle_visible(on: bool) -> void:
	_crosshair.visible = on
	_objective.visible = on and _objective.text != ""
	_torch_label.visible = on and _torch_label.visible


func hide_hud(on: bool) -> void:
	_root.visible = not on


func _process(delta: float) -> void:
	if _notice_time > 0.0:
		_notice_time -= delta
		var a := clampf(_notice_time, 0.0, 1.0)
		_notice.modulate.a = a
	else:
		_notice.modulate.a = move_toward(_notice.modulate.a, 0.0, delta * 2.5)

	if _title_time > 0.0:
		_title_time -= delta
		_room_title.modulate.a = clampf(_title_time * 0.9, 0.0, 1.0)
	else:
		_room_title.modulate.a = move_toward(_room_title.modulate.a, 0.0, delta * 2.0)


	# Compass
	if _compass != null:
		var player = get_tree().get_first_node_in_group("player")
		if player == null:
			var scene = get_tree().current_scene
			player = scene.get_node_or_null("Player") if scene != null else null
		if player != null and is_instance_valid(player):
			var yaw = player.global_transform.basis.get_euler().y
			var deg = fmod(rad_to_deg(yaw), 360.0)
			if deg < 0.0: deg += 360.0
			# map to N=0, E=90 etc (standard)
			var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
			var idx = int(round(deg / 45.0)) % 8
			_compass.text = "%03d° %s" % [int(round(deg)) % 360, dirs[idx]]
			_compass.modulate.a = 0.95
	if _title.visible:
		var go := _title.find_child("GoLabel", true, false) as Label
		if go != null:
			go.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.003)


# ============================================================ overlays

func title_is_open() -> bool:
	return _title.visible


func dismiss_title() -> void:
	_title.visible = false
	title_finished.emit()
	_refresh_blocking()


func open_reader(title: String, body: String) -> void:
	_reader_title.text = title
	_reader_body.text = body
	_reader.visible = true
	_reader_open = true
	_refresh_blocking()


func close_reader() -> void:
	_reader.visible = false
	_reader_open = false
	_refresh_blocking()


func reader_is_open() -> bool:
	return _reader_open


func toggle_journal() -> void:
	_journal_open = not _journal_open
	_journal.visible = _journal_open
	if _journal_open:
		_rebuild_journal()
	_refresh_blocking()


func journal_is_open() -> bool:
	return _journal_open


func _rebuild_journal() -> void:
	for c in _journal_list.get_children():
		c.queue_free()
	if GameState.journal.is_empty():
		var none := Label.new()
		none.text = "Nothing written down yet."
		_font(none, 18)
		none.add_theme_color_override("font_color", Color(0.42, 0.38, 0.34))
		_journal_list.add_child(none)
		return
	for i in GameState.journal.size():
		var l := Label.new()
		l.text = GameState.journal[i]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_font(l, 18)
		l.add_theme_color_override("font_color", Color(0.20, 0.17, 0.15))
		l.custom_minimum_size = Vector2(820, 0)
		_journal_list.add_child(l)


func set_pause(on: bool) -> void:
	_pause_open = on
	_pause.visible = on
	_refresh_blocking()


func pause_is_open() -> bool:
	return _pause_open


func show_death() -> void:
	_death.visible = true
	_refresh_blocking()


func hide_death() -> void:
	_death.visible = false
	_refresh_blocking()


func show_end(true_ending: bool) -> void:
	_end.visible = true
	_end_body.text = ("You kept the light on the whole way.\nATTEMPT #47 is the last one you are allowed to count.\n\n"
		+ "THE LAST LIGHT\n\nThank you for playing.") if true_ending \
		else ("The house put you back.\nSomewhere a flashlight is still on a nightstand.\n\nTHE LAST LIGHT\n\nThank you for playing.")
	_refresh_blocking()


func hide_end() -> void:
	_end.visible = false
	_refresh_blocking()


func _refresh_blocking() -> void:
	_active_overlay = _title.visible or _pause_open or _death.visible or _end.visible
	set_reticle_visible(not _active_overlay and not _journal_open and not _reader_open)