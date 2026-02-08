extends Node
class_name ExhibitLoader
## Handles fetching exhibit data, creating halls, and linking exits.

var _museum: Node3D = null
var _exhibits: Dictionary = {}
var _backlink_map: Dictionary = {}
var _exhibit_hist: Array = []
var _used_exhibit_heights: Dictionary = {}
var _loading_exhibits: Dictionary = {}  # Track in-flight fetches to prevent duplicates

var _starting_height: int = 40
var _height_increment: int = 20

# Configuration
var _items_per_room_estimate: int = 7
var _min_rooms_per_exhibit: int = 2
var _max_exhibits_loaded: int = 999  # Effectively unlimited - exhibits persist for multiplayer room tracking
var _min_room_dimension: int = 2
var _max_room_dimension: int = 5

# Scenes
var TiledExhibitGenerator: PackedScene = preload("res://scenes/TiledExhibitGenerator.tscn")
var WallItem: PackedScene = preload("res://scenes/items/WallItem.tscn")


func init(museum: Node3D, config: Dictionary) -> void:
	_museum = museum
	_items_per_room_estimate = config.get("items_per_room_estimate", 7)
	_min_rooms_per_exhibit = config.get("min_rooms_per_exhibit", 2)
	_max_exhibits_loaded = config.get("max_exhibits_loaded", 2)
	_min_room_dimension = config.get("min_room_dimension", 2)
	_max_room_dimension = config.get("max_room_dimension", 5)


func get_exhibits() -> Dictionary:
	return _exhibits


func get_backlink_map() -> Dictionary:
	return _backlink_map


func clear_backlink_map() -> void:
	_backlink_map.clear()


func get_free_exhibit_height() -> int:
	var height: int = _starting_height
	while _used_exhibit_heights.has(height):
		height += _height_increment
	_used_exhibit_heights[height] = true
	if OS.is_debug_build():
		print("placing exhibit at height=", height)
	return height


func release_exhibit_height(height: int) -> void:
	_used_exhibit_heights.erase(height)


func load_exhibit_from_entry(entry: Hall) -> void:
	var prev_article: String = Util.coalesce(entry.from_title, "Fungus")

	if entry.from_title == "Lobby":
		_link_backlink_to_exit(_museum.get_node("Lobby"), entry)
		return

	if _exhibits.has(prev_article):
		var exhibit: Node = _exhibits[prev_article].exhibit
		if is_instance_valid(exhibit):
			_link_backlink_to_exit(exhibit, entry)
			return

	ExhibitFetcher.fetch([prev_article], {
		"title": prev_article,
		"backlink": true,
		"entry": entry,
	})


func load_exhibit_from_exit(exit: Hall) -> void:
	var next_article: String = Util.coalesce(exit.to_title, "Fungus")

	if _exhibits.has(next_article):
		var next_exhibit: Dictionary = _exhibits[next_article]
		if (
			next_exhibit.has("entry") and
			next_exhibit.entry.hall_type[1] == exit.hall_type[1] and
			next_exhibit.entry.floor_type == exit.floor_type
		):
			link_halls(next_exhibit.entry, exit)
			next_exhibit.entry.from_title = exit.from_title
			return
		else:
			erase_exhibit(next_article)

	# Prevent duplicate fetches while one is in progress
	if _loading_exhibits.has(next_article):
		return
	_loading_exhibits[next_article] = true

	ExhibitFetcher.fetch([next_article], {
		"title": next_article,
		"exit": exit
	})


func load_exhibit_for_rider_without_hall(to_room: String, from_room: String) -> void:
	## Last resort loading for riders when no hall can be found.
	## Creates exhibit without hall linking (rider will be teleported by mount sync).
	if _exhibits.has(to_room):
		return

	if _loading_exhibits.has(to_room):
		return
	_loading_exhibits[to_room] = true

	ExhibitFetcher.fetch([to_room], {
		"title": to_room,
		"rider_load": true,
		"from_room": from_room
	})


func on_fetch_complete(_titles: Array, context: Dictionary) -> void:
	# we don't need to do anything to handle a prefetch
	if context.has("prefetch"):
		_loading_exhibits.erase(context.get("title", ""))
		return

	# Handle secret room content
	if context.get("secret_room", false):
		_on_secret_room_fetch_complete(context)
		return

	var backlink: bool = context.has("backlink") and context.backlink
	var rider_load: bool = context.has("rider_load") and context.rider_load
	var hall: Hall = context.entry if backlink else context.get("exit")
	var result: Dictionary = ExhibitFetcher.get_result(context.title)

	# For rider_load, we don't require a hall - we'll use defaults
	if not result or (not rider_load and not is_instance_valid(hall)):
		_loading_exhibits.erase(context.get("title", ""))
		return

	var prev_title: String
	if backlink:
		prev_title = _backlink_map[context.title]
	elif rider_load:
		prev_title = context.get("from_room", "")
	else:
		prev_title = hall.from_title

	ItemProcessor.create_items(context.title, result, prev_title)

	var data: Dictionary
	while not data:
		data = await ItemProcessor.items_complete
		if data.title != context.title:
			data = {}

	var doors: Array = data.doors
	var items: Array = data.items
	var extra_text: Array = data.extra_text
	var mood: int = data.get("mood", ExhibitMood.Mood.DEFAULT)
	var exhibit_height: int = get_free_exhibit_height()

	var new_exhibit: Node3D = TiledExhibitGenerator.instantiate()
	_museum.add_child(new_exhibit)

	# For rider_load without hall, use default hall_type; don't connect exit_added
	var hall_type: Array = hall.hall_type if is_instance_valid(hall) else [0, 0]
	if is_instance_valid(hall):
		new_exhibit.exit_added.connect(_on_exit_added.bind(doors, backlink, new_exhibit, hall))
	else:
		new_exhibit.exit_added.connect(_on_exit_added_no_hall.bind(doors, new_exhibit))

	new_exhibit.generate({
		"start_pos": Vector3.UP * exhibit_height,
		"min_room_dimension": _min_room_dimension,
		"max_room_dimension": _max_room_dimension,
		"title": context.title,
		"prev_title": prev_title,
		"no_props": items.size() < 10,
		"hall_type": hall_type,
		"exit_limit": doors.size(),
		"mood": mood,
	})

	if not _exhibits.has(context.title):
		_exhibits[context.title] = { "entry": new_exhibit.entry, "exhibit": new_exhibit, "height": exhibit_height, "mood": mood }
		_exhibit_hist.append(context.title)

		# Spawn NPCs if enabled
		if _museum.npcs_enabled:
			var npc_manager: NPCManager = NPCManager.new()
			new_exhibit.add_child(npc_manager)
			npc_manager.call_deferred("init", new_exhibit, _museum.npcs_per_exhibit)
		if _exhibit_hist.size() > _max_exhibits_loaded:
			call_deferred("_cleanup_old_exhibits", new_exhibit.title)

	# Clear loading flag after exhibit exists (handles both new and duplicate fetch cases)
	_loading_exhibits.erase(context.title)

	var image_titles: Array = []
	var item_queue: Array = []
	for item_data: Dictionary in items:
		if item_data:
			if item_data.type == "image" and item_data.has("title") and item_data.title != "":
				image_titles.append(item_data.title)
			item_queue.append(_add_item.bind(new_exhibit, item_data))

	if result.has("wikidata_entity"):
		_museum._queue_item_front(context.title, ExhibitFetcher.fetch_wikidata.bind(result.wikidata_entity, {
			"exhibit": new_exhibit,
			"title": context.title,
			"hall": hall,
			"backlink": backlink,
			"extra_text": extra_text
		}))

	_museum._queue_item_front(context.title, ExhibitFetcher.fetch_images.bind(image_titles, null))
	_museum._queue_item(context.title, item_queue)

	# Spawn persistent ghost silhouettes from previous visits
	var ghosts: Array = TraceManager.get_ghosts(context.title)
	for ghost_data: Dictionary in ghosts:
		GhostSilhouette.spawn_from_data(new_exhibit, ghost_data)

	# Queue secret room content fetch if exhibit has a secret room
	if new_exhibit.has_secret_room():
		var secret_article: String = SecretRoomContent.get_secret_article(context.title)
		var secret_slots: Array = new_exhibit.get_secret_item_slots()
		if secret_slots.size() > 0:
			ExhibitFetcher.fetch([secret_article], {
				"title": secret_article,
				"secret_room": true,
				"exhibit": new_exhibit,
				"exhibit_title": context.title,
				"secret_slots": secret_slots,
			})

	if backlink:
		new_exhibit.entry.loader.body_entered.connect(_museum._on_loader_body_entered.bind(new_exhibit.entry, true))
	elif rider_load:
		# For rider_load, just connect the entry loader without linking to a source hall
		new_exhibit.entry.loader.body_entered.connect(_museum._on_loader_body_entered.bind(new_exhibit.entry, true))
	else:
		link_halls(new_exhibit.entry, hall)


func _on_exit_added_no_hall(exit: Hall, doors: Array, new_exhibit: Node3D) -> void:
	## Simplified exit handler for rider_load case without a source hall.
	var linked_exhibit: String = Util.coalesce(doors.pop_front(), "")
	exit.to_title = linked_exhibit
	if linked_exhibit != "":
		ExhibitGraph.add_edge(new_exhibit.title, linked_exhibit)
	exit.loader.body_entered.connect(_museum._on_loader_body_entered.bind(exit))


func _on_exit_added(exit: Hall, doors: Array, backlink: bool, new_exhibit: Node3D, hall: Hall) -> void:
	var linked_exhibit: String = Util.coalesce(doors.pop_front(), "")
	exit.to_title = linked_exhibit
	if linked_exhibit != "":
		ExhibitGraph.add_edge(new_exhibit.title, linked_exhibit)
	exit.loader.body_entered.connect(_museum._on_loader_body_entered.bind(exit))
	if is_instance_valid(hall) and backlink and exit.to_title == hall.to_title:
		link_halls(hall, exit)


func link_halls(entry: Hall, exit: Hall) -> void:
	if entry.linked_hall == exit and exit.linked_hall == entry:
		return

	for hall: Hall in [entry, exit]:
		Util.clear_listeners(hall, "on_player_toward_exit")
		Util.clear_listeners(hall, "on_player_toward_entry")

	_backlink_map[exit.to_title] = exit.from_title
	exit.on_player_toward_exit.connect(_museum._teleport_manager.teleport.bind(exit, entry))
	entry.on_player_toward_entry.connect(_museum._teleport_manager.teleport.bind(entry, exit, true))
	exit.linked_hall = entry
	entry.linked_hall = exit

	if exit.player_in_hall and exit.player_direction == "exit":
		_museum._teleport_manager.teleport(exit, entry)
	elif entry.player_in_hall and entry.player_direction == "entry":
		_museum._teleport_manager.teleport(entry, exit, true)


func _link_backlink_to_exit(exhibit: Node, hall: Hall) -> void:
	if not is_instance_valid(exhibit) or not is_instance_valid(hall):
		return

	var new_hall: Hall = null
	for exit: Hall in exhibit.exits:
		if exit.to_title == hall.to_title:
			new_hall = exit
			break
	if not new_hall and exhibit.has_method("get") and exhibit.entry:
		Log.error("ExhibitLoader", "could not backlink new hall")
		new_hall = exhibit.entry
	if new_hall:
		link_halls(hall, new_hall)


func _cleanup_old_exhibits(new_title: String) -> void:
	for e: int in range(_exhibit_hist.size()):
		var key: String = _exhibit_hist[e]
		if _exhibits.has(key):
			var old_exhibit: Dictionary = _exhibits[key]
			var player: Node = _museum._player
			if player and abs(4 * old_exhibit.height - player.position.y) < 20:
				continue
			if old_exhibit.exhibit.title == new_title:
				continue
			erase_exhibit(key)
			break


func _on_secret_room_fetch_complete(context: Dictionary) -> void:
	var result: Dictionary = ExhibitFetcher.get_result(context.title)
	if not result:
		return
	var exhibit: Node3D = context.get("exhibit")
	if not is_instance_valid(exhibit):
		return

	var secret_slots: Array = context.get("secret_slots", [])
	if secret_slots.is_empty():
		return

	# Create items from the secret article
	ItemProcessor.create_items(context.title, result)
	var data: Dictionary
	while not data:
		data = await ItemProcessor.items_complete
		if data.title != context.title:
			data = {}

	var items: Array = data.items
	var slot_idx: int = 0
	var image_titles: Array = []
	for item_data: Dictionary in items:
		if slot_idx >= secret_slots.size():
			break
		if item_data and item_data.has("type"):
			if item_data.type == "image" and item_data.has("title") and item_data.title != "":
				image_titles.append(item_data.title)
			var slot: Array = secret_slots[slot_idx]
			_museum._queue_item(context.exhibit_title, _add_item_at_slot.bind(exhibit, item_data, slot))
			slot_idx += 1

	if image_titles.size() > 0:
		_museum._queue_item_front(context.exhibit_title, ExhibitFetcher.fetch_images.bind(image_titles, null))


func _add_item_at_slot(exhibit: Node3D, item_data: Dictionary, slot: Array) -> void:
	if not is_instance_valid(exhibit):
		return
	var item: Node3D = WallItem.instantiate()
	item.position = GridUtils.grid_to_world(slot[0]) - slot[1] * 0.01
	item.rotation.y = GridUtils.vec_to_rot(slot[1])
	_init_item(exhibit, item, item_data)


func erase_exhibit(key: String) -> void:
	if OS.is_debug_build():
		print("erasing exhibit ", key)
	_exhibits[key].exhibit.queue_free()
	release_exhibit_height(_exhibits[key].height)
	_museum._global_item_queue_map.erase(key)
	_exhibits.erase(key)
	var i: int = _exhibit_hist.find(key)
	if i >= 0:
		_exhibit_hist.remove_at(i)


func _add_item(exhibit: Node3D, item_data: Dictionary) -> void:
	if not is_instance_valid(exhibit):
		return

	var slot: Variant = exhibit.get_item_slot()
	if slot == null:
		exhibit.add_room()
		if exhibit.has_item_slot():
			_add_item(exhibit, item_data)
		else:
			Log.error("ExhibitLoader", "unable to add item slots to exhibit")
		return

	var item: Node3D = WallItem.instantiate()
	item.position = GridUtils.grid_to_world(slot[0]) - slot[1] * 0.01
	item.rotation.y = GridUtils.vec_to_rot(slot[1])

	_init_item(exhibit, item, item_data)


func _init_item(exhibit: Node3D, item: Node3D, data: Dictionary) -> void:
	if is_instance_valid(exhibit) and is_instance_valid(item):
		exhibit.add_child(item)
		item.init(data)
