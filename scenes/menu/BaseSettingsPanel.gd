## Base class for settings panels that provides common save/load lifecycle.
##
## Subclasses must implement:
## - _settings_namespace: String property for SettingsManager key
## - _apply_settings(settings: Dictionary): Apply loaded settings to UI
## - _create_settings_obj() -> Dictionary: Serialize current UI state
##
## The base class handles:
## - Loading settings in _ready()
## - Auto-saving when panel becomes hidden
## - Common signal emission for resume
extends VBoxContainer

signal resume

## Override in subclass to set the SettingsManager namespace key
var _settings_namespace: String = ""

var _loaded_settings: bool = false

func _ready() -> void:
	_load_settings()

func _load_settings() -> void:
	var settings = SettingsManager.get_settings(_settings_namespace)
	_loaded_settings = true
	if settings:
		_apply_settings(settings)

## Override in subclass to apply loaded settings to UI elements
func _apply_settings(_settings: Dictionary) -> void:
	pass

## Override in subclass to serialize current UI state to dictionary
func _create_settings_obj() -> Dictionary:
	return {}

func _save_settings() -> void:
	SettingsManager.save_settings(_settings_namespace, _create_settings_obj())

func _on_visibility_changed() -> void:
	if _loaded_settings and not is_visible_in_tree():
		_save_settings()

func _on_resume() -> void:
	_save_settings()
	resume.emit()

func _on_back_pressed() -> void:
	_save_settings()
	resume.emit()
