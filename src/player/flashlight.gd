class_name Flashlight
extends Node3D
## THE LIGHT.
##
## Owns the torch: battery drain, flicker, a fake-volumetric beam cone (so the
## light reads in the GL Compatibility renderer, which has no volumetric fog) and
## the single query every other system uses to ask "is this point lit?".

signal toggled(on: bool)

const RANGE := 15.0
const SPOT_ANGLE := 28.0
const DRAIN_PER_SEC := 1.6
## Kid mode barely sips the cell. The torch's *optics* are untouched on purpose:
## a wider or longer beam would hand the creature a better sense of where you
## are, which is the opposite of what this mode is for.
const DRAIN_KID := 0.65
const CELL_CHARGE := 35.0
const LOW_WARN := 25.0
const FLICKER_BELOW := 20.0

var has_flashlight: bool = false
var battery: float = 100.0
var is_on: bool = false
var drain_per_sec: float = DRAIN_PER_SEC

var spot: SpotLight3D
var cone: MeshInstance3D
var _body: Node3D
var _flicker := 1.0
var _flicker_timer := 0.0
var _warned_low := false
var _dead_announced := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build()
	apply_kid_mode(GameState.kid_mode)
	set_process(true)


func _build() -> void:
	spot = SpotLight3D.new()
	spot.spot_range = RANGE
	spot.spot_angle = SPOT_ANGLE
	spot.spot_angle_attenuation = 0.9
	spot.spot_attenuation = 1.1
	spot.light_energy = 0.0
	spot.light_color = Color(1.0, 0.94, 0.80)
	spot.shadow_enabled = true
	spot.shadow_bias = 0.045
	spot.shadow_normal_bias = 1.4
	spot.position = Vector3(0.16, -0.12, 0.0)
	add_child(spot)

	cone = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 16
	cyl.rings = 1
	cone.mesh = cyl
	cone.material_override = _cone_material()
	cone.rotation_degrees.x = -90.0
	cone.position = Vector3(0.16, -0.12, -RANGE * 0.5)
	var rad: float = tan(deg_to_rad(SPOT_ANGLE * 0.5)) * RANGE
	cone.scale = Vector3(rad, RANGE, rad)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.extra_cull_margin = 4.0
	cone.layers = 0
	add_child(cone)
	_apply_on_state()


func _cone_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded, shadows_disabled, fog_disabled;

varying float v_fade;

void vertex() {
	// cylinder is unit height along +Y, apex at +0.5
	v_fade = clamp(0.5 - VERTEX.y, 0.0, 1.0);
}

void fragment() {
	float a = pow(1.0 - v_fade, 2.2) * 0.085;
	a *= smoothstep(0.0, 0.06, v_fade);
	ALBEDO = vec3(1.0, 0.94, 0.78);
	ALPHA = a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# --- Control ---------------------------------------------------------------

func give_flashlight() -> void:
	has_flashlight = true
	battery = 100.0
	_warned_low = false
	_dead_announced = false


func apply_kid_mode(on: bool) -> void:
	drain_per_sec = DRAIN_KID if on else DRAIN_PER_SEC


func toggle() -> void:
	if not has_flashlight or battery <= 0.0:
		if has_flashlight and battery <= 0.0 and not _dead_announced:
			_dead_announced = true
			Sfx.play_2d(&"light_dead", -8.0)
			GameState.push_notice("The battery is dead.", 2.5)
		return
	is_on = not is_on
	Sfx.play_2d(&"light_on" if is_on else &"light_off", -6.0)
	GameState.light_toggled.emit(is_on)
	_apply_on_state()


func force_off() -> void:
	if is_on:
		is_on = false
		_apply_on_state()
		GameState.light_toggled.emit(false)


func add_battery(amount: float = CELL_CHARGE) -> float:
	var before := battery
	battery = minf(100.0, battery + amount)
	if battery > LOW_WARN:
		_warned_low = false
	return battery - before


func is_lit() -> bool:
	return is_on and battery > 0.0


## 0..1 — how strongly the beam lands on a world point. Used by comic panels
## (reveal) and by the creature (detection).
func cone_factor(p: Vector3) -> float:
	if not is_lit() or spot == null:
		return 0.0
	var to := p - spot.global_position
	var dist := to.length()
	if dist > RANGE or dist < 0.001:
		return 0.0
	var fwd := -spot.global_transform.basis.z
	var ang := fwd.angle_to(to / dist)
	var half := deg_to_rad(SPOT_ANGLE * 0.5)
	if ang > half * 1.5:
		return 0.0
	var angular := 1.0 - clampf((ang / half - 0.85) / 0.65, 0.0, 1.0)
	var dist_fall := 1.0 - clampf(dist / RANGE, 0.0, 1.0) * 0.55
	return clampf(angular * dist_fall, 0.0, 1.0) * _flicker


func _process(delta: float) -> void:
	if not has_flashlight:
		return

	if is_on:
		battery = maxf(0.0, battery - drain_per_sec * delta)
		if battery <= 0.0:
			is_on = false
			Sfx.play_2d(&"light_dead", -6.0)
			GameState.light_toggled.emit(false)
			GameState.push_notice("The battery is dead.", 3.0)

	if battery <= LOW_WARN and not _warned_low and battery > 0.0:
		_warned_low = true
		GameState.push_notice("The light is dying. Find a cell.", 3.0)

	# flicker: constant below 20%, plus random stutters when a cell is nearly flat
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		if battery <= 0.4:
			_flicker_timer = 0.45
		elif battery < FLICKER_BELOW:
			_flicker_timer = _rng.randf_range(0.04, 0.16)
		else:
			_flicker_timer = 0.2
		var healthy := clampf(battery / FLICKER_BELOW, 0.0, 1.0)
		_flicker = lerpf(_rng.randf_range(0.05, 0.45), 1.0, healthy * healthy)
	else:
		_flicker = move_toward(_flicker, 1.0, delta * 6.0)

	_apply_on_state()


func _apply_on_state() -> void:
	var lit := is_lit()
	var energy := 0.0
	var col := Color(1.0, 0.94, 0.80)
	if lit:
		energy = 5.2 * _flicker
		# the beam reddens and dims as the cell drains
		var health := clampf(battery / 45.0, 0.0, 1.0)
		energy *= lerpf(0.55, 1.0, health)
		col = Color(1.0, lerpf(0.72, 0.94, health), lerpf(0.42, 0.80, health))
		energy = maxf(energy, 0.0)
	if spot:
		spot.light_energy = energy
		spot.light_color = col
		spot.visible = energy > 0.01
	if cone:
		cone.visible = lit