extends Node

var QUEUE_WAIT_TIMEOUT_MS: int = 50
var DEFAULT_FRAME_PACING: int = 9
var _global_queue_lock: Mutex = Mutex.new()
var _current_exhibit_lock: Mutex = Mutex.new()
var _current_exhibit: String = "Lobby"
var _quitting: bool = false
var _queue_map: Dictionary = {}

func _exit_tree() -> void:
	set_quitting()

func set_quitting() -> void:
	_quitting = true

func get_quitting() -> bool:
	return _quitting

func set_current_exhibit(title: String) -> void:
	_current_exhibit_lock.lock()
	_current_exhibit = title
	_current_exhibit_lock.unlock()

func get_current_exhibit() -> String:
	_current_exhibit_lock.lock()
	var res: String = _current_exhibit
	_current_exhibit_lock.unlock()
	return res

func setup_queue(queue_name: String, frame_pacing: int = DEFAULT_FRAME_PACING) -> void:
	_queue_map[queue_name] = {
		"exhibit_queues": {},
		"lock": Mutex.new(),
		"last_frame_with_item": 0,
		"frame_pacing": frame_pacing,
	}

func _get_queue(queue_name: String) -> Dictionary:
	var res: Dictionary
	_global_queue_lock.lock()
	if not _queue_map.has(queue_name):
		setup_queue(queue_name)
	res = _queue_map[queue_name]
	_global_queue_lock.unlock()
	return res

func add_item(item_name: String, item: Variant, _exhibit: Variant = null, front: bool = false) -> void:
	var exhibit = _exhibit if _exhibit else get_current_exhibit()
	var queue = _get_queue(item_name)

	queue.lock.lock()
	if not queue.exhibit_queues.has(exhibit):
		queue.exhibit_queues[exhibit] = []

	if front:
		queue.exhibit_queues[exhibit].push_front(item)
	else:
		queue.exhibit_queues[exhibit].append(item)
	queue.lock.unlock()

func process_queue(queue_name: String) -> Variant:
	var queue = _get_queue(queue_name)

	if Platform.is_using_threads():
		while not _quitting:
			var item = _process_queue_item(queue)
			if item:
				return item
			Util.delay_msec(QUEUE_WAIT_TIMEOUT_MS)
	else:
		# Pace the items out across several frames
		var cur_frame = Engine.get_frames_drawn()
		if cur_frame - queue["frame_pacing"] >= queue["last_frame_with_item"]:
			var item = _process_queue_item(queue)
			if item:
				queue["last_frame_with_item"] = cur_frame
				return item
		return null
	return null

func _process_queue_item(queue: Dictionary) -> Variant:
	if _quitting:
		return null

	var exhibit = get_current_exhibit()
	queue.lock.lock()
	var item: Variant
	if queue.exhibit_queues.has(exhibit):
		item = queue.exhibit_queues[exhibit].pop_front()
	queue.lock.unlock()
	return item
