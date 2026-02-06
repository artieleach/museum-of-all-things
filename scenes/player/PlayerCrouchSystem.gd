extends Node
class_name PlayerCrouchSystem
## Handles player crouching: input processing, collision shape scaling, and uncrouch detection.

const CROUCH_HEIGHT_RATIO: float = 0.4  # Crouched height is 40% of standing height

var _player: CharacterBody3D = null
var _starting_height: float = 1.35
var _crouching_height: float = 0.65
var _crouch_time: float = 0.3
var _crouch_speed: float = 0.0

# Cached node references
var _pivot: Node3D = null
var _body_collision: CollisionShape3D = null
var _body_mesh: Node3D = null
var _name_label: Node3D = null

# Stored starting values for body scaling
var _body_collision_start_y: float = 0.0
var _body_collision_start_height: float = 0.0
var _body_mesh_start_y: float = 0.0
var _body_mesh_start_scale: float = 1.0
var _name_label_start_y: float = 2.0


func init(player: CharacterBody3D) -> void:
	_player = player

	if _player.has_node("Pivot"):
		_pivot = _player.get_node("Pivot")
		_starting_height = _pivot.position.y
		_crouching_height = _starting_height / 3
		_crouch_speed = (_starting_height - _crouching_height) / _crouch_time

	# Store starting values for crouch body scaling
	if _player.has_node("CollisionShape2"):
		_body_collision = _player.get_node("CollisionShape2")
		_body_collision_start_y = _body_collision.position.y
		var shape: Shape3D = _body_collision.shape
		if shape is CapsuleShape3D:
			_body_collision_start_height = shape.height
	if _player.has_node("BodyMesh"):
		_body_mesh = _player.get_node("BodyMesh")
		_body_mesh_start_y = _body_mesh.position.y
		_body_mesh_start_scale = _body_mesh.scale.y
	if _player.has_node("NameLabel"):
		_name_label = _player.get_node("NameLabel")
		_name_label_start_y = _name_label.position.y


func get_starting_height() -> float:
	return _starting_height


func get_crouching_height() -> float:
	return _crouching_height


func get_crouch_speed() -> float:
	return _crouch_speed


func is_fully_crouched() -> bool:
	if not _pivot:
		return false
	return _pivot.position.y <= _crouching_height


func is_fully_standing() -> bool:
	if not _pivot:
		return true
	return _pivot.position.y >= _starting_height


func process_crouch(delta: float) -> void:
	if not _pivot:
		return

	var fully_crouched: bool = is_fully_crouched()
	var fully_standing: bool = is_fully_standing()

	if Input.is_action_pressed("crouch") and not fully_crouched:
		_pivot.global_translate(Vector3(0, -_crouch_speed * delta, 0))
	elif not Input.is_action_pressed("crouch") and not fully_standing:
		_pivot.global_translate(Vector3(0, _crouch_speed * delta, 0))

	update_crouch_body()


func get_crouch_factor() -> float:
	if not _pivot:
		return 0.0
	var current_height: float = _pivot.position.y
	var factor: float = 1.0 - (current_height - _crouching_height) / (_starting_height - _crouching_height)
	return clampf(factor, 0.0, 1.0)


func update_crouch_body() -> void:
	var crouch_factor: float = get_crouch_factor()

	# Scale factor for crouched state
	var height_scale: float = 1.0 - (crouch_factor * (1.0 - CROUCH_HEIGHT_RATIO))

	# Update body collision shape
	if _body_collision:
		var shape: Shape3D = _body_collision.shape
		if shape is CapsuleShape3D:
			shape.height = _body_collision_start_height * height_scale
		# Adjust position to keep feet on ground
		_body_collision.position.y = _body_collision_start_y * height_scale

	# Update body mesh
	if _body_mesh:
		_body_mesh.scale.y = _body_mesh_start_scale * height_scale
		_body_mesh.position.y = _body_mesh_start_y * height_scale

	# Update name label position
	if _name_label:
		var standing_label_y: float = _name_label_start_y
		var crouched_label_y: float = _name_label_start_y * CROUCH_HEIGHT_RATIO
		_name_label.position.y = lerpf(standing_label_y, crouched_label_y, crouch_factor)


func force_crouched_position() -> void:
	if _pivot:
		_pivot.position.y = _crouching_height
		update_crouch_body()
