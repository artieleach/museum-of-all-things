extends Node

signal return_to_lobby
signal language_changed(language: String)
signal race_started(target_article: String)
signal race_ended(winner_peer_id: int, winner_name: String)

func emit_return_to_lobby() -> void:
	return_to_lobby.emit()

func emit_language_changed(language: String) -> void:
	language_changed.emit(language)

func emit_race_started(target_article: String) -> void:
	race_started.emit(target_article)

func emit_race_ended(winner_peer_id: int, winner_name: String) -> void:
	race_ended.emit(winner_peer_id, winner_name)
