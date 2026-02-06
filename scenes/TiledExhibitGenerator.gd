extends Node3D
## Procedurally generates tiled exhibit rooms with walls, floors, and item slots.

signal exit_added(exit: Hall)

# Use GridConstants for cell types
const FLOOR_WOOD: int = GridConstants.FLOOR_WOOD
const RESERVED_VAL: int = GridConstants.RESERVED_VAL
const FLOOR_CARPET: int = GridConstants.FLOOR_CARPET
const FLOOR_MARBLE: int = GridConstants.FLOOR_MARBLE

const WALL: int = GridConstants.WALL
const CEILING: int = GridConstants.CEILING
const INTERNAL_HALL: int = GridConstants.INTERNAL_HALL
const INTERNAL_HALL_TURN: int = GridConstants.INTERNAL_HALL_TURN
const HALL_STAIRS_UP: int = GridConstants.HALL_STAIRS_UP
const HALL_STAIRS_DOWN: int = GridConstants.HALL_STAIRS_DOWN
const HALL_STAIRS_TURN: int = GridConstants.HALL_STAIRS_TURN
const MARKER: int = GridConstants.MARKER
const BENCH: int = GridConstants.BENCH
const FREE_WALL: int = GridConstants.FREE_WALL

const DIRECTIONS: Array[Vector3] = GridConstants.DIRECTIONS
const _GROUP_SCENERY := &"Scenery"

@onready var _pool_scene: PackedScene = preload("res://scenes/items/Pool.tscn")
@onready var _planter_scene: PackedScene = preload("res://scenes/items/Planter.tscn")
@onready var _small_planter_scene: PackedScene = preload("res://scenes/items/SmallPlanter.tscn")
@onready var _hall_scene: PackedScene = preload("res://scenes/Hall.tscn")
@onready var _grid_wrapper: PackedScene = preload("res://scenes/util/GridWrapper.tscn")

var _rng: RandomNumberGenerator = null
var title: String = ""
var _prev_title: String = ""

var entry: Hall = null
var exits: Array[Hall] = []

var _room_count: int:
	get:
		return _room_list.size()
	set(_v):
		pass

var _item_slot_map: Dictionary = {}
var _item_slots: Array = []
var _item_slot_idx: int = 0

var _y: int = 0
var _room_list: Dictionary = {}
var _next_room_candidates: Array = []

var _raw_grid: GridMap = null
var _grid: Node = null
var _floor: int = FLOOR_WOOD
var _no_props: bool = false
var _exit_limit: int = 1000000
var _min_room_dimension: int = 2
var _max_room_dimension: int = 5


func _ready() -> void:
	pass


func _rand_dim() -> int:
	return _rng.randi_range(_min_room_dimension, _max_room_dimension)


func rand_dir() -> Vector3:
	return DIRECTIONS[_rng.randi() % DIRECTIONS.size()]


func vlt(v1: Vector3, v2: Vector3) -> Vector3:
	return v1 if v1.x < v2.x or v1.z < v2.z else v2


func vgt(v1: Vector3, v2: Vector3) -> Vector3:
	return v1 if v1.x > v2.x or v1.z > v2.z else v2


func vec_key(v: Vector3) -> Vector3i:
	return Vector3i(int(v.x), int(v.y), int(v.z))


func add_item_slot(s: Array) -> void:
	var k: Vector3i = vec_key(s[0])
	if not _item_slot_map.has(k):
		_item_slot_map[vec_key(s[0])] = s
		_item_slots.append(s)


func has_item_slot() -> bool:
	return _item_slot_idx < _item_slots.size()


func get_item_slot() -> Variant:
	if has_item_slot():
		var slot: Array = _item_slots[_item_slot_idx]
		_item_slot_idx += 1
		return slot
	else:
		return null


func generate(params: Dictionary) -> void:
	# set initial fields
	_min_room_dimension = params.min_room_dimension
	_max_room_dimension = params.max_room_dimension

	var start_pos: Vector3 = params.start_pos
	title = params.title
	var prev_title: String = params.prev_title
	var hall_type: Array = params.hall_type if params.has("hall_type") else [true, 0]
	_y = int(start_pos.y)

	_no_props = params.has("no_props") and params.no_props
	_exit_limit = params.exit_limit if params.has("exit_limit") else 1000000

	# init grid
	_grid = _grid_wrapper.instantiate()
	add_child(_grid)
	_raw_grid = _grid._grid

	# init rng
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash(title)
	_prev_title = prev_title
	_floor = ExhibitStyle.gen_floor(title)

	# init starting hall
	var starting_hall: Hall = _hall_scene.instantiate()
	add_child(starting_hall)
	starting_hall.init(
		_grid,
		prev_title,
		title,
		start_pos + (Vector3.DOWN * hall_type[1]),
		Vector3(1, 0, 0),
		hall_type,
	)

	starting_hall.entry_door.set_open(false, true)
	starting_hall.from_sign.visible = true

	# initialize public fields
	entry = starting_hall

	# now we create the first room
	var room_width: int = _rand_dim()
	var room_length: int = _rand_dim()
	var room_center: Vector3 = Vector3(
		starting_hall.to_pos.x + starting_hall.to_dir.x * (2 + room_width / 2),
		_y,
		starting_hall.to_pos.z + starting_hall.to_dir.z * (2 + room_length / 2),
	) - (starting_hall.to_dir if hall_type[0] else Vector3.ZERO)

	var room_obj: Dictionary = _add_to_room_list(room_center, room_width, room_length)
	var bounds: Array = _room_to_bounds(room_center, room_width, room_length)
	_carve_room(bounds[0], bounds[1], _y)
	_create_next_room_candidate(room_obj)
	_decorate_entry(starting_hall, room_obj)
	_decorate_room(room_obj)


func _create_next_room_candidate(last_room: Dictionary) -> void:
	var room_width: int = _rand_dim()
	var room_length: int = _rand_dim()
	var room_center: Vector3
	var room_bounds: Array
	var next_room_dir: Vector3

	# prepare directions to try
	var try_dirs: Array = DIRECTIONS.duplicate()
	CollectionUtils.shuffle(_rng, try_dirs)

	var failed: bool = true
	for dir: Vector3 in try_dirs:
		# project where the next room will be based on random direction
		room_center = last_room.center + Vector3(
			dir.x * (last_room.width / 2 + room_width / 2 + 3),
			0,
			dir.z * (last_room.length / 2 + room_length / 2 + 3)
		)

		# check if we found a valid room placement
		room_bounds = _room_to_bounds(room_center, room_width, room_length)
		if not _overlaps_room(room_bounds[0], room_bounds[1], _y):
			next_room_dir = dir
			failed = false
			break

	if failed:
		return

	var room_obj: Dictionary = {
		"center": room_center,
		"width": room_width,
		"length": room_length,
	}
	var hall_bounds: Array = _create_hall_bounds(last_room, room_obj)

	_decorate_reserved_walls(last_room, hall_bounds, next_room_dir)

	_grid.reserve_zone(hall_bounds)
	_grid.reserve_zone(room_bounds)
	room_obj.bounds = room_bounds
	room_obj.hall = hall_bounds
	_next_room_candidates.append(room_obj)


func _add_to_room_list(c: Vector3, w: int, l: int) -> Dictionary:
	var room_obj: Dictionary = {
		"center": c,
		"width": w,
		"length": l,
	}
	_room_list[vec_key(c)] = room_obj
	return room_obj


func add_room() -> void:
	if _next_room_candidates.size() == 0:
		push_error("no room candidate to create")
		return
	if _item_slots.size() > Platform.get_max_slots_per_exhibit():
		return

	var idx: int = _rng.randi() % _next_room_candidates.size()
	var room: Dictionary = _next_room_candidates.pop_at(idx)

	_grid.free_reserved_zone(room.center)

	_add_to_room_list(room.center, room.width, room.length)
	_carve_room(room.hall[0], room.hall[1], _y)
	_carve_room(room.bounds[0], room.bounds[1], _y)
	_create_next_room_candidate(room)

	# branch sometimes
	if _rng.randi() % 2 == 0:
		_create_next_room_candidate(room)

	_decorate_room(room)


func _clear_scenery_in_area(h1: Vector3, h2: Vector3) -> void:
	var wh1: Vector3 = GridUtils.grid_to_world(h1)
	var wh2: Vector3 = GridUtils.grid_to_world(h2)
	for c: Node in get_children():
		if c.is_in_group(_GROUP_SCENERY):
			var p: Vector3 = c.global_position
			if p.x >= wh1.x and p.x <= wh2.x and p.z >= wh1.z and p.z <= wh2.z:
				c.queue_free()


func _create_hall_bounds(last_room: Dictionary, next_room: Dictionary) -> Array:
	var start_hall: Vector3 = vlt(last_room.center, next_room.center)
	var end_hall: Vector3 = vgt(last_room.center, next_room.center)
	var hall_width: int

	if (start_hall - end_hall).x != 0:
		hall_width = _rng.randi_range(1, mini(last_room.length, next_room.length))
		start_hall -= Vector3(0, 0, hall_width / 2)
		end_hall += Vector3(0, 0, (hall_width - 1) / 2)
	else:
		hall_width = _rng.randi_range(1, mini(last_room.width, next_room.width))
		start_hall -= Vector3(hall_width / 2, 0, 0)
		end_hall += Vector3((hall_width - 1) / 2, 0, 0)

	return [start_hall, end_hall]


func _decorate_entry(starting_hall: Hall, _room_obj: Dictionary) -> void:
	var free_wall_pos: Vector3 = starting_hall.to_pos + 2 * starting_hall.to_dir
	var free_wall_ori: int = GridUtils.vec_to_orientation(_grid, starting_hall.to_dir.rotated(Vector3.UP, PI / 2))
	_grid.set_cell_item(free_wall_pos, FREE_WALL, free_wall_ori)
	add_item_slot([free_wall_pos - starting_hall.to_dir * 0.075, starting_hall.to_dir])
	add_item_slot([free_wall_pos + starting_hall.to_dir * 0.075, -starting_hall.to_dir])


func _decorate_room(room: Dictionary) -> void:
	var center: Vector3 = room.center
	var width: int = room.width
	var length: int = room.length

	var bounds: Array = _room_to_bounds(center, width, length)
	var c1: Vector3 = bounds[0]
	var c2: Vector3 = bounds[1]
	var y: int = int(center.y)

	# walk border of room to place wall objects
	for z: int in [int(c1.z), int(c2.z)]:
		for x: int in range(int(c1.x), int(c2.x) + 1):
			_decorate_wall_tile(Vector3(x, y, z))
	for x: int in [int(c1.x), int(c2.x)]:
		for z: int in range(int(c1.z), int(c2.z) + 1):
			_decorate_wall_tile(Vector3(x, y, z))

	if !Engine.is_editor_hint() and not _no_props:
		_decorate_room_center(center, width, length)


func _decorate_reserved_walls(last_room: Dictionary, hall_bounds: Array, dir: Vector3) -> void:
	var hall_bounds_width: float = hall_bounds[1].x - hall_bounds[0].x
	var hall_bounds_length: float = hall_bounds[1].z - hall_bounds[0].z
	var planter_pos: Vector3
	var planter_rot: Vector3 = Vector3(0, 0, 0)

	if abs(dir.x) > 0:
		if abs(hall_bounds_length) < 1:
			return
		planter_pos = Vector3(
			last_room.center.x + (last_room.width / 2) * dir.x,
			_y,
			(hall_bounds[1].z + hall_bounds[0].z) / 2.0
		)
	else:
		if abs(hall_bounds_width) < 1:
			return
		planter_rot.y = PI / 2
		planter_pos = Vector3(
			(hall_bounds[1].x + hall_bounds[0].x) / 2.0,
			_y,
			last_room.center.z + (last_room.length / 2 + 1) * dir.z,
		)

	var planter: Node3D = _small_planter_scene.instantiate()
	planter.rotation = planter_rot
	planter.position = GridUtils.grid_to_world(planter_pos) + dir
	add_child(planter)


func _decorate_room_center(center: Vector3, width: int, length: int) -> void:
	if width > 3 and length > 3:
		var bounds: Array = _room_to_bounds(center, width, length)
		var true_center: Vector3 = (bounds[0] + bounds[1]) / 2
		var roll: int = _rng.randi_range(0, 3)
		if roll == 0:
			var pool: Node3D = _pool_scene.instantiate()
			pool.position = GridUtils.grid_to_world(true_center)
			add_child(pool)
			return
		elif roll == 1:
			var planter: Node3D = _planter_scene.instantiate()
			planter.position = GridUtils.grid_to_world(true_center)
			planter.rotation.y = PI / 2 if length > width else 0.0
			add_child(planter)
			return

	var bench_area_bounds: Variant = null
	var bench_area_ori: int = 0

	if width > length and width > 2:
		bench_area_bounds = _room_to_bounds(center, width - 2, 1)
	elif length > width and length > 2:
		bench_area_ori = GridUtils.vec_to_orientation(_grid, Vector3(1, 0, 0))
		bench_area_bounds = _room_to_bounds(center, 1, length - 2)
	if bench_area_bounds:
		var bench_slots: Array = []
		var c1: Vector3 = bench_area_bounds[0]
		var c2: Vector3 = bench_area_bounds[1]
		var y: int = int(center.y)
		for x: int in range(int(c1.x), int(c2.x) + 1):
			for z: int in range(int(c1.z), int(c2.z) + 1):
				var pos: Vector3 = Vector3(x, y, z)
				if _raw_grid.get_cell_item(pos) != -1:
					continue

				var free_wall: bool = _rng.randi_range(0, 1) == 0
				var valid_bench: bool = GridUtils.cell_neighbors(_raw_grid, pos, INTERNAL_HALL).size() == 0 and\
						GridUtils.cell_neighbors(_raw_grid, pos, HALL_STAIRS_UP).size() == 0 and\
						GridUtils.cell_neighbors(_raw_grid, pos, HALL_STAIRS_DOWN).size() == 0
				var valid_free_wall: bool = valid_bench and GridUtils.cell_neighbors(_raw_grid, pos, WALL).size() == 0

				if width > 3 or length > 3 and free_wall and valid_free_wall and _room_count > 2:
					var dir: Vector3 = Vector3.RIGHT if width > length else Vector3.FORWARD
					var item_dir: Vector3 = Vector3.FORWARD if width > length else Vector3.RIGHT
					var ori: int = GridUtils.vec_to_orientation(_grid, dir)
					_grid.set_cell_item(pos, FREE_WALL, ori)
					bench_slots.push_front([pos - item_dir * 0.075, item_dir])
					bench_slots.append([pos + item_dir * 0.075, -item_dir])
				elif valid_bench:
					_grid.set_cell_item(pos, BENCH, bench_area_ori)
		for slot: Array in bench_slots:
			add_item_slot(slot)


func _decorate_wall_tile(pos: Vector3) -> void:
	# we use the raw grid bc we want to ignore reservations here
	if _raw_grid.get_cell_item(pos) == FREE_WALL:
		return

	var wall_neighbors: Array = GridUtils.cell_neighbors(_grid, pos, WALL)
	for wall: Vector3 in wall_neighbors:
		var slot: Vector3 = (wall + pos) / 2
		var hall_dir: Vector3 = wall - pos
		var valid_halls: Array = Hall.valid_hall_types(_grid, wall, hall_dir)

		# put an exit everywhere it fits
		if valid_halls.size() > 0 and exits.size() < _exit_limit:
			var new_hall: Hall = _hall_scene.instantiate()
			var hall_type: Array = valid_halls[_rng.randi() % valid_halls.size()]
			add_child(new_hall)
			new_hall.init(
				_grid,
				title,
				title,
				wall,
				hall_dir,
				hall_type
			)

			exits.append(new_hall)
			emit_signal("exit_added", new_hall)
		# put exhibit items everywhere else
		else:
			add_item_slot([slot, hall_dir])


func _room_to_bounds(center: Vector3, width: int, length: int) -> Array:
	return [
		Vector3(center.x - width / 2, center.y, center.z - length / 2),
		Vector3(center.x + width / 2 - ((width + 1) % 2), center.y, center.z + length / 2 + ((length + 1) % 2))
	]


func _carve_room(corner1: Vector3, corner2: Vector3, y: int) -> void:
	var lx: int = int(corner1.x)
	var gx: int = int(corner2.x)
	var lz: int = int(corner1.z)
	var gz: int = int(corner2.z)

	_clear_scenery_in_area(Vector3(lx, 0, lz), Vector3(gx, 0, gz))

	for x: int in range(lx - 1, gx + 2):
		for z: int in range(lz - 1, gz + 2):
			var c: int = _grid.get_cell_item(Vector3(x, y, z))
			if x < lx or z < lz or x > gx or z > gz:
				if c == HALL_STAIRS_UP or c == HALL_STAIRS_DOWN or c == HALL_STAIRS_TURN:
					continue
				elif c == INTERNAL_HALL:
					_grid.set_cell_item(Vector3(x, y + 1, z), WALL, 0)
				elif _grid.get_cell_item(Vector3(x, y - 1, z)) == -1:
					_grid.set_cell_item(Vector3(x, y, z), WALL, 0)
					_grid.set_cell_item(Vector3(x, y + 1, z), WALL, 0)
					_grid.set_cell_item(Vector3(x, y + 2, z), -1, 0)
			else:
				if c == WALL:
					_grid.set_cell_item(Vector3(x, y, z), -1, 0)
					_grid.set_cell_item(Vector3(x, y + 1, z), -1, 0)
				_grid.set_cell_item(Vector3(x, y + 2, z), CEILING, 0)
				_grid.set_cell_item(Vector3(x, y - 1, z), _floor, 0)


func _overlaps_room(corner1: Vector3, corner2: Vector3, y: int) -> bool:
	for x: int in range(int(corner1.x) - 1, int(corner2.x) + 2):
		for z: int in range(int(corner1.z) - 1, int(corner2.z) + 2):
			if not GridUtils.safe_overwrite(_grid, Vector3(x, y, z)):
				return true
	return false


func get_rooms_for_npcs() -> Array:
	## Returns room data for NPC spawning.
	var result: Array = []
	for room_key: Vector3i in _room_list:
		var room: Dictionary = _room_list[room_key]
		var bounds: Array = _room_to_bounds(room.center, room.width, room.length)
		result.append({
			"center": room.center,
			"bounds": bounds
		})
	return result
