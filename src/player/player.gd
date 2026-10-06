class_name Player
extends CharacterBody3D
## First-person controller. Walk / sprint / crouch, head bob, footstep noise,
## hiding, and the flashlight that everything else hangs off.

signal noise_made(level: float, pos: Vector3)
signal hidden_changed(hidden: bool)

const WALK := 2.65
const SPRINT := 4.55
const CROUCH := 1.35
const ACCEL := 11.0
const AIR_ACCEL := 2.5
const JUMP := 3.4
const EYE_STAND := 1.66
const EYE_CROUCH := 0.95
const MOUSE_SENS := 0.0022
## Arrow-key look, rad/s. These actions were always registered but never read,
## so keyboard-only players had no way to turn around.
const KEY_LOOK := 1.9
const KEY_LOOK_KID := 2.9
const PITCH_LIMIT := deg_to_rad(86.0)

var head: Node3D
var cam: Camera3D
var flashlight: Flashlight
var interactor: Interactor
var _collider: CollisionShape3D

var can_move: bool = false
var is_hidden: bool = false
var crouching: bool = false
var sprinting: bool = false
var noise_level: float = 0.0
var battery: float = 100.0

var hide_spot: HidingSpot = null
var _hide_offset := Vector3.ZERO
var _bob := 0.0
var _bob_amount := 0.0
var _step_phase := 0.0
var _eye := EYE_STAND
var _tilt := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _base_fov := 76.0
var _surface := &"step_wood"


func _ready() -> void:
	collision_layer = 1 << 1
	collision_mask = 1
	_build()
	_yaw = rotation.y


func _build() -> void:
	_collider = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.72
	_collider.shape = cap
	_collider.position = Vector3(0, 0.86, 0)
	add_child(_collider)

	head = Node3D.new()
	head.position = Vector3(0, EYE_STAND, 0)
	add_child(head)

	cam = Camera3D.new()
	cam.fov = _base_fov
	cam.near = 0.05
	cam.far = 90.0
	cam.current = true
	head.add_child(cam)

	var listener := AudioListener3D.new()
	cam.add_child(listener)

	flashlight = Flashlight.new()
	head.add_child(flashlight)

	interactor = Interactor.new()
	interactor.player = self
	cam.add_child(interactor)


func _unhandled_input(event: InputEvent) -> void:
	if not can_move or GameState.has_flag(GameState.KEY_TRANSITION):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - mm.relative.y * MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)
	elif event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		var dt := get_process_delta_time()
		if jm.axis == JOY_AXIS_RIGHT_X:
			_yaw -= jm.axis_value * dt * 2.6
		elif jm.axis == JOY_AXIS_RIGHT_Y:
			_pitch = clampf(_pitch - jm.axis_value * dt * 2.0, -PITCH_LIMIT, PITCH_LIMIT)


func _physics_process(delta: float) -> void:
	if is_hidden:
		velocity = Vector3.ZERO
		_apply_look(delta)
		return

	var wish := Vector2.ZERO
	if can_move:
		wish = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	crouching = can_move and Input.is_action_pressed("crouch") and not _blocked_above()
	var wants_sprint := can_move and Input.is_action_pressed("sprint") and wish.y < -0.1 and not crouching
	sprinting = wants_sprint and not is_hidden

	var speed := WALK
	if crouching:
		speed = CROUCH
	elif sprinting:
		speed = SPRINT
	if is_hidden:
		speed = 0.0

	var basis_f := -global_transform.basis.z
	var basis_r := global_transform.basis.x
	var dir := (basis_r * wish.x + basis_f * -wish.y)
	dir.y = 0.0
	if dir.length_squared() > 1.0:
		dir = dir.normalized()

	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var target_vel := dir * speed
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

	if can_move and Input.is_action_just_pressed("jump") and is_on_floor() and not crouching:
		velocity.y = JUMP
	velocity.y -= 9.8 * delta
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0

	move_and_slide()

	_update_stance(delta)
	_update_bob(delta, speed)
	_apply_look(delta)
	_update_noise(delta, speed)
	_footsteps(delta, speed)


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.0, 0), global_position + Vector3(0, 1.85, 0))
	q.exclude = [get_rid()]
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()


func _update_stance(delta: float) -> void:
	var target_eye := EYE_CROUCH if crouching else EYE_STAND
	if is_hidden:
		target_eye = EYE_CROUCH
	_eye = move_toward(_eye, target_eye, delta * 6.5)
	if _collider:
		var cap := _collider.shape as CapsuleShape3D
		cap.height = 1.05 if crouching else 1.72
		_collider.position.y = cap.height * 0.5
	if head:
		head.position.y = _eye + _bob_amount


func _update_bob(delta: float, speed: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	if moving > 0.2 and is_on_floor():
		_bob += delta * (4.4 + moving * 1.5)
		var amp: float = 0.030 if not crouching else 0.018
		if sprinting:
			amp *= 1.7
		_bob_amount = sin(_bob) * amp
		_tilt = lerpf(_tilt, cos(_bob * 0.5) * 0.012, delta * 6.0)
	else:
		_bob_amount = move_toward(_bob_amount, 0.0, delta * 0.12)
		_tilt = lerpf(_tilt, 0.0, delta * 5.0)
	if is_hidden:
		_bob_amount = 0.0


func _apply_look(delta: float) -> void:
	# Keyboard look. Deliberately not gated behind mouse capture: a player using
	# arrows and WASD should never be locked out by the cursor state.
	if can_move and not GameState.has_flag(GameState.KEY_TRANSITION):
		var key_look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if key_look != Vector2.ZERO:
			var rate := KEY_LOOK_KID if GameState.kid_mode else KEY_LOOK
			_yaw -= key_look.x * rate * delta
			_pitch = clampf(_pitch + key_look.y * rate * delta, -PITCH_LIMIT, PITCH_LIMIT)

	rotation.y = _yaw
	if head:
		head.rotation.x = _pitch
		head.rotation.z = _tilt
	if cam:
		var want_fov: float = _base_fov + (7.0 if sprinting else 0.0)
		cam.fov = lerpf(cam.fov, want_fov, 0.12)


## Aim the camera (and therefore the torch cone) at a world point.
## Measures from the EYE, not the feet: using global_position put every scripted
## look-at about 30 degrees too high at conversational range, which threw the
## torch beam straight over whatever it was meant to be pointing at.
func look_at_point(p: Vector3) -> void:
	var eye: Vector3 = global_position + Vector3(0.0, _eye, 0.0)
	var d := p - eye
	_yaw = atan2(-d.x, -d.z)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -PITCH_LIMIT, PITCH_LIMIT)


# --- Noise: the creature's ears -------------------------------------------

func _update_noise(delta: float, speed: float) -> void:
	var target := 0.0
	if is_on_floor() and speed > 0.1:
		if crouching:
			target = 0.18
		elif sprinting:
			target = 1.0
		else:
			target = 0.5
	if is_hidden:
		target = 0.0
	noise_level = move_toward(noise_level, target, delta * 5.0)
	if noise_level > 0.25:
		noise_made.emit(noise_level, global_position)


func _footsteps(delta: float, speed: float) -> void:
	if not is_on_floor() or speed < 0.3:
		return
	_step_phase += delta * (1.55 if not crouching else 1.15) * (speed / WALK)
	if _step_phase >= 1.0:
		_step_phase -= 1.0
		Sfx.play_3d(_surface, global_position, -19.0 if not sprinting else -14.0,
			_rng_pitch())


func _rng_pitch() -> float:
	return randf_range(0.92, 1.09)


func set_surface(s: StringName) -> void:
	_surface = s


# --- Hiding ----------------------------------------------------------------

func enter_hide_spot(spot: HidingSpot) -> void:
	if is_hidden:
		return
	is_hidden = true
	hide_spot = spot
	GameState.set_flag(GameState.KEY_HIDDEN, true)
	hidden_changed.emit(true)
	var exit_pos: Vector3 = spot.hide_exit_position()
	_hide_offset = exit_pos - global_position
	velocity = Vector3.ZERO
	flashlight.force_off()
	Sfx.play_2d(&"step_soft", -14.0, 0.8)


func exit_hide_spot() -> void:
	if not is_hidden:
		return
	var exit_pos := global_position + _hide_offset
	is_hidden = false
	hide_spot = null
	GameState.set_flag(GameState.KEY_HIDDEN, false)
	hidden_changed.emit(false)
	var space := get_world_3d().direct_space_state
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(
			exit_pos + Vector3(0, 1.2, 0), exit_pos + Vector3(0, 0.1, 0))).is_empty():
		exit_pos = global_position
	global_position = exit_pos
	velocity = Vector3.ZERO