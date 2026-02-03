extends Node

signal ui_cancel_pressed
signal ui_accept_pressed
signal hide_menu
signal open_terminal_menu
signal terminal_result_ready(error: bool, page: String)
signal set_custom_door(title: String)
signal reset_custom_door
signal quit_requested
signal fullscreen_toggled(fullscreen_state: bool)

func emit_ui_cancel_pressed() -> void:
	ui_cancel_pressed.emit()

func emit_ui_accept_pressed() -> void:
	ui_accept_pressed.emit()

func emit_hide_menu() -> void:
	hide_menu.emit()

func emit_open_terminal_menu() -> void:
	open_terminal_menu.emit()

func emit_terminal_result_ready(error: bool, page: String) -> void:
	terminal_result_ready.emit(error, page)

func emit_set_custom_door(title: String) -> void:
	set_custom_door.emit(title)

func emit_reset_custom_door() -> void:
	reset_custom_door.emit()

func emit_quit_requested() -> void:
	quit_requested.emit()
