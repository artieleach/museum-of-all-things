extends Node3D
## Plays footstep sounds based on movement and floor surface type.

@onready var _audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var _water_enter_sound: AudioStream = preload("res://assets/sound/Footsteps/Water/Player Enters Water 2.ogg")

# TODO: this should be a custom resource instead
@onready var _footsteps: Dictionary = {
	"hard": [
		preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 8 reverb.ogg"),
		preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 9 reverb.ogg"),
	],
	"soft": [
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 1.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 2.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 3.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 4.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 5.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 6.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 7.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 8.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 9.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 10.ogg"),
		preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 11.ogg"),
	],
	"water": [
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 1.ogg"),
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 2.ogg"),
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 3.ogg"),
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 4.ogg"),
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 5.ogg"),
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 6.ogg"),
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 7.ogg"),
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 8.ogg"),
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 9.ogg"),
		preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 10.ogg"),
	],
	"dirt": [
		preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 1.ogg"),
		preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 2.ogg"),
		preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 3.ogg"),
		preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 4.ogg"),
		preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 5.ogg"),
		preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 6.ogg"),
		preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 7.ogg"),
	],
	"leaves": [
		preload("res://assets/sound/Environmental Ambience/Leaves 1.ogg"),
		preload("res://assets/sound/Environmental Ambience/Leaves 2.ogg"),
		preload("res://assets/sound/Environmental Ambience/Leaves 3.ogg"),
	],
}

const _DEFAULT_FLOOR_TYPE: String = "hard"
const _FLOOR_CARPET_CELL: int = 11

var _floor_material_map: Dictionary = {
	_FLOOR_CARPET_CELL: "soft",
}

@export var _step_length: float = 3.0

var _on_floor: bool = false
var _distance_from_last_step: float = 0.0
var _step_idx: int = 0
var _last_in_water: bool = false
var _last_on_floor: bool = false

@onready var _last_position: Vector3 = global_position


func _ready() -> void:
	_audio_stream_player_3d.play()


func set_on_floor(on_floor: bool) -> void:
	_on_floor = on_floor


func _physics_process(_delta: float) -> void:
	var step: float = (global_position - _last_position).length()
	_last_position = global_position

	if not _on_floor:
		if _last_on_floor and _distance_from_last_step > _step_length / 2.0:
			call_deferred("_play_footstep")
		_last_in_water = false
		_distance_from_last_step = 0.0
		_last_on_floor = _on_floor
		return

	if _on_floor and not _last_on_floor:
		_last_on_floor = _on_floor
		_distance_from_last_step = 0.0
		call_deferred("_play_footstep")
		return

	_last_on_floor = _on_floor
	_distance_from_last_step += step

	# we've stopped, so play a step
	if _distance_from_last_step > _step_length / 2.0 and step == 0:
		_distance_from_last_step = 0.0
		call_deferred("_play_footstep")
	# otherwise play a step if our distance from last step exceeds step len
	elif _distance_from_last_step > _step_length:
		_distance_from_last_step = 0.0
		call_deferred("_play_footstep")


func _play_footstep(override_type: String = "") -> void:
	var step_type: String
	var obj: Node = $FloorCast.get_collider()
	if override_type != "":
		step_type = override_type
	elif obj and obj.is_in_group("footstep_dirt"):
		step_type = "dirt"
	elif obj and obj.is_in_group("footstep_water"):
		step_type = "water"
	else:
		var floor_cell: Vector3 = GridUtils.world_to_grid(global_position) - Vector3.UP
		var floor_cell_type: int = GridManager.get_cell_item(floor_cell)
		step_type = _floor_material_map.get(
			floor_cell_type,
			_DEFAULT_FLOOR_TYPE
		)

	var step_sfx_list: Array = _footsteps[step_type]
	var step_sfx: AudioStream
	if step_type == "water" and not _last_in_water:
		step_sfx = _water_enter_sound
	else:
		step_sfx = step_sfx_list[randi() % step_sfx_list.size()]

	var playback: AudioStreamPlaybackPolyphonic = _audio_stream_player_3d.get_stream_playback()
	playback.play_stream(step_sfx)

	_last_in_water = step_type == "water"
