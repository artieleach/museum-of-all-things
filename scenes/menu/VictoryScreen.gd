extends Control

signal continue_pressed

@onready var winner_label: Label = $VBoxContainer/WinnerLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton

func _ready() -> void:
	visible = false
	RaceManager.race_ended.connect(_on_race_ended)
	continue_button.pressed.connect(_on_continue_pressed)

func _on_race_ended(winner_peer_id: int, winner_name: String) -> void:
	var display_name = winner_name
	if winner_peer_id == NetworkManager.get_unique_id():
		display_name += " (You!)"

	winner_label.text = display_name + " wins!"
	visible = true
	continue_button.grab_focus()

func _on_continue_pressed() -> void:
	visible = false
	emit_signal("continue_pressed")
