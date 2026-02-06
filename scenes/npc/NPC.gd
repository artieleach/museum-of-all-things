class_name ExhibitNPC
extends CharacterBody3D
## NPC that wanders randomly within exhibit room bounds.

const WALK_SPEED: float = 1.5
const PAUSE_MIN: float = 2.0
const PAUSE_MAX: float = 6.0
const DESTINATION_THRESHOLD: float = 0.5
const GRAVITY: float = 20.0
const BOB_FREQUENCY: float = 10.0
const BOB_AMPLITUDE: float = 0.04

enum State { WALKING, PAUSED }

var _state: State = State.PAUSED
var _destination: Vector3
var _room_bounds: Array  # [Vector3 min, Vector3 max] in world coords
var _pause_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bob_time: float = 0.0
var _body_mesh_base_y: float = 0.85
var _head_mesh_base_y: float = 1.55

@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _head_mesh: MeshInstance3D = $HeadMesh
@onready var _obstacle_ray: RayCast3D = $ObstacleRay


func _ready() -> void:
	_rng.randomize()
	_start_pause()


func init(spawn_pos: Vector3, room_bounds: Array) -> void:
	position = spawn_pos
	_room_bounds = room_bounds
	_destination = spawn_pos


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	match _state:
		State.PAUSED:
			_pause_timer -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			_bob_time = 0.0
			_body_mesh.position.y = _body_mesh_base_y
			if _head_mesh:
				_head_mesh.position.y = _head_mesh_base_y
			if _pause_timer <= 0.0:
				_pick_new_destination()
				_state = State.WALKING

		State.WALKING:
			var to_dest: Vector3 = _destination - global_position
			to_dest.y = 0.0
			var dist: float = to_dest.length()

			if dist < DESTINATION_THRESHOLD:
				_start_pause()
			elif _obstacle_ray.is_colliding():
				_start_pause()
			else:
				var direction: Vector3 = to_dest.normalized()
				velocity.x = direction.x * WALK_SPEED
				velocity.z = direction.z * WALK_SPEED

				# Face movement direction
				if direction.length_squared() > 0.01:
					_obstacle_ray.target_position = direction * 1.0

				# Apply body bob while walking
				_bob_time += delta * BOB_FREQUENCY
				var bob_offset: float = sin(_bob_time) * BOB_AMPLITUDE
				_body_mesh.position.y = _body_mesh_base_y + bob_offset
				if _head_mesh:
					_head_mesh.position.y = _head_mesh_base_y + bob_offset

	move_and_slide()


func _pick_new_destination() -> void:
	if _room_bounds.size() < 2:
		_start_pause()
		return

	var min_bounds: Vector3 = _room_bounds[0]
	var max_bounds: Vector3 = _room_bounds[1]

	# Add margin to keep NPC away from walls
	var margin: float = 1.0
	var min_x: float = min_bounds.x + margin
	var max_x: float = max_bounds.x - margin
	var min_z: float = min_bounds.z + margin
	var max_z: float = max_bounds.z - margin

	# Ensure valid range
	if min_x >= max_x:
		min_x = min_bounds.x
		max_x = max_bounds.x
	if min_z >= max_z:
		min_z = min_bounds.z
		max_z = max_bounds.z

	_destination = Vector3(
		_rng.randf_range(min_x, max_x),
		global_position.y,
		_rng.randf_range(min_z, max_z)
	)


func _start_pause() -> void:
	_state = State.PAUSED
	_pause_timer = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)
	velocity.x = 0.0
	velocity.z = 0.0


func set_npc_color(color: Color) -> void:
	if _body_mesh and _body_mesh.material_override:
		_body_mesh.material_override.set_shader_parameter("fallback_color", color)
	if _head_mesh and _head_mesh.mesh and _head_mesh.mesh.get_surface_count() > 0:
		var head_material: Material = _head_mesh.get_surface_override_material(0)
		if head_material and head_material is StandardMaterial3D:
			var new_head_material: StandardMaterial3D = head_material.duplicate() as StandardMaterial3D
			new_head_material.albedo_color = color.lightened(0.15)
			_head_mesh.set_surface_override_material(0, new_head_material)
