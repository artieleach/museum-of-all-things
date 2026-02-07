extends CharacterBody3D
## Player controller with movement, crouching, mounting, and network interpolation support.
## Uses subsystems for crouch, mount, and skin functionality.

const INTERPOLATION_SPEED: float = 15.0
const TELEPORT_SNAP_THRESHOLD: float = 5.0
const BOB_FREQUENCY: float = 12.0
const BOB_AMPLITUDE: float = 0.05

var _gravity: float = -30.0
var _bob_time: float = 0.0
var _body_mesh_base_y: float = 0.667
var _crouch_move_speed: float = 4.0
var _mouse_sensitivity: float = 0.002
var _joy_sensitivity: float = 0.025
var _joy_deadzone: float = 0.05

@export var jump_impulse: float = 13.0
@export var is_local: bool = true
@export var smooth_movement: bool = false
@export var dampening: float = 0.01
@export var max_speed_walk: float = 5.0
@export var max_speed_dash: float = 10.0
@export var max_speed: float = 5.0

var player_name: String = "Player"
var _original_name: String = ""  # Stored when mounting to restore later
var current_room: String = "Lobby"
var in_hall: bool = false
var _enabled: bool = false
var _invert_y: bool = false
var _mouse_sensitivity_factor: float = 1.0
var _camera_v: Vector2 = Vector2.ZERO

var _joy_right_x: int = JOY_AXIS_RIGHT_X
var _joy_right_y: int = JOY_AXIS_RIGHT_Y

# Network interpolation for remote players
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation_y: float = 0.0
var _target_pivot_rot_x: float = 0.0
var _target_pivot_pos_y: float = 1.35
var _has_network_target: bool = false

# Subsystems
var _crouch_system: PlayerCrouchSystem = null
var _mount_system: PlayerMountSystem = null
var _skin_system: PlayerSkinSystem = null
var _painting_system: PlayerPaintingSystem = null

@onready var camera: Camera3D = $Pivot/Camera3D
@onready var _pivot: Node3D = $Pivot
@onready var _footstep_player: Node = $FootstepPlayer
@onready var _raycast: RayCast3D = $Pivot/Camera3D/RayCast3D
@onready var _multiplayer_sync: MultiplayerSynchronizer = get_node_or_null("MultiplayerSynchronizer")
@onready var _name_label: Label3D = get_node_or_null("NameLabel")
@onready var _body_mesh: MeshInstance3D = get_node_or_null("BodyMesh")
@onready var _head_mesh: MeshInstance3D = get_node_or_null("Pivot/HeadMesh")

var _owned_body_material: Material = null
var _owned_head_material: Material = null


func _ready() -> void:
	SettingsEvents.set_invert_y.connect(_set_invert_y)
	SettingsEvents.set_mouse_sensitivity.connect(_set_mouse_sensitivity)
	SettingsEvents.set_joypad_deadzone.connect(_set_joy_deadzone)

	if _body_mesh:
		_body_mesh_base_y = _body_mesh.position.y

	# Initialize subsystems
	_crouch_system = PlayerCrouchSystem.new()
	_crouch_system.init(self)
	add_child(_crouch_system)

	_mount_system = PlayerMountSystem.new()
	_mount_system.init(self, _crouch_system)
	_mount_system.mount_requested.connect(_on_mount_requested)
	_mount_system.dismount_requested.connect(_on_dismount_requested)
	add_child(_mount_system)

	_skin_system = PlayerSkinSystem.new()
	_skin_system.init(self)
	add_child(_skin_system)

	_painting_system = PlayerPaintingSystem.new()
	_painting_system.init(self)
	_painting_system.steal_requested.connect(_on_steal_requested)
	_painting_system.place_requested.connect(_on_place_requested)
	_painting_system.eat_requested.connect(_on_eat_requested)
	_painting_system.eat_anim_started.connect(_on_eat_anim_started)
	_painting_system.eat_anim_cancelled.connect(_on_eat_anim_cancelled)
	add_child(_painting_system)


# =============================================================================
# PUBLIC API - Facade methods that delegate to subsystems
# =============================================================================

# Mounting API (delegates to PlayerMountSystem)
var mounted_on: Node:
	get: return _mount_system.mounted_on if _mount_system else null
var mounted_by: Node:
	get: return _mount_system.mounted_by if _mount_system else null
var _is_mounted: bool:
	get: return _mount_system.is_mounted() if _mount_system else false
var _has_rider: bool:
	get: return _mount_system.has_rider() if _mount_system else false
var mount_peer_id: int:
	get: return _mount_system.mount_peer_id if _mount_system else -1

# Skin API (delegates to PlayerSkinSystem)
var skin_url: String:
	get: return _skin_system.get_skin_url() if _skin_system else ""

# Painting API (delegates to PlayerPaintingSystem)
var is_carrying_painting: bool:
	get: return _painting_system.is_carrying() if _painting_system else false

# Crouch API (delegates to PlayerCrouchSystem)
var starting_height: float:
	get: return _crouch_system.get_starting_height() if _crouch_system else 1.35
var crouching_height: float:
	get: return _crouch_system.get_crouching_height() if _crouch_system else 0.45


func pause() -> void:
	_enabled = false


func start() -> void:
	_enabled = true


func _set_invert_y(enabled: bool) -> void:
	_invert_y = enabled


func _set_mouse_sensitivity(factor: float) -> void:
	_mouse_sensitivity_factor = factor


func _set_joy_deadzone(value: float) -> void:
	_joy_deadzone = value


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or not is_local:
		return

	# Mount/dismount/steal/place handling (E key)
	if event.is_action_pressed("mount") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if _painting_system and _painting_system.is_carrying():
			_painting_system.try_place_painting()
		elif _mount_system.is_mounted():
			request_dismount()
		elif _painting_system and _painting_system.try_steal_target():
			pass  # Steal initiated
		else:
			_mount_system.try_mount_target()

	# Interact handling (equip skin, etc.) — skip if carrying a painting (right-click is eat)
	if event.is_action_pressed("interact") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if _painting_system and _painting_system.is_carrying():
			pass  # Eat is handled in _process via process_eat()
		else:
			var collider: Node = _raycast.get_collider()
			if collider:
				if collider.has_method("interact"):
					collider.interact()
				elif collider.get_parent() and collider.get_parent().has_method("interact"):
					collider.get_parent().interact()

	var is_mouse: bool = event is InputEventMouseMotion
	if is_mouse and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var delta_x: float = -event.relative.x * _mouse_sensitivity * _mouse_sensitivity_factor
		var delta_y: float = -event.relative.y * _mouse_sensitivity * _mouse_sensitivity_factor * (-1 if _invert_y else 1)

		if not smooth_movement:
			rotate_y(delta_x)
			_pivot.rotate_x(delta_y)
			_pivot.rotation.x = clamp(_pivot.rotation.x, -1.2, 1.2)
		else:
			_camera_v += Vector2(
				clamp(delta_y, -dampening, dampening),
				clamp(delta_x, -dampening, dampening)
			)


func _physics_process(delta: float) -> void:
	# If mounted, let mount system handle position
	if _mount_system and _mount_system.is_mounted():
		_mount_system.process_mount(delta)
		return

	# Interpolate remote player positions
	if not is_local and _has_network_target:
		var horizontal_dist: float = Vector2(global_position.x - _target_position.x, global_position.z - _target_position.z).length()
		global_position = global_position.lerp(_target_position, INTERPOLATION_SPEED * delta)
		rotation.y = lerp_angle(rotation.y, _target_rotation_y, INTERPOLATION_SPEED * delta)
		_pivot.rotation.x = lerp_angle(_pivot.rotation.x, _target_pivot_rot_x, INTERPOLATION_SPEED * delta)
		_pivot.position.y = lerp(_pivot.position.y, _target_pivot_pos_y, INTERPOLATION_SPEED * delta)
		_crouch_system.update_crouch_body()
		# Apply body bob based on interpolation movement
		if _body_mesh:
			if horizontal_dist > 0.01:
				_bob_time += delta * BOB_FREQUENCY
				var bob_offset: float = sin(_bob_time) * BOB_AMPLITUDE
				_body_mesh.position.y = _body_mesh_base_y + bob_offset
			else:
				_bob_time = 0.0
				_body_mesh.position.y = _body_mesh_base_y

	if not _enabled or not is_local:
		return

	velocity.y += _gravity * delta

	var fully_standing: bool = _crouch_system.is_fully_standing()

	if fully_standing and Input.is_action_pressed("dash"):
		max_speed = max_speed_dash
	else:
		max_speed = max_speed_walk

	var speed: float = max_speed if fully_standing else _crouch_move_speed
	var input: Vector2 = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	var desired_velocity: Vector3 = transform.basis * Vector3(input.x, 0, input.y) * speed

	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	set_up_direction(Vector3.UP)
	set_floor_stop_on_slope_enabled(true)
	move_and_slide()

	var delta_vec: Vector2 = Vector2(-Input.get_joy_axis(0, _joy_right_x), -Input.get_joy_axis(0, _joy_right_y))
	if delta_vec.length() > _joy_deadzone:
		rotate_y(delta_vec.x * _joy_sensitivity)
		_pivot.rotate_x(delta_vec.y * _joy_sensitivity)
		_pivot.rotation.x = clamp(_pivot.rotation.x, -1.2, 1.2)

	if smooth_movement:
		rotate_y(_camera_v.y)
		_pivot.rotate_x(_camera_v.x)
		_pivot.rotation.x = clamp(_pivot.rotation.x, -1.2, 1.2)
		_camera_v *= 0.95

	_footstep_player.set_on_floor(is_on_floor())

	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = jump_impulse

	# Apply body bob when moving
	_update_body_bob(delta)

	# Process crouch input
	_crouch_system.process_crouch(delta)

	# Process painting eat
	if _painting_system:
		_painting_system.process_eat(delta)

	if Input.is_action_just_pressed("reset_skin"):
		MultiplayerEvents.emit_skin_reset()


# =============================================================================
# MOUNT SYSTEM DELEGATION
# =============================================================================

func _on_mount_requested(target: Node) -> void:
	request_mount(target)


func _on_dismount_requested() -> void:
	request_dismount()


func request_mount(target: Node) -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("_request_mount"):
		main_node._request_mount(target)


func request_dismount() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("_request_dismount"):
		main_node._request_dismount()


func execute_mount(target: Node, target_peer_id: int = -1) -> void:
	_mount_system.execute_mount(target, target_peer_id)
	# Note: Don't set _enabled = false here - camera control should remain active while mounted
	# Movement is already disabled by _physics_process returning early when mounted
	# Update rider's name to show "hat" format
	_original_name = player_name
	if _name_label and "player_name" in target:
		_name_label.text = target.player_name + " wearing\n" + player_name + " as a hat"


func execute_dismount() -> void:
	_mount_system.execute_dismount()
	if is_local:
		_enabled = true
	# Restore rider's original name
	if _original_name != "" and _name_label:
		_name_label.text = _original_name
		_original_name = ""


func _accept_rider(rider: Node) -> void:
	_mount_system.accept_rider(rider)
	# Hide mount's name when ridden
	if _name_label:
		_name_label.visible = false


func _remove_rider(rider: Node) -> void:
	_mount_system.remove_rider(rider)
	# Restore mount's name visibility when rider leaves
	if _name_label:
		_name_label.visible = true


func apply_network_mount_state(is_mounted_state: bool, peer_id: int, mount_node: Node) -> void:
	# Track previous mount before updating state
	var previous_mount: Node = _mount_system.mounted_on if _mount_system else null

	_mount_system.apply_network_mount_state(is_mounted_state, peer_id, mount_node)

	# Handle name changes for network-synced mount state
	if is_mounted_state and is_instance_valid(mount_node):
		if _original_name == "":  # Only save if not already mounted
			_original_name = player_name
		if _name_label and "player_name" in mount_node:
			_name_label.text = mount_node.player_name + " wearing\n" + player_name + " as a hat"
		# Set mount's rider state so visibility checks work correctly
		if "_mount_system" in mount_node and mount_node._mount_system:
			mount_node._mount_system._has_rider = true
			mount_node._mount_system.mounted_by = self
		# Hide mount's name when ridden
		if "_name_label" in mount_node and mount_node._name_label:
			mount_node._name_label.visible = false
	elif not is_mounted_state:
		# Restore rider's name
		if _original_name != "" and _name_label:
			_name_label.text = _original_name
			_original_name = ""
		# Clear previous mount's rider state
		if is_instance_valid(previous_mount) and "_mount_system" in previous_mount and previous_mount._mount_system:
			previous_mount._mount_system._has_rider = false
			previous_mount._mount_system.mounted_by = null
		# Restore previous mount's name visibility
		if is_instance_valid(previous_mount) and "_name_label" in previous_mount and previous_mount._name_label:
			previous_mount._name_label.visible = true


# =============================================================================
# SKIN SYSTEM DELEGATION
# =============================================================================

func set_player_skin(url: String, texture: ImageTexture = null) -> void:
	_skin_system.set_player_skin(url, texture)


func clear_player_skin() -> void:
	_skin_system.clear_player_skin()


# =============================================================================
# NETWORK AND DISPLAY
# =============================================================================

func set_player_authority(peer_id: int) -> void:
	if _multiplayer_sync:
		_multiplayer_sync.set_multiplayer_authority(peer_id)
	is_local = (peer_id == multiplayer.get_unique_id())
	if is_local and camera:
		camera.make_current()


func set_player_name(new_name: String) -> void:
	player_name = new_name
	if _name_label:
		_name_label.text = new_name


func set_body_visible(is_visible: bool) -> void:
	if _body_mesh:
		_body_mesh.visible = is_visible
	if _head_mesh:
		_head_mesh.visible = is_visible
	if _name_label:
		# Keep nameplate hidden if being ridden by another player
		if is_visible and _has_rider:
			_name_label.visible = false
		else:
			_name_label.visible = is_visible


func get_owned_body_material() -> Material:
	if not _owned_body_material and _body_mesh and _body_mesh.mesh and _body_mesh.mesh.get_surface_count() > 0:
		var material: Material = _body_mesh.get_surface_override_material(0)
		if material:
			_owned_body_material = material.duplicate()
			_body_mesh.set_surface_override_material(0, _owned_body_material)
	return _owned_body_material


func get_owned_head_material() -> Material:
	if not _owned_head_material and _head_mesh and _head_mesh.mesh and _head_mesh.mesh.get_surface_count() > 0:
		var material: Material = _head_mesh.get_surface_override_material(0)
		if material:
			_owned_head_material = material.duplicate()
			_head_mesh.set_surface_override_material(0, _owned_head_material)
	return _owned_head_material


func set_player_color(color: Color) -> void:
	var body_mat: Material = get_owned_body_material()
	if body_mat:
		if body_mat is ShaderMaterial:
			body_mat.set_shader_parameter("fallback_color", color)
		elif body_mat is StandardMaterial3D:
			body_mat.albedo_color = color
	var head_mat: Material = get_owned_head_material()
	if head_mat and head_mat is StandardMaterial3D:
		head_mat.albedo_color = color.lightened(0.15)


func apply_network_position(pos: Vector3, rot_y: float, pivot_rot_x: float, pivot_pos_y: float = 1.35) -> void:
	var should_snap: bool = false

	if not _has_network_target:
		should_snap = true
	else:
		# Detect teleport (large position change) and snap instead of interpolate
		var delta_distance: float = global_position.distance_to(pos)
		if delta_distance > TELEPORT_SNAP_THRESHOLD:
			should_snap = true

	if should_snap:
		global_position = pos
		_pivot.position.y = pivot_pos_y

	_has_network_target = true
	_target_position = pos
	_target_rotation_y = rot_y
	_target_pivot_rot_x = pivot_rot_x
	_target_pivot_pos_y = pivot_pos_y


# =============================================================================
# BODY BOB
# =============================================================================

func _update_body_bob(delta: float) -> void:
	if not _body_mesh:
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.5 and is_on_floor():
		_bob_time += delta * BOB_FREQUENCY
		var bob_offset: float = sin(_bob_time) * BOB_AMPLITUDE
		_body_mesh.position.y = _body_mesh_base_y + bob_offset
	else:
		_bob_time = 0.0
		_body_mesh.position.y = _body_mesh_base_y


# =============================================================================
# CROUCH SYSTEM DELEGATION
# =============================================================================

func _get_crouch_factor() -> float:
	return _crouch_system.get_crouch_factor() if _crouch_system else 0.0


func _update_crouch_body() -> void:
	if _crouch_system:
		_crouch_system.update_crouch_body()


# =============================================================================
# PAINTING SYSTEM DELEGATION
# =============================================================================

func _on_steal_requested(exhibit_title: String, image_title: String, image_url: String, image_size: Vector2) -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("_request_steal_painting"):
		main_node._request_steal_painting(exhibit_title, image_title, image_url, image_size)


func _on_place_requested(exhibit_title: String, image_title: String, image_url: String, wall_position: Vector3, wall_normal: Vector3, image_size: Vector2) -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("_request_place_painting"):
		main_node._request_place_painting(exhibit_title, image_title, image_url, wall_position, wall_normal, image_size)


func _on_eat_requested(exhibit_title: String, image_title: String) -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("_request_eat_painting"):
		main_node._request_eat_painting(exhibit_title, image_title)


func _on_eat_anim_started() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("_broadcast_eat_anim_start"):
		main_node._broadcast_eat_anim_start()


func _on_eat_anim_cancelled() -> void:
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("_broadcast_eat_anim_cancel"):
		main_node._broadcast_eat_anim_cancel()


func execute_steal_painting(texture: Texture2D, url: String, title: String, exhibit_title: String, size: Vector2) -> void:
	if _painting_system:
		_painting_system.execute_steal(texture, url, title, exhibit_title, size)


func execute_drop_painting() -> void:
	if _painting_system:
		_painting_system.execute_drop()
