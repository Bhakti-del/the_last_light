class_name Creature
extends CharacterBody3D
## THE CREATURE.
##
## It is blind. What it actually senses is:
##   * the flashlight beam and its spill (strongest signal in the game),
##   * noise: sprinting is louder than walking, walking louder than crouching,
##   * and nothing at all while you are inside a wardrobe.
##
## Deliberately slow enough that sprinting always beats it — the tension has to
## come from the torch, not from the sprint button.

signal state_changed(state: StringName)

enum State { DORMANT, PROWL, STALK, HUNT, SEARCH }

const SPEED_PROWL := 1.25
const SPEED_STALK := 1.95
const SPEED_HUNT := 4.05

const CATCH_RANGE := 1.15
const HIDE_SAFE_RANGE := 1.6

const AWARE_LIGHT_SPILL := 0.20
const AWARE_LIGHT_BEAM := 1.55
const AWARE_NOISE := 0.95
const AWARE_DECAY := 0.17

const HUNT_AT := 1.0
const CALM_AT := 0.32
const SEARCH_TIME := 7.0
const REPATH_TIME := 0.55

var player: Player = null
var flashlight: Flashlight = null

var state: State = State.DORMANT
var awareness: float = 0.0
var enabled: bool = false

var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _repath: float = 0.0
var _search: float = 0.0
var _wander: float = 0.0
var _home_zone: String = "basement"
var _gravity: float = 18.0
var _grace: float = 0.0
var _los: PhysicsRayQueryParameters3D
var _growl_db: float = -60.0
var _rng := RandomNumberGenerator.new()

const GROWL_VOICE := &"creature_growl"


func _ready() -> void:
	_rng.randomize()
	_home_zone = LevelData.PATROL_HOME
	_build()
	_los = PhysicsRayQueryParameters3D.new()
	_los.collision_mask = 1 << 0
	add_to_group("creature")


func _build() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 0

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 2.10
	shape.shape = cap
	shape.position = Vector3(0, 1.05, 0)
	add_child(shape)

	# A silhouette, not a monster model. Almost black, so the flashlight finds it
	# before the eye does.
	var hide := Color(0.045, 0.042, 0.050)
	var root := Node3D.new()
	add_child(root)

	_torso(root, Vector3(0.00, 1.62, 0.00), Vector3(0.50, 0.62, 0.28), hide)
	_torso(root, Vector3(0.00, 1.14, 0.00), Vector3(0.42, 0.48, 0.24), hide.darkened(0.2))
	_torso(root, Vector3(0.00, 1.98, 0.02), Vector3(0.26, 0.28, 0.26), hide.darkened(0.35))

	for sx in [-1.0, 1.0]:
		_limb(root, Vector3(0.19 * sx, 1.48, 0.00), Vector3(0.13, 0.96, 0.13), hide.darkened(0.15))
		_limb(root, Vector3(0.12 * sx, 0.90, 0.00), Vector3(0.12, 0.92, 0.12), hide.darkened(0.3))

	# two faint eye glints — the only thing you can see without the torch
	for sx in [-1.0, 1.0]:
		var eye := Interactable.make_box(Vector3(0.045, 0.028, 0.02),
			Vector3(0.062 * sx, 1.99, -0.125), Color(0.72, 0.76, 0.62), 0.25, 0.0, 0.9)
		root.add_child(eye)


func _torso(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	parent.add_child(Interactable.make_box(size, pos, col, 0.96))


func _limb(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	parent.add_child(Interactable.make_box(size, pos, col, 0.96))


func spawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	state = State.PROWL
	awareness = 0.0
	_path.clear()
	_grace = 2.0


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if on:
		Sfx.attach_loop(GROWL_VOICE, self, "growl_idle", -60.0)
	else:
		state = State.DORMANT
		velocity = Vector3.ZERO
		Sfx.stop_loop(GROWL_VOICE)

## Called by main.gd so the creature ignores the player for the first moments of
## an attempt, and after every loop restart.
func grant_grace(seconds: float) -> void:
	_grace = seconds


func hear_noise(level: float, pos: Vector3) -> void:
	if not enabled or player == null:
		return
	_gain(level * AWARE_NOISE * _noise_falloff(pos))


## Sound carries: a noise on the far side of the house barely registers.
func _noise_falloff(pos: Vector3) -> float:
	if player == null:
		return 0.0
	var d := global_position.distance_to(pos)
	if d < 16.0:
		return 1.0
	return clampf(16.0 / maxf(d, 0.01), 0.0, 1.0)


func _gain(amount: float) -> void:
	if amount <= 0.0:
		return
	awareness = clampf(awareness + amount, 0.0, 2.0)


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if velocity.y > 0.0 or not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5

	if not enabled or player == null:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		_face_direction(Vector3.ZERO, delta)
		_update_growl(delta)
		return

	_grace = maxf(0.0, _grace - delta)
	_sense(delta)
	_think(delta)
	_move(delta)
	_try_catch()
	_update_growl(delta)


# --- Perception -------------------------------------------------------------

func _sense(delta: float) -> void:
	if player.is_hidden:
		# a wardrobe is total cover at range; only a near miss gives you away
		var d := global_position.distance_to(player.global_position)
		if d < HIDE_SAFE_RANGE:
			_gain(AWARE_LIGHT_SPILL * delta * 4.0)
		else:
			awareness = maxf(0.0, awareness - AWARE_DECAY * 2.0 * delta)
		return

	if flashlight != null and flashlight.is_lit():
		var beam := flashlight.cone_factor(_eye_pos())
		if beam > 0.0 and _has_line_of_sight():
			_gain(AWARE_LIGHT_BEAM * beam * delta)
		elif _has_line_of_sight():
			_gain(AWARE_LIGHT_SPILL * delta)
		if player.is_on_floor() and player.sprinting:
			_gain(0.05 * delta)

	if not _has_line_of_sight():
		awareness = maxf(0.0, awareness - AWARE_DECAY * delta)


func _eye_pos() -> Vector3:
	return player.global_position + Vector3(0.0, player.head.position.y, 0.0)


func _has_line_of_sight() -> bool:
	if player == null:
		return false
	var from := global_position + Vector3(0.0, 1.75, 0.0)
	var to := _eye_pos()
	if from.distance_to(to) > 26.0:
		return false
	_los.from = from
	_los.to = to
	_los.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(_los).is_empty()


# --- Behaviour --------------------------------------------------------------

func _think(delta: float) -> void:
	var want := state
	match state:
		State.DORMANT:
			want = State.PROWL
		State.PROWL:
			if awareness >= HUNT_AT:
				want = State.HUNT
			elif awareness >= 0.45:
				want = State.STALK
		State.STALK:
			if awareness >= HUNT_AT:
				want = State.HUNT
			elif awareness <= 0.18:
				want = State.SEARCH
		State.HUNT:
			if awareness <= CALM_AT:
				want = State.SEARCH
				_search = SEARCH_TIME
		State.SEARCH:
			_search -= delta
			if awareness >= HUNT_AT:
				want = State.HUNT
			elif _search <= 0.0:
				want = State.PROWL
	if want != state:
		_set_state(want)


func _set_state(s: State) -> void:
	state = s
	_repath = 0.0
	match s:
		State.HUNT:
			Sfx.play_2d(&"growl_chase", -7.0)
		State.STALK, State.SEARCH:
			Sfx.play_2d("growl_idle", -12.0)
	state_changed.emit(StringName(State.keys()[s]))


func _move(delta: float) -> void:
	var speed := SPEED_PROWL
	var goal := Vector3.ZERO
	var has_goal := false

	match state:
		State.HUNT:
			speed = SPEED_HUNT
			goal = _eye_pos()
			has_goal = true
		State.STALK:
			speed = SPEED_STALK
			goal = _eye_pos()
			has_goal = true
		State.SEARCH:
			speed = SPEED_PROWL * 1.3
		State.PROWL:
			speed = SPEED_PROWL
		_:
			speed = 0.0

	# --- repath
	_repath -= delta
	if _repath <= 0.0:
		_repath = REPATH_TIME
		_path = PackedVector3Array()
		_path_i = 0
		if has_goal:
			_path = NavGraph.find_path(global_position, _eye_pos())
			if _path.is_empty():
				# no route to the player's floor (hatch still shut) — patrol instead
				_wander = 4.0
		if state == State.PROWL or state == State.SEARCH or _path.is_empty():
			_wander -= delta * 4.0
			if _wander <= 0.0 or _path.is_empty():
				_wander = _rng.randf_range(4.0, 9.0)
				var pick := NavGraph.random_point(_home_zone, global_position, 9.0)
				_path = NavGraph.find_path(global_position, pick)
				_path_i = 0
				if _path.is_empty():
					_path.append(pick)

	# --- follow
	var target := Vector3.ZERO
	if has_goal and global_position.distance_to(goal) < 2.4:
		target = goal
	elif _path_i < _path.size():
		target = _path[_path_i]
		if global_position.distance_to(target) < 0.7:
			_path_i += 1
			if _path_i < _path.size():
				target = _path[_path_i]

	var dir := Vector3.ZERO
	if target != Vector3.ZERO:
		dir = target - global_position
		dir.y = 0.0
		if dir.length() > 0.05:
			dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, 16.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 16.0 * delta)
	move_and_slide()
	_face_direction(dir, delta)


func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.01:
		return
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * 6.0, 0.0, 1.0))


func _try_catch() -> void:
	if _grace > 0.0 or player.is_hidden:
		return
	if global_position.distance_to(player.global_position) > CATCH_RANGE:
		return
	if awareness < 0.55:
		return
	GameState.player_caught.emit()
	_grace = 6.0
	awareness = 0.0
	_set_state(State.SEARCH)


func _update_growl(delta: float) -> void:
	if not enabled:
		return
	var d := global_position.distance_to(player.global_position) if player != null else 99.0
	var target_db := -60.0
	match state:
		State.HUNT:
			target_db = -6.0
		State.STALK:
			target_db = -12.0
		State.SEARCH:
			target_db = -17.0
		State.PROWL:
			target_db = -24.0
		_:
			target_db = -60.0
	# only audible when it is on your floor
	if absf(global_position.y - player.global_position.y) > 1.2:
		target_db = -60.0
	var pitch := 1.0 + clampf(14.0 / maxf(d, 1.0), 0.0, 0.35)
	_growl_db = move_toward(_growl_db, target_db, 22.0 * delta)
	Sfx.set_loop(GROWL_VOICE, _growl_db, pitch)