class_name Interactable
extends StaticBody3D
## Base for everything the player can press E on.
## Lives on its own collision layer so the interactor ray can hit it without
## passing through walls.

signal interacted(by)

@export var prompt: String = "Examine"
@export var enabled: bool = true

var consumed: bool = false
var _glow: OmniLight3D
var _glow_mat: StandardMaterial3D
var _highlighted: bool = false
var _kid_hint: bool = false
var _glow_base_range: float = 1.9


func _init() -> void:
	collision_layer = 1 << 3
	collision_mask = 0


func _ready() -> void:
	setup()


## Subclasses that override `_ready` must call this.
func setup() -> void:
	_build_glow()
	_refresh_glow()


## Small practical light so the player can tell what they are aiming at.
## Kept hidden until highlighted: the house has a lot of these, and invisible
## lights cost the renderer nothing (important on GL Compatibility / WebGL2).
func _build_glow() -> void:
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.93, 0.75)
	_glow.light_energy = 0.0
	_glow.omni_range = 1.9
	_glow.shadow_enabled = false
	_glow.visible = false
	add_child(_glow)


func set_highlight(on: bool) -> void:
	_highlighted = on
	_refresh_glow()


## Kid mode: a permanent, softer version of the highlight so small players can
## spot the things they need. Toggled live from the pause menu.
func set_kid_hint(on: bool) -> void:
	_kid_hint = on
	_refresh_glow()


func _refresh_glow() -> void:
	if _glow == null:
		return
	var e := 0.0
	if _highlighted:
		e += 0.55
	if _kid_hint and not consumed:
		e += 0.26
	_glow.visible = e > 0.0
	_glow.light_energy = e
	_glow.omni_range = _glow_base_range * (1.3 if _kid_hint else 1.0)



func can_interact(_player: Player) -> bool:
	return enabled and not consumed


func get_prompt(_player: Player) -> String:
	return prompt


## Subclasses override. `player` is the Player node.
func interact(player: Player) -> void:
	interacted.emit(player)


func lock_out() -> void:
	consumed = true
	enabled = false
	set_highlight(false)


# --- Shared construction helpers ------------------------------------------

static func make_box(size: Vector3, pos: Vector3, col: Color, rough: float = 0.9,
		metal: float = 0.0, emis: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat(col, rough, metal, emis)
	return mi


static func mat(col: Color, rough: float = 0.9, metal: float = 0.0, emis: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emis
	return m


static func add_shape(body: CollisionObject3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)