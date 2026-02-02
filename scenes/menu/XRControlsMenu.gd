extends "res://scenes/menu/BaseSettingsPanel.gd"

@onready var movement_speed: HSlider = $MovementOptions/MovementSpeed
@onready var movement_speed_value: Label = $MovementOptions/MovementSpeedValue
@onready var teleportation_btn: Button = $MovementOptions/Styles/Teleportation
@onready var direct_movement_btn: Button = $MovementOptions/Styles/DirectMovement
@onready var rotation_increment: HSlider = $RotationOptions/RotationIncrement
@onready var rotation_increment_value: Label = $RotationOptions/RotationIncrementValue
@onready var smooth_rotation: CheckBox = $RotationOptions/SmoothRotation

var _default_settings: Dictionary

func _ready() -> void:
	_settings_namespace = "xr_controls"
	GlobalMenuEvents.load_xr_settings.connect(_load_xr_settings)

func _load_xr_settings() -> void:
	_default_settings = _create_settings_obj()
	_load_settings()

func _apply_settings(settings: Dictionary) -> void:
	if settings.has("movement_speed"):
		movement_speed.value = settings.movement_speed
	if settings.has("movement_style"):
		if settings.movement_style == "teleportation":
			_on_teleportation_pressed()
		elif settings.movement_style == "direct":
			_on_direct_movement_pressed()
	if settings.has("rotation_increment"):
		rotation_increment.value = settings.rotation_increment
	if settings.has("smooth_rotation"):
		smooth_rotation.button_pressed = settings.smooth_rotation

func _create_settings_obj() -> Dictionary:
	return {
		"movement_style": "teleportation" if teleportation_btn.disabled else "direct",
		"movement_speed": movement_speed.value,
		"rotation_increment": rotation_increment.value,
		"smooth_rotation": smooth_rotation.button_pressed
	}

func _on_movement_speed_value_changed(value: float) -> void:
	movement_speed_value.text = str(value)
	GlobalMenuEvents.emit_set_movement_speed(value)

func _on_teleportation_pressed() -> void:
	GlobalMenuEvents.emit_set_xr_movement_style("teleportation")
	teleportation_btn.disabled = true
	direct_movement_btn.disabled = false
	movement_speed.editable = false

func _on_direct_movement_pressed() -> void:
	GlobalMenuEvents.emit_set_xr_movement_style("direct")
	teleportation_btn.disabled = false
	direct_movement_btn.disabled = true
	movement_speed.editable = true

func _on_rotation_increment_value_changed(value: float) -> void:
	rotation_increment_value.text = str(value)
	GlobalMenuEvents.emit_set_xr_rotation_increment(value)

func _on_smooth_rotation_toggled(toggled_on: bool) -> void:
	rotation_increment.editable = not toggled_on
	GlobalMenuEvents.emit_set_xr_smooth_rotation(toggled_on)

func _on_restore_default_pressed() -> void:
	_apply_settings(_default_settings)
