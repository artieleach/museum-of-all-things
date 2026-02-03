extends Node
class_name MuseumTeleportManager
## Handles teleporting players between halls and managing hall door states.

var _museum: Node3D = null
var _players: Array[Node] = []
var _max_teleport_distance: float = 10.0


func init(museum: Node3D, player: Node, max_teleport_distance: float) -> void:
	_museum = museum
	_players.clear()
	if player:
		_players.append(player)
	_max_teleport_distance = max_teleport_distance


func set_player(player: Node) -> void:
	## Backwards compatibility - sets the first player
	_players.clear()
	if player:
		_players.append(player)


func add_player(player: Node) -> void:
	if player and player not in _players:
		_players.append(player)


func remove_player(player: Node) -> void:
	_players.erase(player)


func get_players() -> Array[Node]:
	return _players


func teleport(from_hall: Hall, to_hall: Hall, entry_to_exit: bool = false) -> void:
	_prepare_halls_for_teleport(from_hall, to_hall, entry_to_exit)


func _prepare_halls_for_teleport(from_hall: Hall, to_hall: Hall, entry_to_exit: bool = false) -> void:
	if not is_instance_valid(from_hall) or not is_instance_valid(to_hall):
		return

	from_hall.entry_door.set_open(false)
	from_hall.exit_door.set_open(false)
	to_hall.entry_door.set_open(false, true)
	to_hall.exit_door.set_open(false, true)

	var timer: Timer = _museum.get_node("TeleportTimer")
	Util.clear_listeners(timer, "timeout")
	timer.stop()
	timer.timeout.connect(
		_teleport_player.bind(from_hall, to_hall, entry_to_exit),
		ConnectFlags.CONNECT_ONE_SHOT
	)
	timer.start(HallDoor.animation_duration)


func toggle_exhibit_visibility(hide_title: String, show_title: String, exhibits: Dictionary) -> void:
	var old_exhibit: Node = exhibits[hide_title]['exhibit']
	old_exhibit.visible = false

	var new_exhibit: Node = exhibits[show_title]['exhibit']
	new_exhibit.visible = true


func _teleport_player(from_hall: Hall, to_hall: Hall, entry_to_exit: bool = false) -> void:
	# Exhibits stay visible - room filtering is handled by player visibility instead

	if is_instance_valid(from_hall) and is_instance_valid(to_hall):
		var rot_diff: float = GridUtils.vec_to_rot(to_hall.to_dir) - GridUtils.vec_to_rot(from_hall.to_dir)
		var any_player_teleported: bool = false

		# Teleport all tracked players that are within range
		for player: Node in _players:
			if not is_instance_valid(player):
				continue
			# Skip mounted players - they follow their mount
			if "_is_mounted" in player and player._is_mounted:
				continue
			var distance: float = (from_hall.position - player.global_position).length()
			if distance <= _max_teleport_distance:
				_teleport_single_player(player, from_hall, to_hall, rot_diff)
				any_player_teleported = true

		# In multiplayer, also teleport network players not in our tracked list
		if NetworkManager.is_multiplayer_active():
			_teleport_network_players_in_range(from_hall, to_hall, rot_diff)

		if not any_player_teleported:
			return

		if entry_to_exit:
			to_hall.entry_door.set_open(true)
		else:
			to_hall.exit_door.set_open(true)
			from_hall.entry_door.set_open(true, false)

		_museum._set_current_room_title(from_hall.from_title if entry_to_exit else from_hall.to_title)
	elif is_instance_valid(from_hall):
		if entry_to_exit:
			_museum._load_exhibit_from_entry(from_hall)
		else:
			_museum._load_exhibit_from_exit(from_hall)
	elif is_instance_valid(to_hall):
		if entry_to_exit:
			_museum._load_exhibit_from_exit(to_hall)
		else:
			_museum._load_exhibit_from_entry(to_hall)


func _teleport_single_player(player: Node, from_hall: Hall, to_hall: Hall, rot_diff: float) -> void:
	var diff_from: Vector3 = player.global_position - from_hall.position
	player.global_position = to_hall.position + diff_from.rotated(Vector3(0, 1, 0), rot_diff)
	player.global_rotation.y += rot_diff


func _teleport_network_players_in_range(from_hall: Hall, to_hall: Hall, rot_diff: float) -> void:
	var main_node: Node = _museum.get_parent()
	if main_node and main_node.has_method("get_all_players"):
		var all_players: Array = main_node.get_all_players()
		for player: Node in all_players:
			if player in _players or not is_instance_valid(player):
				continue
			# Skip mounted players - they follow their mount
			if "_is_mounted" in player and player._is_mounted:
				continue
			# Only teleport if within range
			var distance: float = (from_hall.position - player.global_position).length()
			if distance <= _max_teleport_distance:
				_teleport_single_player(player, from_hall, to_hall, rot_diff)
