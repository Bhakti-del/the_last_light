extends Node
## Headless flow test. Run with:
##   godot --headless res://tests/flow_test.tscn
##
## Boots the real main scene and verifies the critical game paths:
## house builds, rune puzzle works, hatch opens, key opens back door,
## creature paths between floors, chair triggers ending.

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

	_node_count = 0
	_stack(world)
	ok(_node_count > 300, "level is actually built (%d nodes)" % _node_count)
	ok(_node_count < 4000, "node count is web-safe (%d)" % _node_count)

	eq(level.panels.size(), Story.active_panels().size(), "every active panel placed")
	ok(level.front_door != null, "front door built")
	ok(level.back_door != null, "back door built")
	ok(level.rune_lock != null, "rune lock built")
	ok(level.hatch_pivot != null, "hatch built")

	# player must not spawn inside geometry
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 1.4, 0),
		player.global_position + Vector3(0, 0.1, 0))
	q.collision_mask = 1 << 0
	ok(space.intersect_ray(q).is_empty(), "player spawns with headroom")

	var down := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 0.5, 0),
		player.global_position + Vector3(0, -1.0, 0))
	down.collision_mask = 1 << 0
	ok(not space.intersect_ray(down).is_empty(), "player spawns on a floor")


func _stack(n: Node) -> void:
	_node_count += 1
	for c in n.get_children():
		_stack(c)


# ------------------------------------------------------- the light puzzle

func _test_rune_puzzle() -> void:
	print("\n[rune puzzle]")
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

	# invisible with torch off
	for i in 4:
		await get_tree().process_frame
	ok(clue._reveal <= 0.001, "clue invisible with torch off (reveal=%.3f)" % clue._reveal)

	# light it up
	light.has_flashlight = true
	light.battery = 100.0
	light.is_on = true
	player.global_position = clue.global_position + Vector3(0.0, -clue.global_position.y, 2.4)
	await get_tree().physics_frame
	player.look_at_point(clue.global_position)
	for i in 30:
		await get_tree().process_frame
	ok(clue._reveal > 0.5, "clue reveals under the beam (reveal=%.3f)" % clue._reveal)

	light.is_on = false
	for i in 120:
		await get_tree().process_frame
	ok(clue._reveal < 0.05, "clue fades when torch off (%.3f)" % clue._reveal)
	light.is_on = true
	for i in 60:
		await get_tree().process_frame

	# solution correctness
	eq(Story.RUNE_SOLUTION[0], "EYE",  "rune solution: dial 1 = EYE")
	eq(Story.RUNE_SOLUTION[1], "MOON", "rune solution: dial 2 = MOON")
	eq(Story.RUNE_SOLUTION[2], "WAVE", "rune solution: dial 3 = WAVE")

	# set dials to solution and pull lever
	for i in 3:
		while Story.GLYPHS[lock.dials[i]] != Story.RUNE_SOLUTION[i]:
			lock.rotate_dial(i)
	lock._on_lever(player)
	await get_tree().process_frame
	ok(lock.solved_state, "lever solves the lock")
	ok(GameState.has_flag("hatch_open"), "solving sets hatch_open flag")

	# hatch cover must disappear
	await get_tree().physics_frame
	ok(not level.hatch_pivot.visible, "hatch cover becomes invisible after solving")

	# Player must physically descend into the basement after the hatch opens.
	var player2: Player = _main.get("player")
	var h2: Rect2 = LevelData.HATCH
	player2.global_position = Vector3(h2.position.x + h2.size.x * 0.5, 0.5, h2.position.y + 0.5)
	player2.velocity = Vector3.ZERO
	player2.can_move = true
	for i in 180:
		await get_tree().physics_frame
	ok(player2.global_position.y < -1.0,
		"player descends into basement via ramp (y=%.2f)" % player2.global_position.y)


# -------------------------------------------------------------- the doors

func _test_doors() -> void:
	print("\n[doors]")
	var level: LevelBuilder = _main.get("level")
	var player: Player = _main.get("player")

	# front door is a permanent dead end
	ok(level.front_door.locked, "front door is permanently locked")
	level.front_door.interact(player)
	ok(not level.front_door.is_open, "front door refuses to open")

	# back door needs the key
	GameState.set_flag("has_back_key", false)
	level.back_door.refresh_lock()
	ok(level.back_door.locked, "back door locked without key")
	GameState.set_flag("has_back_key", true)
	await get_tree().process_frame
	ok(not level.back_door.locked, "back door unlocks when key is taken")
	level.back_door.interact(player)
	ok(level.back_door.is_open, "back door opens with key")


# ------------------------------------------------------------- navigation

func _test_navigation() -> void:
	print("\n[navigation]")
	eq(NavGraph.size(), LevelData.NAV_POINTS.size(), "all waypoints registered")

	var up := NavGraph.find_path(LevelData.STAIR_BOTTOM, LevelData.STAIR_TOP)
	ok(up.size() > 0, "creature can path from basement up stairs (%d hops)" % up.size())

	var down := NavGraph.find_path(LevelData.STAIR_TOP, Vector3(12.5, 0.0, 20.5))
	ok(down.size() > 0, "creature can path to final room (%d hops)" % down.size())

	var cross := NavGraph.find_path(Vector3(4.0, -3.6, 2.4), Vector3(6.0, 0.0, 15.0))
	ok(cross.size() > 0, "creature can path basement -> living room (%d hops)" % cross.size())


# ----------------------------------------------------------- pickups

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
	eq(overlaps, 0, "no two pickups overlap")

	var key_pos := Vector3.ZERO
	for c in level.get_children():
		if c is Pickup and (c as Pickup).kind == "key":
			key_pos = c.position
	ok(key_pos.y < LevelData.BASEMENT_CEIL, "key is in the basement (y=%.2f)" % key_pos.y)

	var player: Player = _main.get("player")
	for c in level.get_children():
		if c is Pickup and (c as Pickup).kind == "flashlight":
			(c as Pickup).interact(player)
	ok(player.flashlight.has_flashlight, "picking up torch grants flashlight")


# --------------------------------------------------------------- ending

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

	GameState.loops_completed = 0
	level.final_chair.interact(null)
	eq(_seq_got, "final", "first run chair plays FINAL_SEQUENCE")

	GameState.loops_completed = 1
	level.final_chair.interact(null)
	eq(_seq_got, "true_ending", "second run chair plays TRUE_ENDING")
	eq(_seq_count, 2, "each chair press plays exactly one sequence")

	ok(Story.FINAL_SEQUENCE.size() >= 8, "final sequence has enough beats")
	ok(Story.TRUE_ENDING.size() >= 5, "true ending has enough beats")

	var joined := ""
	for beat in Story.FINAL_SEQUENCE:
		joined += str(beat.get("text", "")) + str(beat.get("caption", ""))
	ok(joined.contains("CREATURE"), "final sequence mentions the creature")
	ok(joined.contains("IT WAS THE LIGHT"), "final sequence delivers the twist")

	GameState.loops_completed = 1
	var ids: Array[String] = []
	for p in Story.active_panels():
		ids.append(str(p["id"]))
	ok(ids.has("bed_attempt"), "after a loop the attempt panel appears")
	GameState.loops_completed = 0


# ------------------------------------------------------------- lighting

func _test_lighting() -> void:
	print("\n[lighting]")
	var level: LevelBuilder = _main.get("level")

	var envs := 0
	var we_node: WorldEnvironment = null
	for c in _main.get_children():
		if c is WorldEnvironment:
			envs += 1
			we_node = c
	ok(envs == 1, "exactly one WorldEnvironment")
	if we_node == null:
		return
	var e: Environment = we_node.environment
	ok(e != null, "environment is assigned")
	if e == null:
		return
	ok(e.ambient_light_energy > 0.0, "ambient fill is not zero (%.3f)" % e.ambient_light_energy)
	ok(e.ambient_light_energy < 0.5, "ambient fill stays moody (%.3f)" % e.ambient_light_energy)

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
