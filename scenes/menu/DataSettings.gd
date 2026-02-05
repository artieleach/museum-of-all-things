extends "res://scenes/menu/BaseSettingsPanel.gd"

@onready var auto_limit_checkbox: CheckBox = %AutoLimitCheckbox
@onready var cache_size_limit: SpinBox = %CacheSizeLimit
@onready var cache_size_limit_value: Label = %CacheSizeLimitValue
@onready var cache_label: Label = %CacheLabel

func _ready() -> void:
	_settings_namespace = "data"
	CacheControl.cache_size_result.connect(_show_cache_size)
	super._ready()

func _apply_settings(settings: Dictionary) -> void:
	auto_limit_checkbox.button_pressed = settings.auto_limit_cache
	cache_size_limit.value = settings.get("cache_limit_size", 4e9) / 1e9
	cache_size_limit.editable = settings.auto_limit_cache

func _create_settings_obj() -> Dictionary:
	return {
		"auto_limit_cache": auto_limit_checkbox.button_pressed,
		"cache_limit_size": int(cache_size_limit.value * 1e9)
	}

func _on_visibility_changed() -> void:
	if visible:
		_refresh_cache_label()
	super._on_visibility_changed()

func _check_box_toggled(toggled_on: bool) -> void:
	cache_size_limit.editable = toggled_on

func _refresh_cache_label() -> void:
	cache_label.text = "Cache (calculating size...)"
	CacheControl.calculate_cache_size()

func _show_cache_size(result) -> void:
	cache_label.text = "Cache (%3.2f GB)" % [result / 1000000000.0]

func _on_clear_cache_pressed() -> void:
	CacheControl.clear_cache()
	_refresh_cache_label()

func _on_cache_size_limit_value_changed(value: float) -> void:
	cache_size_limit_value.text = "%d Gb" % int(value)
