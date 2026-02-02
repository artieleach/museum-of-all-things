extends Node3D
## Museum controller managing exhibits, lobby, teleportation, and item queue.
## Uses subsystems for teleportation, multiplayer sync, and exhibit loading.

const _LOBBY_DATA_PATH: String = "res://assets/resources/lobby_data.tres"
const QUEUE_DELAY: float = 0.05

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

# =============================================================================
# PRIVATE STATE VARIABLES
# =============================================================================
var _xr: bool = false
var _current_room_title: String = "$Lobby"
var _grid: GridMap = null
var _player: Node = null
var _custom_door: Hall = null

var _queue_running: bool = false
var _global_item_queue_map: Dictionary = {}

# =============================================================================
# SUBSYSTEMS
# =============================================================================
var _teleport_manager: MuseumTeleportManager = null
var _multiplayer_sync: MuseumMultiplayerSync = null
var _exhibit_loader: ExhibitLoader = null

# Public access to exhibits (used by subsystems)
var _exhibits: Dictionary:
	get: return _exhibit_loader.get_exhibits() if _exhibit_loader else {}


# =============================================================================
# LIFECYCLE
# =============================================================================
func _init() -> void:
	RenderingServer.set_debug_generate_wireframes(true)


func _ready() -> void:
	_xr = Platform.is_xr()
	$WorldEnvironment.environment.ssr_enabled = not _xr

	_grid = $Lobby/GridMap

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
	GlobalMenuEvents.reset_custom_door.connect(_reset_custom_door)
	GlobalMenuEvents.set_custom_door.connect(_set_custom_door)
	GlobalMenuEvents.set_language.connect(_on_change_language)


func init(player: Node) -> void:
	_player = player
	_teleport_manager.init(self, player, _xr, max_teleport_distance)
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
		StaticData = ResourceLoader.load(_LOBBY_DATA_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		_set_up_lobby($Lobby)


# =============================================================================
# ROOM/EXHIBIT STATE
# =============================================================================
func get_current_room() -> String:
	return _current_room_title


func reset_to_lobby() -> void:
	_set_current_room_title("$Lobby")
	var exhibits: Dictionary = _exhibit_loader.get_exhibits()
	for exhibit_key: String in exhibits:
		if exhibit_key == "$Lobby":
			exhibits[exhibit_key]['exhibit'].visible = true
		else:
			exhibits[exhibit_key]['exhibit'].visible = false


func _set_current_room_title(title: String) -> void:
	if title == "$Lobby":
		_exhibit_loader.clear_backlink_map()

	_current_room_title = title
	WorkQueue.set_current_exhibit(title)
	GlobalMenuEvents.emit_set_current_room(title)
	_start_queue()

	# Race win detection
	if RaceManager.is_race_active() and title == RaceManager.get_target_article():
		RaceManager.notify_article_reached(NetworkManager.get_unique_id(), title)

	var fog_color: Color = ExhibitStyle.gen_fog(_current_room_title)
	var environment: Environment = $WorldEnvironment.environment

	if environment.fog_light_color != fog_color:
		var tween: Tween = create_tween()
		tween.tween_property(
				environment,
				"fog_light_color",
				fog_color,
				1.0)

		tween.set_trans(Tween.TRANS_LINEAR)
		tween.set_ease(Tween.EASE_IN_OUT)


# =============================================================================
# EXHIBIT LOADING (DELEGATES TO ExhibitLoader)
# =============================================================================
func _load_exhibit_from_entry(entry: Hall) -> void:
	_exhibit_loader.load_exhibit_from_entry(entry)


func _load_exhibit_from_exit(exit: Hall) -> void:
	_exhibit_loader.load_exhibit_from_exit(exit)


func _on_fetch_complete(titles: Array, context: Dictionary) -> void:
	_exhibit_loader.on_fetch_complete(titles, context)


func _on_wikidata_complete(entity: String, ctx: Dictionary) -> void:
	var result: Dictionary = ExhibitFetcher.get_result(entity)
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

	if body.is_in_group("Player"):
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
	get_tree().create_timer(QUEUE_DELAY).timeout.connect(_process_item_queue.bind())


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
