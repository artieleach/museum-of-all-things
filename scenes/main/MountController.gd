extends Node
class_name MountController
## Handles mount request processing and RPC synchronization across peers.

var _main: Node = null
var _mount_state: Dictionary = {}  # peer_id -> mount_peer_id (-1 if not mounted)

var _multiplayer_controller: MultiplayerController = null


func init(main: Node, multiplayer_controller: MultiplayerController) -> void:
	_main = main
	_multiplayer_controller = multiplayer_controller


func get_mount_state() -> Dictionary:
	return _mount_state


func request_mount(target: Node, local_player: Node) -> void:
	if not _multiplayer_controller.is_multiplayer_game() or not NetworkManager.is_multiplayer_active():
		# Single player - just mount directly
		if is_instance_valid(target) and not target.has_rider:
			local_player.execute_mount(target)
		return

	# Multiplayer - find peer_id of target
	var mount_peer_id: int = -1
	var network_players: Dictionary = _multiplayer_controller.get_network_players()
	for peer_id: int in network_players:
		if network_players[peer_id] == target:
			mount_peer_id = peer_id
			break

	if mount_peer_id == -1:
		return  # Target not found

	# Send RPC to server
	if NetworkManager.is_server():
		handle_mount_request(NetworkManager.get_unique_id(), mount_peer_id, local_player)
	else:
		_main._request_mount_rpc.rpc_id(1, NetworkManager.get_unique_id(), mount_peer_id)


func request_dismount(local_player: Node) -> void:
	if not _multiplayer_controller.is_multiplayer_game() or not NetworkManager.is_multiplayer_active():
		# Single player - dismount directly
		local_player.execute_dismount()
		return

	# Multiplayer - send RPC to server
	if NetworkManager.is_server():
		handle_dismount_request(NetworkManager.get_unique_id(), local_player)
	else:
		_main._request_dismount_rpc.rpc_id(1, NetworkManager.get_unique_id())


func handle_mount_request(rider_peer_id: int, mount_peer_id: int, local_player: Node) -> void:
	# Server-side validation and execution
	var rider: Node = _multiplayer_controller.get_player_by_peer_id(rider_peer_id, local_player)
	var mount: Node = _multiplayer_controller.get_player_by_peer_id(mount_peer_id, local_player)

	if not is_instance_valid(rider) or not is_instance_valid(mount):
		return
	if rider == mount:
		return  # Can't mount self
	if mount.has_rider:
		return  # Mount already has a rider
	if rider.is_mounted:
		return  # Rider is already mounted
	if "in_hall" in rider and rider.in_hall:
		return  # Can't mount in a hallway

	# Store mount state
	_mount_state[rider_peer_id] = mount_peer_id

	# Execute locally if this is the server's player
	if rider_peer_id == NetworkManager.get_unique_id():
		local_player.execute_mount(mount, mount_peer_id)
	elif _multiplayer_controller.get_network_players().has(rider_peer_id):
		_multiplayer_controller.get_network_players()[rider_peer_id].execute_mount(mount, mount_peer_id)

	# Broadcast to all clients
	_main._execute_mount_sync.rpc(rider_peer_id, mount_peer_id)


func handle_dismount_request(rider_peer_id: int, local_player: Node) -> void:
	# Server-side validation and execution
	if not _mount_state.has(rider_peer_id) or _mount_state[rider_peer_id] == -1:
		return  # Not mounted

	# Clear mount state
	_mount_state[rider_peer_id] = -1

	# Execute locally if this is the server's player
	if rider_peer_id == NetworkManager.get_unique_id():
		local_player.execute_dismount()
	elif _multiplayer_controller.get_network_players().has(rider_peer_id):
		_multiplayer_controller.get_network_players()[rider_peer_id].execute_dismount()

	# Broadcast to all clients
	_main._execute_dismount_sync.rpc(rider_peer_id)


func execute_mount_sync(rider_peer_id: int, mount_peer_id: int, local_player: Node) -> void:
	var rider: Node = _multiplayer_controller.get_player_by_peer_id(rider_peer_id, local_player)
	var mount: Node = _multiplayer_controller.get_player_by_peer_id(mount_peer_id, local_player)

	if not is_instance_valid(rider) or not is_instance_valid(mount):
		return

	# Don't re-execute if we're the server (already done)
	if NetworkManager.is_server():
		return

	rider.execute_mount(mount, mount_peer_id)
	Log.debug("Mount", "Mount sync - %d mounted on %d" % [rider_peer_id, mount_peer_id])


func execute_dismount_sync(rider_peer_id: int, local_player: Node) -> void:
	var rider: Node = _multiplayer_controller.get_player_by_peer_id(rider_peer_id, local_player)
	if not is_instance_valid(rider):
		return
	if NetworkManager.is_server():
		return
	rider.execute_dismount()
	Log.debug("Mount", "Dismount sync - %d" % rider_peer_id)
