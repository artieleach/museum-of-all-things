extends Control

signal resume
signal settings
signal vr_controls
signal return_to_lobby
signal teleport_to_player(peer_id: int)

@onready var vbox = $MarginContainer/VBoxContainer
@onready var _xr = Util.is_xr()
@onready var player_list_section = $MarginContainer/VBoxContainer/PlayerListSection
@onready var player_list = %PlayerList
@onready var teleport_button = %TeleportButton

var _player_peer_ids: Array = []  # Maps ItemList indices to peer_ids

func _on_visibility_changed():
	if visible and vbox:
		vbox.get_node("Resume").grab_focus()
		_update_player_list_visibility()
		if player_list_section.visible:
			_update_player_list()

func _ready():
	GlobalMenuEvents.set_current_room.connect(set_current_room)
	GlobalMenuEvents.ui_cancel_pressed.connect(ui_cancel_pressed)
	GlobalMenuEvents.multiplayer_started.connect(_on_multiplayer_started)
	GlobalMenuEvents.multiplayer_ended.connect(_on_multiplayer_ended)
	NetworkManager.peer_connected.connect(_on_peer_changed)
	NetworkManager.peer_disconnected.connect(_on_peer_changed)
	NetworkManager.player_info_updated.connect(_on_peer_changed)
	set_current_room(current_room)

	# opening page in a browser outside VR is confusing
	if _xr:
		$MarginContainer/VBoxContainer/Open.visible = false

	if Util.is_web():
		%AskQuit.visible = false

	_update_player_list_visibility()

func ui_cancel_pressed():
	if visible:
		call_deferred("_on_resume_pressed")

var current_room = "$Lobby"
func set_current_room(room):
	current_room = room
	vbox.get_node("Title").text = current_room.replace("$", "") + ((" - " + tr("Paused")) if not _xr else "")
	vbox.get_node("Open").disabled = current_room.begins_with("$")
	$MarginContainer/VBoxContainer/Language.visible = current_room == "$Lobby"

func _on_resume_pressed():
	emit_signal("resume")

func _on_settings_pressed():
	emit_signal("settings")

func _on_lobby_pressed():
	emit_signal("return_to_lobby")

func _on_open_pressed():
	var lang = TranslationServer.get_locale()
	OS.shell_open("https://" + lang + ".wikipedia.org/wiki/" + current_room)

func _on_quit_pressed():
	GlobalMenuEvents.emit_quit_requested()

func _on_ask_quit_pressed():
	if not _xr:
		_on_quit_pressed()
	else:
		$MarginContainer/VBoxContainer.visible = false
		$MarginContainer/QuitContainer.visible = true
		$MarginContainer/QuitContainer/Quit.grab_focus()

func _on_cancel_quit_pressed():
	$MarginContainer/QuitContainer.visible = false
	$MarginContainer/VBoxContainer.visible = true
	$MarginContainer/VBoxContainer/Resume.grab_focus()

func _on_vr_controls_pressed() -> void:
	emit_signal("vr_controls")

func _update_player_list_visibility() -> void:
	if player_list_section:
		player_list_section.visible = NetworkManager.is_multiplayer_active()

func _on_multiplayer_started() -> void:
	_update_player_list_visibility()

func _on_multiplayer_ended() -> void:
	_update_player_list_visibility()

func _on_peer_changed(_id = null) -> void:
	if visible and player_list_section.visible:
		_update_player_list()

func _update_player_list() -> void:
	player_list.clear()
	_player_peer_ids.clear()
	teleport_button.disabled = true

	for peer_id in NetworkManager.get_player_list():
		var player_name = NetworkManager.get_player_name(peer_id)
		var suffix = " (Host)" if peer_id == 1 else ""
		var you_suffix = " (You)" if peer_id == NetworkManager.get_unique_id() else ""
		var idx = player_list.add_item(player_name + suffix + you_suffix)
		player_list.set_item_custom_fg_color(idx, NetworkManager.get_player_color(peer_id))
		_player_peer_ids.append(peer_id)

func _on_player_list_item_selected(index: int) -> void:
	if index >= 0 and index < _player_peer_ids.size():
		var peer_id = _player_peer_ids[index]
		# Disable teleport if selecting self
		teleport_button.disabled = (peer_id == NetworkManager.get_unique_id())
	else:
		teleport_button.disabled = true

func _on_teleport_pressed() -> void:
	var selected = player_list.get_selected_items()
	if selected.size() > 0:
		var index = selected[0]
		if index >= 0 and index < _player_peer_ids.size():
			var peer_id = _player_peer_ids[index]
			if peer_id != NetworkManager.get_unique_id():
				emit_signal("teleport_to_player", peer_id)
				emit_signal("resume")
