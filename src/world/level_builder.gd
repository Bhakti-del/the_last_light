class_name LevelBuilder
extends Node3D
## Generates the entire house at runtime from LevelData: shells, doorway gaps,
## the basement stair, props, practical lights, comic panels, interactables and
## the creature navigation graph.

const FLOOR_THICK := 0.30
const CEIL_THICK := 0.22
const STAIR_STEPS := 20

## Position, colour, energy and range of every practical light in the house.
## Warm and dim: enough to walk by, not enough to stop caring about the torch.
const PRACTICALS := [
	{"pos": Vector3(4.2, 1.15, 0.45), "col": Color(1.00, 0.80, 0.54), "energy": 0.60, "range": 5.0},
	{"pos": Vector3(7.4, 2.35, 7.0), "col": Color(0.70, 0.80, 1.00), "energy": 0.34, "range": 7.0},
	{"pos": Vector3(11.9, 2.30, 4.0), "col": Color(0.90, 0.78, 0.60), "energy": 0.62, "range": 7.0},
	{"pos": Vector3(16.6, 2.40, 2.6), "col": Color(0.88, 0.76, 0.58), "energy": 0.40, "range": 5.5},
	{"pos": Vector3(20.0, 2.55, 3.4), "col": Color(1.00, 0.66, 0.32), "energy": 0.50, "range": 6.5},
	{"pos": Vector3(22.0, 1.10, 6.6), "col": Color(0.92, 0.80, 0.62), "energy": 0.34, "range": 4.5},
	{"pos": Vector3(7.0, 2.60, 12.5), "col": Color(0.90, 0.76, 0.58), "energy": 0.62, "range": 8.0},
	{"pos": Vector3(3.0, 2.50, 14.0), "col": Color(0.86, 0.74, 0.58), "energy": 0.40, "range": 6.0},
	{"pos": Vector3(19.5, 2.40, 12.4), "col": Color(0.95, 0.80, 0.60), "energy": 0.50, "range": 7.0},
	{"pos": Vector3(17.6, 2.45, 15.4), "col": Color(0.88, 0.76, 0.60), "energy": 0.38, "range": 5.5},
	{"pos": Vector3(20.0, -1.60, 4.0), "col": Color(1.00, 0.62, 0.28), "energy": 0.46, "range": 6.5},
	{"pos": Vector3(10.0, -1.50, 4.0), "col": Color(0.85, 0.72, 0.55), "energy": 0.38, "range": 6.5},
	{"pos": Vector3(19.0, -1.55, 3.6), "col": Color(0.82, 0.70, 0.56), "energy": 0.32, "range": 5.5},
]

var player: Player = null
var panels: Array[Node3D] = []
var front_door: Door = null
var back_door: Door = null
var rune_lock: RuneLock = null
var hatch_pivot: Node3D = null
var final_chair: Interactable = null
var practicals: Array = []

var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _hatch_cover_size := Vector3.ZERO
var _hatch_wired: bool = false
var _hinted: int = 0


func _ready() -> void:
	_rng.seed = 20240613


func build(p_player: Player) -> void:
	player = p_player
	_make_materials()
	_build_shells()
	_build_stairs()
	_build_doors()
	_build_rune_lock()
	_build_props()
	_build_practical_lights()
	_place_panels()
	_place_notes()
	_place_pickups()
	_place_hiding_spots()
	_build_zones()
	_build_nav()


# ============================================================ materials

func _mat(key: String, col: Color, rough: float, metal: float = 0.0, emis: float = 0.0, tex_scale: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emis
	if tex_scale > 0.0:
		m.albedo_texture = ComicArt.grime_texture(Color(1, 1, 1), 0.035, 1.5, hash(key))
		m.texture_repeat = true
		m.uv1_scale = Vector3(tex_scale, tex_scale, 1.0)
	_mats[key] = m
	return m


func _make_materials() -> void:
	_mat("floor_wood", Color(0.30, 0.21, 0.14), 0.72, 0.0, 0.0, 0.55)
	_mat("floor_concrete", Color(0.26, 0.26, 0.25), 0.94, 0.0, 0.0, 0.4)
	_mat("wall_plaster", Color(0.44, 0.40, 0.34), 0.95, 0.0, 0.0, 0.35)
	_mat("wall_paper", Color(0.36, 0.30, 0.26), 0.96, 0.0, 0.0, 0.30)
	_mat("wall_concrete", Color(0.24, 0.24, 0.23), 0.96, 0.0, 0.0, 0.35)
	_mat("ceiling", Color(0.28, 0.26, 0.24), 0.98, 0.0, 0.0, 0.3)
	_mat("trim", Color(0.20, 0.14, 0.11), 0.85)
	_mat("dark_wood", Color(0.16, 0.11, 0.08), 0.86)
	_mat("metal", Color(0.28, 0.29, 0.31), 0.42, 0.75)
	_mat("rust", Color(0.34, 0.20, 0.13), 0.72, 0.45)
	_mat("brass", Color(0.46, 0.36, 0.17), 0.35, 0.85)
	_mat("fabric", Color(0.22, 0.17, 0.19), 0.97)
	_mat("cloth_dark", Color(0.13, 0.12, 0.14), 0.98)
	_mat("paper", Color(0.80, 0.76, 0.66), 0.95)
	_mat("bulb", Color(1.0, 0.86, 0.60), 0.3, 0.0, 4.0)
	_mat("exit_green", Color(0.20, 0.95, 0.42), 0.4, 0.0, 3.0)


# ============================================================ primitives

func _box(size: Vector3, pos: Vector3, mat: String, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mats[mat]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if parent:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi


func _solid(size: Vector3, pos: Vector3, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 0
	body.collision_mask = 0
	body.position = pos
	if parent:
		parent.add_child(body)
	else:
		add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	return body


## A solid box: visible mesh + matching collider.
func _solidbox(size: Vector3, pos: Vector3, mat: String, parent: Node3D = null) -> StaticBody3D:
	var body := _solid(size, pos, parent)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mats[mat]
	body.add_child(mi)
	return body


static func subtract(rect: Rect2, hole: Rect2) -> Array:
	var out: Array = []
	if not rect.intersects(hole):
		return [rect]
	if hole.position.y > rect.position.y:
		out.append(Rect2(rect.position.x, rect.position.y, rect.size.x, hole.position.y - rect.position.y))
	if hole.end.y < rect.end.y:
		out.append(Rect2(rect.position.x, hole.end.y, rect.size.x, rect.end.y - hole.end.y))
	var my := maxf(rect.position.y, hole.position.y)
	var my2 := minf(rect.end.y, hole.end.y)
	if hole.position.x > rect.position.x:
		out.append(Rect2(rect.position.x, my, hole.position.x - rect.position.x, my2 - my))
	if hole.end.x < rect.end.x:
		out.append(Rect2(hole.end.x, my, rect.end.x - hole.end.x, my2 - my))
	return out


static func split_axis(a: float, b: float, holes: Array) -> Array:
	var cuts: Array = []
	var sorted: Array = holes.duplicate()
	sorted.sort_custom(func(p, q): return p[0] < q[0])
	var cursor := a
	for h in sorted:
		var s: float = maxf(h[0], a)
		var e: float = minf(h[1], b)
		if e <= s:
			continue
		if s > cursor:
			cuts.append(Vector2(cursor, s))
		cursor = maxf(cursor, e)
	if cursor < b:
		cuts.append(Vector2(cursor, b))
	return cuts


# ============================================================ shells

func _build_shells() -> void:
	# one slab for the whole ground floor, with the hatch cut out
	for r in subtract(Rect2(0, 0, 24, 8), LevelData.HATCH):
		_solidbox(Vector3(r.size.x, FLOOR_THICK, r.size.y),
			Vector3(r.position.x + r.size.x * 0.5, -FLOOR_THICK * 0.5, r.position.y + r.size.y * 0.5),
			"floor_wood")
		_slab_top(Vector3(r.size.x, 0.02, r.size.y),
			Vector3(r.position.x + r.size.x * 0.5, 0.011, r.position.y + r.size.y * 0.5), "floor_wood")

	for room in LevelData.ROOMS:
		if room == "basement":
			continue
		_build_room_shell(room)

	# basement
	var br: Rect2 = LevelData.rect_of("basement")
	var by := LevelData.floor_y("basement")
	_solidbox(Vector3(br.size.x, FLOOR_THICK, br.size.y),
		Vector3(br.position.x + br.size.x * 0.5, by - FLOOR_THICK * 0.5, br.position.y + br.size.y * 0.5),
		"floor_concrete")
	_build_walls("basement", "wall_concrete")
	_solidbox(Vector3(br.size.x, CEIL_THICK, br.size.y),
		Vector3(br.position.x + br.size.x * 0.5, by + LevelData.ceil_h("basement") + CEIL_THICK * 0.5,
			br.position.y + br.size.y * 0.5), "ceiling")


func _slab_top(size: Vector3, pos: Vector3, mat: String) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mats[mat]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_room_shell(room: String) -> void:
	var r: Rect2 = LevelData.rect_of(room)
	var y := LevelData.floor_y(room)
	var h := LevelData.ceil_h(room)
	var floor_mat: String = "floor_concrete" if LevelData.ROOMS[room]["floor"] == "concrete" else "floor_wood"

	if room == "storage":
		for piece in subtract(r, LevelData.HATCH):
			_solidbox(Vector3(piece.size.x, FLOOR_THICK, piece.size.y),
				Vector3(piece.position.x + piece.size.x * 0.5, -FLOOR_THICK * 0.5,
					piece.position.y + piece.size.y * 0.5), floor_mat)
	else:
		_solidbox(Vector3(r.size.x, FLOOR_THICK, r.size.y),
			Vector3(r.position.x + r.size.x * 0.5, -FLOOR_THICK * 0.5, r.position.y + r.size.y * 0.5),
			floor_mat)

	_solidbox(Vector3(r.size.x, CEIL_THICK, r.size.y),
		Vector3(r.position.x + r.size.x * 0.5, y + h + CEIL_THICK * 0.5, r.position.y + r.size.y * 0.5),
		"ceiling")
	_build_walls(room, "wall_paper" if LevelData.ROOMS[room]["floor"] == "wood" else "wall_concrete")


func _gaps_for(room: String, wall: String) -> Array:
	var out: Array = []
	for g in LevelData.GAPS:
		if g["a"] == room and g["wall"] == wall:
			out.append(Vector2(g["gap"].position.x, g["gap"].end.x))
	return out


func _build_walls(room: String, mat: String) -> void:
	var r: Rect2 = LevelData.rect_of(room)
	var y := LevelData.floor_y(room)
	var h := LevelData.ceil_h(room)
	var t := LevelData.WALL

	for seg in split_axis(r.position.x, r.end.x, _gaps_for(room, "N")):
		_solidbox(Vector3(seg.y - seg.x, h, t),
			Vector3((seg.x + seg.y) * 0.5, y + h * 0.5, r.position.y), mat)
	for seg in split_axis(r.position.x, r.end.x, _gaps_for(room, "S")):
		_solidbox(Vector3(seg.y - seg.x, h, t),
			Vector3((seg.x + seg.y) * 0.5, y + h * 0.5, r.end.y), mat)
	for seg in split_axis(r.position.y, r.end.y, _gaps_for(room, "W")):
		_solidbox(Vector3(t, h, seg.y - seg.x),
			Vector3(r.position.x, y + h * 0.5, (seg.x + seg.y) * 0.5), mat)
	for seg in split_axis(r.position.y, r.end.y, _gaps_for(room, "E")):
		_solidbox(Vector3(t, h, seg.y - seg.x),
			Vector3(r.end.x, y + h * 0.5, (seg.x + seg.y) * 0.5), mat)

	# lintels over every doorway, so the opening reads as a door and not a hole
	var lintel_y := LevelData.DOOR_H
	if lintel_y < h - 0.05:
		for g in _gaps_for(room, "N"):
			_solidbox(Vector3(g.y - g.x, h - lintel_y, t),
				Vector3((g.x + g.y) * 0.5, y + lintel_y + (h - lintel_y) * 0.5, r.position.y), mat)
		for g in _gaps_for(room, "S"):
			_solidbox(Vector3(g.y - g.x, h - lintel_y, t),
				Vector3((g.x + g.y) * 0.5, y + lintel_y + (h - lintel_y) * 0.5, r.end.y), mat)
		for g in _gaps_for(room, "W"):
			_solidbox(Vector3(t, h - lintel_y, g.y - g.x),
				Vector3(r.position.x, y + lintel_y + (h - lintel_y) * 0.5, (g.x + g.y) * 0.5), mat)
		for g in _gaps_for(room, "E"):
			_solidbox(Vector3(t, h - lintel_y, g.y - g.x),
				Vector3(r.end.x, y + lintel_y + (h - lintel_y) * 0.5, (g.x + g.y) * 0.5), mat)

	# skirting boards
	var trim_h := 0.12
	var sk: Array = [
		[Vector3(r.size.x + t, trim_h, 0.04), Vector3(r.position.x + r.size.x * 0.5, y + trim_h * 0.5, r.position.y + 0.02)],
		[Vector3(r.size.x + t, trim_h, 0.04), Vector3(r.position.x + r.size.x * 0.5, y + trim_h * 0.5, r.end.y - 0.02)],
		[Vector3(0.04, trim_h, r.size.y - t), Vector3(r.position.x + 0.02, y + trim_h * 0.5, r.position.y + r.size.y * 0.5)],
		[Vector3(0.04, trim_h, r.size.y - t), Vector3(r.end.x - 0.02, y + trim_h * 0.5, r.position.y + r.size.y * 0.5)],
	]
	for s in sk:
		var mi := _box(s[0], s[1], "trim")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ============================================================ basement stair

func _build_stairs() -> void:
	var h: Rect2 = LevelData.HATCH
	var y0 := 0.0
	var y1 := LevelData.BASEMENT_Y
	var run := h.size.y
	var drop := y0 - y1
	var rise := drop / float(STAIR_STEPS)
	var step_run := run / float(STAIR_STEPS)

	# --- visible nosings. The ramp below carries the player, so these are
	# thin caps whose top sits on the ramp surface at their own centre: the
	# uphill half buries itself in the ramp and the downhill half reads as a
	# stair lip.
	for i in STAIR_STEPS:
		var z := h.position.y + step_run * (float(i) + 0.5)
		var top := y0 - rise * (float(i) + 0.5)
		var mi := _box(Vector3(h.size.x - 0.16, 0.14, step_run + 0.01),
			Vector3(h.position.x + h.size.x * 0.5, top - 0.07, z),
			"metal" if i % 2 == 0 else "rust")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# --- the ramp collider. rotation.x is positive so the +Z (south) end drops.
	var mid_z := h.position.y + run * 0.5
	var length := Vector2(run, drop).length()
	var pitch := atan2(drop, run)
	var mid_y := (y0 + y1) * 0.5
	var ramp := _solid(Vector3(h.size.x - 0.16, 0.30, length),
		Vector3(h.position.x + h.size.x * 0.5, mid_y - 0.10, mid_z))
	ramp.rotation.x = pitch

	# stringers either side of the ramp, so you cannot slip beside it
	for sx in [-1.0, 1.0]:
		_solidbox(Vector3(0.12, 0.72, length),
			Vector3(h.position.x + h.size.x * 0.5 + sx * (h.size.x * 0.5 - 0.08), mid_y - 0.16, mid_z),
			"rust").rotation.x = pitch

	# --- rails follow the slope, with a post at each end
	var rail_h := 1.0
	for sx in [-1.0, 1.0]:
		var x := h.position.x + (0.06 if sx < 0.0 else h.size.x - 0.06)
		_solidbox(Vector3(0.08, 0.08, length), Vector3(x, mid_y + rail_h - 0.10, mid_z),
			"rust").rotation.x = pitch
		for s in [-1.0, 1.0]:
			# post: from the ramp surface up to the rail
			var pz := mid_z + (0.10 if s > 0.0 else -0.10) * length
			var py := mid_y - (0.10 if s > 0.0 else -0.10) * (drop / run)
			_solidbox(Vector3(0.08, rail_h, 0.08), Vector3(x, py + rail_h * 0.5, pz), "rust")

	# closed end (south) at floor level, so the only way down is from the north
	_solidbox(Vector3(h.size.x, rail_h, 0.10),
		Vector3(h.position.x + h.size.x * 0.5, y0 + rail_h * 0.5, h.end.y - 0.05), "rust")

	# --- the hatch cover. Hinged along its WEST edge and swung up against the
	# stairwell rail: a north-hinged cover this long (4.3 m) could not open without
	# punching through a 3.1 m ceiling.
	var cover_w := h.size.x - 0.10
	var cover_d := h.size.y - 0.10
	hatch_pivot = Node3D.new()
	hatch_pivot.position = Vector3(h.position.x + 0.05, y0 + 0.06, h.position.y + h.size.y * 0.5)
	add_child(hatch_pivot)
	_hatch_cover_size = Vector3(cover_w, 0.10, cover_d)
	var cover := _solid(_hatch_cover_size, Vector3(cover_w * 0.5, 0, 0), hatch_pivot)
	var cm := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = _hatch_cover_size
	cm.mesh = cb
	cm.material_override = _mats["metal"]
	cover.add_child(cm)
	for i in 3:
		_box(Vector3(cover_w - 0.08, 0.05, 0.07),
			Vector3(cover_w * 0.5, 0.07, -cover_d * 0.5 + 0.6 + float(i) * 1.6), "rust", hatch_pivot)

	if not _hatch_wired:
		_hatch_wired = true
		GameState.flag_changed.connect(_on_hatch_flag)
	_open_hatch()


## Swing the cover up against the west rail. `rotation.z` positive lifts +X to +Y.
func _open_hatch() -> void:
	if hatch_pivot == null:
		return
	var want := deg_to_rad(90.0) if GameState.has_flag("hatch_open") else 0.0
	hatch_pivot.rotation.z = want


func _on_hatch_flag(key: String) -> void:
	if key == "hatch_open":
		_open_hatch()


# ============================================================ doors

func _build_doors() -> void:
	var r: Rect2 = LevelData.rect_of("foyer")
	front_door = Door.create(Vector3(r.end.x - 0.06, 0.0, 12.4), -PI * 0.5, 1.25, 2.25)
	# No unlocking flag: the chain is on the far side, so this is a dead end and
	# the whole point of the back-room beat.
	front_door.locked = true
	front_door.locked_prompt = "Chained from the outside. It will not move."
	front_door.open_prompt = "Open the front door"
	front_door.swing_degrees = -104.0
	add_child(front_door)

	# EXIT sign + a little green practical
	var sign := _box(Vector3(0.10, 0.30, 0.72), Vector3(r.end.x - 0.24, 2.55, 12.4), "exit_green")
	sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_omni(Vector3(r.end.x - 0.6, 2.5, 12.4), Color(0.35, 1.0, 0.55), 1.0, 5.6)

	# the chain, visible on the leaf side
	for i in 3:
		_box(Vector3(0.06, 0.06, 0.62), Vector3(r.end.x - 0.24, 1.02 + float(i) * 0.20, 12.4), "metal")

	# boarded-over opening to the back room
	back_door = Door.create(Vector3(17.5, 0.0, 17.06), PI, 1.35, 2.3)
	back_door.locked = true
	back_door.locked_flag = "has_back_key"
	back_door.locked_prompt = "Boarded shut. Something behind it, maybe."
	back_door.open_prompt = "Push through"
	back_door.swing_degrees = 88.0
	add_child(back_door)
	for i in 3:
		var plank := _box(Vector3(1.6, 0.16, 0.05), Vector3(17.5, 0.5 + float(i) * 0.72, 17.02), "dark_wood")
		plank.rotation.z = deg_to_rad(_rng.randf_range(-7.0, 7.0))


# ============================================================ puzzle

func _build_rune_lock() -> void:
	rune_lock = RuneLock.create(Vector3(20.5, 0.0, 0.18), 0.0)
	add_child(rune_lock)
	rune_lock.solved.connect(_on_rune_solved)


func _on_rune_solved() -> void:
	Sfx.play_2d(&"sting", -6.0)
	GameState.push_notice("Something heavy shifts under the floor.", 3.4)


# ============================================================ props

func _build_props() -> void:
	_props_bedroom()
	_props_hallway()
	_props_storage()
	_props_living()
	_props_foyer()
	_props_basement()
	_props_final()


func _props_bedroom() -> void:
	# bed against the north-west corner
	_solidbox(Vector3(1.6, 0.34, 2.1), Vector3(2.6, 0.17, 2.0), "dark_wood")
	_box(Vector3(1.54, 0.24, 2.0), Vector3(2.6, 0.46, 2.0), "cloth_dark")
	_box(Vector3(1.54, 0.10, 0.7), Vector3(2.6, 0.60, 1.35), "fabric")
	_box(Vector3(0.9, 0.14, 0.5), Vector3(2.6, 0.63, 2.6), "paper")
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.10, 0.9, 0.10), Vector3(2.6 + 0.72 * sx, 0.45, 3.0), "dark_wood")
	# nightstand + the flashlight on it
	_solidbox(Vector3(0.52, 0.62, 0.46), Vector3(4.2, 0.31, 0.45), "dark_wood")
	_box(Vector3(0.46, 0.16, 0.03), Vector3(4.2, 0.44, 0.22), "trim")
	# wardrobe in the south-west
	_solidbox(Vector3(1.1, 2.05, 0.55), Vector3(1.1, 1.02, 7.3), "dark_wood")
	# broken lamp
	_box(Vector3(0.05, 0.9, 0.05), Vector3(4.2, 0.45, 0.45), "metal")
	_box(Vector3(0.34, 0.26, 0.34), Vector3(4.2, 1.02, 0.45), "paper")
	# scattered paper
	for i in 7:
		_box(Vector3(0.2, 0.004, 0.26),
			Vector3(_rng.randf_range(0.6, 8.2), 0.01, _rng.randf_range(0.7, 7.6)), "paper")


func _props_hallway() -> void:
	# runner rug
	_box(Vector3(1.7, 0.012, 6.6), Vector3(11.9, 0.012, 4.0), "fabric")
	# coat rack against the north wall, clear of both east-wall panels
	_solidbox(Vector3(0.10, 1.9, 0.10), Vector3(12.5, 0.95, 0.35), "dark_wood")
	_box(Vector3(0.9, 0.06, 0.06), Vector3(12.5, 1.82, 0.35), "dark_wood")
	_box(Vector3(0.30, 0.85, 0.22), Vector3(12.3, 1.35, 0.35), "cloth_dark")
	# picture frames on the west wall, all empty (the panel above z=5.5 has them covered)
	for z in [1.6, 5.0]:
		_box(Vector3(0.05, 0.55, 0.40), Vector3(9.2, 1.75, z), "dark_wood")
	# a chest at the south end
	_solidbox(Vector3(1.2, 0.7, 0.55), Vector3(10.4, 0.35, 7.3), "dark_wood")


func _props_storage() -> void:
	# shelving along the north wall, x 15.4 .. 18.0 — the rune lock at x=20.5 and
	# the clue panel on the east wall both need clear wall
	_solidbox(Vector3(2.6, 0.08, 0.62), Vector3(16.7, 0.50, 0.42), "dark_wood")
	_solidbox(Vector3(2.6, 0.08, 0.62), Vector3(16.7, 1.40, 0.42), "dark_wood")
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.08, 1.9, 0.62), Vector3(16.7 + 1.26 * sx, 0.95, 0.42), "dark_wood")
	for k in 6:
		for i in 2:
			_box(Vector3(0.30, 0.28, 0.30),
				Vector3(15.9 + float(k) * 0.36, 0.72 + float(i) * 0.9, 0.42), "rust" if k % 2 else "metal")
	# crates
	var crates := [Vector3(15.9, 0, 6.9), Vector3(17.1, 0, 7.2), Vector3(16.4, 0.95, 7.0)]
	for i in crates.size():
		var c: Vector3 = crates[i]
		var s := 0.9 if i < 2 else 0.7
		_solidbox(Vector3(s, s, s), Vector3(c.x, c.y + s * 0.5, c.z), "dark_wood")
	# workbench, away from the stairwell
	_solidbox(Vector3(2.2, 0.10, 0.72), Vector3(22.0, 0.90, 6.6), "dark_wood")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.09, 0.9, 0.09), Vector3(22.0 + 1.0 * sx, 0.45, 6.6 + 0.30 * sz), "dark_wood")
	# pipes on the ceiling
	for i in 2:
		_box(Vector3(0.14, 0.14, 8.0), Vector3(16.0 + float(i) * 6.4, 2.85, 4.0), "rust")


func _props_living() -> void:
	# (the sofa is built by the "behind the sofa" hiding spot further down)
	# coffee table + the ATTEMPT #01 log
	_solidbox(Vector3(1.2, 0.08, 0.66), Vector3(7.4, 0.46, 12.6), "dark_wood")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.07, 0.46, 0.07), Vector3(7.4 + 0.52 * sx, 0.23, 12.6 + 0.27 * sz), "dark_wood")
	# dead television
	_solidbox(Vector3(1.5, 0.55, 0.55), Vector3(11.0, 0.28, 9.2), "dark_wood")
	_box(Vector3(1.30, 0.78, 0.10), Vector3(11.0, 1.00, 9.28), "metal")
	# bookshelf with the ATTEMPT #17 log
	_solidbox(Vector3(1.1, 2.0, 0.34), Vector3(1.5, 1.0, 15.9), "dark_wood")
	for i in 4:
		_box(Vector3(1.02, 0.05, 0.30), Vector3(1.5, 0.28 + float(i) * 0.48, 15.9), "dark_wood")
		for k in 7:
			_box(Vector3(0.09, 0.30, 0.24),
				Vector3(1.06 + float(k) * 0.13, 0.46 + float(i) * 0.48, 15.9),
				"cloth_dark" if k % 3 else "rust")
	# dead floor lamp
	_box(Vector3(0.34, 0.03, 0.34), Vector3(13.4, 0.02, 15.6), "metal")
	_box(Vector3(0.05, 1.5, 0.05), Vector3(13.4, 0.75, 15.6), "metal")
	_box(Vector3(0.44, 0.34, 0.44), Vector3(13.4, 1.62, 15.6), "paper")
	# armchair
	_solidbox(Vector3(0.9, 0.42, 0.85), Vector3(9.0, 0.36, 15.6), "cloth_dark")
	_solidbox(Vector3(0.9, 0.62, 0.22), Vector3(9.0, 0.78, 16.0), "cloth_dark")
	# rug
	_box(Vector3(4.4, 0.012, 3.0), Vector3(6.0, 0.012, 13.4), "cloth_dark")


func _props_foyer() -> void:
	# shoe rack
	_solidbox(Vector3(1.4, 0.5, 0.4), Vector3(17.4, 0.25, 9.0), "dark_wood")
	# hall table + a dead plant
	_solidbox(Vector3(0.5, 0.8, 0.5), Vector3(22.4, 0.40, 9.6), "dark_wood")
	_box(Vector3(0.34, 0.5, 0.34), Vector3(22.4, 1.05, 9.6), "cloth_dark")
	# stairs-look-alike banister dividing the foyer from the final room
	_solidbox(Vector3(0.12, 1.0, 8.0), Vector3(15.6, 0.5, 12.5), "dark_wood")
	for i in 7:
		_box(Vector3(0.09, 0.9, 0.09), Vector3(15.6, 0.45, 9.0 + float(i) * 1.1), "dark_wood")
	# umbrella stand
	_solidbox(Vector3(0.3, 0.55, 0.3), Vector3(20.6, 0.27, 15.6), "metal")
	# grandfather clock, stopped — parked clear of the east-wall panel
	_solidbox(Vector3(0.5, 2.1, 0.32), Vector3(23.4, 1.05, 15.0), "dark_wood")
	_box(Vector3(0.34, 0.34, 0.04), Vector3(23.4, 1.86, 14.82), "paper")


func _props_basement() -> void:
	var y := LevelData.BASEMENT_Y
	# boiler
	_solidbox(Vector3(1.3, 1.9, 1.1), Vector3(4.6, y + 0.95, 5.9), "rust")
	_box(Vector3(0.9, 0.14, 0.9), Vector3(4.6, y + 1.95, 5.9), "metal")
	_box(Vector3(0.10, 1.6, 0.10), Vector3(4.6, y + 2.8, 6.3), "rust")
	# pipes along the ceiling
	for i in 3:
		_box(Vector3(0.16, 0.16, 5.6), Vector3(6.0 + float(i) * 5.5, y + 2.95, 4.0), "rust")
	# shelving along the north wall, x 14 .. 18
	for i in 2:
		_solidbox(Vector3(4.0, 0.08, 0.55), Vector3(16.0, y + 0.7 + float(i) * 0.8, 1.35), "dark_wood")
		for sx in [-1.0, 1.0]:
			_box(Vector3(0.08, 1.9, 0.55), Vector3(16.0 + 1.9 * sx, y + 0.95, 1.35), "dark_wood")
		for k in 8:
			_box(Vector3(0.28, 0.26, 0.30),
				Vector3(14.4 + float(k) * 0.44, y + 0.87 + float(i) * 0.8, 1.35), "metal" if k % 2 else "rust")
	# a crate for the ATTEMPT #32 house book
	_solidbox(Vector3(0.95, 1.0, 0.95), Vector3(4.2, y + 0.5, 2.4), "dark_wood")
	# cot
	_solidbox(Vector3(0.9, 0.10, 2.0), Vector3(8.2, y + 0.42, 4.6), "cloth_dark")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.08, 0.42, 0.08), Vector3(8.2 + 0.4 * sx, y + 0.21, 4.6 + 0.9 * sz), "metal")
	# crates and a rocking chair
	for i in 4:
		_solidbox(Vector3(0.85, 0.85, 0.85), Vector3(11.5 + float(i) * 0.95, y + 0.43, 5.9), "dark_wood")
	_solidbox(Vector3(0.55, 0.10, 0.55), Vector3(17.2, y + 0.45, 3.0), "dark_wood")
	_solidbox(Vector3(0.55, 0.6, 0.10), Vector3(17.2, y + 0.75, 3.26), "dark_wood")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.06, 0.45, 0.06), Vector3(17.2 + 0.24 * sx, y + 0.22, 3.0 + 0.24 * sz), "dark_wood")
	# chest where the key lives
	_solidbox(Vector3(1.1, 0.75, 0.6), Vector3(3.4, y + 0.375, 1.9), "dark_wood")


func _props_final() -> void:
	# a single chair in the middle of the room
	final_chair = Interactable.new()
	final_chair.position = Vector3(12.5, 0.0, 21.6)
	final_chair.prompt = "Sit in the chair"
	final_chair.interacted.connect(func(_p: Player) -> void:
		GameState.run_sequence.emit("final" if GameState.loops_completed == 0 else "true_ending"))
	add_child(final_chair)
	_box(Vector3(0.52, 0.08, 0.52), Vector3(0, 0.46, 0), "dark_wood", final_chair)
	_box(Vector3(0.52, 0.62, 0.08), Vector3(0, 0.76, 0.23), "dark_wood", final_chair)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.07, 0.46, 0.07), Vector3(0.22 * sx, 0.23, 0.22 * sz),
				"dark_wood", final_chair)
	Interactable.add_shape(final_chair, Vector3(0.7, 0.9, 0.7), Vector3(0, 0.45, 0))

	# a crate beside the chair, for the ATTEMPT #46 house book
	_solidbox(Vector3(0.70, 0.70, 0.70), Vector3(11.2, 0.35, 20.4), "dark_wood")

	# bare bulb on a flex
	_box(Vector3(0.03, 1.5, 0.03), Vector3(12.5, 2.55, 21.6), "metal")
	var bulb := _box(Vector3(0.11, 0.14, 0.11), Vector3(12.5, 1.76, 21.6), "bulb")
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_omni(Vector3(12.5, 1.7, 21.6), Color(1.0, 0.84, 0.58), 0.55, 7.5)

	# debris
	for i in 9:
		_box(Vector3(_rng.randf_range(0.15, 0.5), 0.03, _rng.randf_range(0.15, 0.5)),
			Vector3(_rng.randf_range(6.0, 19.0), 0.02, _rng.randf_range(17.8, 23.4)), "paper")


func _build_practical_lights() -> void:
	# One weak practical per room. The house is a horror set, but a player who
	# cannot make out the shape of the room they are standing in is not being
	# scared, they are being stuck — so every room gets a pool of dim warm light
	# to navigate by. The torch is still far brighter and still the only way to
	# read the comic panels.
	for p in PRACTICALS:
		_omni(p["pos"], p["col"], p["energy"], p["range"])


func _omni(pos: Vector3, col: Color, energy: float, range_m: float) -> void:
	var o := OmniLight3D.new()
	o.light_color = col
	o.light_energy = energy
	o.omni_range = range_m
	o.shadow_enabled = false
	o.position = pos
	add_child(o)
	practicals.append({"light": o, "energy": energy, "range": range_m})


## Kid mode lifts every practical. Kept as one call so the mood of the whole
## house is a single number to tune.
func set_light_mood(kid: bool) -> void:
	for p in practicals:
		var o: OmniLight3D = p["light"]
		if not is_instance_valid(o):
			continue
		o.light_energy = float(p["energy"]) * (1.5 if kid else 1.0)
		o.omni_range = float(p["range"]) * (1.18 if kid else 1.0)


# ============================================================ content

func _place_panels() -> void:
	for spec in Story.active_panels():
		var room := str(spec["room"])
		var wall := str(spec["wall"])
		var anchor: Array = LevelData.wall_anchor(room, wall, float(spec["at"]), float(spec["y"]))
		var panel := ComicPanel.new()
		add_child(panel)
		panel.position = anchor[0]
		panel.rotation.y = anchor[1]
		panel.setup(spec)
		panel.light = player.flashlight if player != null else null
		panels.append(panel)


func _place_notes() -> void:
	for spec in Story.NOTES:
		var accent := Color(0.82, 0.78, 0.68)
		if str(spec["room"]) == "basement":
			accent = Color(0.68, 0.66, 0.62)
		elif str(spec["room"]) == "final":
			accent = Color(0.74, 0.71, 0.70)
		var r := Readable.create(spec["pos"], spec, accent)
		add_child(r)


func _place_pickups() -> void:
	# the torch, waiting on the nightstand
	var torch := Pickup.create("flashlight", Vector3(4.2, 0.66, 0.45))
	torch.rotation_degrees = Vector3(0, 30, 0)
	add_child(torch)

	# five spare cells, one per room you will want light in
	add_child(Pickup.create("battery", Vector3(2.6, 0.59, 1.3)))		# on the bed
	add_child(Pickup.create("battery", Vector3(21.0, 0.97, 6.6)))		# storage workbench
	add_child(Pickup.create("battery", Vector3(17.85, -2.06, 1.4)))		# basement shelving
	add_child(Pickup.create("battery", Vector3(6.8, 0.52, 12.9)))		# living room table
	add_child(Pickup.create("battery", Vector3(17.4, 0.52, 9.0)))		# foyer shoe rack

	# the key, on top of the chest in the basement
	var key := Pickup.create("key", Vector3(3.4, -2.82, 1.9), "has_back_key")
	add_child(key)


func _place_hiding_spots() -> void:
	# Each spot is placed where nothing else is built, and its exit is a clear
	# patch of floor the player can be pushed back onto.
	add_child(HidingSpot.create(Vector3(6.4, 0.0, 1.15), "wardrobe", Vector3(6.4, 0.0, 2.1)))
	add_child(HidingSpot.create(Vector3(13.9, 0.0, 6.9), "wardrobe", Vector3(13.9, 0.0, 5.9)))
	add_child(HidingSpot.create(Vector3(3.4, 0.0, 12.4), "sofa", Vector3(3.4, 0.0, 10.9)))
	add_child(HidingSpot.create(Vector3(16.9, 0.0, 5.4), "crate", Vector3(16.9, 0.0, 6.5)))
	add_child(HidingSpot.create(Vector3(16.6, LevelData.BASEMENT_Y, 5.9), "crate",
		Vector3(16.6, LevelData.BASEMENT_Y, 4.8)))


func _build_zones() -> void:
	var z_bed := ZoneTrigger.room("bedroom", Vector3(9, 3, 8), Vector3(4.5, 0, 4.0))
	z_bed.objective_key = "wake"
	add_child(z_bed)

	var z_hall := ZoneTrigger.room("hallway", Vector3(6, 3, 8), Vector3(12, 0, 4.0), "explore")
	# fires on every entry so the room title tracks the player, but it must not
	# clobber the objective once the player has moved on to a later task
	# The hallway objective ("explore") gets overtaken by clearer ones later
	# (hatch, basement, key). Leaving it repeatable would overwrite a more
	# specific objective if the player loops back through the front hall.
	z_hall.once = true
	add_child(z_hall)

	var z_store := ZoneTrigger.room("storage", Vector3(9, 3.4, 8), Vector3(19.5, 0, 4.0), "runes")
	add_child(z_store)

	var z_living := ZoneTrigger.room("living", Vector3(15, 3.4, 9), Vector3(7.5, 0, 12.5), "return")
	add_child(z_living)

	var z_foyer := ZoneTrigger.room("foyer", Vector3(9, 3.4, 9), Vector3(19.5, 0, 12.5), "door")
	add_child(z_foyer)

	var z_base := ZoneTrigger.room("basement", Vector3(22, 3.4, 6), Vector3(12, LevelData.BASEMENT_Y, 4.0), "")
	add_child(z_base)

	var z_final := ZoneTrigger.room("final", Vector3(15, 3.6, 7), Vector3(12.5, 0, 20.5), "final")
	add_child(z_final)

	# --- scripted beats
	var encounter := ZoneTrigger.box(Vector3(11.9, 0, 4.0), Vector3(6, 3, 2.6))
	encounter.sting = &"growl_alert"
	encounter.sting_db = -3.0
	encounter.once = true
	encounter.subtitle = "Something moved somewhere else in the house."
	add_child(encounter)

	var down := ZoneTrigger.box(Vector3(20.0, 0, 1.9), Vector3(2.4, 3, 1.6))
	down.sting = &"twist"
	down.once = true
	add_child(down)


func _build_nav() -> void:
	NavGraph.clear()
	for entry in LevelData.NAV_POINTS:
		NavGraph.add_point(entry[0], entry[1])
	NavGraph.force_link(LevelData.STAIR_TOP, LevelData.STAIR_BOTTOM)
	NavGraph.rebuild()


# ============================================================ helpers

func repoint_panels(light: Flashlight) -> void:
	for p in panels:
		p.light = light


# ============================================================ kid mode

## Kid mode leaves a soft glow on everything you can pick up or press, so a
## small player can find the torch, the cells and the key without hunting for
## a silhouette in a dim room. Purely additive: the highlight light the
## interactor already casts still works on top of it.
func apply_kid_mode(on: bool) -> void:
	_hinted = _hint_tree(self, on)
	set_light_mood(on)
	if rune_lock != null and is_instance_valid(rune_lock):
		rune_lock.apply_kid_mode(on)


func _hint_tree(node: Node, on: bool) -> int:
	var n := 0
	for c in node.get_children():
		if c is Interactable:
			(c as Interactable).set_kid_hint(on)
			n += 1
		n += _hint_tree(c, on)
	return n


## How many interactables are currently carrying a kid-mode glow.
func hinted_count() -> int:
	return _hinted
