extends "res://scenes/menu/BaseSettingsPanel.gd"

@onready var global_volume: HSlider = %GlobalVolume
@onready var sound_volume: HSlider = %SoundVolume
@onready var ambience_volume: HSlider = %AmbienceVolume
@onready var music_volume: HSlider = %MusicVolume
@onready var global_value: Label = %GlobalValue
@onready var sound_value: Label = %SoundValue
@onready var ambience_value: Label = %AmbienceValue
@onready var music_value: Label = %MusicValue

var global_bus_name: String = "Master"
var global_bus_idx: int
var sound_bus_name: String = "Sound"
var sound_bus_idx: int
var ambience_bus_name: String = "Ambience"
var ambience_bus_idx: int
var music_bus_name: String = "Music"
var music_bus_idx: int

func _ready() -> void:
	_settings_namespace = "audio"
	global_bus_idx = AudioServer.get_bus_index(global_bus_name)
	sound_bus_idx = AudioServer.get_bus_index(sound_bus_name)
	ambience_bus_idx = AudioServer.get_bus_index(ambience_bus_name)
	music_bus_idx = AudioServer.get_bus_index(music_bus_name)
	super._ready()

func _apply_settings(settings: Dictionary) -> void:
	global_volume.value = settings.global
	sound_volume.value = settings.sound
	ambience_volume.value = settings.ambience
	music_volume.value = settings.music

func _create_settings_obj() -> Dictionary:
	return {
		"global": global_volume.value,
		"sound": sound_volume.value,
		"ambience": ambience_volume.value,
		"music": music_volume.value,
	}

func _on_global_volume_changed(value: float) -> void:
	global_value.text = str(value * 100) + "%"
	_change_volume(global_bus_idx, value)

func _on_sound_volume_changed(value: float) -> void:
	sound_value.text = str(value * 100) + "%"
	_change_volume(sound_bus_idx, value)

func _on_ambience_volume_changed(value: float) -> void:
	ambience_value.text = str(value * 100) + "%"
	_change_volume(ambience_bus_idx, value)

func _on_music_volume_changed(value: float) -> void:
	music_value.text = str(value * 100) + "%"
	_change_volume(music_bus_idx, value)

func _change_volume(idx: int, value: float) -> void:
	AudioServer.set_bus_volume_db(idx, linear_to_db(value))
