extends Control

signal resume
signal settings
signal vr_controls
signal return_to_lobby
signal start_race

@onready var vbox = $MarginContainer/VBoxContainer
@onready var race_button = $MarginContainer/VBoxContainer/Race
@onready var cancel_race_button = $MarginContainer/VBoxContainer/CancelRace

func _on_visibility_changed():
	if visible and vbox:
		vbox.get_node("Resume").grab_focus()
		_update_race_button_visibility()

func _ready():
	SettingsEvents.set_current_room.connect(set_current_room)
	UIEvents.ui_cancel_pressed.connect(ui_cancel_pressed)
	MultiplayerEvents.multiplayer_started.connect(_update_race_button_visibility)
	MultiplayerEvents.multiplayer_ended.connect(_update_race_button_visibility)
	RaceManager.race_started.connect(_on_race_state_changed)
	RaceManager.race_ended.connect(_on_race_state_changed)
	RaceManager.race_cancelled.connect(_update_race_button_visibility)
	set_current_room(current_room)

	# opening page in a browser outside VR is confusing

	if Platform.is_web():
		%AskQuit.visible = false

	_update_race_button_visibility()

func ui_cancel_pressed():
	if visible:
		call_deferred("_on_resume_pressed")

var current_room = "$Lobby"
func set_current_room(room):
	current_room = room
	vbox.get_node("Title").text = current_room.replace("$", "") + (" - " + tr("Paused"))
	vbox.get_node("Open").disabled = current_room.begins_with("$")
	$MarginContainer/VBoxContainer/Language.visible = current_room == "$Lobby"

func _on_resume_pressed():
	resume.emit()

func _on_settings_pressed():
	settings.emit()

func _on_lobby_pressed():
	return_to_lobby.emit()

func _on_open_pressed():
	var lang = TranslationServer.get_locale()
	OS.shell_open("https://" + lang + ".wikipedia.org/wiki/" + current_room)

func _on_quit_pressed():
	UIEvents.emit_quit_requested()

func _on_ask_quit_pressed():
	_on_quit_pressed()

func _on_cancel_quit_pressed():
	$MarginContainer/QuitContainer.visible = false
	$MarginContainer/VBoxContainer.visible = true
	$MarginContainer/VBoxContainer/Resume.grab_focus()

func _on_vr_controls_pressed() -> void:
	vr_controls.emit()

func _on_race_pressed() -> void:
	start_race.emit()

func _on_cancel_race_pressed() -> void:
	RaceManager.cancel_race()

func _on_race_state_changed(_arg1 = null, _arg2 = null) -> void:
	_update_race_button_visibility()

func _update_race_button_visibility() -> void:
	if not race_button:
		return
	# Show race button if: multiplayer active and no race is active (any player can start)
	var should_show = NetworkManager.is_multiplayer_active() and not RaceManager.is_race_active()
	race_button.visible = should_show
	# Show cancel button if: multiplayer active and race is active
	if cancel_race_button:
		var should_show_cancel = NetworkManager.is_multiplayer_active() and RaceManager.is_race_active()
		cancel_race_button.visible = should_show_cancel
