extends Node
class_name MultiplayerController
## Handles network player spawning, position sync, and multiplayer session management.

signal player_spawned(peer_id: int)
signal player_removed(peer_id: int)

const POSITION_SYNC_INTERVAL: float = 0.05  # 20 updates per second

var _main: Node = null
var _network_players: Dictionary = {}  # peer_id -> player node
var _is_multiplayer_game: bool = false
var _position_sync_timer: float = 0.0
var _server_mode: bool = false
var _server_port: int = 7777

var NetworkPlayer: PackedScene = null
var _starting_point: Vector3 = Vector3(0, 4, 0)


func init(main: Node, network_player_scene: PackedScene, starting_point: Vector3) -> void:
	_main = main
	NetworkPlayer = network_player_scene
	_starting_point = starting_point
	NetworkManager.player_room_changed.connect(_on_player_room_changed)


func set_server_mode(enabled: bool, port: int = 7777) -> void:
	_server_mode = enabled
	_server_port = port


func is_server_mode() -> bool:
	return _server_mode


func get_server_port() -> int:
	return _server_port


func is_multiplayer_game() -> bool:
	return _is_multiplayer_game


func set_multiplayer_game(value: bool) -> void:
	_is_multiplayer_game = value


func get_network_players() -> Dictionary:
	return _network_players


func spawn_network_player(peer_id: int) -> Node:
	if _network_players.has(peer_id):
		return _network_players[peer_id]

	var net_player: Node = NetworkPlayer.instantiate()
	net_player.name = "NetworkPlayer_" + str(peer_id)
	net_player.is_local = false
	_main.add_child(net_player)

	net_player.set_player_authority(peer_id)
	net_player.set_player_name(NetworkManager.get_player_name(peer_id))
	net_player.set_player_color(NetworkManager.get_player_color(peer_id))
	var skin_url: String = NetworkManager.get_player_skin(peer_id)
	if skin_url != "":
		net_player.set_player_skin(skin_url)
	net_player.position = _starting_point

	_network_players[peer_id] = net_player
	MultiplayerEvents.emit_player_joined(peer_id, NetworkManager.get_player_name(peer_id))

	Log.info("Multiplayer", "Spawned network player for peer %d" % peer_id)

	emit_signal("player_spawned", peer_id)
	return net_player


func remove_network_player(peer_id: int, local_player: Node, mount_state: Dictionary) -> void:
	if _network_players.has(peer_id):
		var player_node: Node = _network_players[peer_id]
		if is_instance_valid(player_node):
			# Handle mount cleanup before removing player
			# If disconnected player had a rider, dismount them
			if player_node._has_rider and is_instance_valid(player_node.mounted_by):
				player_node.mounted_by.execute_dismount()

			# If disconnected player was riding someone, clear mount's rider state
			if player_node._is_mounted and is_instance_valid(player_node.mounted_on):
				player_node.mounted_on._remove_rider(player_node)

			# If local player was mounted on disconnected player, dismount
			if local_player and local_player._is_mounted and local_player.mounted_on == player_node:
				local_player.execute_dismount()

			player_node.queue_free()
			_network_players.erase(peer_id)

		# Clear mount state tracking
		if mount_state.has(peer_id):
			mount_state.erase(peer_id)

		MultiplayerEvents.emit_player_left(peer_id)
		emit_signal("player_removed", peer_id)

		Log.info("Multiplayer", "Removed network player for peer %d" % peer_id)


func update_player_info(peer_id: int) -> void:
	if _network_players.has(peer_id):
		var net_player: Node = _network_players[peer_id]
		if is_instance_valid(net_player):
			net_player.set_player_name(NetworkManager.get_player_name(peer_id))
			net_player.set_player_color(NetworkManager.get_player_color(peer_id))
			var skin_url: String = NetworkManager.get_player_skin(peer_id)
			if skin_url != "":
				net_player.set_player_skin(skin_url)
			else:
				net_player.clear_player_skin()


func end_multiplayer_session() -> void:
	_is_multiplayer_game = false

	# Remove all network players
	for peer_id: int in _network_players.keys():
		var player_node: Node = _network_players[peer_id]
		if is_instance_valid(player_node):
			player_node.queue_free()
	_network_players.clear()

	MultiplayerEvents.emit_multiplayer_ended()


func get_player_by_peer_id(peer_id: int, local_player: Node) -> Node:
	if peer_id == NetworkManager.get_unique_id():
		return local_player
	elif _network_players.has(peer_id):
		return _network_players[peer_id]
	return null


func get_all_players(local_player: Node) -> Array:
	var players: Array = [local_player]
	for peer_id: int in _network_players:
		if is_instance_valid(_network_players[peer_id]):
			players.append(_network_players[peer_id])
	return players


func process_position_sync(delta: float, local_player: Node) -> bool:
	if not _is_multiplayer_game or not NetworkManager.is_multiplayer_active() or not local_player:
		return false

	_position_sync_timer += delta
	if _position_sync_timer >= POSITION_SYNC_INTERVAL:
		_position_sync_timer = 0.0
		return true
	return false


func apply_network_position(peer_id: int, pos: Vector3, rot_y: float, pivot_rot_x: float, pivot_pos_y: float, is_mounted: bool, mounted_peer_id: int, local_player: Node, current_room: String = "Lobby") -> void:
	# Update room in player_info
	if NetworkManager.player_info.has(peer_id):
		NetworkManager.player_info[peer_id].current_room = current_room

	if _network_players.has(peer_id):
		var net_player: Node = _network_players[peer_id]
		if is_instance_valid(net_player):
			# Update network player's room property (needed for mount room syncing)
			if "current_room" in net_player:
				net_player.current_room = current_room

			# Check if local player is mounted on this network player
			var local_riding_this_player: bool = false
			if local_player and "_is_mounted" in local_player and local_player._is_mounted:
				if "mount_peer_id" in local_player and local_player.mount_peer_id == peer_id:
					local_riding_this_player = true
					# Only sync room if the exhibit exists on this client (or it's the lobby)
					if "current_room" in local_player and local_player.current_room != current_room:
						var can_transition: bool = current_room == "Lobby"
						if not can_transition and _main and _main.has_node("Museum"):
							var museum: Node = _main.get_node("Museum")
							if museum.has_method("has_exhibit"):
								can_transition = museum.has_exhibit(current_room)
						if can_transition:
							local_player.current_room = current_room

			# Check if player is in the same room before showing
			var local_room: String = local_player.current_room if local_player and "current_room" in local_player else "Lobby"

			# For mounted players, also check mount's room in case of sync timing issues
			var effective_room: String = current_room
			if is_mounted and mounted_peer_id > 0:
				var mount_room: String = NetworkManager.get_player_room(mounted_peer_id)
				if mount_room != "" and mount_room != current_room:
					effective_room = mount_room

			# Always show mount if local player is riding them, even if rooms differ
			if effective_room != local_room and not local_riding_this_player:
				net_player.set_body_visible(false)
				return

			net_player.set_body_visible(true)

			if net_player.has_method("apply_network_position"):
				net_player.apply_network_position(pos, rot_y, pivot_rot_x, pivot_pos_y)
			if net_player.has_method("apply_network_mount_state"):
				var mount_node: Node = get_player_by_peer_id(mounted_peer_id, local_player) if is_mounted else null
				net_player.apply_network_mount_state(is_mounted, mounted_peer_id, mount_node)


func _on_player_room_changed(peer_id: int, _room: String) -> void:
	# If the local player changed rooms, update visibility of all remote players
	if peer_id == NetworkManager.get_unique_id():
		if _main and _main.has_method("get_local_player"):
			var local_player: Node = _main.get_local_player()
			if local_player:
				update_all_player_visibility(local_player)
	else:
		# A remote player changed rooms, update just their visibility
		_update_player_visibility(peer_id)


func _update_player_visibility(peer_id: int) -> void:
	if not _network_players.has(peer_id):
		return
	var net_player: Node = _network_players[peer_id]
	if not is_instance_valid(net_player):
		return

	var remote_room: String = NetworkManager.get_player_room(peer_id)

	# If mounted, use mount's room to handle room transition sync timing
	if "_is_mounted" in net_player and net_player._is_mounted:
		if "mount_peer_id" in net_player and net_player.mount_peer_id > 0:
			var mount_room: String = NetworkManager.get_player_room(net_player.mount_peer_id)
			if mount_room != "":
				remote_room = mount_room

	var local_room: String = "Lobby"
	if _main and _main.has_method("get_local_player"):
		var local_player: Node = _main.get_local_player()
		if local_player and "current_room" in local_player:
			local_room = local_player.current_room

	net_player.set_body_visible(remote_room == local_room)


func update_all_player_visibility(local_player: Node) -> void:
	var local_room: String = local_player.current_room if local_player and "current_room" in local_player else "Lobby"
	for peer_id: int in _network_players:
		var net_player: Node = _network_players[peer_id]
		if is_instance_valid(net_player):
			var remote_room: String = NetworkManager.get_player_room(peer_id)

			# If mounted, use mount's room to handle room transition sync timing
			if "_is_mounted" in net_player and net_player._is_mounted:
				if "mount_peer_id" in net_player and net_player.mount_peer_id > 0:
					var mount_room: String = NetworkManager.get_player_room(net_player.mount_peer_id)
					if mount_room != "":
						remote_room = mount_room

			net_player.set_body_visible(remote_room == local_room)
