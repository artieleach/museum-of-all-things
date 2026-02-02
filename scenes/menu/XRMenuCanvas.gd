extends CanvasLayer

func _on_pause_menu_return_to_lobby() -> void:
	GlobalMenuEvents.emit_return_to_lobby()

func _on_pause_menu_resume() -> void:
	GlobalMenuEvents.emit_hide_menu()

func _on_pause_menu_settings() -> void:
	$PauseMenu.visible = false
	$Settings.visible = true

func _on_settings_resume() -> void:
	$PauseMenu.visible = true
	$Settings.visible = false
