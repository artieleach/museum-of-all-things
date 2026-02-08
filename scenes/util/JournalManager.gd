extends Node
## Persistent explorer's journal. Auto-logs exhibit visits, supports pinning items.

signal entry_added(entry: Dictionary)
signal item_pinned(title: String, item: Dictionary)

const MAX_ENTRIES: int = 500
const JOURNAL_NS: String = "journal"

var _entries: Array = []
var _entry_map: Dictionary = {}  # title -> entry index for quick lookup


func _ready() -> void:
	_load()
	SettingsEvents.set_current_room.connect(_on_room_changed)


func _load() -> void:
	var data: Variant = SettingsManager.get_settings(JOURNAL_NS)
	if data is Dictionary and data.has("entries"):
		_entries = data.entries
		for i: int in _entries.size():
			_entry_map[_entries[i].title] = i


func _save() -> void:
	SettingsManager.save_settings(JOURNAL_NS, {"entries": _entries})


func _on_room_changed(title: String) -> void:
	if title == "Lobby" or title.is_empty():
		return
	add_visit(title)


func add_visit(title: String) -> void:
	if _entry_map.has(title):
		# Update visit count and timestamp
		var idx: int = _entry_map[title]
		_entries[idx].visit_count = _entries[idx].get("visit_count", 1) + 1
		_entries[idx].last_visited = Time.get_unix_time_from_system()
		_save()
		return

	# Get snippet from ExhibitFetcher result if available
	var snippet: String = ""
	var result: Variant = ExhibitFetcher.get_result(title)
	if result and result.has("extract"):
		snippet = result.extract.substr(0, 200)

	var entry: Dictionary = {
		"title": title,
		"snippet": snippet,
		"timestamp": Time.get_unix_time_from_system(),
		"last_visited": Time.get_unix_time_from_system(),
		"visit_count": 1,
		"pinned_items": [],
	}

	_entries.append(entry)
	_entry_map[title] = _entries.size() - 1

	# Enforce max entries (remove oldest)
	while _entries.size() > MAX_ENTRIES:
		var removed: Dictionary = _entries.pop_front()
		_entry_map.erase(removed.title)
		# Rebuild indices
		for i: int in _entries.size():
			_entry_map[_entries[i].title] = i

	_save()
	entry_added.emit(entry)


func pin_item(exhibit_title: String, item_type: String, item_data: Dictionary) -> void:
	if not _entry_map.has(exhibit_title):
		add_visit(exhibit_title)

	var idx: int = _entry_map[exhibit_title]
	var pinned: Dictionary = {
		"type": item_type,
		"caption": item_data.get("caption", ""),
	}
	if item_type == "image":
		pinned.url = item_data.get("url", "")
	elif item_type == "text":
		pinned.excerpt = item_data.get("excerpt", "").substr(0, 300)

	_entries[idx].pinned_items.append(pinned)

	# Limit pins per entry
	if _entries[idx].pinned_items.size() > 20:
		_entries[idx].pinned_items = _entries[idx].pinned_items.slice(-20)

	_save()
	item_pinned.emit(exhibit_title, pinned)


func get_entries() -> Array:
	return _entries


func get_entry(title: String) -> Variant:
	if _entry_map.has(title):
		return _entries[_entry_map[title]]
	return null


func get_entry_count() -> int:
	return _entries.size()
