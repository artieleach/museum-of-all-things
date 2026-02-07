extends Node3D
## Museum controller managing exhibits, lobby, teleportation, and item queue.
## Uses subsystems for teleportation, multiplayer sync, and exhibit loading.

const _LOBBY_DATA_PATH: String = "res://assets/resources/lobby_data.tres"
const QUEUE_DELAY: float = 0.05
const _GROUP_PLAYER := &"Player"

var StaticData: Resource = preload("res://assets/resources/lobby_data.tres")

# =============================================================================
# EXPORT CONFIGURATION
# =============================================================================
@export var items_per_room_estimate: int = 7
@export var min_rooms_per_exhibit: int = 2
@export var fog_depth: float = 10.0
@export var fog_depth_lobby: float = 20.0
@export var ambient_light_lobby: float = 0.4
@export var ambient_light: float = 0.2
@export var max_teleport_distance: float = 10.0
@export var max_exhibits_loaded: int = 2
@export var min_room_dimension: int = 2
@export var max_room_dimension: int = 5
@export var npcs_enabled: bool = false
@export var npcs_per_exhibit: int = 0

# =============================================================================
# PRIVATE STATE VARIABLES
# =============================================================================
var _current_room_title: String = "$Lobby"
var _grid: GridMap = null
var _player: Node = null
var _custom_door: Hall = null

var _queue_running: bool = false
var _global_item_queue_map: Dictionary = {}
var _fog_tween: Tween = null
var _queue_timer: Timer = null

# =============================================================================
# SUBSYSTEMS
# =============================================================================
var _teleport_manager: MuseumTeleportManager = null
var _multiplayer_sync: MuseumMultiplayerSync = null
var _exhibit_loader: ExhibitLoader = null

# Public access to exhibits (used by subsystems)
var _exhibits: Dictionary:
	get: return _exhibit_loader.get_exhibits() if _exhibit_loader else {}

# Track exhibits currently being loaded for riders (to prevent duplicate fetches)
var _rider_loading_exhibits: Dictionary = {}


func has_exhibit(title: String) -> bool:
	return _exhibits.has(title)


func clear_rider_loading(title: String) -> void:
	_rider_loading_exhibits.erase(title)


func sync_rider_to_room(room_title: String) -> void:
	## Called when a rider follows their mount to a new room.
	## Updates museum state locally without broadcasting to network.
	if room_title == _current_room_title:
		return

	# Open doors for the rider (mimics _teleport_player door handling)
	# 1. Open the exit door in the source hall (door rider passes through)
	var from_hall: Hall = _find_hall_for_room_transition(_current_room_title, room_title)
	if from_hall:
		from_hall.exit_door.set_open(true)
		from_hall.entry_door.set_open(true)

	# 2. Open the exit door in the destination entry hall (door ahead in new room)
	if _exhibits.has(room_title):
		var dest_exhibit: Node = _exhibits[room_title].get("exhibit")
		if is_instance_valid(dest_exhibit) and "entry" in dest_exhibit:
			dest_exhibit.entry.exit_door.set_open(true)

	_current_room_title = room_title
	WorkQueue.set_current_exhibit(room_title)
	SettingsEvents.emit_set_current_room(room_title)
	_start_queue()

	# Update fog color
	_tween_fog_color(ExhibitStyle.gen_fog(_current_room_title))


func load_exhibit_for_rider(from_room: String, to_room: String) -> void:
	if has_exhibit(to_room):
		_rider_loading_exhibits.erase(to_room)  # Clean up tracking
		return  # Already loaded

	# Prevent duplicate fetches while loading is in progress
	if _rider_loading_exhibits.has(to_room):
		return

	# Try finding hall in from_room first
	var hall: Hall = _find_hall_for_room_transition(from_room, to_room)

	# Fallback: search all loaded exhibits for any hall that leads to to_room
	if not hall:
		hall = _find_any_hall_to_room(to_room)

	if hall:
		_rider_loading_exhibits[to_room] = true
		_exhibit_loader.load_exhibit_from_exit(hall)
	else:
		# Last resort: load without hall context (uses default hall styling)
		_rider_loading_exhibits[to_room] = true
		_exhibit_loader.load_exhibit_for_rider_without_hall(to_room, from_room)


func _find_hall_for_room_transition(from_room: String, to_room: String) -> Hall:
	if _exhibits.has(from_room):
		var exhibit_data: Dictionary = _exhibits[from_room]
		var exhibit: Node = exhibit_data.get("exhibit")
		if is_instance_valid(exhibit) and "exits" in exhibit:
			for exit: Hall in exhibit.exits:
				if exit.to_title == to_room:
					return exit

	if from_room == "$Lobby" and has_node("Lobby"):
		for exit: Hall in $Lobby.exits:
			if exit.to_title == to_room:
				return exit

	return null


func _find_any_hall_to_room(to_room: String) -> Hall:
	## Fallback: search ALL loaded exhibits for any hall that leads to to_room.
	## Used when the rider's from_room exhibit was unloaded.
	for exhibit_key: String in _exhibits:
		var exhibit_data: Dictionary = _exhibits[exhibit_key]
		var exhibit: Node = exhibit_data.get("exhibit")
		if is_instance_valid(exhibit) and "exits" in exhibit:
			for exit: Hall in exhibit.exits:
				if exit.to_title == to_room:
					return exit
	return null


# =============================================================================
# LIFECYCLE
# =============================================================================
func _init() -> void:
	if OS.is_debug_build():
		RenderingServer.set_debug_generate_wireframes(true)


func _ready() -> void:
	_grid = $Lobby/GridMap

	_queue_timer = Timer.new()
	_queue_timer.wait_time = QUEUE_DELAY
	_queue_timer.one_shot = true
	_queue_timer.timeout.connect(_process_item_queue)
	add_child(_queue_timer)

	# Initialize subsystems
	_teleport_manager = MuseumTeleportManager.new()
	add_child(_teleport_manager)

	_multiplayer_sync = MuseumMultiplayerSync.new()
	add_child(_multiplayer_sync)
	_multiplayer_sync.init(self)

	_exhibit_loader = ExhibitLoader.new()
	add_child(_exhibit_loader)
	_exhibit_loader.init(self, {
		"items_per_room_estimate": items_per_room_estimate,
		"min_rooms_per_exhibit": min_rooms_per_exhibit,
		"max_exhibits_loaded": max_exhibits_loaded,
		"min_room_dimension": min_room_dimension,
		"max_room_dimension": max_room_dimension,
	})

	ExhibitFetcher.wikitext_complete.connect(_on_fetch_complete)
	ExhibitFetcher.wikidata_complete.connect(_on_wikidata_complete)
	ExhibitFetcher.commons_images_complete.connect(_on_commons_images_complete)
	UIEvents.reset_custom_door.connect(_reset_custom_door)
	UIEvents.set_custom_door.connect(_set_custom_door)
	SettingsEvents.set_language.connect(_on_change_language)


func init(player: Node) -> void:
	_player = player
	_teleport_manager.init(self, player, max_teleport_distance)
	_set_up_lobby($Lobby)
	reset_to_lobby()


# =============================================================================
# LOBBY MANAGEMENT
# =============================================================================
func _get_lobby_exit_zone(exit: Hall) -> Variant:
	var ex: float = GridUtils.grid_to_world(exit.from_pos).x
	var ez: float = GridUtils.grid_to_world(exit.from_pos).z
	for w: Variant in StaticData.wings:
		var c1: Vector2 = w.corner_1
		var c2: Vector2 = w.corner_2
		if ex >= c1.x and ex <= c2.x and ez >= c1.y and ez <= c2.y:
			return w
	return null


func _set_up_lobby(lobby: Node) -> void:
	var exits: Array = lobby.exits
	_exhibit_loader.get_exhibits()["$Lobby"] = { "exhibit": lobby, "height": 0 }

	if OS.is_debug_build():
		print("Setting up lobby with %s exits..." % exits.size())

	var wing_indices: Dictionary = {}

	for exit: Hall in exits:
		var wing: Variant = _get_lobby_exit_zone(exit)

		if wing:
			if not wing_indices.has(wing.name):
				wing_indices[wing.name] = -1
			wing_indices[wing.name] += 1
			if wing_indices[wing.name] < wing.exhibits.size():
				exit.to_title = wing.exhibits[wing_indices[wing.name]]
				ExhibitGraph.add_edge("$Lobby", exit.to_title)

		elif not _custom_door:
			_custom_door = exit
			_custom_door.entry_door.set_open(false, true)
			_custom_door.to_sign.visible = false

		exit.loader.body_entered.connect(_on_loader_body_entered.bind(exit))


func _set_custom_door(title: String) -> void:
	if _custom_door and is_instance_valid(_custom_door):
		_custom_door.to_title = title
		_custom_door.entry_door.set_open(true)


func _reset_custom_door(_title: String) -> void:
	if _custom_door and is_instance_valid(_custom_door):
		_custom_door.entry_door.set_open(false)


func _on_change_language(_lang: String = "") -> void:
	if _current_room_title == "$Lobby":
		for exhibit: String in _exhibit_loader.get_exhibits().keys():
			if exhibit != "$Lobby":
				_exhibit_loader.erase_exhibit(exhibit)
		ExhibitGraph.reset()
		StaticData = ResourceLoader.load(_LOBBY_DATA_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		_set_up_lobby($Lobby)


# =============================================================================
# ROOM/EXHIBIT STATE
# =============================================================================
func get_current_room() -> String:
	return _current_room_title


func reset_to_lobby() -> void:
	ExhibitGraph.reset()
	for exit: Hall in $Lobby.exits:
		if exit.to_title != "" and exit.to_title != "$Lobby":
			ExhibitGraph.add_edge("$Lobby", exit.to_title)
	_set_current_room_title("$Lobby")
	# All exhibits stay visible - room filtering is handled by player visibility instead
	var exhibits: Dictionary = _exhibit_loader.get_exhibits()
	for exhibit_key: String in exhibits:
		exhibits[exhibit_key]['exhibit'].visible = true


func _set_current_room_title(title: String) -> void:
	if title == "$Lobby":
		_exhibit_loader.clear_backlink_map()

	_current_room_title = title
	WorkQueue.set_current_exhibit(title)
	SettingsEvents.emit_set_current_room(title)
	_start_queue()

	# Update local player's room BEFORE broadcasting (so visibility checks use the new value)
	if _player and "current_room" in _player:
		_player.current_room = title

		# Also update any rider mounted on local player (sync room immediately to prevent race condition)
		if "_has_rider" in _player and _player._has_rider:
			var rider: Node = _player.mounted_by
			if is_instance_valid(rider) and "current_room" in rider:
				rider.current_room = title

	# Broadcast room change to network
	if NetworkManager.is_multiplayer_active():
		NetworkManager.set_local_player_room(title)

	# Race win detection
	if RaceManager.is_race_active() and title == RaceManager.get_target_article():
		RaceManager.notify_article_reached(NetworkManager.get_unique_id(), title)

	_tween_fog_color(ExhibitStyle.gen_fog(_current_room_title))


func _tween_fog_color(fog_color: Color) -> void:
	var environment: Environment = $WorldEnvironment.environment
	if environment.fog_light_color == fog_color:
		return
	if _fog_tween and _fog_tween.is_valid():
		_fog_tween.kill()
	_fog_tween = create_tween()
	_fog_tween.tween_property(environment, "fog_light_color", fog_color, 1.0)
	_fog_tween.set_trans(Tween.TRANS_LINEAR)
	_fog_tween.set_ease(Tween.EASE_IN_OUT)


# =============================================================================
# EXHIBIT LOADING (DELEGATES TO ExhibitLoader)
# =============================================================================
func _load_exhibit_from_entry(entry: Hall) -> void:
	_exhibit_loader.load_exhibit_from_entry(entry)


func _load_exhibit_from_exit(exit: Hall) -> void:
	_exhibit_loader.load_exhibit_from_exit(exit)


func _on_fetch_complete(titles: Array, context: Dictionary) -> void:
	clear_rider_loading(context.get("title", ""))
	_exhibit_loader.on_fetch_complete(titles, context)


func _on_wikidata_complete(entity: String, ctx: Dictionary) -> void:
	var result: Variant = ExhibitFetcher.get_result(entity)
	if result and (result.has("commons_category") or result.has("commons_gallery")):
		if result.has("commons_category"):
			ExhibitFetcher.fetch_commons_images(result.commons_category, ctx)
		if result.has("commons_gallery"):
			ExhibitFetcher.fetch_commons_images(result.commons_gallery, ctx)
	else:
		_queue_extra_text(ctx.exhibit, ctx.extra_text)
		_queue_item(ctx.title, _on_finished_exhibit.bind(ctx))


func _on_commons_images_complete(images: Array, ctx: Dictionary) -> void:
	if images.size() > 0:
		var item_data: Array = ItemProcessor.commons_images_to_items(ctx.title, images, ctx.extra_text)
		for item: Dictionary in item_data:
			_queue_item(ctx.title, _exhibit_loader._add_item.bind(
				ctx.exhibit,
				item
			))
	_queue_item(ctx.title, _on_finished_exhibit.bind(ctx))


func _on_finished_exhibit(ctx: Dictionary) -> void:
	if not is_instance_valid(ctx.exhibit):
		return
	if OS.is_debug_build():
		print("finished exhibit. slots=", ctx.exhibit._item_slots.size())
	if ctx.backlink:
		_exhibit_loader._link_backlink_to_exit(ctx.exhibit, ctx.hall)


# =============================================================================
# MULTIPLAYER TRANSITIONS (DELEGATES TO MuseumMultiplayerSync)
# =============================================================================
func _on_loader_body_entered(body: Node, hall: Hall, backlink: bool = false) -> void:
	if hall.to_title == "" or hall.to_title == _current_room_title:
		return

	if body.is_in_group(_GROUP_PLAYER):
		# In multiplayer, only the local player triggers transitions
		if NetworkManager.is_multiplayer_active() and not _multiplayer_sync.is_local_player(body):
			return

		if NetworkManager.is_multiplayer_active():
			_multiplayer_sync.request_multiplayer_transition(hall, backlink)
		else:
			# Single player mode - direct transition
			if backlink:
				_load_exhibit_from_entry(hall)
			else:
				_load_exhibit_from_exit(hall)


@rpc("any_peer", "call_remote", "reliable")
func request_transition(to_title: String, hall_info: Dictionary) -> void:
	_multiplayer_sync.handle_transition_request(to_title, hall_info)


@rpc("authority", "call_local", "reliable")
func execute_transition(to_title: String, from_title: String, hall_info: Dictionary) -> void:
	_multiplayer_sync.execute_transition(to_title, from_title, hall_info)


func sync_to_exhibit(exhibit_title: String) -> void:
	_multiplayer_sync.sync_to_exhibit(exhibit_title)


# =============================================================================
# ITEM QUEUE SYSTEM
# =============================================================================
func _process_item_queue() -> void:
	var queue: Array = _global_item_queue_map.get(_current_room_title, [])
	if queue.is_empty():
		_queue_running = false
		return
	var callable: Callable = queue.pop_front()
	_queue_running = true
	callable.call()
	_queue_timer.start()


func _queue_item_front(title: String, item: Variant) -> void:
	_queue_item(title, item, true)


func _queue_item(title: String, item: Variant, front: bool = false) -> void:
	if not _global_item_queue_map.has(title):
		_global_item_queue_map[title] = []
	if typeof(item) == TYPE_ARRAY:
		_global_item_queue_map[title].append_array(item)
	elif not front:
		_global_item_queue_map[title].append(item)
	else:
		_global_item_queue_map[title].push_front(item)
	_start_queue()


func _start_queue() -> void:
	if not _queue_running:
		_process_item_queue()


func _queue_extra_text(exhibit: Node, extra_text: Array) -> void:
	for item: Dictionary in extra_text:
		_queue_item(exhibit.title, _exhibit_loader._add_item.bind(exhibit, item))
