extends Node
class_name PointingController
## Manages reaction Sprite3D spawning and chime audio for pointing system.

const REACTION_TEXTS: Array[String] = ["!", "?", "*", "<3"]
const REACTION_COLORS: Array[Color] = [
	Color(1.0, 0.8, 0.2),  # ! - gold
	Color(0.3, 0.7, 1.0),  # ? - blue
	Color(1.0, 1.0, 0.5),  # star - yellow
	Color(1.0, 0.3, 0.5),  # heart - pink
]
const REACTION_RISE_SPEED: float = 1.5
const REACTION_LIFETIME: float = 2.0
const CHIME_SOUND: String = "res://assets/sound/UI/UI Crystal 1.ogg"

var _main: Node = null
var _chime: AudioStream = null


func init(main: Node) -> void:
	_main = main
	if ResourceLoader.exists(CHIME_SOUND):
		_chime = load(CHIME_SOUND)


func spawn_reaction(reaction_index: int, world_pos: Vector3) -> void:
	if reaction_index < 0 or reaction_index >= REACTION_TEXTS.size():
		return

	var label: Label3D = Label3D.new()
	label.text = REACTION_TEXTS[reaction_index]
	label.font_size = 96
	label.modulate = REACTION_COLORS[reaction_index]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	_main.add_child(label)
	label.global_position = world_pos + Vector3.UP * 0.5

	# Animate rise + fade
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * REACTION_RISE_SPEED * REACTION_LIFETIME, REACTION_LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, REACTION_LIFETIME)
	tween.chain().tween_callback(label.queue_free)

	# Play chime
	if _chime:
		var audio: AudioStreamPlayer = AudioStreamPlayer.new()
		audio.stream = _chime
		audio.volume_db = -10.0
		audio.bus = &"SFX"
		_main.add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
