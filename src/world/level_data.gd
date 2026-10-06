class_name LevelData
extends RefCounted
## The house, as data. Ground floor at y = 0, basement at y = BASEMENT_Y.
##
##            x=0        9      15      24
##   z=0   +---------+-------+--------+
##         | BEDROOM | HALL  | STORAGE|      hatch -> BASEMENT (below storage)
##   z=8   +---------+-------+--------+
##         |      LIVING ROOM       |      z=17 wall holds the FINAL ROOM door
##   z=17  +---------------------+---+
##         |      FINAL ROOM      |        front door on the foyer east wall
##   z=24  +---------------------+

const WALL := 0.30
const BASEMENT_Y := -3.6
const BASEMENT_CEIL := -0.35
## Height of every doorway opening. Walls are built solid to the ceiling and a
## lintel fills the strip above this, so gaps never read as floor-to-ceiling holes.
const DOOR_H := 2.15

const ROOMS := {
	"bedroom": {"rect": Rect2(0, 0, 9, 8), "h": 2.85, "floor": "wood"},
	"hallway": {"rect": Rect2(9, 0, 6, 8), "h": 2.55, "floor": "wood"},
	"storage": {"rect": Rect2(15, 0, 9, 8), "h": 3.10, "floor": "concrete"},
	"living": {"rect": Rect2(0, 8, 15, 9), "h": 3.15, "floor": "wood"},
	"foyer": {"rect": Rect2(15, 8, 9, 9), "h": 3.15, "floor": "wood"},
	"final": {"rect": Rect2(5, 17, 15, 7), "h": 3.30, "floor": "wood"},
	"basement": {"rect": Rect2(1, 1, 22, 6), "h": 3.30, "floor": "concrete"},
}

## Doorways cut through room boundaries. Every interior doorway needs an entry on
## BOTH sides, because each room builds its own shell and the two shells overlap
## on the shared wall line.
const GAPS := [
	# bedroom <-> hallway  (wall x = 9)
	{"a": "bedroom", "wall": "E", "gap": Rect2(3.4, 4.7, 1, 1)},
	{"a": "hallway", "wall": "W", "gap": Rect2(3.4, 4.7, 1, 1)},
	# hallway <-> storage  (wall x = 15)
	{"a": "hallway", "wall": "E", "gap": Rect2(3.4, 4.7, 1, 1)},
	{"a": "storage", "wall": "W", "gap": Rect2(3.4, 4.7, 1, 1)},
	# hallway <-> living room  (wall z = 8)
	{"a": "hallway", "wall": "S", "gap": Rect2(11.4, 12.7, 1, 1)},
	{"a": "living", "wall": "N", "gap": Rect2(11.4, 12.7, 1, 1)},
	# living room <-> foyer  (wall x = 15)
	{"a": "living", "wall": "E", "gap": Rect2(11.4, 12.7, 1, 1)},
	{"a": "foyer", "wall": "W", "gap": Rect2(11.4, 12.7, 1, 1)},
	# foyer <-> final room  (wall z = 17)
	{"a": "foyer", "wall": "S", "gap": Rect2(16.8, 18.2, 1, 1)},
	{"a": "final", "wall": "N", "gap": Rect2(16.8, 18.2, 1, 1)},
	# foyer -> the street (wall x = 24)
	{"a": "foyer", "wall": "E", "gap": Rect2(11.75, 13.05, 1, 1)},
]

const HATCH := Rect2(18.8, 1.9, 2.4, 4.4)
const SPAWN := Vector3(5.6, 0.10, 6.4)
const SPAWN_YAW := 0.0

## Waypoints the creature can use. Ground floor and basement are separate
## graphs joined only by the stairs.
const NAV_POINTS := [
	# ground floor
	[Vector3(4.5, 0.0, 3.0), "ground"], [Vector3(4.5, 0.0, 6.6), "ground"],
	[Vector3(11.8, 0.0, 2.0), "ground"], [Vector3(11.8, 0.0, 4.6), "ground"],
	[Vector3(11.8, 0.0, 7.0), "ground"], [Vector3(13.4, 0.0, 4.6), "ground"],
	[Vector3(17.2, 0.0, 2.0), "ground"], [Vector3(17.2, 0.0, 4.6), "ground"],
	[Vector3(17.2, 0.0, 7.0), "ground"], [Vector3(22.0, 0.0, 2.2), "ground"],
	[Vector3(22.0, 0.0, 6.6), "ground"], [Vector3(20.0, 0.0, 4.6), "ground"],
	[Vector3(12.0, 0.0, 10.0), "ground"], [Vector3(12.0, 0.0, 14.5), "ground"],
	[Vector3(6.0, 0.0, 10.0), "ground"], [Vector3(6.0, 0.0, 15.0), "ground"],
	[Vector3(1.8, 0.0, 11.5), "ground"], [Vector3(13.0, 0.0, 11.8), "ground"],
	[Vector3(17.4, 0.0, 10.0), "ground"], [Vector3(17.4, 0.0, 14.5), "ground"],
	[Vector3(22.0, 0.0, 12.4), "ground"], [Vector3(19.5, 0.0, 12.4), "ground"],
	[Vector3(9.0, 0.0, 19.0), "ground"], [Vector3(12.5, 0.0, 19.4), "ground"],
	[Vector3(16.0, 0.0, 19.0), "ground"], [Vector3(12.5, 0.0, 22.6), "ground"],
	# basement
	[Vector3(4.0, -3.6, 2.4), "basement"], [Vector3(8.0, -3.6, 2.4), "basement"],
	[Vector3(8.0, -3.6, 5.6), "basement"], [Vector3(12.0, -3.6, 2.4), "basement"],
	[Vector3(12.0, -3.6, 5.6), "basement"], [Vector3(16.0, -3.6, 2.4), "basement"],
	[Vector3(16.0, -3.6, 5.6), "basement"], [Vector3(20.5, -3.6, 2.6), "basement"],
	[Vector3(20.5, -3.6, 5.4), "basement"], [Vector3(20.0, -3.6, 5.7), "basement"],
	[Vector3(19.9, -3.6, 2.0), "basement"],
]

## Stair top / bottom pair — the only link between floors.
const STAIR_TOP := Vector3(20.0, 0.0, 2.3)
const STAIR_BOTTOM := Vector3(20.0, -3.6, 5.9)

const CREATURE_SPAWN := Vector3(20.5, -3.55, 6.4)
const PATROL_HOME := "basement"


static func rect_of(room: String) -> Rect2:
	return ROOMS[room]["rect"]


static func floor_y(room: String) -> float:
	return BASEMENT_Y if room == "basement" else 0.0


static func ceil_h(room: String) -> float:
	return float(ROOMS[room]["h"])


## Resolve a panel's room + wall spec into a world position and yaw.
static func wall_anchor(room: String, wall: String, along: float, height: float) -> Array:
	var r: Rect2 = rect_of(room)
	var y := floor_y(room)
	var eps := WALL * 0.5 + 0.012
	match wall:
		"N":
			return [Vector3(along, y + height, r.position.y + eps), 0.0]
		"S":
			return [Vector3(along, y + height, r.end.y - eps), PI]
		"W":
			return [Vector3(r.position.x + eps, y + height, along), PI * 0.5]
		"E":
			return [Vector3(r.end.x - eps, y + height, along), -PI * 0.5]
		_:
			return [Vector3(along, y + height, r.position.y + eps), 0.0]