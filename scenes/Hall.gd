extends Node3D
class_name Hall
## A hallway connecting two exhibit areas with entry/exit doors.

signal on_player_toward_exit
signal on_player_toward_entry

# Use GridConstants for cell types
const WALL: int = GridConstants.WALL
const INTERNAL_HALL: int = GridConstants.INTERNAL_HALL
const INTERNAL_HALL_TURN: int = GridConstants.INTERNAL_HALL_TURN
const HALL_STAIRS_UP: int = GridConstants.HALL_STAIRS_UP
const HALL_STAIRS_DOWN: int = GridConstants.HALL_STAIRS_DOWN
const HALL_STAIRS_TURN: int = GridConstants.HALL_STAIRS_TURN

const UP: int = GridConstants.LEVEL_UP
const FLAT: int = GridConstants.LEVEL_FLAT
const DOWN: int = GridConstants.LEVEL_DOWN

@onready var _grid_wrapper: PackedScene = preload("res://scenes/util/GridWrapper.tscn")
@onready var loader: Area3D = $LoaderTrigger
@onready var entry_door: Node3D = $EntryDoor
@onready var exit_door: Node3D = $ExitDoor
@onready var _detector: Area3D = $HallDirectionDetector
@onready var from_sign: Node3D = $FromSign
@onready var to_sign: Node3D = $ToSign

var _grid: Node = null
var hall_type: Array = [true, FLAT]
var floor_type: int = 0
var player_direction: String = ""

var from_pos: Vector3 = Vector3.ZERO
var from_dir: Vector3 = Vector3.ZERO
var to_pos: Vector3 = Vector3.ZERO
var to_dir: Vector3 = Vector3.ZERO
var linked_hall: Hall = null

var player_in_hall: bool:
	get:
		return _detector.player != null
	set(_value):
		pass

var from_title: String:
	get:
		return from_sign.text
	set(v):
		from_sign.text = v

var to_title: String:
	get:
		return to_sign.text
	set(v):
		to_sign.text = v


static func valid_hall_types(grid: Node, hall_start: Vector3, hall_dir: Vector3) -> Array:
	var hall_corner: Vector3 = hall_start + hall_dir

	var hall_dir_right: Vector3 = hall_dir.rotated(Vector3.UP, 3 * PI / 2)
	var hall_exit_right: Vector3 = hall_corner + hall_dir_right
	var past_hall_exit_right: Vector3 = hall_corner + 2 * hall_dir_right

	var corner_empty_neighbors: Array = GridUtils.cell_neighbors(grid, hall_corner - Vector3.UP, -1)

	if (
		not GridUtils.safe_overwrite(grid, hall_corner) or
		corner_empty_neighbors.size() != 4
	):
		return []

	var valid_halls: Array = []

	if (
		not (
			grid.get_cell_item(past_hall_exit_right - Vector3.UP) != -1 and
			grid.get_cell_item(past_hall_exit_right) == -1
		) and
		not (
			grid.get_cell_item(past_hall_exit_right - Vector3.UP) == 1 and
			grid.get_cell_item(past_hall_exit_right) == 1
		) and
		GridUtils.safe_overwrite(grid, hall_exit_right)
	):
		valid_halls.append([true, FLAT])
		valid_halls.append([true, UP])
		valid_halls.append([true, DOWN])

	return valid_halls


func init(grid: Variant, p_from_title: String, p_to_title: String, hall_start: Vector3, hall_dir: Vector3, _hall_type: Array = [true, FLAT]) -> void:
	floor_type = ExhibitStyle.gen_floor(p_from_title)
	position = GridUtils.grid_to_world(hall_start)
	loader.monitoring = true

	if grid is GridMap:
		_grid = _grid_wrapper.instantiate()
		_grid.init(grid)
		add_child(_grid)
	else:
		_grid = grid

	hall_type = _hall_type
	_create_curve_hall(hall_start, hall_dir, hall_type[0], hall_type[1])

	from_dir = hall_dir
	from_pos = hall_start

	from_sign.position = GridUtils.grid_to_world(to_pos + to_dir * 0.65) - position
	from_sign.position += to_dir.rotated(Vector3.UP, PI / 2).normalized() * 1.5
	from_sign.rotation.y = GridUtils.vec_to_rot(to_dir) + PI
	from_sign.text = p_from_title
	from_sign.visible = false

	to_sign.position = GridUtils.grid_to_world(hall_start - hall_dir * 0.60) - position
	to_sign.position -= hall_dir.rotated(Vector3.UP, PI / 2).normalized() * 1.5
	to_sign.rotation.y = GridUtils.vec_to_rot(hall_dir)
	to_sign.text = p_to_title

	entry_door.position = GridUtils.grid_to_world(from_pos) - 1.9 * from_dir - position
	entry_door.rotation.y = GridUtils.vec_to_rot(from_dir) + PI
	exit_door.position = GridUtils.grid_to_world(to_pos) + 1.9 * to_dir - position
	exit_door.rotation.y = GridUtils.vec_to_rot(to_dir)
	entry_door.set_open(true, true)
	exit_door.set_open(false, true)

	var center_pos: Vector3 = GridUtils.grid_to_world((from_pos + to_pos) / 2) + Vector3(0, 4, 0) - position

	_detector.position = center_pos
	_detector.monitoring = true
	_detector.direction_changed.connect(_on_direction_changed)
	_detector.init(GridUtils.grid_to_world(from_pos), GridUtils.grid_to_world(to_pos))

	loader.position = center_pos

	ExhibitFetcher.wikitext_failed.connect(_on_fetch_failed)


func _create_curve_hall(hall_start: Vector3, hall_dir: Vector3, is_right: bool = true, level: int = FLAT) -> void:
	var ori: int = GridUtils.vec_to_orientation(_grid, hall_dir)
	var ori_turn: int = GridUtils.vec_to_orientation(_grid, hall_dir.rotated(Vector3.UP, 3 * PI / 2))
	var corner_ori: int = ori if is_right else ori_turn
	var hall_corner: Vector3 = hall_start + hall_dir

	if level == FLAT:
		_grid.set_cell_item(hall_start, INTERNAL_HALL, ori)
		_grid.set_cell_item(hall_start - Vector3.UP, floor_type, 0)
		_grid.set_cell_item(hall_start + Vector3.UP, WALL, 0)
		_grid.set_cell_item(hall_corner, INTERNAL_HALL_TURN, corner_ori)
		_grid.set_cell_item(hall_corner - Vector3.UP, floor_type, 0)
		_grid.set_cell_item(hall_corner + Vector3.UP, WALL, 0)
		$Light.global_position = GridUtils.grid_to_world(hall_corner) + Vector3.UP * 2
	elif level == UP:
		_grid.set_cell_item(hall_start, HALL_STAIRS_UP, ori)
		_grid.set_cell_item(hall_start + Vector3.UP, -1, ori)
		_grid.set_cell_item(hall_corner + Vector3.UP, -1, ori)
		_grid.set_cell_item(hall_corner, HALL_STAIRS_TURN, corner_ori)
		$Light.global_position = GridUtils.grid_to_world(hall_corner) + Vector3.UP * 4
	elif level == DOWN:
		_grid.set_cell_item(hall_start, HALL_STAIRS_DOWN, ori)
		_grid.set_cell_item(hall_start + Vector3.UP, -1, ori)
		_grid.set_cell_item(hall_corner, -1, ori)
		_grid.set_cell_item(hall_corner - Vector3.UP, HALL_STAIRS_TURN, corner_ori)
		$Light.global_position = GridUtils.grid_to_world(hall_corner)

	var exit_hall_dir: Vector3 = hall_dir.rotated(Vector3.UP, (3 if is_right else 1) * PI / 2)
	var exit_hall: Vector3 = hall_corner + exit_hall_dir
	var exit_ori: int = GridUtils.vec_to_orientation(_grid, exit_hall_dir)
	var exit_ori_neg: int = GridUtils.vec_to_orientation(_grid, -exit_hall_dir)

	to_dir = exit_hall_dir

	if level == FLAT:
		_grid.set_cell_item(exit_hall, INTERNAL_HALL, exit_ori)
		_grid.set_cell_item(exit_hall - Vector3.UP, floor_type, 0)
		_grid.set_cell_item(exit_hall + Vector3.UP, WALL, 0)
		to_dir = exit_hall_dir
		to_pos = exit_hall
	elif level == UP:
		_grid.set_cell_item(exit_hall + Vector3.UP, HALL_STAIRS_DOWN, exit_ori_neg)
		_grid.set_cell_item(exit_hall + 2 * Vector3.UP, -1, 0)
		_grid.set_cell_item(exit_hall, -1, 0)
		_grid.set_cell_item(exit_hall - Vector3.UP, -1, 0)
		to_pos = exit_hall + Vector3.UP
	elif level == DOWN:
		_grid.set_cell_item(exit_hall - Vector3.UP, HALL_STAIRS_UP, exit_ori_neg)
		_grid.set_cell_item(exit_hall, -1, 0)
		_grid.set_cell_item(exit_hall + Vector3.UP, -1, 0)
		to_pos = exit_hall - Vector3.UP


func _exit_tree() -> void:
	if ExhibitFetcher.wikitext_failed.is_connected(_on_fetch_failed):
		ExhibitFetcher.wikitext_failed.disconnect(_on_fetch_failed)


func _on_fetch_failed(titles: Array, message: String) -> void:
	for title: String in titles:
		if title == to_title:
			exit_door.set_message("Error Loading Exhibit: " + message)


func _on_direction_changed(direction: String) -> void:
	player_direction = direction
	if direction == "exit":
		emit_signal("on_player_toward_exit")
	else:
		emit_signal("on_player_toward_entry")
