extends Node

const _settings_ns: String = "language"
var _locale: String = "en"

func _create_settings_obj() -> Dictionary:
	return {
		"locale": _locale
	}

func _ready() -> void:
	var loaded_settings = SettingsManager.get_settings(_settings_ns)
	if loaded_settings:
		set_locale(loaded_settings.locale)

func get_locale() -> String:
	return _locale

func set_locale(locale: String) -> void:
	_locale = locale
	TranslationServer.set_locale(locale)
	ExhibitFetcher.set_language(locale)
	SettingsEvents.set_language.emit(locale)
	SettingsManager.save_settings(_settings_ns, _create_settings_obj())
