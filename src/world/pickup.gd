class_name Pickup
extends Interactable
## Flashlight, spare battery cells and keys.

var kind: String = "battery"
var item_id: String = ""
var label_text: String = ""
var spin: bool = true

var _pivot: Node3D


static func create(p_kind: String, p_pos: Vector3, p_item: String = "", p_label: String = "") -> Pickup:
	var p := Pickup.new()
	p.kind = p_kind
	p.position = p_pos
	p.item_id = p_item
	p.label_text = p_label if p_label != "" else p_kind.capitalize()
	p.prompt = "Take " + p.label_text.to_lower()
	return p


func _ready() -> void:
	# setup() first: the builders below tune the highlight light it creates
	setup()
	match kind:
		"flashlight": _build_flashlight()
		"battery": _build_battery()
		"key": _build_key()
		_: _build_battery()
	set_highlight(false)


func _build_flashlight() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var body := Interactable.make_box(Vector3(0.075, 0.075, 0.30), Vector3(0, 0.03, 0),
		Color(0.16, 0.17, 0.19), 0.55, 0.65)
	_pivot.add_child(body)
	var head := Interactable.make_box(Vector3(0.115, 0.115, 0.10), Vector3(0, 0.03, -0.19),
		Color(0.30, 0.30, 0.33), 0.45, 0.75)
	_pivot.add_child(head)
	var lens := Interactable.make_box(Vector3(0.085, 0.085, 0.02), Vector3(0, 0.03, -0.245),
		Color(0.95, 0.90, 0.72), 0.2, 0.0, 0.35)
	_pivot.add_child(lens)
	_pivot.rotation_degrees = Vector3(-14, 24, 0)
	Interactable.add_shape(self, Vector3(0.34, 0.26, 0.5), Vector3(0, 0.03, 0))
	_glow_base_range = 1.3


func _build_battery() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var shell := Interactable.make_box(Vector3(0.09, 0.16, 0.09), Vector3(0, 0.08, 0),
		Color(0.20, 0.26, 0.22), 0.5, 0.5)
	_pivot.add_child(shell)
	var cap := Interactable.make_box(Vector3(0.05, 0.035, 0.05), Vector3(0, 0.175, 0),
		Color(0.72, 0.66, 0.42), 0.35, 0.8)
	_pivot.add_child(cap)
	var glow := Interactable.make_box(Vector3(0.093, 0.02, 0.093), Vector3(0, 0.10, 0),
		Color(0.55, 0.95, 0.65), 0.3, 0.0, 1.4)
	_pivot.add_child(glow)
	Interactable.add_shape(self, Vector3(0.34, 0.34, 0.34), Vector3(0, 0.09, 0))
	_glow.light_color = Color(0.6, 1.0, 0.7)
	_glow_base_range = 1.1


func _build_key() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var iron := Color(0.42, 0.44, 0.47)
	var shaft := Interactable.make_box(Vector3(0.022, 0.022, 0.19), Vector3(0, 0.02, 0),
		iron, 0.35, 0.9)
	_pivot.add_child(shaft)
	var bow := Interactable.make_box(Vector3(0.075, 0.075, 0.022), Vector3(0, 0.02, -0.115),
		iron, 0.35, 0.9)
	_pivot.add_child(bow)
	var hole := Interactable.make_box(Vector3(0.035, 0.035, 0.03), Vector3(0, 0.02, -0.115),
		Color(0.05, 0.05, 0.06), 0.9, 0.0)
	_pivot.add_child(hole)
	for i in 2:
		var tooth := Interactable.make_box(Vector3(0.020, 0.055, 0.020),
			Vector3(0, -0.012, 0.070 + float(i) * 0.035), iron, 0.35, 0.9)
		_pivot.add_child(tooth)
	_pivot.rotation_degrees = Vector3(0, randf_range(0.0, 360.0), 90)
	Interactable.add_shape(self, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.02, 0))
	_glow.light_color = Color(0.85, 0.92, 1.0)


func _process(delta: float) -> void:
	if spin and _pivot:
		_pivot.rotate_y(delta * 1.1)


func interact(player: Player) -> void:
	match kind:
		"flashlight":
			player.flashlight.give_flashlight()
			Sfx.play_2d(&"pickup", -5.0)
			GameState.set_flag("has_flashlight")
			GameState.push_notice("You found a flashlight. [F] to switch it on.", 4.5)
			GameState.set_objective_key("explore")
		"battery":
			var gained: float = player.flashlight.add_battery()
			if gained <= 0.5:
				Sfx.play_2d(&"click", -14.0)
				GameState.push_notice("The cell is dead.", 2.0)
				return
			Sfx.play_2d(&"pickup", -6.0)
			GameState.push_notice("Battery cell  +%d%%" % int(round(gained)), 2.6)
		"key":
			var key_flag := item_id if item_id != "" else "has_front_key"
			GameState.add_item("key")
			GameState.set_flag(key_flag)
			Sfx.play_2d(&"key", -4.0)
			GameState.push_notice("Took the %s." % label_text.to_lower(), 3.0)
		_:
			pass
	consumed = true
	visible = false
	collision_layer = 0
	set_process(false)
	if _pivot:
		_pivot.visible = false
	set_highlight(false)