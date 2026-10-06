extends Node
## Headless flow test. Run with:
##   godot --headless res://tests/flow_test.tscn
##
## It has to be a *scene*, not a bare --script run: autoload singletons only
## resolve as global identifiers when the project boots normally.
##
## Boots the real main scene and asserts the things the game's whole design
## rests on: the house builds, the light-only rune panel exists, the hatch
## responds to its flag, the key opens the back door (and NOT the front door),
## the creature can path between floors, and the chair plays the right ending.

var _fails: Array[String] = []
var _checks := 0
var _main: Node = null
var _node_count := 0
var _seq_got := ""
var _seq_count := 0


func _ready() -> void:
	_run()


func ok(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  PASS  ", what)
	else:
		_fails.append(what)
		print("  FAIL  ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s  (got %s, want %s)" % [what, str(a), str(b)])


func _run() -> void:
	print("\n=== THE LAST LIGHT — flow test ===\n")
	await get_tree().physics_frame
	await get_tree().physics_frame

	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	for i in 6:
		await get_tree().physics_frame

	_test_build()
	await _test_rune_puzzle()
	await _test_doors()
	await _test_navigation()
	await _test_ending()
	await _test_pickups()
	await _test_lighting()
	await _test_kid_mode()

	print("\n--- %d checks, %d failed ---" % [_checks, _fails.size()])
	for f in _fails:
		print("   FAILED: ", f)
	print("")
	get_tree().quit(1 if _fails.size() > 0 else 0)


# ---------------------------------------------------------------- the house

func _test_build() -> void:
	print("\n[house]")
	var world: Node = _main.get("world")
	ok(world != null, "world exists")
	var player: Player = _main.get("player")
	var level: LevelBuilder = _main.get("level")
	ok(player != null and level != null, "player and level exist")

	# node budget
	_node_count = 0
	_stack(world)
	ok(_node_count > 300, "level is actually built (%d nodes)" % _node_count)
	ok(_node_count < 4000, "node count is web-safe (%d)" % _node_count)

	eq(level.panels.size(), Story.active_panels().size(), "every active panel placed")
	ok(level.front_door != null, "front door built")
	ok(level.back_door != null, "back door built")
	ok(level.rune_lock != null, "rune lock built")
	ok(level.hatch_pivot != null, "hatch built")

	# the player must not spawn inside geometry
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 1.4, 0), player.global_position + Vector3(0, 0.1, 0))
	q.collision_mask = 1 << 0
	ok(space.intersect_ray(q).is_empty(), "player spawns with headroom")

	# and must be standing on the floor
	var down := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 0.5, 0), player.global_position + Vector3(0, -1.0, 0))
	down.collision_mask = 1 << 0
	ok(not space.intersect_ray(down).is_empty(), "player spawns on a floor")


func _stack(n: Node) -> void:
	_node_count += 1
	for c in n.get_children():
		_stack(c)


# ------------------------------------------------------- the light puzzle

func _test_rune_puzzle() -> void:
	print("\n[rune puzzle — light only]")
	var level: LevelBuilder = _main.get("level")
	var lock: RuneLock = level.rune_lock
	var clue: ComicPanel = null
	for p in level.panels:
		if p.id == "storage_runes":
			clue = p
	ok(clue != null, "the rune clue panel exists")
	if clue == null:
		return
	ok(clue.data.get("glyphs", false) == true, "clue panel carries glyphs")

	var player: Player = _main.get("player")
	var light: Flashlight = player.flashlight
	ok(clue.light == light, "panel is wired to the player's torch")

	# invisible while the torch is off — the real in-game dark
	for i in 4:
		await get_tree().process_frame
	ok(clue._reveal <= 0.001, "clue invisible with the torch off (reveal=%.3f)" % clue._reveal)

	# now light it up from close range
	light.has_flashlight = true
	light.battery = 100.0
	light.is_on = true
	# stand in the storage room, 2.4 m off the panel, facing it
	player.global_position = clue.global_position + Vector3(0.0, -clue.global_position.y, 2.4)
	await get_tree().physics_frame
	player.look_at_point(clue.global_position)
	for i in 4:
		await get_tree().process_frame
	var d := light.global_position.distance_to(clue.global_position)
	var sp := light.spot
	var to := clue.global_position - sp.global_position
	var ang := (-sp.global_transform.basis.z).angle_to(to.normalized())
	print("        diag: dist=%.2f lit=%s spot=%s spotpos=%s ang=%.1f deg half=%.1f deg flicker=%.2f"
		% [d, str(light.is_lit()), str(sp != null), str(sp.global_position if sp else Vector3.ZERO),
			rad_to_deg(ang), light.SPOT_ANGLE * 0.5, light._flicker])
	for i in 30:
		await get_tree().process_frame
	ok(clue._reveal > 0.5, "clue reveals under the beam (reveal=%.3f)" % clue._reveal)

	# and that switching the torch off hides it again
	light.is_on = false
	for i in 120:
		await get_tree().process_frame
	ok(clue._reveal < 0.05, "clue fades out when the torch is switched off (%.3f)" % clue._reveal)
	light.is_on = true
	for i in 60:
		await get_tree().process_frame

	# the solution is derivable only from the panel data
	eq(Story.RUNE_SOLUTION[0], "EYE", "rune solution: dial 1 = EYE")
	eq(Story.RUNE_SOLUTION[1], "MOON", "rune solution: dial 2 = MOON")
	eq(Story.RUNE_SOLUTION[2], "WAVE", "rune solution: dial 3 = WAVE")
	ok(Story.GLYPHS.find("EYE") >= 0, "glyph vocabulary contains the solution")

	# dial cycling reaches every glyph, and the lever solves on the right combo
	for i in 3:
		while Story.GLYPHS[lock.dials[i]] != Story.RUNE_SOLUTION[i]:
			lock.rotate_dial(i)
	eq(str(lock.dials), "[1, 0, 2]", "dials reach the solution by cycling")
	lock._on_lever(player)
	await get_tree().process_frame
	ok(lock.solved_state, "lever solves the lock")
	ok(GameState.has_flag("hatch_open"), "solving sets hatch_open")

	# the hatch must actually move
	await get_tree().physics_frame
	ok(absf(level.hatch_pivot.rotation.z) > 1.0, "hatch cover swings open (%.2f rad)" % level.hatch_pivot.rotation.z)


# -------------------------------------------------------------- the doors

func _test_doors() -> void:
	print("\n[doors]")
	var level: LevelBuilder = _main.get("level")
	var player: Player = _main.get("player")

	# front door is a permanent dead end
	level.front_door.refresh_lock()
	ok(level.front_door.locked, "front door starts locked")
	level.front_door.interact(player)
	ok(not level.front_door.is_open, "front door refuses to open even after interaction")

	# back door wants the key
	GameState.set_flag("has_back_key", false)
	level.back_door.refresh_lock()
	ok(level.back_door.locked, "back door locked without the key")
	GameState.set_flag("has_back_key", true)
	await get_tree().process_frame
	ok(not level.back_door.locked, "back door unlocks live when the key is taken")
	level.back_door.interact(player)
	ok(level.back_door.is_open, "back door opens with the key")
	ok(level.back_door._target_rot != 0.0, "back door swings")


# ------------------------------------------------------------- navigation

func _test_navigation() -> void:
	print("\n[navigation]")
	eq(NavGraph.size(), LevelData.NAV_POINTS.size(), "all waypoints registered")

	# basement -> ground floor must be routable, or the creature is stuck
	var up := NavGraph.find_path(LevelData.STAIR_BOTTOM, LevelData.STAIR_TOP)
	ok(up.size() > 0, "creature can path from the basement up the stairs (%d hops)" % up.size())

	var down := NavGraph.find_path(LevelData.STAIR_TOP, Vector3(12.5, 0.0, 20.5))
	ok(down.size() > 0, "creature can path to the final room (%d hops)" % down.size())

	var cross := NavGraph.find_path(Vector3(4.0, -3.6, 2.4), Vector3(6.0, 0.0, 15.0))
	ok(cross.size() > 0, "creature can path basement -> living room (%d hops)" % cross.size())

	# every room should be reachable from the spawn
	for probe in [Vector3(5.6, 0.1, 6.4), Vector3(20.0, 0.0, 4.0), Vector3(19.5, 0.0, 12.4)]:
		var path := NavGraph.find_path(LevelData.CREATURE_SPAWN, probe)
		ok(path.size() > 0, "spawn -> %v is routable" % probe)


# ----------------------------------------------------------- pickups/ending

func _test_pickups() -> void:
	print("\n[pickups]")
	var level: LevelBuilder = _main.get("level")
	var batteries := 0
	var keys := 0
	var torches := 0
	var overlaps := 0
	var seen: Array[Vector3] = []
	for c in level.get_children():
		if c is Pickup:
			var p := c as Pickup
			if p.kind == "battery":
				batteries += 1
			elif p.kind == "key":
				keys += 1
			else:
				torches += 1
			for q in seen:
				if p.position.distance_to(q) < 0.35:
					overlaps += 1
			seen.append(p.position)
	eq(batteries, 5, "five battery cells placed")
	eq(keys, 1, "one key placed")
	eq(torches, 1, "one torch placed")
	eq(overlaps, 0, "no two pickups occupy the same spot")

	# the key must be reachable in the basement, not floating in the bedroom
	var key_pos := Vector3.ZERO
	for c in level.get_children():
		if c is Pickup and (c as Pickup).kind == "key":
			key_pos = c.position
	ok(key_pos.y < LevelData.BASEMENT_CEIL, "the key is down in the basement (y=%.2f)" % key_pos.y)

	# torch grant sets the flag the game gates on
	var player: Player = _main.get("player")
	GameState.set_flag("has_flashlight", false)
	for c in level.get_children():
		if c is Pickup and (c as Pickup).kind == "flashlight":
			(c as Pickup).interact(player)
	ok(player.flashlight.has_flashlight, "taking the torch grants the flashlight")
	ok(GameState.has_flag("has_flashlight"), "taking the torch sets has_flashlight")


func _test_ending() -> void:
	print("\n[ending]")
	var level: LevelBuilder = _main.get("level")
	ok(level.final_chair != null, "the chair exists")
	if level.final_chair == null:
		return

	_seq_got = ""
	_seq_count = 0
	GameState.run_sequence.connect(func(id: String) -> void:
		_seq_count += 1
		_seq_got = id)

	# first run through -> the loop ending, not the true ending
	GameState.loops_completed = 0
	level.final_chair.interact(null)
	eq(_seq_got, "final", "attempt #46 chair plays FINAL_SEQUENCE")

	# after a loop -> the true ending
	GameState.loops_completed = 1
	level.final_chair.interact(null)
	eq(_seq_got, "true_ending", "attempt #47 chair plays the TRUE_ENDING")
	eq(_seq_count, 2, "each chair press plays exactly one sequence")

	ok(Story.FINAL_SEQUENCE.size() >= 8, "final sequence has enough beats")
	ok(Story.TRUE_ENDING.size() >= 5, "true ending has enough beats")
	# the twist must land
	var joined := ""
	for beat in Story.FINAL_SEQUENCE:
		joined += str(beat.get("text", "")) + str(beat.get("caption", ""))
	ok(joined.contains("CREATURE"), "final sequence blames the creature first")
	ok(joined.contains("IT WAS THE LIGHT"), "final sequence delivers the twist")

	# and the loop must reveal the extra panel
	GameState.loops_completed = 1
	var ids: Array[String] = []
	for p in Story.active_panels():
		ids.append(str(p["id"]))
	ok(ids.has("bed_attempt"), "after a loop the ATTEMPT #47 panel appears")
	eq(ids.count("bed_attempt"), 1, "the loop panel is not duplicated")
	GameState.loops_completed = 0
	eq(Story.active_panels().size(), Story.PANELS.size() - 1, "loop panel is hidden on the first run")


# ------------------------------------------------------------- the lighting

## The house used to be lit by one torch and five omnis below 0.16 energy, i.e.
## black. These lock in the floor that makes it playable: a visible ambient fill
## and at least one working practical in every room.
func _test_lighting() -> void:
	print("\n[lighting]")
	var level: LevelBuilder = _main.get("level")

	var we := _main.find_child("*", true, false)
	var envs := 0
	for c in _main.get_children():
		if c is WorldEnvironment:
			envs += 1
	ok(envs == 1, "exactly one WorldEnvironment")
	var we_node: WorldEnvironment = null
	for c in _main.get_children():
		if c is WorldEnvironment:
			we_node = c
	if we_node == null:
		return
	var e: Environment = we_node.environment
	ok(e != null, "environment is assigned")
	if e == null:
		return
	ok(e.ambient_light_energy > 0.0, "ambient fill is not zero (%.3f)" % e.ambient_light_energy)
	ok(e.ambient_light_energy < 0.5, "ambient fill stays moody (%.3f)" % e.ambient_light_energy)
	eq(e.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR, "ambient is a flat colour fill")
	ok(not e.fog_enabled, "no fog (unsupported by GL Compatibility)")

	# every room needs somewhere to stand that is not a void
	ok(level.practicals.size() >= LevelData.ROOMS.size(),
		"at least one practical per room (%d lights, %d rooms)"
			% [level.practicals.size(), LevelData.ROOMS.size()])
	for room in LevelData.ROOMS:
		var r: Rect2 = LevelData.rect_of(room)
		var y0 := LevelData.floor_y(room)
		var y1 := y0 + LevelData.ceil_h(room)
		var lit := 0
		for p in level.practicals:
			var o: OmniLight3D = p["light"]
			if not is_instance_valid(o):
				continue
			if float(p["energy"]) <= 0.0:
				continue
			if r.has_point(Vector2(o.position.x, o.position.z)) \
					and o.position.y > y0 and o.position.y < y1:
				lit += 1
		ok(lit > 0, "room '%s' has a working practical (%d)" % [room, lit])

	# kid mode lifts the whole house without touching the design
	var base := 0.0
	for p in level.practicals:
		base += float(p["energy"])
	level.set_light_mood(true)
	var lifted := 0.0
	var wider := 0
	for p in level.practicals:
		var o: OmniLight3D = p["light"]
		lifted += o.light_energy
		if o.omni_range > float(p["range"]):
			wider += 1
	ok(lifted > base, "kid mode brightens every practical (%.2f -> %.2f)" % [base, lifted])
	ok(wider == level.practicals.size(), "kid mode widens every practical (%d)" % wider)
	level.set_light_mood(false)
	var restored := 0.0
	for p in level.practicals:
		restored += (p["light"] as OmniLight3D).light_energy
	ok(is_equal_approx(restored, base), "mood restores exactly (%.2f)" % restored)


# --------------------------------------------------------------- kid mode

## Off by default so the shipped build plays as designed; everything else has to
## apply live, from the pause menu, without restarting the attempt.
func _test_kid_mode() -> void:
	print("\n[kid mode]")
	var level: LevelBuilder = _main.get("level")
	var player: Player = _main.get("player")
	var light: Flashlight = player.flashlight
	var interactor: Interactor = player.interactor

	ok(not GameState.kid_mode, "kid mode is off by default")
	eq(interactor.reach, Interactor.REACH, "default interact reach")
	ok(is_equal_approx(light.drain_per_sec, Flashlight.DRAIN_PER_SEC), "default battery drain")
	ok(not level.rune_lock._kid_hint.visible, "rune lock keeps its answer hidden")

	# a small player must be able to find things without hunting for them. Note
	# _test_pickups already consumed the torch, so check a cell that is still lying
	# around — a consumed pickup must NOT keep glowing.
	var torch: Pickup = null
	var cell: Pickup = null
	for c in level.get_children():
		if c is Pickup:
			var p := c as Pickup
			if p.kind == "flashlight":
				torch = p
			elif p.kind == "battery" and cell == null and not p.consumed:
				cell = p
	ok(torch != null, "the torch pickup exists")
	ok(cell != null, "an uncollected battery cell exists")
	ok(not torch._glow.visible, "pickups do not glow by default")
	ok(not cell._glow.visible, "uncollected cells do not glow by default")

	# flip it on the way the pause menu does
	GameState.set_objective_key("runes")
	var before := GameState.objective
	GameState.set_kid_mode(true)
	await get_tree().process_frame

	ok(GameState.kid_mode, "kid mode turned on")
	eq(interactor.reach, Interactor.REACH_KID, "longer interact reach")
	ok(interactor.reach > Interactor.REACH, "reach actually grew (%.1f)" % interactor.reach)
	ok(light.drain_per_sec < Flashlight.DRAIN_PER_SEC,
		"battery drains slower (%.2f/s)" % light.drain_per_sec)
	ok(cell._glow.visible, "uncollected cells glow so they can be found")
	ok(not torch._glow.visible, "a picked-up torch does not glow")
	ok(level.hinted_count() > 0, "interactables were hinted (%d)" % level.hinted_count())
	# _test_rune_puzzle already solved this lock, so the hint stays hidden -- what
	# matters is that the answer is on the lock and that visibility tracks state.
	ok(level.rune_lock._kid_hint.text.contains("EYE") \
		and level.rune_lock._kid_hint.text.contains("MOON") \
		and level.rune_lock._kid_hint.text.contains("WAVE"),
		"rune lock carries the sequence (%s)" % level.rune_lock._kid_hint.text)
	ok(not level.rune_lock._kid_hint.visible, "a solved lock hides its hint")

	# the puzzle is still solvable, it just no longer requires reading a dark wall
	var kid_runes := Story.objective_for("runes")
	ok(kid_runes != before, "objective re-renders in kid mode")
	ok(kid_runes.contains("EYE") and kid_runes.contains("MOON") and kid_runes.contains("WAVE"),
		"kid objective names the sequence (%s)" % kid_runes)
	eq(GameState.objective, kid_runes, "the live objective follows the mode")
	ok(GameState.journal.any(func(t: String) -> bool: return t.contains("ARROW KEYS")),
		"the journal explains the controls")
	ok(GameState.journal.any(func(t: String) -> bool: return t.contains("1 = EYE") and t.contains("2 = MOON") and t.contains("3 = WAVE")),
		"the journal carries the dial answer")

	# the bigger UI actually got bigger
	var hud: Hud = _main.get("hud")
	var normal_size := hud._objective.get_theme_font_size("font_size")
	GameState.set_kid_mode(false)
	await get_tree().process_frame
	var small_size := hud._objective.get_theme_font_size("font_size")
	ok(normal_size > small_size, "objective text is bigger in kid mode (%d vs %d)"
		% [normal_size, small_size])
	eq(interactor.reach, Interactor.REACH, "reach restored")
	ok(not cell._glow.visible, "pickup glow cleared")
	ok(not level.rune_lock._kid_hint.visible, "rune answer hidden again")
	ok(is_equal_approx(light.drain_per_sec, Flashlight.DRAIN_PER_SEC), "drain restored")

	# and the objective goes back to the game's own wording
	ok(not GameState.objective.contains("EYE"), "objective reverts to the plain version")
