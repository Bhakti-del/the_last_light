class_name ComicSequence
extends CanvasLayer
## The ending: a run of full-screen comic panels, one at a time.
##
## Uses the same `ComicArt` rasteriser as the in-world panels, so the final beat
## of the game looks like the thing the whole game has been about.

signal finished()

const SIZE := Vector2i(768, 576)

var _bg: ColorRect
var _frame: Control
var _art: TextureRect
var _caption: Label
var _text: Label
var _sfx: Label
var _hint: Label

var _specs: Array = []
var _index: int = -1
var _hold: float = 0.0
var _running: bool = false
var _time: float = 0.0
var _fade: float = 0.0


func _ready() -> void:
	layer = 20
	visible = false
	_build()
	set_process(false)


func _build() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.015, 0.014, 0.018)
	add_child(_bg)

	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.pivot_offset = Vector2(384, 288)
	add_child(_frame)

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.size = Vector2(SIZE)
	_art.position = Vector2(-384, -288)
	_art.anchor_left = 0.5
	_art.anchor_right = 0.5
	_art.anchor_top = 0.5
	_art.anchor_bottom = 0.5
	_art.offset_left = -384
	_art.offset_right = 384
	_art.offset_top = -288
	_art.offset_bottom = 288
	_frame.add_child(_art)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color(0.13, 0.11, 0.10))
	_caption.add_theme_color_override("font_outline_color", Color(0.95, 0.93, 0.87, 0.9))
	_caption.add_theme_constant_override("outline_size", 7)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.anchor_left = 0.5
	_caption.anchor_right = 0.5
	_caption.offset_left = -340
	_caption.offset_right = 340
	_caption.offset_top = -270
	_caption.offset_bottom = -180
	_frame.add_child(_caption)

	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 30)
	_text.add_theme_color_override("font_color", Color(0.11, 0.10, 0.10))
	_text.add_theme_color_override("font_outline_color", Color(0.95, 0.93, 0.87, 0.9))
	_text.add_theme_constant_override("outline_size", 7)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.anchor_left = 0.5
	_text.anchor_right = 0.5
	_text.offset_left = -340
	_text.offset_right = 340
	_text.offset_top = 40
	_text.offset_bottom = 250
	_frame.add_child(_text)

	_sfx = Label.new()
	_sfx.add_theme_font_size_override("font_size", 88)
	_sfx.add_theme_color_override("font_color", Color(0.80, 0.09, 0.07))
	_sfx.add_theme_color_override("font_outline_color", Color(0.97, 0.95, 0.90))
	_sfx.add_theme_constant_override("outline_size", 16)
	_sfx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sfx.anchor_left = 0.5
	_sfx.anchor_right = 0.5
	_sfx.offset_left = -400
	_sfx.offset_right = 400
	_sfx.offset_top = -120
	_sfx.offset_bottom = 40
	_sfx.visible = false
	_frame.add_child(_sfx)

	_hint = Label.new()
	_hint.text = "[SPACE] continue"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.55, 0.53, 0.49))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.offset_left = -200
	_hint.offset_right = 200
	_hint.offset_top = 300
	_hint.offset_bottom = 340
	_frame.add_child(_hint)


## `specs` is a list of dictionaries: art, paper, caption, text, sfx, hold, big.
func play(specs: Array) -> void:
	_specs = specs
	_index = -1
	_running = true
	visible = true
	_bg.modulate.a = 0.0
	_frame.modulate.a = 0.0
	_frame.scale = Vector2(1.06, 1.06)
	_fade = 0.0
	set_process(true)
	_advance()


func stop() -> void:
	_running = false
	visible = false
	set_process(false)


func is_running() -> bool:
	return _running


func _advance() -> void:
	_index += 1
	if _index >= _specs.size():
		_running = false
		visible = false
		set_process(false)
		finished.emit()
		return

	var spec: Dictionary = _specs[_index]
	_hold = float(spec.get("hold", 2.5))
	_art.texture = ComicArt.panel(str(spec.get("paper", "dark")), str(spec.get("art", "wall_panel")),
		SIZE.x, SIZE.y, hash(str(spec.get("caption", "")) + str(_index)))

	var cap := str(spec.get("caption", ""))
	var big := bool(spec.get("big", false))
	_caption.text = cap
	_caption.visible = cap != ""
	_caption.add_theme_font_size_override("font_size", 46 if big else 30)

	var body := str(spec.get("text", ""))
	_text.text = body
	_text.visible = body != ""
	_text.add_theme_font_size_override("font_size", 46 if big else 30)

	var word := str(spec.get("sfx", ""))
	_sfx.text = word
	_sfx.visible = word != ""

	_fade = 0.0
	if word != "":
		Sfx.play_2d(&"twist", -4.0)


func _process(delta: float) -> void:
	_bg.modulate.a = move_toward(_bg.modulate.a, 1.0, delta * 2.2)
	_frame.modulate.a = move_toward(_frame.modulate.a, 1.0, delta * 3.0)
	_frame.scale = _frame.scale.lerp(Vector2.ONE, clampf(delta * 5.0, 0.0, 1.0))

	if _fade < 0.45:
		_fade += delta
		return

	_time += delta
	if _time >= _hold or Input.is_action_just_pressed("skip") \
			or Input.is_action_just_pressed("interact"):
		_time = 0.0
		_fade = 0.0
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event.is_action_pressed("skip") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_time = _hold