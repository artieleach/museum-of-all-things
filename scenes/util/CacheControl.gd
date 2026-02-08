extends Node

signal cache_size_result(cache_info)

var cache_dir: String = "user://cache/"
var global_cache_dir: String = ProjectSettings.globalize_path(cache_dir)
var _cache_stat_thread: Thread
var _cache_stat_timer: Timer
var CACHE_STAT_QUEUE: String = "CacheStat"
var _cache_size_info: int = 0
var _last_stat_time: int = 0
var _max_stat_age: int = 2000

func _ready() -> void:
	if Platform.is_using_threads():
		_cache_stat_thread = Thread.new()
		_cache_stat_thread.start(_cache_stat_loop)
	elif not Platform.is_web():
		_cache_stat_timer = Timer.new()
		add_child(_cache_stat_timer)
		_cache_stat_timer.timeout.connect(_cache_stat_item)
		_cache_stat_timer.start()

func _exit_tree() -> void:
	WorkQueue.set_quitting()
	if _cache_stat_thread:
		_cache_stat_thread.wait_to_finish()

func _cache_stat_loop() -> void:
	while not WorkQueue.get_quitting():
		_cache_stat_item()

func _cache_stat_item() -> void:
	var item = WorkQueue.process_queue(CACHE_STAT_QUEUE)
	if item and len(item) > 0 and item[0] == "size":
		if Time.get_ticks_msec() - _last_stat_time < _max_stat_age:
			call_deferred("_emit_cache_size")
		else:
			_cache_size_info = _get_cache_size()
			_last_stat_time = Time.get_ticks_msec()
			call_deferred("_emit_cache_size")

func _emit_cache_size() -> void:
	cache_size_result.emit(_cache_size_info)

func auto_limit_cache_enabled() -> bool:
	var settings = SettingsManager.get_settings("data")
	if settings:
		return settings.auto_limit_cache
	else:
		return true

func clear_cache() -> void:
	var dir = DirAccess.open(cache_dir)
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if not file:
			break
		dir.remove(file)

	_last_stat_time = 0

func calculate_cache_size() -> void:
	if not Platform.is_web():
		WorkQueue.add_item(CACHE_STAT_QUEUE, ["size"])

func _get_cache_size() -> int:
	if Platform.is_web():
		return -1
	elif OS.get_name() == "Windows":
		return _get_cache_size_windows()
	else:
		return _get_cache_size_unix()

func _get_cache_size_os_agnostic() -> int:
	var dir = DirAccess.open(cache_dir)
	dir.list_dir_begin()

	var file = dir.get_next()
	var total_length = 0
	while file:
		var handle = FileAccess.open(cache_dir + file, FileAccess.READ)
		if handle:
			total_length += handle.get_length()
			handle.close()
		file = dir.get_next()
	return total_length

func _get_cache_size_unix() -> int:
	var output = []
	OS.execute("du", ["-sb", global_cache_dir], output)
	if output.size() > 0:
		var parts = output[0].strip_edges().split("\t")
		if parts.size() > 1:
			return int(parts[0])
	return -1

func _get_cache_size_windows() -> int:
	var output = []
	var command = "powershell"
	var args = [
		"-command",
		"(Get-ChildItem -Path '" + global_cache_dir + "' -Recurse | Measure-Object -Property Length -Sum).Sum"
	]

	OS.execute(command, args, output)

	if output.size() > 0:
		return int(output[0].strip_edges())
	return -1

func cull_cache_to_size(max_size: int, target_size: int) -> void:
	var dir = DirAccess.open(cache_dir)
	dir.list_dir_begin()

	# do a fast check first using OS stat command
	var os_cache_size = _get_cache_size()
	if os_cache_size < max_size:
		return

	var file = dir.get_next()
	var file_array = []
	var total_length = 0
	while file:
		var file_path = cache_dir + file
		var handle = FileAccess.open(file_path, FileAccess.READ)
		if handle:
			var file_len = handle.get_length()
			total_length += file_len
			handle.close()
			file_array.append([
				file,
				file_len,
				FileAccess.get_modified_time(file_path),
			])
		file = dir.get_next()

	var deletion_target = total_length - target_size
	if total_length > max_size and deletion_target > 0:
		file_array.sort_custom(func(a, b): return a[2] < b[2])
		for file_entry in file_array:
			dir.remove(file_entry[0])
			deletion_target -= file_entry[1]
			if deletion_target <= 0:
				break
