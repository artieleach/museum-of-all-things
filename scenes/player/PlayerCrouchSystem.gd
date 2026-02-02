extends Node
class_name PlayerCrouchSystem
## Handles player crouching: input processing, collision shape scaling, and uncrouch detection.

const STANDING_BODY_HEIGHT: float = 1.7
const CROUCHING_BODY_HEIGHT: float = 0.68  # 40% of standing height

var _player: CharacterBody3D = null
var _starting_height: float = 1.35
var _crouching_height: float = 0.45
var _crouch_time: float = 0.4
var _crouch_speed: float = 0.0

# Stored starting values for body scaling
var _body_collision_start_y: float = 0.0
var _body_collision_start_height: float = 0.0
var _body_mesh_start_y: float = 0.0
var _body_mesh_start_scale: float = 1.0
var _name_label_start_y: float = 2.0


func init(player: CharacterBody3D) -> void:
	_player = player

	if _player.has_node("Pivot"):
		_starting_height = _player.get_node("Pivot").position.y
		_crouching_height = _starting_height / 3
		_crouch_speed = (_starting_height - _crouching_height) / _crouch_time

	# Store starting values for crouch body scaling
	if _player.has_node("CollisionShape2"):
		_body_collision_start_y = _player.get_node("CollisionShape2").position.y
		var shape: Shape3D = _player.get_node("CollisionShape2").shape
		if shape is CapsuleShape3D:
			_body_collision_start_height = shape.height
	if _player.has_node("BodyMesh"):
		_body_mesh_start_y = _player.get_node("BodyMesh").position.y
		_body_mesh_start_scale = _player.get_node("BodyMesh").scale.y
	if _player.has_node("NameLabel"):
		_name_label_start_y = _player.get_node("NameLabel").position.y


func get_starting_height() -> float:
	return _starting_height


func get_crouching_height() -> float:
	return _crouching_height


func get_crouch_speed() -> float:
	return _crouch_speed


func is_fully_crouched() -> bool:
	if not _player or not _player.has_node("Pivot"):
		return false
	return _player.get_node("Pivot").position.y <= _crouching_height


func is_fully_standing() -> bool:
	if not _player or not _player.has_node("Pivot"):
		return true
	return _player.get_node("Pivot").position.y >= _starting_height


func process_crouch(delta: float) -> void:
	if not _player or not _player.has_node("Pivot"):
		return

	var pivot: Node3D = _player.get_node("Pivot")
	var fully_crouched: bool = is_fully_crouched()
	var fully_standing: bool = is_fully_standing()

	if Input.is_action_pressed("crouch") and not fully_crouched:
		pivot.global_translate(Vector3(0, -_crouch_speed * delta, 0))
	elif not Input.is_action_pressed("crouch") and not fully_standing:
		if can_uncrouch():
			pivot.global_translate(Vector3(0, _crouch_speed * delta, 0))

	update_crouch_body()


func can_uncrouch() -> bool:
	if not _player or not _player.has_node("CeilingRayCast"):
		return true

	var ceiling_ray: RayCast3D = _player.get_node("CeilingRayCast")

	var current_height: float = lerpf(STANDING_BODY_HEIGHT, CROUCHING_BODY_HEIGHT, get_crouch_factor())
	var target_height: float = STANDING_BODY_HEIGHT

	var clearance_needed: float = target_height - current_height + 0.1
	if clearance_needed <= 0:
		return true

	ceiling_ray.target_position = Vector3(0, current_height + clearance_needed, 0)
	ceiling_ray.force_raycast_update()

	return not ceiling_ray.is_colliding()


func get_crouch_factor() -> float:
	if not _player or not _player.has_node("Pivot"):
		return 0.0
	var current_height: float = _player.get_node("Pivot").position.y
	var factor: float = 1.0 - (current_height - _crouching_height) / (_starting_height - _crouching_height)
	return clampf(factor, 0.0, 1.0)


func update_crouch_body() -> void:
	var crouch_factor: float = get_crouch_factor()

	# Scale factor for crouched state (crouch reduces height to 40%)
	var height_scale: float = 1.0 - (crouch_factor * 0.6)

	# Update body collision shape
	if _player.has_node("CollisionShape2"):
		var collision: CollisionShape3D = _player.get_node("CollisionShape2")
		var shape: Shape3D = collision.shape
		if shape is CapsuleShape3D:
			shape.height = _body_collision_start_height * height_scale
		# Adjust position to keep feet on ground
		collision.position.y = _body_collision_start_y * height_scale

	# Update body mesh
	if _player.has_node("BodyMesh"):
		_player.get_node("BodyMesh").scale.y = _body_mesh_start_scale * height_scale
		_player.get_node("BodyMesh").position.y = _body_mesh_start_y * height_scale

	# Update name label position
	if _player.has_node("NameLabel"):
		var standing_label_y: float = _name_label_start_y
		var crouched_label_y: float = _name_label_start_y * 0.4
		_player.get_node("NameLabel").position.y = lerpf(standing_label_y, crouched_label_y, crouch_factor)


func force_crouched_position() -> void:
	if _player and _player.has_node("Pivot"):
		_player.get_node("Pivot").position.y = _crouching_height
		update_crouch_body()
