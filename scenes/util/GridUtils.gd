class_name GridUtils
extends RefCounted

static func vec_to_rot(vec: Vector3) -> float:
	if vec.z < -0.1:
		return 0.0
	elif vec.z > 0.1:
		return PI
	elif vec.x > 0.1:
		return 3 * PI / 2
	elif vec.x < -0.1:
		return PI / 2
	return 0.0

## Accepts GridMap or GridWrapper
static func vec_to_orientation(grid: Variant, vec: Vector3) -> int:
	var vec_basis := Basis.looking_at(vec.normalized())
	return grid.get_orthogonal_index_from_basis(vec_basis)

static func grid_to_world(vec: Vector3) -> Vector3:
	return Constants.GRID_CELL_SIZE * vec

static func world_to_grid(vec: Vector3) -> Vector3:
	return (vec / Constants.GRID_CELL_SIZE).round()

## Accepts GridMap or GridWrapper
static func cell_neighbors(grid: Variant, pos: Vector3, id: int) -> Array[Vector3]:
	var neighbors: Array[Vector3] = []
	for x in range(-1, 2):
		for z in range(-1, 2):
			# no diagonals
			if x != 0 and z != 0:
				continue
			elif x == 0 and z == 0:
				continue

			var vec := Vector3(pos.x + x, pos.y, pos.z + z)
			var cell_val: int = grid.get_cell_item(vec)

			if cell_val == id:
				neighbors.append(vec)
	return neighbors

## Accepts GridMap or GridWrapper
static func only_types_in_cells(grid: Variant, cells: Array, types: Array, debug_print: bool = false) -> bool:
	for c in cells:
		var v: int = grid.get_cell_item(c)
		if not types.has(v):
			if debug_print:
				print("returning false-- found type ", v)
			return false
	return true

## Accepts GridMap or GridWrapper
static func safe_overwrite(grid: Variant, pos: Vector3) -> bool:
	return only_types_in_cells(grid, [
		pos,
		pos - Vector3.UP,
		pos + Vector3.UP,
	], [-1, 5])
