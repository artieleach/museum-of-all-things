class_name NPCManager
extends Node
## Spawns and manages NPCs within an exhibit.

const NPC_SCENE: PackedScene = preload("res://scenes/npc/NPC.tscn")
const DEFAULT_COUNT: int = 12
const WALL_MARGIN: float = 1.5

var _exhibit: Node3D = null
var _npcs: Array[ExhibitNPC] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Predefined NPC colors for variety
const NPC_COLORS: Array[Color] = [
	Color(0.8, 0.3, 0.3),  # Red
	Color(0.3, 0.8, 0.3),  # Green
	Color(0.3, 0.3, 0.8),  # Blue
	Color(0.8, 0.8, 0.3),  # Yellow
	Color(0.8, 0.3, 0.8),  # Magenta
	Color(0.3, 0.8, 0.8),  # Cyan
	Color(0.8, 0.5, 0.2),  # Orange
	Color(0.5, 0.3, 0.7),  # Purple
]


func init(exhibit: Node3D, count: int = DEFAULT_COUNT) -> void:
	_exhibit = exhibit
	_rng.seed = hash(exhibit.title) if "title" in exhibit else randi()
	_spawn_npcs(count)


func _spawn_npcs(count: int) -> void:
	var spawn_data: Array = _get_spawn_positions()
	if spawn_data.is_empty():
		return

	for i in range(count):
		var data: Dictionary = spawn_data[i % spawn_data.size()]
		var npc: ExhibitNPC = NPC_SCENE.instantiate()

		# Create unique material instance for this NPC
		var mesh: MeshInstance3D = npc.get_node("BodyMesh")
		if mesh and mesh.get_surface_override_material(0):
			var mat: Material = mesh.get_surface_override_material(0).duplicate()
			mesh.material_override = mat
			var color: Color = NPC_COLORS[_rng.randi() % NPC_COLORS.size()]
			npc.set_npc_color(color)

		_exhibit.add_child(npc)
		# Generate fresh random position for each NPC instead of using pre-computed pos
		var spawn_pos: Vector3 = _get_random_pos_in_bounds(data.bounds)
		spawn_pos.y = data.bounds[0].y + 0.1
		npc.init(spawn_pos, data.bounds)
		_npcs.append(npc)


func _get_random_pos_in_bounds(bounds: Array) -> Vector3:
	## Generate a random position within bounds, respecting wall margin.
	var min_b: Vector3 = bounds[0]
	var max_b: Vector3 = bounds[1]
	var min_x: float = min_b.x + WALL_MARGIN
	var max_x: float = max_b.x - WALL_MARGIN
	var min_z: float = min_b.z + WALL_MARGIN
	var max_z: float = max_b.z - WALL_MARGIN
	# Handle small rooms where margin exceeds room size
	if min_x >= max_x:
		min_x = (min_b.x + max_b.x) / 2.0
		max_x = min_x
	if min_z >= max_z:
		min_z = (min_b.z + max_b.z) / 2.0
		max_z = min_z
	return Vector3(
		_rng.randf_range(min_x, max_x),
		0.0,
		_rng.randf_range(min_z, max_z)
	)


func _get_spawn_positions() -> Array:
	## Get spawn positions and room bounds from exhibit rooms.
	var result: Array = []

	if not is_instance_valid(_exhibit):
		return result

	if _exhibit.has_method("get_rooms_for_npcs"):
		var rooms: Array = _exhibit.get_rooms_for_npcs()
		for room: Dictionary in rooms:
			var bounds: Array = room.bounds

			# Convert grid coords to world coords
			var world_bounds: Array = [
				GridUtils.grid_to_world(bounds[0]),
				GridUtils.grid_to_world(bounds[1])
			]

			# Generate random spawn position within room bounds
			var spawn_pos: Vector3 = _get_random_pos_in_bounds(world_bounds)
			spawn_pos.y = world_bounds[0].y + 0.1  # Use floor Y from bounds

			result.append({
				"pos": spawn_pos,
				"bounds": world_bounds
			})

	return result
