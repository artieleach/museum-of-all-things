extends Control
class_name GuestbookOverlay
## Read/write UI for the guestbook.

signal message_submitted(exhibit_title: String, message: String)

var _exhibit_title: String = ""
var _is_open: bool = false

@onready var _messages_label: RichTextLabel = $PanelContainer/VBoxContainer/MessagesLabel
@onready var _input_field: LineEdit = $PanelContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var _submit_btn: Button = $PanelContainer/VBoxContainer/HBoxContainer/SubmitBtn
@onready var _close_btn: Button = $PanelContainer/CloseBtn


func _ready() -> void:
	visible = false
	_submit_btn.pressed.connect(_submit)
	_close_btn.pressed.connect(close)
	_input_field.text_submitted.connect(_on_text_submitted)


func open(exhibit_title: String) -> void:
	_exhibit_title = exhibit_title
	_is_open = true
	visible = true
	_refresh()
	_input_field.grab_focus()


func close() -> void:
	_is_open = false
	visible = false


func is_open() -> bool:
	return _is_open


func _on_text_submitted(_text: String) -> void:
	_submit()


func _submit() -> void:
	var msg: String = _input_field.text.strip_edges()
	if msg.is_empty() or msg.length() > 140:
		return
	_input_field.text = ""

	var player_name: String = NetworkManager.local_player_name if NetworkManager.local_player_name != "" else "Anonymous"
	TraceManager.add_guestbook_message(_exhibit_title, player_name, msg)
	message_submitted.emit(_exhibit_title, msg)
	_refresh()


func _refresh() -> void:
	var messages: Array = TraceManager.get_messages(_exhibit_title)
	var text: String = "[b][font_size=24]Guestbook - %s[/font_size][/b]\n\n" % _exhibit_title

	if messages.is_empty():
		text += "[i]No messages yet. Be the first to write![/i]"
	else:
		# Show latest messages first
		var start: int = maxi(0, messages.size() - 20)
		for i: int in range(messages.size() - 1, start - 1, -1):
			var msg: Dictionary = messages[i]
			text += "[b]%s[/b]: %s\n" % [msg.get("name", "?"), msg.get("text", "")]

	_messages_label.text = ""
	_messages_label.append_text(text)


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
