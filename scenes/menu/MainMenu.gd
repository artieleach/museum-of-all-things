extends Control

signal start
signal settings
signal start_multiplayer

var fade_in_start: Color = Color(0.973, 0.976, 0.98, 1.0)
var fade_in_end: Color = Color(0.973, 0.976, 0.98, 0.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_on_visibility_changed()
	call_deferred("_start_fade_in")

	if Platform.is_web():
		%Quit.visible = false

func _on_visibility_changed() -> void:
	if visible and is_inside_tree():
		$MarginContainer/CenterContainer/VBoxContainer/PanelContainer/ButtonContainer/Start.call_deferred("grab_focus")

func _start_fade_in() -> void:
	$FadeIn.color = fade_in_start
	$FadeInStage2.color = fade_in_start
	var tween = get_tree().create_tween()
	tween.tween_property($FadeIn, "color", fade_in_end, 1.5)
	tween.tween_property($FadeInStage2, "color", fade_in_end, 1.5)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)

func _on_start_pressed() -> void:
	start.emit()

func _on_settings_pressed() -> void:
	settings.emit()

func _on_multiplayer_pressed() -> void:
	start_multiplayer.emit()

func _on_quit_button_pressed() -> void:
	get_tree().quit()
