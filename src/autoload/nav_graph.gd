extends Node
## Waypoint graph + A* used by the creature.
## Chosen over a baked NavigationMesh because it is deterministic, cheap,
## exports cleanly to web, and lets level designers place patrol routes by hand.

const LINK_RADIUS := 5.0

class Point extends RefCounted:
	var id: int
	var pos: Vector3
	var zone: String
	var node: Node
	var links: PackedInt32Array = PackedInt32Array()
	var forced: PackedInt32Array = PackedInt32Array()

	func _init(p_id: int, p_pos: Vector3, p_zone: String, p_node: Node) -> void:
		id = p_id
		pos = p_pos
		zone = p_zone
		node = p_node


var _points: Array[Point] = []
var _forced_pairs: Array = []


func clear() -> void:
	_points.clear()
	_forced_pairs.clear()


func add_point(pos: Vector3, zone: String = "ground", node: Node = null) -> int:
	var p := Point.new(_points.size(), pos, zone, node)
	_points.append(p)
	return p.id


func force_link(a: Vector3, b: Vector3) -> void:
	_forced_pairs.append([a, b])


func rebuild() -> void:
	for p in _points:
		p.links = PackedInt32Array()
	for i in _points.size():
		for j in range(i + 1, _points.size()):
			var a := _points[i]
			var b := _points[j]
			if a.zone == b.zone and a.pos.distance_to(b.pos) <= LINK_RADIUS:
				_link(i, j)
	for pair in _forced_pairs:
		var i := nearest_index(pair[0])
		var j := nearest_index(pair[1])
		if i >= 0 and j >= 0 and i != j:
			_link(i, j)


func _link(i: int, j: int) -> void:
	var a := _points[i]
	var b := _points[j]
	if not a.links.has(j):
		a.links.append(j)
	if not b.links.has(i):
		b.links.append(i)


func size() -> int:
	return _points.size()


func point_pos(i: int) -> Vector3:
	if i < 0 or i >= _points.size():
		return Vector3.ZERO
	return _points[i].pos


## Nearest waypoint, biased to the same floor so the creature never paths
## through the basement ceiling (or tries to climb to it).
func nearest_index(pos: Vector3, prefer_zone: String = "") -> int:
	var best := -1
	var best_score := INF
	for p in _points:
		var score: float = p.pos.distance_to(pos)
		if prefer_zone != "" and p.zone != prefer_zone:
			score += 1000.0
		# heavily penalise a different storey
		score += absf(p.pos.y - pos.y) * 6.0
		if score < best_score:
			best_score = score
			best = p.id
	return best


func zone_of(pos: Vector3) -> String:
	var i := nearest_index(pos)
	return _points[i].zone if i >= 0 else "ground"


## A* over the waypoint graph. Returns waypoints excluding the start point.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := _points.size()
	if n == 0:
		return out
	var start := nearest_index(from)
	var goal := nearest_index(to)
	if start < 0 or goal < 0:
		return out
	if start == goal:
		out.append(_points[goal].pos)
		return out

	var g_score := PackedFloat32Array()
	g_score.resize(n)
	g_score.fill(INF)
	var f_score := PackedFloat32Array()
	f_score.resize(n)
	f_score.fill(INF)
	var came := PackedInt32Array()
	came.resize(n)
	came.fill(-1)
	var closed := {}
	var open := PackedInt32Array([start])

	g_score[start] = 0.0
	f_score[start] = _points[start].pos.distance_to(_points[goal].pos)

	while open.size() > 0:
		# linear scan is fine: the graph is < 100 nodes
		var bi := 0
		for i in open.size():
			if f_score[open[i]] < f_score[open[bi]]:
				bi = i
		var cur: int = open[bi]
		open.remove_at(bi)

		if cur == goal:
			_reconstruct(cur, came, from, out)
			return out

		if closed.has(cur):
			continue
		closed[cur] = true

		for nb in _points[cur].links:
			if closed.has(nb):
				continue
			# vertical links cost more so the creature prefers flat routes
			var step: float = _points[cur].pos.distance_to(_points[nb].pos)
			if absf(_points[cur].pos.y - _points[nb].pos.y) > 0.8:
				step *= 1.6
			var tentative: float = g_score[cur] + step
			if tentative < g_score[nb]:
				came[nb] = cur
				g_score[nb] = tentative
				f_score[nb] = tentative + _points[nb].pos.distance_to(_points[goal].pos)
				if not open.has(nb):
					open.append(nb)
	return out


func _reconstruct(goal: int, came: PackedInt32Array, from: Vector3, out: PackedVector3Array) -> void:
	var chain: Array[int] = []
	var cur := goal
	var guard := 0
	while cur != -1 and guard < 256:
		chain.push_front(cur)
		cur = came[cur]
		guard += 1
	for id in chain:
		var p := _points[id]
		if p.pos.distance_to(from) > 0.6:
			out.append(p.pos)


## A random waypoint in `zone`, optionally within `radius` of `near`.
func random_point(zone: String, near: Vector3 = Vector3.ZERO, radius: float = 0.0) -> Vector3:
	var candidates: Array[Vector3] = []
	for p in _points:
		if p.zone != zone:
			continue
		if radius > 0.0 and p.pos.distance_to(near) > radius:
			continue
		candidates.append(p.pos)
	if candidates.is_empty():
		for p in _points:
			candidates.append(p.pos)
	if candidates.is_empty():
		return Vector3.ZERO
	return candidates[randi() % candidates.size()]