extends Node
## Centralized logging with file output and network relay for dedicated servers.

signal log_received(timestamp: String, level: String, source: String, message: String)

enum Level { DEBUG, INFO, WARN, ERROR }

const MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10 MB
const MAX_LOG_FILES: int = 5
const HISTORY_SIZE: int = 500
const BATCH_INTERVAL: float = 0.25

var _file: FileAccess = null
var _file_path: String = ""
var _history: Array[Array] = []
var _batch: Array[Array] = []
var _batch_timer: Timer = null
var _subscribers: Array[int] = []
var _initialized: bool = false

static var _level_names: PackedStringArray = PackedStringArray(["DEBUG", "INFO", "WARN", "ERROR"])


func debug(source: String, message: String) -> void:
	_log(Level.DEBUG, source, message)


func info(source: String, message: String) -> void:
	_log(Level.INFO, source, message)


func warn(source: String, message: String) -> void:
	_log(Level.WARN, source, message)


func error(source: String, message: String) -> void:
	_log(Level.ERROR, source, message)


func _log(level: Level, source: String, message: String) -> void:
	var timestamp: String = Time.get_datetime_string_from_system(false, true)
	var level_name: String = _level_names[level]
	var line: String = "[%s] [%s] [%s] %s" % [timestamp, level_name, source, message]

	# Always print to stdout
	if level == Level.ERROR:
		printerr(line)
	else:
		print(line)

	# Server-only: file + network
	if NetworkManager.is_dedicated_server:
		_ensure_initialized()
		_write_to_file(line)

		var entry: Array = [timestamp, level_name, source, message]
		_history.append(entry)
		if _history.size() > HISTORY_SIZE:
			_history.remove_at(0)

		_batch.append(entry)


func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_open_log_file()

	_batch_timer = Timer.new()
	_batch_timer.wait_time = BATCH_INTERVAL
	_batch_timer.autostart = true
	_batch_timer.timeout.connect(_flush_batch)
	add_child(_batch_timer)


func _open_log_file() -> void:
	var log_dir: String = "user://logs"
	DirAccess.make_dir_recursive_absolute(log_dir)
	_rotate_logs(log_dir)

	var timestamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	_file_path = log_dir.path_join("server_%s.log" % timestamp)
	_file = FileAccess.open(_file_path, FileAccess.WRITE)
	if _file == null:
		printerr("Logger: Failed to open log file: %s" % _file_path)


func _rotate_logs(log_dir: String) -> void:
	var dir: DirAccess = DirAccess.open(log_dir)
	if dir == null:
		return

	var files: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with("server_") and file_name.ends_with(".log"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort alphabetically (timestamp-based names sort chronologically)
	files.sort()

	# Remove oldest files if at limit (keep MAX_LOG_FILES - 1 to make room for new)
	while files.size() >= MAX_LOG_FILES:
		var oldest: String = files[0]
		dir.remove(oldest)
		files.remove_at(0)


func _write_to_file(line: String) -> void:
	if _file == null:
		return

	_file.store_line(line)
	_file.flush()

	# Check rotation
	if _file.get_length() >= MAX_FILE_SIZE:
		_file.close()
		_open_log_file()


func _flush_batch() -> void:
	if _batch.is_empty() or _subscribers.is_empty():
		return

	var to_send: Array[Array] = _batch.duplicate()
	_batch.clear()

	for peer_id: int in _subscribers:
		if multiplayer.multiplayer_peer != null:
			_receive_log_batch.rpc_id(peer_id, to_send)


@rpc("any_peer", "call_remote", "reliable")
func _request_subscribe() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		return
	if peer_id not in _subscribers:
		_subscribers.append(peer_id)
		info("Logger", "Client %d subscribed to server logs" % peer_id)

	# Send history
	if not _history.is_empty():
		_receive_log_batch.rpc_id(peer_id, _history.duplicate())


@rpc("authority", "call_remote", "reliable")
func _receive_log_batch(entries: Array) -> void:
	for entry: Array in entries:
		if entry.size() >= 4:
			log_received.emit(entry[0], entry[1], entry[2], entry[3])


func _exit_tree() -> void:
	if _file != null:
		_file.close()

	# Clean up subscriber list for disconnected peers
	_subscribers.clear()


func _on_peer_disconnected(peer_id: int) -> void:
	_subscribers.erase(peer_id)


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
