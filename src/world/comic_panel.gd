class_name ComicPanel
extends Node3D
## A comic panel burnt into the wallpaper.
##
## Core theme fusion (COMIC + LIGHT): the panel is fully transparent until the
## player's flashlight cone lands on it. Walk away or switch the torch off and
## it fades back into the wall within a second — the player has to remember it,
## or open the journal.

const REVEAL_RANGE := 9.5
const FADE_IN := 7.0
const FADE_OUT := 2.2
const INK := Color(0.06, 0.05, 0.06)
const PAPER_INK_OUTLINE := Color(0.97, 0.95, 0.90)

var data: Dictionary = {}
var id: String = ""

var _reveal: float = 0.0
var _once: bool = false
var _quad: Sprite3D
## Untyped on purpose: the entries are Sprite3D / Label3D, which share `modulate`
## but have no common base class that declares it.
var _faders: Array = []
var light: Node3D = null


func setup(panel_data: Dictionary) -> void:
	data = panel_data
	id = str(panel_data.get("id", "panel"))
	var w: float = float(panel_data.get("w", 1.7))
	var h: float = float(panel_data.get("h", 1.25))
	var art := str(panel_data.get("art", "wall_panel"))
	var paper := str(panel_data.get("paper", "newsprint"))

	_quad = Sprite3D.new()
	_quad.texture = ComicArt.panel(paper, art, 384, 288, hash(id))
	_quad.pixel_size = w / 384.0
	_quad.shaded = false
	_quad.double_sided = false
	_quad.modulate = Color(1, 1, 1, 0)
	_quad.render_priority = 2
	add_child(_quad)
	_faders.append(_quad)

	var sfx_word := str(panel_data.get("sfx", ""))
	var caption := str(panel_data.get("caption", ""))
	var body := str(panel_data.get("text", ""))
	if body.contains("%d"):
		body = body % (46 + GameState.loops_completed)

	if sfx_word != "":
		_add_text(sfx_word, w * 0.9, h * 0.42, 96, Color(0.86, 0.10, 0.08),
			Color(1, 0.96, 0.86), Vector2(0.0, 0.0), 14.0)

	# text block sits in the lower two thirds, caption in a box at the top
	var top := h * 0.5
	if caption != "":
		var cap := _make_label(caption, 44, w * 0.84, h * 0.20)
		cap.position = Vector3(0.0, top - h * 0.13, 0.012)
		add_child(cap)
		_faders.append(cap)
		_rect_ink(w * 0.86, h * 0.15, Vector3(0.0, top - h * 0.13, 0.006))

	if body != "":
		var avail := h * (0.62 if caption != "" else 0.78)
		var lab := _make_label(body, 56, w * 0.84, avail)
		lab.position = Vector3(0.0, -h * 0.06 if caption != "" else 0.0, 0.012)
		add_child(lab)
		_faders.append(lab)

	if bool(panel_data.get("glyphs", false)):
		_add_glyph_sequence(w, h)

	set_process(true)


func _make_label(txt: String, font_size: int, target_w: float, max_h: float) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font_size = font_size
	l.outline_size = maxi(4, font_size / 6)
	l.modulate = Color(INK.r, INK.g, INK.b, 0.0)
	l.outline_modulate = Color(PAPER_INK_OUTLINE.r, PAPER_INK_OUTLINE.g, PAPER_INK_OUTLINE.b, 0.0)
	l.shaded = false
	l.double_sided = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.render_priority = 3

	var lines := txt.split("\n")
	var longest := 1
	for ln in lines:
		longest = maxi(longest, ln.length())
	var text_w: float = float(longest) * float(font_size) * 0.60
	var text_h: float = float(lines.size()) * float(font_size) * 1.30
	var ps: float = minf(target_w / maxf(text_w, 1.0), max_h / maxf(text_h, 1.0))
	l.pixel_size = ps
	l.position.z = 0.012
	return l


func _add_text(txt: String, target_w: float, target_h: float, font_size: int, col: Color, outline: Color, _off: Vector2, rot_deg: float) -> void:
	var l := Label3D.new()
	l.text = txt
	l.font_size = font_size
	l.outline_size = int(font_size * 0.16)
	l.modulate = Color(col.r, col.g, col.b, 0.0)
	l.outline_modulate = Color(outline.r, outline.g, outline.b, 0.0)
	l.shaded = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var wpx := float(txt.length()) * float(font_size) * 0.68
	l.pixel_size = minf(target_w / maxf(wpx, 1.0), target_h / (float(font_size) * 1.2))
	l.rotation_degrees.z = rot_deg
	l.render_priority = 4
	add_child(l)
	_faders.append(l)


## The hatch clue: three framed glyphs in the order the player must set.
func _add_glyph_sequence(panel_w: float, panel_h: float) -> void:
	var sol: Array = Story.RUNE_SOLUTION
	var cell := panel_w * 0.26
	var gap := cell * 1.16
	var total := gap * float(sol.size() - 1)
	for i in sol.size():
		var kind: String = Story.GLYPH_KINDS[Story.GLYPHS.find(str(sol[i]))]
		var x := -total * 0.5 + gap * float(i)
		var y := -panel_h * 0.30

		var frame := Sprite3D.new()
		frame.texture = ComicArt.glyph_texture(kind, 128)
		frame.pixel_size = cell / 128.0
		frame.shaded = false
		frame.modulate = Color(1, 1, 1, 0)
		frame.position = Vector3(x, y, 0.010)
		frame.render_priority = 3
		add_child(frame)
		_faders.append(frame)

		var nm := _make_label(sol[i], 34, cell * 0.98, panel_h * 0.09)
		nm.position = Vector3(x, y - cell * 0.72, 0.014)
		add_child(nm)
		_faders.append(nm)

		if i < sol.size() - 1:
			var arrow := _make_label(">", 40, cell * 0.30, panel_h * 0.10)
			arrow.position = Vector3(x + gap * 0.5, y, 0.014)
			add_child(arrow)
			_faders.append(arrow)


func _rect_ink(w: float, h: float, pos: Vector3) -> void:
	var r := Sprite3D.new()
	r.texture = _flat_ink(w, h)
	r.shaded = false
	r.modulate = Color(1, 1, 1, 0)
	r.position = pos
	r.render_priority = 1
	add_child(r)
	_faders.append(r)


func _flat_ink(w: float, h: float) -> ImageTexture:
	var iw := 64
	var ih := maxi(4, int(round(float(iw) * h / maxf(w, 0.01))))
	var img := Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.06, 0.05, 0.06, 0.92))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	var target := 0.0
	if light != null and is_instance_valid(light):
		var d := light.global_position.distance_to(global_position)
		if d < REVEAL_RANGE:
			target = light.cone_factor(global_position)
			target *= clampf(1.0 - (d / REVEAL_RANGE) * 0.45, 0.35, 1.0)

	var rate := FADE_IN if target > _reveal else FADE_OUT
	_reveal = move_toward(_reveal, target, rate * delta)
	if _reveal <= 0.001 and target <= 0.0:
		if _quad.modulate.a > 0.0:
			_apply_alpha(0.0)
		if _once:
			set_process(false)
		return

	_apply_alpha(clampf(_reveal, 0.0, 1.0))

	if _reveal > 0.55 and not _once:
		_once = true
		_on_first_read()


func _apply_alpha(a: float) -> void:
	for c in _faders:
		if is_instance_valid(c):
			var m: Color = c.modulate
			m.a = a
			c.modulate = m
			if c is Label3D:
				var om: Color = c.outline_modulate
				om.a = a
				c.outline_modulate = om


func _on_first_read() -> void:
	Sfx.play_3d(&"panel", global_position, -6.0)
	GameState.set_flag("panel_" + id)
	var j := str(data.get("journal", ""))
	if j != "":
		GameState.add_journal(j)
	GameState.flag_changed.emit("panel_read")