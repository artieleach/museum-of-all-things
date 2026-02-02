## Popup wrapper for TerminalMenu that forwards the resume signal.
## Used when TerminalMenu is displayed as a popup overlay rather than inline.
extends Control

signal resume

func _on_terminal_menu_resume() -> void:
	if visible:
		call_deferred("emit_signal", "resume")
