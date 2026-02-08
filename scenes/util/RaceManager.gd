extends Node

signal race_started(target_article: String)
signal race_ended(winner_peer_id: int, winner_name: String)
signal race_cancelled

enum State { IDLE, ACTIVE }

var _state: State = State.IDLE
var _target_article: String = ""
var _winner_peer_id: int = -1
var _winner_name: String = ""

func _ready() -> void:
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.peer_connected.connect(_on_peer_connected)

func is_race_active() -> bool:
	return _state == State.ACTIVE

func get_target_article() -> String:
	return _target_article

func get_state() -> State:
	return _state

func start_race(target_article: String) -> void:
	if not NetworkManager.is_server():
		Log.error("RaceManager", "Only the host can start a race")
		return

	if _state == State.ACTIVE:
		Log.error("RaceManager", "Race already active")
		return

	_target_article = target_article
	_state = State.ACTIVE
	_winner_peer_id = -1
	_winner_name = ""

	if OS.is_debug_build():
		print("RaceManager: Starting race to find '", target_article, "'")

	_sync_race_start.rpc(target_article)
	race_started.emit(target_article)

func notify_article_reached(peer_id: int, article_title: String) -> void:
	if _state != State.ACTIVE:
		return

	if article_title != _target_article:
		return

	if NetworkManager.is_server():
		_handle_win(peer_id)
	else:
		_request_win_validation.rpc_id(1, peer_id, article_title)

func _handle_win(peer_id: int) -> void:
	if _state != State.ACTIVE:
		return

	_state = State.IDLE
	_winner_peer_id = peer_id
	_winner_name = NetworkManager.get_player_name(peer_id)

	if OS.is_debug_build():
		print("RaceManager: Winner is ", _winner_name, " (peer ", peer_id, ")")

	_sync_race_end.rpc(peer_id, _winner_name)
	race_ended.emit(peer_id, _winner_name)

func cancel_race() -> void:
	if _state != State.ACTIVE:
		return

	if NetworkManager.is_server():
		_state = State.IDLE
		_target_article = ""
		_winner_peer_id = -1
		_winner_name = ""
		_sync_race_cancel.rpc()
		race_cancelled.emit()
	else:
		_request_race_cancel.rpc_id(1)

func _on_server_disconnected() -> void:
	if _state == State.ACTIVE:
		cancel_race()

func _on_peer_connected(peer_id: int) -> void:
	if NetworkManager.is_server() and _state == State.ACTIVE:
		_sync_race_state_to_peer.rpc_id(peer_id, _target_article)

@rpc("authority", "call_local", "reliable")
func _sync_race_start(target_article: String) -> void:
	_target_article = target_article
	_state = State.ACTIVE
	_winner_peer_id = -1
	_winner_name = ""

	if OS.is_debug_build():
		print("RaceManager: Race started, target: ", target_article)

	if not NetworkManager.is_server():
		race_started.emit(target_article)

@rpc("authority", "call_local", "reliable")
func _sync_race_end(winner_peer_id: int, winner_name: String) -> void:
	_state = State.IDLE
	_winner_peer_id = winner_peer_id
	_winner_name = winner_name

	if OS.is_debug_build():
		print("RaceManager: Race ended, winner: ", winner_name)

	if not NetworkManager.is_server():
		race_ended.emit(winner_peer_id, winner_name)

@rpc("authority", "call_local", "reliable")
func _sync_race_cancel() -> void:
	_state = State.IDLE
	_target_article = ""
	_winner_peer_id = -1
	_winner_name = ""

	if not NetworkManager.is_server():
		race_cancelled.emit()

@rpc("authority", "call_remote", "reliable")
func _sync_race_state_to_peer(target_article: String) -> void:
	_target_article = target_article
	_state = State.ACTIVE
	_winner_peer_id = -1
	_winner_name = ""

	if OS.is_debug_build():
		print("RaceManager: Late join - synced to race for '", target_article, "'")

	race_started.emit(target_article)

@rpc("any_peer", "call_remote", "reliable")
func _request_win_validation(peer_id: int, article_title: String) -> void:
	if not NetworkManager.is_server():
		return

	if _state != State.ACTIVE:
		return

	if article_title != _target_article:
		return

	_handle_win(peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_race_cancel() -> void:
	if not NetworkManager.is_server():
		return

	cancel_race()
