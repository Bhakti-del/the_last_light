class_name HidingSpot
extends Interactable
## Wardrobe, under the bed, behind the sofa. Breaks line of sight entirely.

var inside_offset := Vector3(0, 0, 0)
var stand_position := Vector3(0, 0, 0)
var view_limit := 1.15

var _furniture: Node3D


static func create(p_pos: Vector3, p_kind: String, p_exit: Vector3) -> HidingSpot:
	var h := HidingSpot.new()
	h.position = p_pos
	h.kind = p_kind
	h.stand_position = p_exit
	return h


var kind: String = "wardrobe"


func _ready() -> void:
	setup()
	match kind:
		"wardrobe": _build_wardrobe()
		"bed": _build_under_bed()
		"sofa": _build_behind_sofa()
		"crate": _build_crate()
		_: _build_wardrobe()
	_glow.light_color = Color(0.75, 0.85, 1.0)
	_glow_base_range = 1.2


## One solid collider matching the visible furniture, so the player cannot walk
## through the wardrobe and can stand exactly where the mesh is.
func _furniture_body(size: Vector3, offset: Vector3) -> void:
	Interactable.add_shape(self, size, offset)


func _build_wardrobe() -> void:
	var wood := Color(0.17, 0.12, 0.10)
	_furniture = Node3D.new()
	add_child(_furniture)
	var shell := Interactable.make_box(Vector3(1.20, 2.10, 0.58), Vector3(0, 1.05, 0), wood, 0.9)
	_furniture.add_child(shell)
	for s in [-1.0, 1.0]:
		var door := Interactable.make_box(Vector3(0.55, 1.95, 0.04),
			Vector3(0.30 * s, 1.05, 0.30), wood.lightened(0.05), 0.9)
		_furniture.add_child(door)
		var knob := Interactable.make_box(Vector3(0.05, 0.05, 0.05),
			Vector3(0.06 * s, 1.05, 0.33), Color(0.5, 0.44, 0.3), 0.35, 0.8)
		_furniture.add_child(knob)
	_furniture_body(Vector3(1.20, 2.10, 0.58), Vector3(0, 1.05, 0))
	inside_offset = Vector3(0, 0.2, 0)


func _build_under_bed() -> void:
	var wood := Color(0.16, 0.12, 0.11)
	_furniture = Node3D.new()
	add_child(_furniture)
	var frame := Interactable.make_box(Vector3(1.50, 0.30, 2.10), Vector3(0, 0.32, 0), wood, 0.9)
	_furniture.add_child(frame)
	var mattress := Interactable.make_box(Vector3(1.44, 0.22, 2.00), Vector3(0, 0.58, 0),
		Color(0.30, 0.28, 0.30), 0.95)
	_furniture.add_child(mattress)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := Interactable.make_box(Vector3(0.10, 0.18, 0.10),
				Vector3(0.68 * sx, 0.09, 0.98 * sz), wood, 0.9)
			_furniture.add_child(leg)
	_furniture_body(Vector3(1.50, 0.74, 2.10), Vector3(0, 0.37, 0))
	inside_offset = Vector3(0, 0.10, 0)


func _build_behind_sofa() -> void:
	var cloth := Color(0.20, 0.16, 0.18)
	_furniture = Node3D.new()
	add_child(_furniture)
	var seat := Interactable.make_box(Vector3(1.90, 0.40, 0.85), Vector3(0, 0.36, 0), cloth, 0.95)
	_furniture.add_child(seat)
	var back := Interactable.make_box(Vector3(1.90, 0.60, 0.22), Vector3(0, 0.78, -0.32), cloth, 0.95)
	_furniture.add_child(back)
	for sx in [-1.0, 1.0]:
		var arm := Interactable.make_box(Vector3(0.20, 0.34, 0.85), Vector3(0.85 * sx, 0.60, 0), cloth, 0.95)
		_furniture.add_child(arm)
	_furniture_body(Vector3(1.90, 0.80, 0.85), Vector3(0, 0.40, -0.10))
	# the player crouches in the gap behind the backrest
	inside_offset = Vector3(0, 0.12, 0.66)


func _build_crate() -> void:
	var wood := Color(0.24, 0.18, 0.13)
	_furniture = Node3D.new()
	add_child(_furniture)
	var box := Interactable.make_box(Vector3(0.95, 0.95, 0.95), Vector3(0, 0.475, 0), wood, 0.95)
	_furniture.add_child(box)
	for s in [-1.0, 1.0]:
		var slat := Interactable.make_box(Vector3(1.0, 0.08, 0.06),
			Vector3(0, 0.475 + 0.35 * s, 0.49), wood.lightened(0.06), 0.95)
		_furniture.add_child(slat)
	_furniture_body(Vector3(0.95, 0.95, 0.95), Vector3(0, 0.475, 0))
	inside_offset = Vector3(0, 0.2, 0)


## Where the player is placed when they leave the hiding place.
func hide_exit_position() -> Vector3:
	return stand_position


func can_interact(_player: Player) -> bool:
	# While hidden the only affordance is "leave", so the spot must stay usable.
	return enabled


func get_prompt(player: Player) -> String:
	if player != null and player.is_hidden:
		return "Leave hiding place"
	return "Hide"


func interact(player: Player) -> void:
	if player == null:
		return
	if player.is_hidden:
		player.exit_hide_spot()
		return
	player.enter_hide_spot(self)