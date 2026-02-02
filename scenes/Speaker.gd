extends Node
## Text-to-speech wrapper for accessibility.

var _voice: String = ""


func _ready() -> void:
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language("en")
	if voices.size() == 0:
		return
	_voice = voices[0]


func speak(text: String) -> void:
	if _voice != "":
		DisplayServer.tts_speak(text, _voice)


func stop() -> void:
	DisplayServer.tts_stop()
