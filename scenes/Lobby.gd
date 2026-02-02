extends Node3D
## Lobby area with procedurally placed hall exits.

# Use GridConstants for cell types
const FLOOR_WOOD: int = GridConstants.FLOOR_WOOD
const FLOOR_CARPET: int = GridConstants.FLOOR_CARPET
const FLOOR_MARBLE: int = GridConstants.FLOOR_MARBLE
const INTERNAL_HALL: int = GridConstants.INTERNAL_HALL
const DIRECTIONS: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
const FLOORS: Array[int] = GridConstants.FLOOR_TYPES

@onready var _hall_scene: PackedScene = preload("res://scenes/Hall.tscn")
@onready var _grid: GridMap = $GridMap
@onready var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var exits: Array[Hall] = []
var entry: Hall = null


func _ready() -> void:
	GridManager.update_from_gridmap(_grid)
	_rng.seed = hash("$Lobby")
	for cell_pos: Vector3i in _grid.get_used_cells():
		var c: Vector3 = Vector3(cell_pos)
		if _grid.get_cell_item(c) == INTERNAL_HALL:
			var hall_dir: Variant = _get_hall_dir(c)
			if not hall_dir:
				continue
			var hall_instance: Hall = _hall_scene.instantiate()
			add_child(hall_instance)
			hall_instance.init(_grid, "$Lobby", "$Lobby", c, hall_dir, [true, _rng.randi_range(-1, 1)])
			exits.append(hall_instance)


func _get_hall_dir(pos: Vector3) -> Variant:
	var p: Vector3 = pos - Vector3.UP
	var ori: int = _grid.get_cell_item_orientation(pos)
	var dirs: Array[Vector3] = []

	if ori == 0 or ori == 10:
		dirs = [Vector3.FORWARD, Vector3.BACK]
	elif ori == 16 or ori == 22:
		dirs = [Vector3.LEFT, Vector3.RIGHT]

	for dir: Vector3 in dirs:
		var cell: Vector3 = p + dir
		if FLOORS.has(_grid.get_cell_item(cell)):
			return -dir

	return null
