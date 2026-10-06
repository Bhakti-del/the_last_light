class_name Readable
extends Interactable
## A document lying in the world. Press E to read it; it goes into the journal.

var doc_id: String = ""
var title: String = ""
var body: String = ""
var sets_flag: String = ""
var journal_line: String = ""


static func create(p_pos: Vector3, p_data: Dictionary, accent: Color) -> Readable:
	var r := Readable.new()
	r.position = p_pos
	r.doc_id = str(p_data.get("id", "note"))
	r.title = str(p_data.get("title", "NOTE"))
	r.body = str(p_data.get("body", ""))
	r.sets_flag = str(p_data.get("flag", ""))
	r.journal_line = str(p_data.get("journal", ""))
	r.prompt = "Read"
	r.accent = accent
	return r


var accent: Color = Color(0.86, 0.82, 0.72)


func _ready() -> void:
	setup()
	var sheet := Interactable.make_box(Vector3(0.24, 0.012, 0.32), Vector3(0, 0, 0),
		accent, 0.95)
	add_child(sheet)
	# a little stack so it reads as a document, not a token
	for i in 3:
		var l := Interactable.make_box(Vector3(0.235, 0.004, 0.315),
			Vector3(randf_range(-0.006, 0.006), -0.010 - float(i) * 0.004, randf_range(-0.006, 0.006)),
			accent.darkened(0.10), 0.95)
		add_child(l)
	# ruled ink lines
	for i in 6:
		var ink := Interactable.make_box(Vector3(0.15, 0.002, 0.006),
			Vector3(0, 0.008, -0.11 + float(i) * 0.042), Color(0.15, 0.13, 0.12), 0.9)
		add_child(ink)
	Interactable.add_shape(self, Vector3(0.40, 0.42, 0.40), Vector3(0, 0, 0))
	_glow.light_color = Color(1.0, 0.95, 0.82)
	_glow_base_range = 1.15


func can_interact(_player: Player) -> bool:
	return enabled


func get_prompt(_player: Player) -> String:
	return "Read" if not consumed else "Read again"


func interact(_player: Player) -> void:
	consumed = true
	Sfx.play_2d(&"page", -8.0)
	GameState.open_document.emit(title, body)
	if sets_flag != "":
		GameState.set_flag(sets_flag)
	if journal_line != "":
		GameState.add_journal(journal_line)