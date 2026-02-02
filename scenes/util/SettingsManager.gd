extends Node

signal settings_load_error(error: Error)
signal settings_save_error(error: Error)

const _settings_file: String = "user://user_settings.json"

var _settings: Dictionary = {}
var _is_loaded: bool = false

func _read_settings() -> Error:
	var file := FileAccess.open(_settings_file, FileAccess.READ)
	if not file:
		var err := FileAccess.get_open_error()
		if err != ERR_FILE_NOT_FOUND:
			push_error("SettingsManager: Failed to open settings file: %s" % error_string(err))
			settings_load_error.emit(err)
		return err

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null and not json_text.is_empty():
		push_error("SettingsManager: Failed to parse settings JSON")
		settings_load_error.emit(ERR_PARSE_ERROR)
		return ERR_PARSE_ERROR

	if parsed is Dictionary:
		_settings = parsed
	else:
		_settings = {}

	_is_loaded = true
	return OK

func _write_settings() -> Error:
	var json_text := JSON.stringify(_settings)
	var file := FileAccess.open(_settings_file, FileAccess.WRITE)
	if not file:
		var err := FileAccess.get_open_error()
		push_error("SettingsManager: Failed to open settings file for writing: %s" % error_string(err))
		settings_save_error.emit(err)
		return err

	file.store_string(json_text)
	file.close()
	return OK

func get_settings(ns: String) -> Variant:
	if not _is_loaded:
		_read_settings()
	return _settings.get(ns, null)

func save_settings(ns: String, obj: Dictionary) -> Error:
	_settings[ns] = obj
	return _write_settings()

func is_loaded() -> bool:
	return _is_loaded
