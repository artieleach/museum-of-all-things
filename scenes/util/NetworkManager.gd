extends Node

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connection_failed
signal connection_succeeded
signal server_disconnected
signal player_info_updated(id: int)
signal player_room_changed(id: int, room: String)

# Deprecated: use Constants.DEFAULT_PORT and Constants.MAX_PLAYERS instead
const DEFAULT_PORT := Constants.DEFAULT_PORT
const MAX_PLAYERS := Constants.MAX_PLAYERS

var peer: ENetMultiplayerPeer = null
var player_info: Dictionary = {}  # peer_id -> { name: String, color: Color, skin_url: String }
var local_player_name: String = "Player"
var local_player_color: Color = Color(0.2, 0.5, 0.8, 1.0)  # Default blue
var local_player_skin: String = ""
var is_hosting: bool = false
var is_dedicated_server: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT, dedicated: bool = false) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		peer = null
		return error

	multiplayer.multiplayer_peer = peer
	is_hosting = true
	is_dedicated_server = dedicated

	# Register host player (skip for dedicated servers)
	if not dedicated:
		player_info[1] = { "name": local_player_name, "color": local_player_color, "skin_url": local_player_skin, "current_room": "Lobby" }

	Log.debug("Network", "Hosting game on port %d (dedicated: %s)" % [port, str(dedicated)])

	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		peer = null
		return error

	multiplayer.multiplayer_peer = peer
	is_hosting = false

	Log.debug("Network", "Joining game at %s:%d" % [address, port])

	return OK

func disconnect_from_game() -> void:
	if peer:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = null
	player_info.clear()
	is_hosting = false
	is_dedicated_server = false

	Log.debug("Network", "Disconnected from game")

func is_multiplayer_active() -> bool:
	return peer != null and multiplayer.multiplayer_peer != null

func is_server() -> bool:
	return is_multiplayer_active() and multiplayer.is_server()

func get_unique_id() -> int:
	if is_multiplayer_active():
		return multiplayer.get_unique_id()
	return 1

func get_player_list() -> Array:
	return player_info.keys()

func get_player_name(peer_id: int) -> String:
	if player_info.has(peer_id):
		return player_info[peer_id].name
	return "Unknown"

func get_player_color(peer_id: int) -> Color:
	if player_info.has(peer_id) and player_info[peer_id].has("color"):
		return player_info[peer_id].color
	return Color(0.2, 0.5, 0.8, 1.0)  # Default blue

func get_player_skin(peer_id: int) -> String:
	if player_info.has(peer_id) and player_info[peer_id].has("skin_url"):
		return player_info[peer_id].skin_url
	return ""

func set_local_player_room(room: String) -> void:
	var my_id = get_unique_id()
	if player_info.has(my_id):
		player_info[my_id].current_room = room
		if is_multiplayer_active():
			_broadcast_player_room.rpc(my_id, room)

func get_player_room(peer_id: int) -> String:
	if player_info.has(peer_id) and player_info[peer_id].has("current_room"):
		return player_info[peer_id].current_room
	return "Lobby"

@rpc("any_peer", "call_local", "reliable")
func _broadcast_player_room(peer_id: int, room: String) -> void:
	if player_info.has(peer_id):
		player_info[peer_id].current_room = room
	emit_signal("player_room_changed", peer_id, room)

func set_local_player_name(player_name: String) -> void:
	local_player_name = player_name
	var my_id = get_unique_id()
	if player_info.has(my_id):
		player_info[my_id].name = player_name
		# Broadcast info change to all peers
		if is_multiplayer_active():
			_broadcast_player_info.rpc(my_id, player_name, local_player_color.to_html(), local_player_skin)

func set_local_player_color(color: Color) -> void:
	local_player_color = color
	var my_id = get_unique_id()
	if player_info.has(my_id):
		player_info[my_id].color = color
		# Broadcast info change to all peers
		if is_multiplayer_active():
			_broadcast_player_info.rpc(my_id, local_player_name, color.to_html(), local_player_skin)

func set_local_player_skin(skin_url: String) -> void:
	local_player_skin = skin_url
	var my_id = get_unique_id()
	if player_info.has(my_id):
		player_info[my_id].skin_url = skin_url
		# Broadcast info change to all peers
		if is_multiplayer_active():
			_broadcast_player_info.rpc(my_id, local_player_name, local_player_color.to_html(), skin_url)

@rpc("any_peer", "call_local", "reliable")
func _broadcast_player_info(peer_id: int, player_name: String, color_html: String, skin_url: String = "") -> void:
	var current_room: String = "Lobby"
	if player_info.has(peer_id) and player_info[peer_id].has("current_room"):
		current_room = player_info[peer_id].current_room
	player_info[peer_id] = { "name": player_name, "color": Color.html(color_html), "skin_url": skin_url, "current_room": current_room }
	emit_signal("player_info_updated", peer_id)

@rpc("any_peer", "reliable")
func _request_player_info(from_peer: int) -> void:
	# Send our info back to the requesting peer
	_receive_player_info.rpc_id(from_peer, multiplayer.get_unique_id(), local_player_name, local_player_color.to_html(), local_player_skin)

@rpc("any_peer", "reliable")
func _receive_player_info(peer_id: int, player_name: String, color_html: String, skin_url: String = "") -> void:
	var current_room: String = "Lobby"
	if player_info.has(peer_id) and player_info[peer_id].has("current_room"):
		current_room = player_info[peer_id].current_room
	player_info[peer_id] = { "name": player_name, "color": Color.html(color_html), "skin_url": skin_url, "current_room": current_room }
	emit_signal("player_info_updated", peer_id)

func _on_peer_connected(id: int) -> void:
	Log.info("Network", "Peer connected: %d" % id)

	# Request player info from the new peer
	_request_player_info.rpc_id(id, multiplayer.get_unique_id())

	# Send our info to the new peer (skip for dedicated servers)
	if not is_dedicated_server:
		_receive_player_info.rpc_id(id, multiplayer.get_unique_id(), local_player_name, local_player_color.to_html(), local_player_skin)
		# Also send our current room so the new peer knows where we are
		var my_id := multiplayer.get_unique_id()
		var my_room := get_player_room(my_id)
		_broadcast_player_room.rpc_id(id, my_id, my_room)

	# If we're the server, send all existing player info to the new peer
	if is_server():
		for existing_id in player_info.keys():
			if existing_id != id:
				var info = player_info[existing_id]
				var color_html = info.color.to_html() if info.has("color") else Color(0.2, 0.5, 0.8, 1.0).to_html()
				var skin = info.skin_url if info.has("skin_url") else ""
				_receive_player_info.rpc_id(id, existing_id, info.name, color_html, skin)
				# Also send each existing player's current room
				var room: String = info.current_room if info.has("current_room") else "Lobby"
				_broadcast_player_room.rpc_id(id, existing_id, room)

	emit_signal("peer_connected", id)

func _on_peer_disconnected(id: int) -> void:
	Log.info("Network", "Peer disconnected: %d" % id)

	player_info.erase(id)
	emit_signal("peer_disconnected", id)

func _on_connected_to_server() -> void:
	Log.debug("Network", "Connected to server")

	# Register ourselves
	var my_id = multiplayer.get_unique_id()
	player_info[my_id] = { "name": local_player_name, "color": local_player_color, "skin_url": local_player_skin, "current_room": "Lobby" }

	emit_signal("connection_succeeded")

func _on_connection_failed() -> void:
	Log.warn("Network", "Connection failed")

	peer = null
	multiplayer.multiplayer_peer = null
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	Log.info("Network", "Server disconnected")

	peer = null
	multiplayer.multiplayer_peer = null
	player_info.clear()
	is_hosting = false
	is_dedicated_server = false
	emit_signal("server_disconnected")
