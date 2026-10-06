extends Node
## Every line of text in the game: comic panels, readable documents, objectives,
## room titles and the ending sequence. Designers edit this file and nothing else.

const GLYPHS := ["MOON", "EYE", "WAVE", "BONE"]
const GLYPH_KINDS := ["moon", "eye", "wave", "bone"]
const RUNE_SOLUTION := ["EYE", "MOON", "WAVE"]

const ROOM_TITLES := {
	"bedroom": "BEDROOM",
	"hallway": "HALLWAY",
	"storage": "STORAGE ROOM",
	"living": "LIVING ROOM",
	"basement": "BASEMENT",
	"foyer": "EXIT AREA",
	"final": "",
}

## Panels revealed only by the flashlight beam.
## Placement: `room` + `wall` (N/S/E/W) + `at` (offset along that wall).
const PANELS := [
	{
		"id": "bed_message", "room": "bedroom", "wall": "N", "at": 4.5, "h": 1.5,
		"w": 1.7, "y": 1.65, "art": "note", "paper": "card",
		"text": "DON'T LET\nTHE LIGHT DIE.",
		"journal": "A note taped to the wall in my own handwriting: “DON’T LET THE LIGHT DIE.” I have no memory of writing it.",
	},
	{
		"id": "bed_attempt", "room": "bedroom", "wall": "W", "at": 5.2, "h": 1.1,
		"w": 1.4, "y": 1.6, "art": "scrap", "paper": "cheap", "min_loop": 1,
		"sfx": "",
		"text": "ATTEMPT\n#%d",
		"journal": "Scrawled into the plaster: ATTEMPT #47. This is not the first time I have woken up here.",
	},
	{
		"id": "hall_light", "room": "hallway", "wall": "E", "at": 2.0, "h": 1.25,
		"w": 1.7, "y": 1.6, "art": "wall_panel", "paper": "newsprint",
		"caption": "THE HALLWAY",
		"text": "LIGHT IS HOW YOU SEE.\nLIGHT IS HOW IT SEES YOU.",
		"journal": "A panel burnt into the wallpaper: LIGHT IS HOW YOU SEE. LIGHT IS HOW IT SEES YOU.",
	},
	{
		"id": "hall_run", "room": "hallway", "wall": "E", "at": 6.5, "h": 1.3,
		"w": 1.6, "y": 1.6, "art": "action", "paper": "cheap",
		"sfx": "RUN!",
		"journal": "RUN! — the word is torn through the wallpaper from the inside.",
	},
	{
		"id": "hall_name", "room": "hallway", "wall": "W", "at": 6.4, "h": 1.2,
		"w": 1.7, "y": 1.55, "art": "wall_panel", "paper": "newsprint",
		"caption": "NOTE",
		"text": "IT DOESN'T NEED\nTO SEE YOU.\nIT ONLY NEEDS TO\nSEE THE LIGHT.",
		"journal": "Somebody wrote: IT DOESN’T NEED TO SEE YOU. IT ONLY NEEDS TO SEE THE LIGHT.",
	},
	{
		"id": "storage_runes", "room": "storage", "wall": "E", "at": 3.0, "h": 1.5,
		"w": 2.0, "y": 1.6, "art": "poster", "paper": "card",
		"caption": "THE ORDER",
		"text": "SET THE THREE LOCKS\nAS BELOW. THE FOURTH\nMARK IS A LIE.",
		"glyphs": true,
		"journal": "Instructions for the hatch: set the three locks as below. The fourth mark is a lie.",
	},
	{
		"id": "storage_name", "room": "storage", "wall": "W", "at": 6.2, "h": 1.2,
		"w": 1.7, "y": 1.6, "art": "wall_panel", "paper": "newsprint",
		"caption": "",
		"text": "SOMETHING DOWN\nHERE KNOWS\nMY NAME.",
		"journal": "SOMETHING DOWN HERE KNOWS MY NAME.",
	},
	{
		"id": "living_distrust", "room": "living", "wall": "N", "at": 4.2, "h": 1.35,
		"w": 1.8, "y": 1.62, "art": "wall_panel", "paper": "newsprint",
		"text": "DON'T TRUST\nTHE LIGHT.",
		"journal": "An empty wall that is not empty: DON’T TRUST THE LIGHT.",
	},
	{
		"id": "living_shadow", "room": "living", "wall": "W", "at": 13.2, "h": 1.3,
		"w": 1.8, "y": 1.6, "art": "wall_panel", "paper": "newsprint",
		"caption": "REMEMBER",
		"text": "I GOT OUT ON\nATTEMPT #17.\nI THINK.",
		"journal": "I GOT OUT ON ATTEMPT #17. I THINK. — written in my handwriting.",
	},
	{
		"id": "living_bigger", "room": "living", "wall": "E", "at": 10.5, "h": 1.2,
		"w": 1.7, "y": 1.55, "art": "memory", "paper": "newsprint",
		"caption": "...",
		"text": "THE HOUSE IS\nBIGGER INSIDE.",
		"journal": "THE HOUSE IS BIGGER INSIDE.",
	},
	{
		"id": "basement_dark", "room": "basement", "wall": "N", "at": 11.0, "h": 1.2,
		"w": 1.8, "y": 1.5, "art": "wall_panel", "paper": "basement",
		"caption": "",
		"text": "IT DOESN'T FEAR\nTHE DARK.\nIT FEARS THE BEAM.",
		"journal": "IT DOESN’T FEAR THE DARK. IT FEARS THE BEAM.",
	},
	{
		"id": "basement_lair", "room": "basement", "wall": "S", "at": 12.0, "h": 1.7,
		"w": 2.4, "y": 1.6, "art": "tally", "paper": "basement",
		"sfx": "",
		"text": "EVERY\nSINGLE TIME.",
		"journal": "The wall is covered in tally marks. Not dozens. Hundreds. In my handwriting.",
	},
	{
		"id": "basement_32", "room": "basement", "wall": "E", "at": 4.2, "h": 1.2,
		"w": 1.6, "y": 1.5, "art": "record", "paper": "basement",
		"text": "ATTEMPT #32\nI FOUND THE KEY.\nI DID NOT FIND\nTHE DOOR.",
		"journal": "ATTEMPT #32 — I FOUND THE KEY. I DID NOT FIND THE DOOR.",
	},
	{
		"id": "foyer_notout", "room": "foyer", "wall": "W", "at": 14.2, "h": 1.25,
		"w": 1.7, "y": 1.6, "art": "wall_panel", "paper": "newsprint",
		"text": "THE FRONT DOOR\nIS NOT THE WAY OUT.",
		"journal": "THE FRONT DOOR IS NOT THE WAY OUT.",
	},
	{
		"id": "foyer_chain", "room": "foyer", "wall": "E", "at": 9.3, "h": 1.2,
		"w": 1.7, "y": 1.75, "art": "wall_panel", "paper": "newsprint",
		"caption": "",
		"text": "IT CHAINS THE\nDOOR FROM\nTHE INSIDE.",
		"journal": "IT CHAINS THE DOOR FROM THE INSIDE.",
	},
	{
		"id": "final_records", "room": "final", "wall": "N", "at": 8.5, "h": 1.35,
		"w": 2.1, "y": 1.6, "art": "record", "paper": "dark",
		"text": "#01   #17\n#32   #46",
		"journal": "Four sets of initials and four numbers, cut into the plaster: #01, #17, #32, #46. All of them are mine.",
	},
	{
		"id": "final_tally", "room": "final", "wall": "S", "at": 12.5, "h": 1.8,
		"w": 2.6, "y": 1.65, "art": "tally", "paper": "dark",
		"text": "AND THEN\nIT STARTED\nAGAIN.",
		"journal": "And then it started again.",
	},
	{
		"id": "final_face", "room": "final", "wall": "W", "at": 21.0, "h": 1.4,
		"w": 1.8, "y": 1.6, "art": "memory", "paper": "dark",
		"text": "IT WAS NEVER\nTHE CREATURE\nTHAT KEPT\nYOU HERE.",
		"journal": "IT WAS NEVER THE CREATURE THAT KEPT YOU HERE.",
	},
]

## Readable documents (press E).
const NOTES := [
	{
		"id": "note_light", "room": "bedroom", "pos": Vector3(2.6, 0.72, 2.6),
		"title": "POCKET NOTE",
		"body": "RULES I WROTE DOWN FOR MYSELF.\n\n1. The torch sees for you.\n2. The torch sees for it.\n3. Spare cells are somewhere downstairs.\n4. Do not run unless you have to.\n\nIt hears running more than it sees anything.",
		"journal": "My own rules: the torch sees for you, the torch sees for it. It hears running more than it sees anything.",
		"flag": "note_light",
	},
	{
		"id": "note_01", "room": "living", "pos": Vector3(7.4, 0.55, 12.6),
		"title": "ATTEMPT #01 — HOUSE BOOK",
		"body": "Woke up in the bedroom. No memory of the door.\n\nFound the torch on the nightstand. Wrote\nDONT LET THE LIGHT DIE on the wall so I\nwould not forget it again.\n\nThere was nothing else in the house.\n\nI am writing this down to prove that\nI am the first person to think this.",
		"journal": "ATTEMPT #01 — I woke up, found the torch, wrote the message on the wall. There was nothing else in the house.",
		"flag": "attempt_01",
	},
	{
		"id": "note_17", "room": "living", "pos": Vector3(1.5, 1.78, 15.9),
		"title": "ATTEMPT #17 — HOUSE BOOK",
		"body": "I know the layout now. I know where the\npanels are. I know which words are lies.\n\nThe front door is chained from the inside.\nI am sure of it. I have tried it eleven times.\n\nIf you are reading this and the number is\nabove 17, then none of it worked for me\neither, and I am sorry.",
		"journal": "ATTEMPT #17 — I know the layout. The front door is chained from the inside. I have tried it eleven times.",
		"flag": "attempt_17",
	},
	{
		"id": "note_32", "room": "basement", "pos": Vector3(4.2, -2.58, 2.4),
		"title": "ATTEMPT #32 — HOUSE BOOK",
		"body": "Found the key under the boiler.\n\nIt does not open the front door. I tried it\nfor a long time. It opens the boarded door\nat the back of the exit hall.\n\nThe tally wall in the basement is mine.\nI stopped counting at four hundred.\n\nIf it is me down here then it is me up\nthere too, and one of us is going to\nhave a very bad night.",
		"journal": "ATTEMPT #32 — found the key. It opens the boarded door at the back, not the front door. The tally wall in the basement is mine.",
		"flag": "attempt_32",
	},
	{
		"id": "note_46", "room": "final", "pos": Vector3(11.2, 0.73, 20.4),
		"title": "ATTEMPT #46 — HOUSE BOOK",
		"body": "This is the chair. This is where I sit.\n\nThe creature is not in this room. I have\nnever once seen it in this room. That is\nthe part I cannot make fit.\n\nForty-six times I have come up those stairs.\nForty-six times I have sat in this chair.\n\nIf I sit down again I will not get up\nwith my name attached.",
		"journal": "ATTEMPT #46 — this is the chair. The creature has never once been in this room.",
		"flag": "attempt_46",
	},
]

## Objectives keyed by chapter.
const OBJECTIVES := {
	"wake": "Get up.",
	"flashlight": "Find a light. Find a way out of this room.",
	"explore": "Leave the bedroom. Stay quiet.",
	"storage": "Find a way down.",
	"runes": "Read the wall. Set the three locks.",
	"basement": "Search the basement. There is a key somewhere.",
	"return": "Get back upstairs. The front door is in the exit hall.",
	"door": "Unlock the front door.",
	"backroom": "Open the door at the back of the exit hall.",
	"final": "Sit in the chair.",
}

## Kid mode: same beats, one instruction at a time, no riddles in the wording.
## The rune lock is the one puzzle the game hides on purpose, so its answer is
## simply given away here rather than left on a panel nobody will find.
const OBJECTIVES_KID := {
	"wake": "1. Get out of bed.",
	"flashlight": "2. Pick up the flashlight on the little table.",
	"explore": "3. Walk out of the bedroom. Do not run.",
	"storage": "4. Find the wooden stairs going down.",
	"runes": "5. Turn the three dials to EYE, then MOON, then WAVE. Pull the lever.",
	"basement": "6. Look around the basement for a key.",
	"return": "7. Go back upstairs to the exit hall.",
	"door": "8. The front door will not open. Find another door.",
	"backroom": "9. Open the door at the back of the exit hall.",
	"final": "10. Sit in the chair to finish the game.",
}

const FINAL_SEQUENCE := [
	{"art": "record", "paper": "dark", "caption": "ATTEMPT #01", "text": "THE FIRST TIME, YOU FOUND\nTHE HOUSE EMPTY.", "hold": 2.6},
	{"art": "memory", "paper": "dark", "caption": "ATTEMPT #17", "text": "YOU GOT AS FAR AS\nTHE DOOR.", "hold": 2.4},
	{"art": "memory", "paper": "dark", "caption": "ATTEMPT #32", "text": "YOU GOT AS FAR AS\nTHE BASEMENT.", "hold": 2.4},
	{"art": "tally", "paper": "dark", "caption": "ATTEMPT #46", "text": "YOU GOT AS FAR AS\nTHIS CHAIR.", "hold": 2.6},
	{"art": "record", "paper": "dark", "caption": "", "text": "AND THEN YOU\nWOKE UP AGAIN.", "hold": 2.4},
	{"art": "action", "paper": "dark", "sfx": "BANG!", "text": "", "hold": 2.0},
	{"art": "memory", "paper": "dark", "caption": "", "text": "IT WAS NEVER THE CREATURE\nTHAT KEPT YOU HERE.", "hold": 2.8},
	{"art": "wall_panel", "paper": "dark", "caption": "", "text": "IT WAS THE LIGHT.", "hold": 2.6},
	{"art": "wall_panel", "paper": "dark", "caption": "", "text": "YOU HAVE BEEN\nHERE BEFORE.", "hold": 4.2, "big": true},
]

const TRUE_ENDING := [
	{"art": "wall_panel", "paper": "dark", "caption": "ATTEMPT #47", "text": "YOU KEPT THE LIGHT ON\nTHE WHOLE WAY.", "hold": 2.6},
	{"art": "wall_panel", "paper": "dark", "caption": "", "text": "YOU READ EVERY PANEL.", "hold": 2.4},
	{"art": "memory", "paper": "dark", "caption": "", "text": "AND THE HOUSE LET YOU\nOUT OF THE BASEMENT,\nNOT OUT OF ITSELF.", "hold": 3.0},
	{"art": "action", "paper": "dark", "sfx": "LIGHT!", "text": "", "hold": 2.2},
	{"art": "wall_panel", "paper": "dark", "caption": "", "text": "THE LIGHT IS YOU.", "hold": 4.0, "big": true},
	{"art": "record", "paper": "dark", "caption": "ATTEMPT #48", "text": "SOMEBODY ELSE\nWILL FIND THE TORCH.", "hold": 4.0},
]


func get_panel(id: String) -> Dictionary:
	for p in PANELS:
		if p["id"] == id:
			return p
	return {}


func get_note(id: String) -> Dictionary:
	for n in NOTES:
		if n["id"] == id:
			return n
	return {}


func objective_for(key: String) -> String:
	if GameState.kid_mode and OBJECTIVES_KID.has(key):
		return str(OBJECTIVES_KID[key])
	return str(OBJECTIVES.get(key, ""))


## Panel ids that should exist for the current attempt.
func active_panels() -> Array:
	var out: Array = []
	for p in PANELS:
		if int(p.get("min_loop", 0)) <= GameState.loops_completed:
			out.append(p)
	return out