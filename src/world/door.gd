class_name Door
extends Interactable
## A hinged door. Locked until a flag is set (usually a key pickup).

var locked: bool = false
var locked_flag: String = ""
var locked_prompt: String = "Locked."
var open_prompt: String = "Open"
var closed_prompt: String = "Close"
var swing_degrees: float = 96.0
var slam_on_close: bool = false

var is_open: bool = false
var _pivot: Node3D
var _leaf: MeshInstance3D
var _target_rot: float = 0.0
var _rest_y: float = 0.0


static func create(p_pos: Vector3, p_yaw: float, width: float = 1.1, height: float = 2.15) -> Door:
	var d := Door.new()
	d.position = p_pos
	d.rotation.y = p_yaw
	d._leaf_w = width
	d._leaf_h = height
	return d


var _leaf_w: float = 1.1
var _leaf_h: float = 2.15


func _ready() -> void:
	setup()
	_rest_y = position.y

	var pivot := Node3D.new()
	pivot.position = Vector3(-_leaf_w * 0.5, 0, 0)
	add_child(pivot)
	_pivot = pivot

	var leaf := Interactable.make_box(Vector3(_leaf_w, _leaf_h, 0.06), Vector3(_leaf_w * 0.5, _leaf_h * 0.5, 0),
		Color(0.19, 0.14, 0.12), 0.85)
	pivot.add_child(leaf)
	_leaf = leaf
	# panels
	for i in 2:
		var p := Interactable.make_box(Vector3(_leaf_w * 0.62, _leaf_h * 0.30, 0.02),
			Vector3(_leaf_w * 0.5, 0.42 + float(i) * 0.72, 0.04),
			Color(0.16, 0.12, 0.10), 0.85)
		pivot.add_child(p)
	var knob := Interactable.make_box(Vector3(0.07, 0.07, 0.07),
		Vector3(_leaf_w * 0.90, _leaf_h * 0.47, 0.07), Color(0.55, 0.48, 0.30), 0.3, 0.85)
	pivot.add_child(knob)

	# collision rides the pivot so the doorway actually clears when it swings
	var leaf_shape := CollisionShape3D.new()
	var leaf_bs := BoxShape3D.new()
	leaf_bs.size = Vector3(_leaf_w, _leaf_h, 0.12)
	leaf_shape.shape = leaf_bs
	leaf_shape.position = Vector3(_leaf_w * 0.5, _leaf_h * 0.5, 0)
	pivot.add_child(leaf_shape)

	# generous interaction volume in front of the leaf
	var wide := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(_leaf_w * 1.3, _leaf_h, 1.2)
	wide.shape = bs
	wide.position = Vector3(_leaf_w * 0.5, _leaf_h * 0.5, 0)
	pivot.add_child(wide)

	refresh_lock()
	# the key can be picked up after this door was built, so re-check the gate
	# whenever any flag changes rather than only at _ready
	GameState.flag_changed.connect(_on_flag_changed)


func _on_flag_changed(_key: String) -> void:
	refresh_lock()


func refresh_lock() -> void:
	if locked_flag != "":
		locked = not GameState.has_flag(locked_flag)
	if locked:
		prompt = locked_prompt
	else:
		prompt = open_prompt if not is_open else closed_prompt


func can_interact(_player: Player) -> bool:
	return enabled


func interact(player: Player) -> void:
	if locked:
		Sfx.play_3d(&"door_locked", global_position, -8.0)
		GameState.push_notice(locked_prompt, 2.2)
		return
	is_open = not is_open
	refresh_lock()
	interacted.emit(player)
	if is_open:
		Sfx.play_3d(&"door_open", global_position, -9.0)
		_target_rot = deg_to_rad(swing_degrees)
	else:
		_target_rot = 0.0
		if slam_on_close:
			Sfx.play_3d(&"door_locked", global_position, -12.0, 1.3)


func set_open(open: bool, silent: bool = true) -> void:
	is_open = open
	_target_rot = deg_to_rad(swing_degrees) if open else 0.0
	refresh_lock()
	if open and not silent:
		Sfx.play_3d(&"door_open", global_position, -9.0)


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, _target_rot, clampf(delta * 3.4, 0.0, 1.0))