class_name SettingsEvents
extends Node

signal fullscreen_toggled(enabled: bool)
signal set_current_room(room: Variant)
signal set_xr_movement_style(style: Variant)
signal set_movement_speed(speed: float)
signal set_xr_rotation_increment(increment: Variant)
signal set_xr_smooth_rotation(enabled: bool)
signal load_xr_settings
signal set_invert_y(enabled: bool)
signal set_mouse_sensitivity(factor: float)
signal set_joypad_deadzone(value: float)

func emit_fullscreen_toggled(enabled: bool) -> void:
	fullscreen_toggled.emit(enabled)

func emit_set_current_room(room: Variant) -> void:
	set_current_room.emit(room)

func emit_set_xr_movement_style(style: Variant) -> void:
	set_xr_movement_style.emit(style)

func emit_set_movement_speed(speed: float) -> void:
	set_movement_speed.emit(speed)

func emit_set_xr_rotation_increment(increment: Variant) -> void:
	set_xr_rotation_increment.emit(increment)

func emit_set_xr_smooth_rotation(enabled: bool) -> void:
	set_xr_smooth_rotation.emit(enabled)

func emit_load_xr_settings() -> void:
	load_xr_settings.emit()

func emit_set_invert_y(enabled: bool) -> void:
	set_invert_y.emit(enabled)

func emit_set_mouse_sensitivity(factor: float) -> void:
	set_mouse_sensitivity.emit(factor)

func emit_set_joypad_deadzone(value: float) -> void:
	set_joypad_deadzone.emit(value)
