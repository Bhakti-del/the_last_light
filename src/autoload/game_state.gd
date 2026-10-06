extends Node
## Global game state: flags, inventory, chapters, attempts, objectives.
## Also registers the input map at runtime so project.godot stays diff-safe.

signal flag_changed(key: String)
signal item_added(id: String)
signal objective_changed(text: String)
signal notice(text: String, duration: float)
signal chapter_changed(chapter: String)
signal attempt_started(attempt: int)
signal player_caught()
signal game_completed(true_ending: bool)
signal light_toggled(on: bool)
signal open_document(title: String, body: String)
signal run_sequence(id: String)
signal kid_mode_changed(on: bool)

const KEY_LIGHT := "light"
const KEY_CREATURE := "creature"
const KEY_GAMEOVER := "gameover"
const KEY_TRANSITION := "transition"
const KEY_HIDDEN := "hidden"

var flags: Dictionary = {}
var items: Array[String] = []
var journal: Array[String] = []
var attempt: int = 1
var chapter: String = "bedroom"
var objective: String = ""
var objective_key: String = ""
var loops_completed: int = 0
## Accessibility layer, toggled from the pause menu. Off by default so the
## shipped build plays exactly as designed; turns on bigger text, longer reach,
## softer battery drain and objectives that spell the puzzles out.
var kid_mode: bool = false

var _notice_queue: Array = []
var _notice_busy := false


func _init() -> void:
	_register_input()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- Input map -------------------------------------------------------------
# Built in code instead of serialised InputEvent blobs in project.godot.

func _register_input() -> void:
	_action("move_forward", [KEY_W], JOY_AXIS_LEFT_Y, -1.0)
	_action("move_back", [KEY_S], JOY_AXIS_LEFT_Y, 1.0)
	_action("move_left", [KEY_A], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [KEY_D], JOY_AXIS_LEFT_X, 1.0)
	_action("sprint", [KEY_SHIFT])
	_action("crouch", [KEY_CTRL, KEY_C])
	_action("jump", [KEY_SPACE])
	_action("interact", [KEY_E], JOY_BUTTON_A)
	_action("toggle_light", [KEY_F], JOY_BUTTON_RIGHT_SHOULDER)
	_action("journal", [KEY_TAB, KEY_J], JOY_BUTTON_Y)
	_action("pause", [KEY_ESCAPE], JOY_BUTTON_START)
	_action("look_left", [KEY_LEFT])
	_action("look_right", [KEY_RIGHT])
	_action("look_up", [KEY_UP])
	_action("look_down", [KEY_DOWN])
	_action("skip", [KEY_SPACE], JOY_BUTTON_B)


func _action(name: String, keys: Array = [], axis: int = -1, axis_value: float = 0.0) -> void:
	if InputMap.has_action(name):
		InputMap.erase_action(name)
	InputMap.add_action(name, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)
	if axis >= 0:
		var jb := InputEventJoypadMotion.new()
		jb.axis = axis
		jb.axis_value = axis_value
		InputMap.action_add_event(name, jb)


# --- Kid mode --------------------------------------------------------------

func set_kid_mode(on: bool) -> void:
	if kid_mode == on:
		return
	kid_mode = on
	refresh_objective()
	kid_mode_changed.emit(on)


# --- Flags -----------------------------------------------------------------

func set_flag(key: String, value: bool = true) -> void:
	if flags.get(key, false) == value:
		return
	flags[key] = value
	flag_changed.emit(key)


func has_flag(key: String) -> bool:
	return bool(flags.get(key, false))


func toggle_flag(key: String) -> bool:
	var v := not has_flag(key)
	set_flag(key, v)
	return v


# --- Inventory -------------------------------------------------------------

func add_item(id: String) -> void:
	if items.has(id):
		return
	items.append(id)
	item_added.emit(id)


func has_item(id: String) -> bool:
	return items.has(id)


func remove_item(id: String) -> void:
	items.erase(id)


# --- Journal ---------------------------------------------------------------

## The comic panels fade when you look away; the journal is what you keep.
func add_journal(text: String) -> void:
	if text.strip_edges() == "" or journal.has(text):
		return
	journal.append(text)


# --- Objectives / notices --------------------------------------------------

func set_objective(text: String) -> void:
	if objective == text:
		return
	objective = text
	objective_changed.emit(text)


## The common path: remember which beat this is, so flipping kid mode can
## re-render the same objective in its plainer wording without losing our place.
func set_objective_key(key: String) -> void:
	objective_key = key
	set_objective(Story.objective_for(key))


func refresh_objective() -> void:
	if objective_key != "":
		set_objective(Story.objective_for(objective_key))


func push_notice(text: String, duration: float = 3.5) -> void:
	_notice_queue.append({"text": text, "duration": duration})
	if not _notice_busy:
		_run_next_notice()


func _run_next_notice() -> void:
	if _notice_queue.is_empty():
		_notice_busy = false
		return
	_notice_busy = true
	var n: Dictionary = _notice_queue.pop_front()
	notice.emit(n["text"], n["duration"])
	await get_tree().create_timer(n["duration"]).timeout
	_run_next_notice()


# --- Chapters / attempts ---------------------------------------------------

func set_chapter(name: String) -> void:
	if chapter == name:
		return
	chapter = name
	chapter_changed.emit(name)


func begin_attempt(n: int) -> void:
	attempt = n
	attempt_started.emit(n)


func complete_loop(true_ending: bool) -> void:
	loops_completed += 1
	game_completed.emit(true_ending)


func wipe_run() -> void:
	flags.clear()
	items.clear()
	journal.clear()
	objective = ""
	objective_key = ""


func debug_state() -> String:
	return "attempt=%d chapter=%s flags=%d items=%d" % [attempt, chapter, flags.size(), items.size()]