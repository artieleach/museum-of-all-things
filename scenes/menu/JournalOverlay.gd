extends Control
class_name JournalOverlay
## Wikipedia-style overlay showing journal entries and pinned items.

signal closed

const ENTRIES_PER_PAGE: int = 5
const WIKI_BLUE: String = "#0645ad"
const WIKI_GRAY: String = "#54595d"
const HEADING_RULE: String = "[color=#a2a9b1]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]"

var _current_page: int = 0
var _is_open: bool = false

@onready var _panel: PanelContainer = $PanelContainer
@onready var _content: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentLabel
@onready var _page_label: Label = $PanelContainer/MarginContainer/VBoxContainer/NavHBox/PageLabel
@onready var _prev_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/NavHBox/PrevBtn
@onready var _next_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/NavHBox/NextBtn
@onready var _close_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/CloseBtn


func _ready() -> void:
	visible = false
	_prev_btn.pressed.connect(_prev_page)
	_next_btn.pressed.connect(_next_page)
	_close_btn.pressed.connect(close)


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	visible = true
	_current_page = _max_page()
	_refresh()


func close() -> void:
	_is_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _is_open


func _max_page() -> int:
	var entries: Array = JournalManager.get_entries()
	if entries.is_empty():
		return 0
	return maxi(0, (entries.size() - 1) / ENTRIES_PER_PAGE)


func _prev_page() -> void:
	_current_page = maxi(0, _current_page - 1)
	_refresh()


func _next_page() -> void:
	_current_page = mini(_max_page(), _current_page + 1)
	_refresh()


func _refresh() -> void:
	var entries: Array = JournalManager.get_entries()
	var total: int = entries.size()
	var start: int = _current_page * ENTRIES_PER_PAGE
	var end: int = mini(start + ENTRIES_PER_PAGE, total)

	_page_label.text = "Page %d of %d" % [_current_page + 1, _max_page() + 1]
	_prev_btn.disabled = _current_page <= 0
	_next_btn.disabled = _current_page >= _max_page()

	var text: String = ""

	# Article intro
	if total == 0:
		text += "[i][color=%s]No entries yet. Visit an exhibit to begin your journal.[/color][/i]\n" % WIKI_GRAY
	else:
		text += "[color=%s][i]This journal documents [b]%d[/b] exhibit%s visited by the explorer." % [WIKI_GRAY, total, "s" if total != 1 else ""]
		text += " Showing entries %d–%d.[/i][/color]\n\n" % [start + 1, end]

	# Contents box
	if end - start > 1:
		text += "[font_size=18][b]Contents[/b][/font_size]\n"
		for i: int in range(start, end):
			var entry: Dictionary = entries[i]
			var num: int = i - start + 1
			text += "  %d  [color=%s]%s[/color]\n" % [num, WIKI_BLUE, entry.title]
		text += "\n"

	# Entries as article sections
	for i: int in range(start, end):
		var entry: Dictionary = entries[i]
		text += _format_entry(entry)

	_content.text = ""
	_content.append_text(text)


func _format_entry(entry: Dictionary) -> String:
	var date_str: String = Time.get_datetime_string_from_unix_time(int(entry.get("timestamp", 0)))
	var visit_count: int = entry.get("visit_count", 1)
	var out: String = ""

	# Section heading
	out += "[font_size=22][color=#000000]%s[/color][/font_size]\n" % entry.title
	out += HEADING_RULE + "\n"

	# Metadata line
	var meta_parts: PackedStringArray = PackedStringArray()
	meta_parts.append("First visited: %s" % date_str.substr(0, 10))
	if visit_count > 1:
		meta_parts.append("Visited %d times" % visit_count)
		var last_str: String = Time.get_datetime_string_from_unix_time(int(entry.get("last_visited", 0)))
		meta_parts.append("Last: %s" % last_str.substr(0, 10))
	out += "[font_size=14][color=%s]%s[/color][/font_size]\n" % [WIKI_GRAY, " · ".join(meta_parts)]

	# Snippet / extract
	var snippet: String = entry.get("snippet", "")
	if snippet != "":
		out += "\n"
		if snippet.length() > 200:
			out += snippet.substr(0, 200) + "..."
		else:
			out += snippet
		out += "\n"

	# Pinned items
	var pins: Array = entry.get("pinned_items", [])
	if not pins.is_empty():
		out += "\n[font_size=16][b]Pinned items[/b][/font_size]\n"
		for pin: Dictionary in pins:
			if pin.type == "image":
				out += "  [color=%s]Image[/color] – %s\n" % [WIKI_BLUE, pin.get("caption", "untitled")]
			elif pin.type == "text":
				var excerpt: String = pin.get("excerpt", "")
				if excerpt.length() > 100:
					excerpt = excerpt.substr(0, 100) + "..."
				out += "  [color=%s]Text[/color] – %s\n" % [WIKI_BLUE, excerpt]

	out += "\n"
	return out


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("strafe_left") or event.is_action_pressed("move_forward"):
		_prev_page()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("strafe_right") or event.is_action_pressed("move_back"):
		_next_page()
		get_viewport().set_input_as_handled()
