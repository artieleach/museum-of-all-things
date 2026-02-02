extends Node
class_name PlayerMountSystem
## Handles player mounting and dismounting: riding other players, managing rider state.

signal mount_requested(target: Node)
signal dismount_requested

const MOUNT_HEIGHT_OFFSET: float = 1.7

var _player: CharacterBody3D = null
var _crouch_system: PlayerCrouchSystem = null

var mounted_on: Node = null       # Player we're riding
var mounted_by: Node = null       # Player riding us
var _is_mounted: bool = false
var _has_rider: bool = false
var mount_peer_id: int = -1

# Store original collision settings
var _original_collision_layer: int = 524288
var _original_collision_mask: int = 524289


func init(player: CharacterBody3D, crouch_system: PlayerCrouchSystem) -> void:
	_player = player
	_crouch_system = crouch_system
	_original_collision_layer = player.collision_layer
	_original_collision_mask = player.collision_mask


func is_mounted() -> bool:
	return _is_mounted


func has_rider() -> bool:
	return _has_rider


func process_mount(_delta: float) -> void:
	if not _is_mounted:
		return

	# Follow mount's position
	if is_instance_valid(mounted_on):
		# Check if we can safely follow mount to their room
		var can_follow: bool = true
		if "current_room" in _player and "current_room" in mounted_on:
			if _player.current_room != mounted_on.current_room:
				# Only follow if the exhibit exists on this client (or it's the lobby)
				var target_room: String = mounted_on.current_room
				can_follow = target_room == "$Lobby"
				var museum: Node = null
				if not can_follow:
					var main_node: Node = _player.get_tree().current_scene
					if main_node and main_node.has_node("Museum"):
						museum = main_node.get_node("Museum")
						if museum.has_method("has_exhibit"):
							can_follow = museum.has_exhibit(target_room)

						# If exhibit doesn't exist, trigger loading so we can follow next frame
						if not can_follow and museum.has_method("load_exhibit_for_rider"):
							museum.load_exhibit_for_rider(_player.current_room, target_room)

				if can_follow:
					_player.current_room = target_room
					# Sync museum state for rider's client (updates fog, events, etc.)
					if museum and museum.has_method("sync_rider_to_room"):
						museum.sync_rider_to_room(target_room)

		# Only update position if we can safely follow
		if can_follow:
			_player.global_position = mounted_on.global_position + Vector3(0, MOUNT_HEIGHT_OFFSET, 0)
	else:
		# Mount became invalid, force dismount
		execute_dismount()


func try_mount_target() -> void:
	if not _player.has_node("Pivot/Camera3D/RayCast3D"):
		return

	var raycast: RayCast3D = _player.get_node("Pivot/Camera3D/RayCast3D")
	if not raycast.is_colliding():
		return

	var collider: Node = raycast.get_collider()
	if not collider:
		return

	# Check if we hit a player
	if collider.is_in_group("Player") and collider != _player:
		emit_signal("mount_requested", collider)


func request_dismount() -> void:
	emit_signal("dismount_requested")


func execute_mount(target: Node, target_peer_id: int = -1) -> void:
	if not is_instance_valid(target):
		return
	if "_has_rider" in target and target._has_rider:
		return  # Target already has a rider

	mounted_on = target
	mount_peer_id = target_peer_id
	_is_mounted = true

	# Clear velocity and disable all collision while mounted
	_player.velocity = Vector3.ZERO
	_player.collision_layer = 0
	_player.collision_mask = 0

	# Disable collision shapes entirely
	if _player.has_node("CollisionShape2"):
		_player.get_node("CollisionShape2").disabled = true
	if _player.has_node("Feet"):
		_player.get_node("Feet").disabled = true

	# Remove from Player group to prevent triggering area detections
	if _player.is_in_group("Player"):
		_player.remove_from_group("Player")

	# Force rider to crouched position immediately
	if _crouch_system:
		_crouch_system.force_crouched_position()

	# Tell mount they have a rider
	if target.has_method("_accept_rider"):
		target._accept_rider(_player)


func execute_dismount() -> void:
	if not _is_mounted or not is_instance_valid(mounted_on):
		_is_mounted = false
		mounted_on = null
		mount_peer_id = -1
		# Re-enable collision shapes in case we got here from invalid mount
		_restore_collision()
		return

	# Get dismount position (offset to the side of mount)
	var dismount_pos: Vector3 = mounted_on.global_position + mounted_on.global_transform.basis.x * 1.0
	dismount_pos.y = mounted_on.global_position.y

	# Tell mount we're leaving
	if mounted_on.has_method("_remove_rider"):
		mounted_on._remove_rider(_player)

	_restore_collision()

	# Move to dismount position
	_player.global_position = dismount_pos
	_player.velocity = Vector3.ZERO

	_is_mounted = false
	mounted_on = null
	mount_peer_id = -1


func _restore_collision() -> void:
	# Re-enable collision shapes
	if _player.has_node("CollisionShape2"):
		_player.get_node("CollisionShape2").disabled = false
	if _player.has_node("Feet"):
		_player.get_node("Feet").disabled = false

	# Re-enable collision
	_player.collision_layer = _original_collision_layer
	_player.collision_mask = _original_collision_mask

	# Re-add to Player group
	if not _player.is_in_group("Player"):
		_player.add_to_group("Player")


func accept_rider(rider: Node) -> void:
	mounted_by = rider
	_has_rider = true


func remove_rider(rider: Node) -> void:
	if mounted_by == rider:
		mounted_by = null
		_has_rider = false


func apply_network_mount_state(is_mounted_state: bool, peer_id: int, mount_node: Node) -> void:
	_is_mounted = is_mounted_state
	mount_peer_id = peer_id
	mounted_on = mount_node

	if is_mounted_state and is_instance_valid(mount_node):
		# Disable all collision while mounted
		_player.velocity = Vector3.ZERO
		_player.collision_layer = 0
		_player.collision_mask = 0
		if _player.has_node("CollisionShape2"):
			_player.get_node("CollisionShape2").disabled = true
		if _player.has_node("Feet"):
			_player.get_node("Feet").disabled = true
		# Remove from Player group to prevent triggering area detections
		if _player.is_in_group("Player"):
			_player.remove_from_group("Player")
		# Force crouched position
		if _crouch_system:
			_crouch_system.force_crouched_position()
	else:
		_restore_collision()
		mounted_on = null
		mount_peer_id = -1
