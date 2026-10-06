class_name Interactor
extends Node3D
## Casts a short ray from the camera and reports whatever the player is aiming
## at, so the HUD can show a prompt and E can trigger it.

const REACH := 3.1
## Kid mode reaches further, so a small player does not have to stand on top of
## a thing and hunt for the exact pixel before pressing E.
const REACH_KID := 4.3
const PROMPT_PIXEL := 0.0016
const PROMPT_PIXEL_KID := 0.0025

signal target_changed(target)
signal activated(target)

var player: Player
var current: Interactable = null
## Turned off while a full-screen overlay (journal, reader, pause) is up, so E
## cannot reach through the UI into the world.
var enabled: bool = true

var reach: float = REACH

var _ray: RayCast3D
var _prompt_label: Label3D


func _ready() -> void:
	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -reach)
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	# the world layer stops the ray at walls; the interactable layer is the target
	_ray.collision_mask = (1 << 0) | (1 << 3)
	add_child(_ray)

	_prompt_label = Label3D.new()
	_prompt_label.font_size = 44
	_prompt_label.outline_size = 12
	_prompt_label.modulate = Color(0.97, 0.95, 0.90, 0.0)
	_prompt_label.outline_modulate = Color(0.05, 0.04, 0.05, 0.0)
	_prompt_label.shaded = false
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.render_priority = 8
	_prompt_label.pixel_size = PROMPT_PIXEL
	_prompt_label.position = Vector3(0, -0.32, -reach + 0.12)
	_prompt_label.visible = false
	add_child(_prompt_label)

	set_process(true)


func apply_kid_mode(on: bool) -> void:
	reach = REACH_KID if on else REACH
	if _ray != null:
		_ray.target_position = Vector3(0, 0, -reach)
	if _prompt_label != null:
		_prompt_label.pixel_size = PROMPT_PIXEL_KID if on else PROMPT_PIXEL
		_prompt_label.position = Vector3(0, -0.32, -reach + 0.12)


func _process(_delta: float) -> void:
	if not enabled:
		_prompt_label.visible = false
		if current != null and is_instance_valid(current):
			current.set_highlight(false)
			current = null
			target_changed.emit(null)
		return

	var found := _resolve()
	if found != current:
		if current != null and is_instance_valid(current):
			current.set_highlight(false)
		current = found
		if current != null:
			current.set_highlight(true)
		target_changed.emit(current)

	var usable: bool = current != null and is_instance_valid(current) and current.can_interact(player)
	if usable:
		_prompt_label.text = "[E]  " + current.get_prompt(player)
		_prompt_label.modulate.a = 1.0
		_prompt_label.outline_modulate.a = 1.0
		_prompt_label.visible = true
	else:
		_prompt_label.visible = false

	if usable and Input.is_action_just_pressed("interact"):
		current.interact(player)
		activated.emit(current)


func _resolve() -> Interactable:
	# While hidden the player is *inside* the furniture, so a ray cast from the
	# camera cannot hit it. Target the active hiding place directly instead.
	if player != null and player.is_hidden and player.hide_spot != null \
			and is_instance_valid(player.hide_spot):
		return player.hide_spot

	_ray.force_raycast_update()
	if not _ray.is_colliding():
		return null
	var col := _ray.get_collider()
	if col == null:
		return null
	if col is Interactable:
		return col
	# an interactable may sit on a child of the hit body
	for c in col.get_children():
		if c is Interactable:
			return c
	return null