class_name GridConstants
## Shared constants for grid cell types used across Hall.gd and TiledExhibitGenerator.gd.

# Floor types
const FLOOR_WOOD: int = 0
const FLOOR_CARPET: int = 11
const FLOOR_MARBLE: int = 12

# Structure types
const RESERVED_VAL: int = 1
const CEILING: int = 3
const WALL: int = 5
const INTERNAL_HALL_TURN: int = 6
const INTERNAL_HALL: int = 7
const MARKER: int = 8
const BENCH: int = 9
const FREE_WALL: int = 10

# Stair types
const HALL_STAIRS_UP: int = 16
const HALL_STAIRS_DOWN: int = 17
const HALL_STAIRS_TURN: int = 18

# Hall level directions
const LEVEL_UP: int = 1
const LEVEL_FLAT: int = 0
const LEVEL_DOWN: int = -1

# Standard directions
const DIRECTIONS: Array[Vector3] = [
	Vector3(1, 0, 0),
	Vector3(0, 0, 1),
	Vector3(-1, 0, 0),
	Vector3(0, 0, -1)
]

# Floor type arrays
const FLOOR_TYPES: Array[int] = [FLOOR_WOOD, FLOOR_MARBLE, FLOOR_CARPET]
