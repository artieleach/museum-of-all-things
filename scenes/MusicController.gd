extends Node3D
## Controls background music playback with random track selection.

@onready var _tracks: Array[AudioStream] = [
	preload("res://assets/sound/Music/MoAT Track 1 - Waiting on the Weather.ogg"),
	preload("res://assets/sound/Music/MoAT Track 2 - Comfort on the way.ogg"),
	preload("res://assets/sound/Music/MoAT Track 3 - Life is Older Than You Knew.ogg"),
	preload("res://assets/sound/Music/MoAT Track 4 - Blue Sky Inside.ogg"),
	preload("res://assets/sound/Music/MoAT Track 5 - Waiting for a ride.ogg"),
	preload("res://assets/sound/Music/MoAT Track 6 - Memory In Passing.ogg"),
	preload("res://assets/sound/Music/MoAT Track 7 - Blue Sky Outside.ogg"),
	preload("res://assets/sound/Music/MoAT Track 8 - Stillness After Closing.ogg"),
]

@export var min_space_start: float = 20.0
@export var min_space: float = 60.0 * 3
@export var max_space: float = 60.0 * 6

var _last_track: int = -1


func _ready() -> void:
	var wait_time: float = randf_range(min_space_start, max_space)
	if OS.is_debug_build():
		print("waiting for first track. time=", wait_time)
	get_tree().create_timer(wait_time).timeout.connect(_play_track)
	$AudioStreamPlayer.finished.connect(_reset_timer)


func _play_track() -> void:
	var track_idx: int
	if _last_track < 0:
		track_idx = randi() % _tracks.size()
	else:
		track_idx = (_last_track + (randi() % (_tracks.size() - 1))) % _tracks.size()
	_last_track = track_idx

	if OS.is_debug_build():
		print("playing music. track #", track_idx)

	$AudioStreamPlayer.stream = _tracks[track_idx]
	$AudioStreamPlayer.seek(0.0)
	$AudioStreamPlayer.play()


func _reset_timer() -> void:
	var wait_time: float = randf_range(min_space, max_space)
	if OS.is_debug_build():
		print("waiting for next track. time=", wait_time)
	get_tree().create_timer(wait_time).timeout.connect(_play_track)
