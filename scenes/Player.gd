extends CharacterBody3D

var gravity = -30
var crouch_move_speed = 4
var mouse_sensitivity = 0.002
var joy_sensitivity = 0.025
var joy_deadzone = 0.05
@export var jump_impulse = 13

var starting_height
var crouching_height
var crouch_time = 0.4
var crouch_speed
var _enabled = false

# Crouch body scaling
var _body_collision_start_y: float
var _body_collision_start_height: float
var _body_mesh_start_y: float
var _body_mesh_start_scale: float
var _name_label_start_y: float

@export var is_local: bool = true
var player_name: String = "Player"
var skin_url: String = ""
var _skin_texture: ImageTexture = null

# Network interpolation for remote players
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation_y: float = 0.0
var _target_pivot_rot_x: float = 0.0
var _target_pivot_pos_y: float = 1.35
var _has_network_target: bool = false
const INTERPOLATION_SPEED: float = 15.0

# Mounting system
var mounted_on: Node = null      # Player we're riding
var mounted_by: Node = null      # Player riding us
var _is_mounted: bool = false
var _has_rider: bool = false
var mount_peer_id: int = -1
const MOUNT_HEIGHT_OFFSET: float = 1.7

var _joy_right_x = JOY_AXIS_RIGHT_X
var _joy_right_y = JOY_AXIS_RIGHT_Y

@onready var camera = get_node("Pivot/Camera3D")

@export var smooth_movement = false
@export var dampening = 0.01
@export var max_speed_walk = 5
@export var max_speed_dash = 10
@export var max_speed = max_speed_walk

var _invert_y = false
var _mouse_sensitivity_factor = 1.0

func _ready():
	GlobalMenuEvents.set_invert_y.connect(_set_invert_y)
	GlobalMenuEvents.set_mouse_sensitivity.connect(_set_mouse_sensitivity)
	GlobalMenuEvents.set_joypad_deadzone.connect(_set_joy_deadzone)

	starting_height = $Pivot.get_position().y
	crouching_height = starting_height / 3
	crouch_speed = (starting_height - crouching_height) / crouch_time

	# Store starting values for crouch body scaling
	if has_node("CollisionShape2"):
		_body_collision_start_y = $CollisionShape2.position.y
		var shape = $CollisionShape2.shape
		if shape is CapsuleShape3D:
			_body_collision_start_height = shape.height
	if has_node("BodyMesh"):
		_body_mesh_start_y = $BodyMesh.position.y
		_body_mesh_start_scale = $BodyMesh.scale.y
	if has_node("NameLabel"):
		_name_label_start_y = $NameLabel.position.y

func _set_invert_y(enabled):
	_invert_y = enabled

func _set_mouse_sensitivity(factor):
	_mouse_sensitivity_factor = factor

func _set_joy_deadzone(value):
	joy_deadzone = value

func pause():
	_enabled = false

func start():
	_enabled = true

func get_input_dir():
	var input_dir = Vector3()
	if Input.is_action_pressed("move_forward"):
		input_dir -= global_transform.basis.z
	if Input.is_action_pressed("move_back"):
		input_dir += global_transform.basis.z
	if Input.is_action_pressed("strafe_left"):
		input_dir -= global_transform.basis.x
	if Input.is_action_pressed("strafe_right"):
		input_dir += global_transform.basis.x
	return input_dir.normalized()

var camera_v = Vector2.ZERO
func _unhandled_input(event):
	if not _enabled or not is_local:
		return

	# Mount/dismount handling
	if event.is_action_pressed("mount") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if _is_mounted:
			request_dismount()
		else:
			_try_mount_target()

	var is_mouse = event is InputEventMouseMotion
	if is_mouse and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var delta_x = -event.relative.x * mouse_sensitivity * _mouse_sensitivity_factor
		var delta_y = -event.relative.y * mouse_sensitivity * _mouse_sensitivity_factor * (-1 if _invert_y else 1)

		if not smooth_movement:
			rotate_y(delta_x)
			$Pivot.rotate_x(delta_y)
			$Pivot.rotation.x = clamp($Pivot.rotation.x, -1.2, 1.2)
		else:
			camera_v += Vector2(
				clamp(delta_y, -dampening, dampening),
				clamp(delta_x, -dampening, dampening)
			)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# Interpolate remote player positions
	if not is_local and _has_network_target:
		global_position = global_position.lerp(_target_position, INTERPOLATION_SPEED * delta)
		rotation.y = lerp_angle(rotation.y, _target_rotation_y, INTERPOLATION_SPEED * delta)
		$Pivot.rotation.x = lerp_angle($Pivot.rotation.x, _target_pivot_rot_x, INTERPOLATION_SPEED * delta)
		$Pivot.position.y = lerp($Pivot.position.y, _target_pivot_pos_y, INTERPOLATION_SPEED * delta)
		_update_crouch_body()

	# If mounted, follow mount's position
	if _is_mounted and is_instance_valid(mounted_on):
		global_position = mounted_on.global_position + Vector3(0, MOUNT_HEIGHT_OFFSET, 0)
		return

	if not _enabled or not is_local:
		return

	velocity.y += gravity * delta

	var fully_crouched = $Pivot.get_position().y <= crouching_height
	var fully_standing = $Pivot.get_position().y >= starting_height

	if fully_standing and Input.is_action_pressed("dash"):
		max_speed = max_speed_dash
	else:
		max_speed = max_speed_walk

	var speed = max_speed if fully_standing else crouch_move_speed
	var input = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	var desired_velocity = transform.basis * Vector3(input.x, 0, input.y) * speed

	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	set_up_direction(Vector3.UP)
	set_floor_stop_on_slope_enabled(true)
	move_and_slide()

	#var delta_vec = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var delta_vec = Vector2(-Input.get_joy_axis(0, _joy_right_x), -Input.get_joy_axis(0, _joy_right_y))
	if delta_vec.length() > joy_deadzone:
		rotate_y(delta_vec.x * joy_sensitivity)
		$Pivot.rotate_x(delta_vec.y * joy_sensitivity)
		$Pivot.rotation.x = clamp($Pivot.rotation.x, -1.2, 1.2)

	if smooth_movement:
		rotate_y(camera_v.y)
		$Pivot.rotate_x(camera_v.x)
		$Pivot.rotation.x = clamp($Pivot.rotation.x, -1.2, 1.2)
		camera_v *= 0.95

	$FootstepPlayer.set_on_floor(is_on_floor())

	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = jump_impulse
		pass

	if Input.is_action_pressed("crouch") and not fully_crouched:
		$Pivot.global_translate(Vector3(0, -crouch_speed * delta, 0))
	elif not Input.is_action_pressed("crouch") and not fully_standing:
		$Pivot.global_translate(Vector3(0, crouch_speed * delta, 0))

	# Update body collision and visual based on crouch
	_update_crouch_body()

	if Input.is_action_pressed("interact"):
		var collider = $Pivot/Camera3D/RayCast3D.get_collider()
		if collider:
			# Check collider itself first, then parent (for ImageItem where we hit the StaticBody3D)
			if collider.has_method("interact"):
				collider.interact()
			elif collider.get_parent() and collider.get_parent().has_method("interact"):
				collider.get_parent().interact()
	
	if Input.is_action_just_pressed("reset_skin"):
		GlobalMenuEvents.emit_skin_reset()

func set_player_authority(peer_id: int) -> void:
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)
	is_local = (peer_id == multiplayer.get_unique_id())
	if is_local and has_node("Pivot/Camera3D"):
		$Pivot/Camera3D.make_current()

func set_player_name(new_name: String) -> void:
	player_name = new_name
	if has_node("NameLabel"):
		$NameLabel.text = new_name

func set_body_visible(visible: bool) -> void:
	if has_node("BodyMesh"):
		$BodyMesh.visible = visible
	if has_node("NameLabel"):
		$NameLabel.visible = visible

func set_player_color(color: Color) -> void:
	if has_node("BodyMesh"):
		var mesh_instance = $BodyMesh as MeshInstance3D
		var material = mesh_instance.get_surface_override_material(0)
		if material:
			# Create a unique copy to avoid sharing material across players
			if material is ShaderMaterial:
				var new_material = material.duplicate() as ShaderMaterial
				new_material.set_shader_parameter("fallback_color", color)
				mesh_instance.set_surface_override_material(0, new_material)
			elif material is StandardMaterial3D:
				var new_material = material.duplicate() as StandardMaterial3D
				new_material.albedo_color = color
				mesh_instance.set_surface_override_material(0, new_material)

func apply_network_position(pos: Vector3, rot_y: float, pivot_rot_x: float, pivot_pos_y: float = 1.35) -> void:
	# Set target for interpolation (first update snaps to position)
	if not _has_network_target:
		global_position = pos
		rotation.y = rot_y
		$Pivot.rotation.x = pivot_rot_x
		$Pivot.position.y = pivot_pos_y
		_has_network_target = true
	_target_position = pos
	_target_rotation_y = rot_y
	_target_pivot_rot_x = pivot_rot_x
	_target_pivot_pos_y = pivot_pos_y

func set_player_skin(url: String, texture: ImageTexture = null) -> void:
	skin_url = url
	if texture:
		_apply_skin_texture(texture)
	elif url != "":
		# Request texture via DataManager
		if not DataManager.loaded_image.is_connected(_on_skin_image_loaded):
			DataManager.loaded_image.connect(_on_skin_image_loaded)
		DataManager.request_image(url)

func _on_skin_image_loaded(url: String, texture: ImageTexture, _ctx) -> void:
	if url != skin_url:
		return
	DataManager.loaded_image.disconnect(_on_skin_image_loaded)
	_apply_skin_texture(texture)

func _apply_skin_texture(texture: ImageTexture) -> void:
	_skin_texture = texture
	if not has_node("BodyMesh"):
		return

	var mesh_instance = $BodyMesh as MeshInstance3D
	var material = mesh_instance.get_surface_override_material(0)
	if material and material is ShaderMaterial:
		var shader_mat = material.duplicate() as ShaderMaterial
		shader_mat.set_shader_parameter("texture_albedo", texture)
		shader_mat.set_shader_parameter("has_texture", true)
		mesh_instance.set_surface_override_material(0, shader_mat)

func clear_player_skin() -> void:
	skin_url = ""
	_skin_texture = null
	if not has_node("BodyMesh"):
		return

	var mesh_instance = $BodyMesh as MeshInstance3D
	var material = mesh_instance.get_surface_override_material(0)
	if material and material is ShaderMaterial:
		var shader_mat = material.duplicate() as ShaderMaterial
		shader_mat.set_shader_parameter("has_texture", false)
		mesh_instance.set_surface_override_material(0, shader_mat)

# Mounting system functions
func _try_mount_target() -> void:
	var raycast = $Pivot/Camera3D/RayCast3D
	if not raycast.is_colliding():
		return

	var collider = raycast.get_collider()
	if not collider:
		return

	# Check if we hit a player
	if collider.is_in_group("Player") and collider != self:
		request_mount(collider)

func request_mount(target: Node) -> void:
	# Get the Main node to send RPC
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("_request_mount"):
		main_node._request_mount(target)

func request_dismount() -> void:
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("_request_dismount"):
		main_node._request_dismount()

func execute_mount(target: Node, target_peer_id: int = -1) -> void:
	if not is_instance_valid(target):
		return
	if target._has_rider:
		return  # Target already has a rider

	mounted_on = target
	mount_peer_id = target_peer_id
	_is_mounted = true

	# Disable collision while mounted
	set_collision_layer_value(20, false)
	set_collision_mask_value(1, false)

	# Disable movement
	_enabled = false

	# Tell mount they have a rider
	target._accept_rider(self)

	if OS.is_debug_build():
		print("Player: Mounted on ", target.name)

func execute_dismount() -> void:
	if not _is_mounted or not is_instance_valid(mounted_on):
		_is_mounted = false
		mounted_on = null
		mount_peer_id = -1
		return

	# Get dismount position (offset to the side of mount)
	var dismount_pos = mounted_on.global_position + mounted_on.global_transform.basis.x * 1.0
	dismount_pos.y = mounted_on.global_position.y

	# Tell mount we're leaving
	mounted_on._remove_rider(self)

	# Re-enable collision
	set_collision_layer_value(20, true)
	set_collision_mask_value(1, true)

	# Move to dismount position
	global_position = dismount_pos

	# Re-enable movement for local player
	if is_local:
		_enabled = true

	_is_mounted = false
	mounted_on = null
	mount_peer_id = -1

	if OS.is_debug_build():
		print("Player: Dismounted")

func _accept_rider(rider: Node) -> void:
	mounted_by = rider
	_has_rider = true
	if OS.is_debug_build():
		print("Player: Accepted rider ", rider.name)

func _remove_rider(rider: Node) -> void:
	if mounted_by == rider:
		mounted_by = null
		_has_rider = false
		if OS.is_debug_build():
			print("Player: Removed rider ", rider.name)

func apply_network_mount_state(is_mounted: bool, peer_id: int, mount_node: Node) -> void:
	# Called for remote players to sync mount state
	_is_mounted = is_mounted
	mount_peer_id = peer_id
	mounted_on = mount_node

	if is_mounted and is_instance_valid(mount_node):
		set_collision_layer_value(20, false)
	else:
		set_collision_layer_value(20, true)
		mounted_on = null
		mount_peer_id = -1

func _update_crouch_body() -> void:
	# Calculate crouch factor (0 = standing, 1 = fully crouched)
	var current_height = $Pivot.position.y
	var crouch_factor = 1.0 - (current_height - crouching_height) / (starting_height - crouching_height)
	crouch_factor = clamp(crouch_factor, 0.0, 1.0)

	# Scale factor for crouched state (crouch reduces height to 1/3)
	var height_scale = 1.0 - (crouch_factor * 0.6)  # Crouched is 40% of standing height

	# Update body collision shape
	if has_node("CollisionShape2"):
		var collision = $CollisionShape2
		var shape = collision.shape
		if shape is CapsuleShape3D:
			shape.height = _body_collision_start_height * height_scale
		# Adjust position to keep feet on ground
		collision.position.y = _body_collision_start_y * height_scale

	# Update body mesh
	if has_node("BodyMesh"):
		$BodyMesh.scale.y = _body_mesh_start_scale * height_scale
		$BodyMesh.position.y = _body_mesh_start_y * height_scale

	# Update name label position
	if has_node("NameLabel"):
		var standing_label_y = _name_label_start_y
		var crouched_label_y = _name_label_start_y * 0.4  # Lower when crouched
		$NameLabel.position.y = lerp(standing_label_y, crouched_label_y, crouch_factor)
