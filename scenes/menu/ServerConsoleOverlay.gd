extends Control
## In-game overlay that displays server log messages streamed via Log.

const MAX_LINES: int = 500

var _subscribed: bool = false
var _line_count: int = 0

@onready var _log_output: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/LogOutput
@onready var _line_count_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/LineCountLabel


func _ready() -> void:
	visible = false


func toggle() -> void:
	visible = not visible
	if visible and not _subscribed:
		_subscribe()


func _subscribe() -> void:
	if _subscribed:
		return
	_subscribed = true
	Log.log_received.connect(_on_log_received)

	if NetworkManager.is_multiplayer_active() and not NetworkManager.is_server():
		Log._request_subscribe.rpc_id(1)


func _on_log_received(timestamp: String, level: String, source: String, message: String) -> void:
	var color: String
	match level:
		"DEBUG":
			color = "gray"
		"WARN":
			color = "yellow"
		"ERROR":
			color = "red"
		_:
			color = "white"

	var line: String = "[color=%s][%s] [%s] [%s] %s[/color]" % [color, timestamp, level, source, message]
	_log_output.append_text(line + "\n")
	_line_count += 1

	if _line_count > MAX_LINES:
		_log_output.remove_paragraph(0)
		_line_count -= 1

	_line_count_label.text = "%d / %d" % [_line_count, MAX_LINES]
