extends Node

signal player_joined(peer_id: int, player_name: String)
signal player_left(peer_id: int)
signal multiplayer_started
signal multiplayer_ended
signal skin_selected(url: String, texture: ImageTexture)
signal skin_reset

func emit_player_joined(peer_id: int, player_name: String) -> void:
	player_joined.emit(peer_id, player_name)

func emit_player_left(peer_id: int) -> void:
	player_left.emit(peer_id)

func emit_multiplayer_started() -> void:
	multiplayer_started.emit()

func emit_multiplayer_ended() -> void:
	multiplayer_ended.emit()

func emit_skin_selected(url: String, texture: ImageTexture) -> void:
	skin_selected.emit(url, texture)

func emit_skin_reset() -> void:
	skin_reset.emit()
