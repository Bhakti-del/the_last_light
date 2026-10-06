class_name ZoneTrigger
extends Area3D
## Room volumes and scripted story beats. Fires once when the player enters.

var room_id: String = ""
var set_chapter_to: String = ""
var objective_key: String = ""
var once: bool = true
var sequence_id: String = ""
var sting: StringName = &""
var sting_db: float = -8.0
var subtitle: String = ""
## If set, teleports the player to this world position when triggered.
var teleport_to: Vector3 = Vector3(0, -9999, 0)

var _fired: bool = false


static func room(p_room: String, p_size: Vector3, p_pos: Vector3, p_objective: String = "") -> ZoneTrigger:
	var z := ZoneTrigger.new()
	z.room_id = p_room
	z.set_chapter_to = p_room
	z.objective_key = p_objective
	return box(p_pos, p_size)


## Ad-hoc volume used for scripted beats. Always give it a shape — a ZoneTrigger
## with no CollisionShape3D silently never fires.
static func box(p_pos: Vector3, p_size: Vector3) -> ZoneTrigger:
	var z := ZoneTrigger.new()
	z.monitoring = true
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = p_size
	cs.shape = bs
	cs.position = Vector3(0, p_size.y * 0.5, 0)
	z.add_child(cs)
	z.position = p_pos
	return z


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _fired or not (body is Player):
		return
	if once:
		_fired = true
	fire()


func fire() -> void:
	if set_chapter_to != "":
		GameState.set_chapter(set_chapter_to)
	if objective_key != "":
		GameState.set_objective_key(objective_key)
	if sting != &"":
		Sfx.play_3d(sting, global_position, sting_db)
	if subtitle != "":
		GameState.push_notice(subtitle, 3.2)
	if sequence_id != "":
		GameState.run_sequence.emit(sequence_id)
	if teleport_to.y > -9998.0:
		# Find the player body that entered and move it
		for body in get_overlapping_bodies():
			if body is Player:
				body.global_position = teleport_to
				body.velocity = Vector3.ZERO
				break