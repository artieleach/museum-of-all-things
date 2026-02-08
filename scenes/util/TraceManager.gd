extends Node
## Persists ghost silhouettes and guestbook messages per exhibit.

signal ghost_placed(exhibit_title: String, pos: Vector3)
signal guestbook_message_added(exhibit_title: String, message: String)

const TRACE_FILE: String = "user://visitor_traces.json"
const MAX_GHOSTS_PER_EXHIBIT: int = 20
const MAX_MESSAGES_PER_EXHIBIT: int = 50

var _data: Dictionary = {}  # exhibit_title -> { ghosts: [], messages: [] }


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(TRACE_FILE):
		return
	var file: FileAccess = FileAccess.open(TRACE_FILE, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_data = parsed


func _save() -> void:
	var file: FileAccess = FileAccess.open(TRACE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data))
		file.close()


func _ensure_exhibit(title: String) -> void:
	if not _data.has(title):
		_data[title] = {"ghosts": [], "messages": []}


func add_ghost(exhibit_title: String, pos: Vector3, rot_y: float) -> void:
	_ensure_exhibit(exhibit_title)
	var ghosts: Array = _data[exhibit_title].ghosts
	ghosts.append({"x": pos.x, "y": pos.y, "z": pos.z, "rot_y": rot_y, "time": Time.get_unix_time_from_system()})
	while ghosts.size() > MAX_GHOSTS_PER_EXHIBIT:
		ghosts.pop_front()
	_save()
	ghost_placed.emit(exhibit_title, pos)


func get_ghosts(exhibit_title: String) -> Array:
	if _data.has(exhibit_title) and _data[exhibit_title].has("ghosts"):
		return _data[exhibit_title].ghosts
	return []


func add_guestbook_message(exhibit_title: String, player_name: String, message: String) -> void:
	_ensure_exhibit(exhibit_title)
	var messages: Array = _data[exhibit_title].messages
	messages.append({
		"name": player_name,
		"text": message.substr(0, 140),
		"time": Time.get_unix_time_from_system(),
	})
	while messages.size() > MAX_MESSAGES_PER_EXHIBIT:
		messages.pop_front()
	_save()
	guestbook_message_added.emit(exhibit_title, message)


func get_messages(exhibit_title: String) -> Array:
	if _data.has(exhibit_title) and _data[exhibit_title].has("messages"):
		return _data[exhibit_title].messages
	return []
