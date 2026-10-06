extends Node3D
## Entry point. Owns the world: builds the house, spawns the player and the
## creature, wires every signal together, and drives the attempt / loop / ending
## flow.

const SURFACE_BY_FLOOR := {"wood": "step_wood", "concrete": "step_concrete"}

## Moonlight leaking through the house. Not a light source you can point at —
## just enough for the eye to find edges and read a silhouette, so a player with
## the torch off is lost rather than blind.
const AMBIENT := Color(0.42, 0.52, 0.72)
const AMBIENT_ENERGY := 0.16
const AMBIENT_ENERGY_KID := 0.30

var world: Node3D = null
var level: LevelBuilder = null
var player: Player = null
var creature: Creature = null
var hud: Hud = null
var sequence: ComicSequence = null

var _env: WorldEnvironment
var _ambience: StringName = &""
var _surface: String = ""
var _started: bool = false


func _ready() -> void:
	_build_environment()

	hud = Hud.new()
	add_child(hud)
	sequence = ComicSequence.new()
	add_child(sequence)

	hud.title_finished.connect(_on_title_finished)
	hud.resume_requested.connect(_set_paused.bind(false))
	hud.restart_requested.connect(_on_restart_requested)
	sequence.finished.connect(_on_sequence_finished)
	GameState.player_caught.connect(_on_player_caught)
	GameState.run_sequence.connect(_on_run_sequence)
	GameState.kid_mode_changed.connect(_on_kid_mode_changed)

	_start_attempt(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A cool ambient floor under the practical lights. GL Compatibility supports
## ambient from an environment fine; what it does not support is volumetric fog,
## which is why the torch fakes its own beam cone instead.
func _build_environment() -> void:
	_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.background_color = Color(0.012, 0.014, 0.022)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = AMBIENT
	e.ambient_light_energy = AMBIENT_ENERGY
	_env.environment = e
	add_child(_env)


func _on_kid_mode_changed(on: bool) -> void:
	if _env != null and _env.environment != null:
		_env.environment.ambient_light_energy = AMBIENT_ENERGY_KID if on else AMBIENT_ENERGY
	if level != null:
		level.apply_kid_mode(on)
	if player != null:
		player.interactor.apply_kid_mode(on)
		player.flashlight.apply_kid_mode(on)
	# Both notes are the things a small player would otherwise be stuck on: how
	# to operate the game, and the one answer the game hides on a dark wall.
	GameState.add_journal("HOW TO PLAY: WASD or the ARROW KEYS move and look. "
		+ "E uses things. F is the torch. ESC pauses.")
	GameState.add_journal("THE THREE DIALS: 1 = EYE, 2 = MOON, 3 = WAVE.")




# ============================================================ world lifecycle

func _start_attempt(fresh: bool) -> void:
	if world != null:
		world.queue_free()
		world = null
	level = null
	player = null
	creature = null

	world = Node3D.new()
	world.name = "World"
	add_child(world)

	player = Player.new()
	player.name = "Player"
	player.position = LevelData.SPAWN
	player.rotation.y = LevelData.SPAWN_YAW
	world.add_child(player)
	player.can_move = false

	level = LevelBuilder.new()
	level.name = "Level"
	world.add_child(level)
	level.build(player)

	creature = Creature.new()
	creature.name = "Creature"
	creature.player = player
	creature.flashlight = player.flashlight
	world.add_child(creature)
	creature.spawn_at(LevelData.CREATURE_SPAWN)
	creature.set_enabled(true)
	creature.grant_grace(6.0)
	player.noise_made.connect(creature.hear_noise)

	if fresh:
		GameState.wipe_run()
		GameState.begin_attempt(1)
	GameState.set_flag(GameState.KEY_TRANSITION, _started)
	GameState.set_chapter("bedroom")
	GameState.set_objective_key("wake")

	_update_ambience("")

	# A restarted attempt must come back up in whatever mode the player chose,
	# and the loop wipes the journal, so the plain-language notes go back in.
	_on_kid_mode_changed(GameState.kid_mode)

	if _started:
		GameState.set_flag(GameState.KEY_TRANSITION, false)
		player.can_move = true
		creature.grant_grace(6.0)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_title_finished() -> void:
	_started = true
	GameState.set_flag(GameState.KEY_TRANSITION, false)
	player.can_move = true
	creature.grant_grace(8.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.push_notice("You are in a bed you do not remember lying down in.", 5.0)


# ============================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if hud.title_is_open():
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			hud.dismiss_title()
		return

	if sequence.is_running() or hud.pause_is_open():
		return

	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_set_paused(not hud.pause_is_open())
		return

	if hud.reader_is_open():
		if event.is_action_pressed("interact") or event.is_action_pressed("journal"):
			get_viewport().set_input_as_handled()
			hud.close_reader()
		return

	if event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		hud.toggle_journal()
		_sync_input()
		return

	if event.is_action_pressed("toggle_light"):
		get_viewport().set_input_as_handled()
		player.flashlight.toggle()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _started:
		if not hud.is_blocking() and not sequence.is_running():
			_set_paused(true)


func _set_paused(on: bool) -> void:
	hud.set_pause(on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	get_tree().paused = on
	_sync_input()


func _sync_input() -> void:
	if player == null:
		return
	var blocked: bool = hud.is_blocking() or hud.journal_is_open() or hud.reader_is_open() \
		or sequence.is_running() or GameState.has_flag(GameState.KEY_TRANSITION)
	player.can_move = _started and not blocked
	player.interactor.enabled = not blocked


# ============================================================ frame

func _process(_delta: float) -> void:
	if player == null:
		return
	hud.set_torch(player.flashlight.battery, player.flashlight.has_flashlight)
	_update_surface()
	_update_ambience(GameState.chapter)
	_sync_input()


func _update_surface() -> void:
	var room := _room_at(player.global_position)
	var mat_key: String = "wood"
	if room != "":
		mat_key = str(LevelData.ROOMS[room]["floor"])
	var s: String = str(SURFACE_BY_FLOOR.get(mat_key, "step_wood"))
	if s != _surface:
		_surface = s
		player.set_surface(s)


func _room_at(pos: Vector3) -> String:
	for name in LevelData.ROOMS:
		if name == "basement":
			continue
		if LevelData.rect_of(name).has_point(Vector2(pos.x, pos.z)):
			return str(name)
	var br: Rect2 = LevelData.rect_of("basement")
	if br.has_point(Vector2(pos.x, pos.z)):
		return "basement"
	return ""


## One ambience bed per part of the house: the basement hums, upstairs it drips.
func _update_ambience(chapter: String) -> void:
	var want: StringName = &"drone"
	match chapter:
		"basement":
			want = &"hum"
		"final":
			want = &"drone"
		_:
			want = &"whisper" if chapter == "foyer" else &"drone"
	if want == _ambience:
		return
	if _ambience != &"":
		Sfx.stop_bus_voice(_ambience)
	_ambience = want
	Sfx.start_loop(_ambience, Sfx.BUS_AMB, -24.0)


# ============================================================ beats

func _on_player_caught() -> void:
	if hud.is_blocking() or sequence.is_running():
		return
	GameState.set_flag(GameState.KEY_TRANSITION, true)
	player.can_move = false
	player.interactor.enabled = false
	player.flashlight.force_off()
	Sfx.play_2d(&"scream", -3.0)
	Sfx.play_2d(&"twist", -6.0)
	hud.hide_hud(true)
	hud.show_death()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	creature.set_enabled(false)


func _on_run_sequence(id: String) -> void:
	if sequence.is_running():
		return
	GameState.set_flag(GameState.KEY_TRANSITION, true)
	player.can_move = false
	player.interactor.enabled = false
	player.flashlight.force_off()
	creature.set_enabled(false)
	hud.hide_hud(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sequence.play(Story.TRUE_ENDING if id == "true_ending" else Story.FINAL_SEQUENCE)


func _on_sequence_finished() -> void:
	var true_ending := GameState.loops_completed > 0
	hud.hide_hud(false)
	GameState.complete_loop(true_ending)
	if true_ending:
		hud.show_end(true)
		return
	# ...and wake up in the same bed.
	GameState.push_notice("ATTEMPT #%d" % (47 + GameState.loops_completed - 1), 4.0)
	_start_attempt(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_room_title("bedroom")


func _on_restart_requested() -> void:
	hud.hide_death()
	hud.hide_end()
	hud.hide_hud(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if sequence.is_running():
		sequence.stop()
	_start_attempt(false)
	hud.show_room_title("bedroom")


func _notification_free() -> void:
	pass