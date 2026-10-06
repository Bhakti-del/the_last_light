class_name RuneLock
extends Node3D
## THE LIGHT PUZZLE (Storage Room hatch).
##
## Three brass dials, four glyphs each. The correct order exists only on a comic
## panel that is invisible until the flashlight is pointed at it — so the puzzle
## is literally unsolvable in the dark. That is the whole thesis of the game in
## one interaction.

signal solved()

var dials: Array[int] = [0, 0, 0]
var solved_state: bool = false
var attempts: int = 0

var _plate: Node3D
var _dial_nodes: Array[Node3D] = []
var _glyph_nodes: Array[Sprite3D] = []
var _status: Label3D
var _kid_hint: Label3D
var _lever: Interactable
var _unlock_flag: String = "hatch_open"


static func create(p_pos: Vector3, p_yaw: float) -> RuneLock:
	var r := RuneLock.new()
	r.position = p_pos
	r.rotation.y = p_yaw
	return r


func _ready() -> void:
	_build()
	_kid_hint.visible = GameState.kid_mode and not GameState.has_flag(_unlock_flag)
	if GameState.has_flag(_unlock_flag):
		_set_solved_visuals()


func _build() -> void:
	_plate = Node3D.new()
	add_child(_plate)

	var brass := Color(0.42, 0.34, 0.18)
	var iron := Color(0.24, 0.24, 0.26)
	_plate.add_child(Interactable.make_box(Vector3(1.70, 0.90, 0.10), Vector3(0, 1.05, 0), iron, 0.55, 0.55))
	_plate.add_child(Interactable.make_box(Vector3(1.58, 0.78, 0.03), Vector3(0, 1.05, 0.06), brass, 0.4, 0.7))

	# three dials in a row
	var spacing := 0.44
	for i in 3:
		var x := (float(i) - 1.0) * spacing
		var dial := Dial.new()
		dial.position = Vector3(x, 1.05, 0.08)
		dial.index = i
		dial.lock = self
		_plate.add_child(dial)
		_dial_nodes.append(dial)

		var ring := Interactable.make_box(Vector3(0.34, 0.34, 0.04), Vector3(x, 1.05, 0.10),
			brass.lightened(0.10), 0.35, 0.8)
		_plate.add_child(ring)

		var g := Sprite3D.new()
		g.texture = ComicArt.glyph_texture("moon", 128)
		g.pixel_size = 0.22 / 128.0
		g.shaded = false
		g.position = Vector3(x, 1.05, 0.13)
		g.render_priority = 3
		_plate.add_child(g)
		_glyph_nodes.append(g)

		var idx := Label3D.new()
		idx.text = str(i + 1)
		idx.font_size = 26
		idx.outline_size = 8
		idx.modulate = Color(0.10, 0.09, 0.08)
		idx.shaded = false
		idx.pixel_size = 0.0022
		idx.position = Vector3(x, 0.72, 0.11)
		_plate.add_child(idx)

	# status readout
	_status = Label3D.new()
	_status.text = ""
	_status.font_size = 34
	_status.outline_size = 10
	_status.modulate = Color(1.0, 0.86, 0.55)
	_status.outline_modulate = Color(0.05, 0.04, 0.05)
	_status.shaded = false
	_status.pixel_size = 0.0026
	_status.position = Vector3(0, 1.42, 0.10)
	_plate.add_child(_status)

	# Kid mode writes the answer on the lock itself. Everywhere else the sequence
	# exists only on a comic panel that is invisible until the torch finds it,
	# which is the whole thesis of the game and not something to soften away.
	_kid_hint = Label3D.new()
	_kid_hint.text = "1  EYE     2  MOON     3  WAVE"
	_kid_hint.font_size = 40
	_kid_hint.outline_size = 12
	_kid_hint.modulate = Color(0.72, 0.95, 0.75)
	_kid_hint.outline_modulate = Color(0.04, 0.06, 0.04)
	_kid_hint.shaded = false
	_kid_hint.pixel_size = 0.0022
	_kid_hint.position = Vector3(0, 1.74, 0.10)
	_kid_hint.visible = false
	_plate.add_child(_kid_hint)

	# the lever
	_lever = Interactable.new()
	_lever.position = Vector3(0.74, 1.00, 0.10)
	_lever.prompt = "Pull the lever"
	_plate.add_child(_lever)
	var base := Interactable.make_box(Vector3(0.16, 0.34, 0.14), Vector3(0.74, 0.86, 0.10),
		iron, 0.5, 0.7)
	_plate.add_child(base)
	var arm := Interactable.make_box(Vector3(0.07, 0.36, 0.07), Vector3(0.74, 1.08, 0.16),
		brass.lightened(0.15), 0.35, 0.8)
	_plate.add_child(arm)
	Interactable.add_shape(_lever, Vector3(0.34, 0.44, 0.4), Vector3(0, 0.02, 0.08))
	_lever.interacted.connect(_on_lever)

	_refresh_glyphs()


func rotate_dial(index: int) -> void:
	if solved_state:
		return
	dials[index] = (dials[index] + 1) % Story.GLYPHS.size()
	Sfx.play_3d(&"dial", global_position, -7.0, randf_range(0.94, 1.08))
	_refresh_glyphs()


func _refresh_glyphs() -> void:
	for i in _glyph_nodes.size():
		var kind: String = Story.GLYPH_KINDS[dials[i]]
		_glyph_nodes[i].texture = ComicArt.glyph_texture(kind, 128)


func _on_lever(_by: Player) -> void:
	if solved_state:
		return
	attempts += 1
	Sfx.play_3d(&"lever", global_position, -5.0)
	var want: Array = Story.RUNE_SOLUTION
	var ok := true
	for i in 3:
		if Story.GLYPHS[dials[i]] != want[i]:
			ok = false
	if ok:
		_set_solved_visuals()
		GameState.set_flag(_unlock_flag)
		Sfx.play_2d(&"success", -4.0)
		GameState.push_notice("The hatch gives. Something below is unlocked.", 4.0)
		GameState.set_objective_key("basement")
		solved.emit()
	else:
		_status.text = "NOTHING HAPPENS"
		Sfx.play_2d(&"door_locked", -8.0, 0.85)
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(_status) and not solved_state:
			_status.text = ""


func _set_solved_visuals() -> void:
	solved_state = true
	_status.text = "OPEN"
	_status.modulate = Color(0.55, 1.0, 0.60)
	if _kid_hint != null and is_instance_valid(_kid_hint):
		_kid_hint.visible = false
	if _lever and is_instance_valid(_lever):
		_lever.prompt = "Unlocked"
		_lever.enabled = false
		_lever.lock_out()
		_lever.set_highlight(false)


## Kid mode: print the sequence on the lock. Toggled live from the pause menu.
func apply_kid_mode(on: bool) -> void:
	if _kid_hint != null and is_instance_valid(_kid_hint):
		_kid_hint.visible = on and not solved_state


func is_correct() -> bool:
	var want: Array = Story.RUNE_SOLUTION
	for i in 3:
		if Story.GLYPHS[dials[i]] != want[i]:
			return false
	return true


## One dial, one press. `Dial` is tiny on purpose: it is a button, not a prop.
class Dial extends Interactable:
	var index: int = 0
	var lock: RuneLock

	func _ready() -> void:
		prompt = "Turn dial %d" % (index + 1)
		collision_layer = 1 << 3
		collision_mask = 0
		var g := OmniLight3D.new()
		g.light_color = Color(1.0, 0.92, 0.72)
		g.light_energy = 0.0
		g.omni_range = 1.1
		g.shadow_enabled = false
		g.visible = false
		add_child(g)
		_glow = g
		_glow_base_range = 1.1
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(0.34, 0.34, 0.35)
		cs.shape = s
		add_child(cs)

	func interact(_player: Player) -> void:
		if lock != null:
			lock.rotate_dial(index)