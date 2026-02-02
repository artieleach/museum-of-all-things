extends Node3D
class_name HallDoor

static var animation_duration: float = 0.25

@onready var _door: Node3D = $Door
@onready var _open: bool = false
var _open_pos: Vector3 = Vector3(0, 6.5, 0)
var _closed_pos: Vector3 = Vector3(0, 2, 0)

func open() -> void:
	set_open(true)

func close() -> void:
	set_open(false)

func set_open(open: bool = true, instant: bool = false) -> void:
	if is_visible() and not instant:
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(
			_door,
			"position",
			_open_pos if open else _closed_pos,
			animation_duration
		)
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.set_ease(Tween.EASE_IN_OUT)
		if open:
			$OpenSound.play()
	else:
		_door.position = _open_pos if open else _closed_pos

@onready var label_pivot: Node3D = $Door/LabelPivot
@onready var top_label: Label3D = $Door/LabelPivot/Label1
@onready var bottom_label: Label3D = $Door/LabelPivot/Label2
var _label_tween: Tween = null

func set_message(msg: String, instant: bool = false) -> void:
	if _label_tween:
		_label_tween.kill()

	bottom_label.text = msg

	if is_visible() and not instant:
		_label_tween = get_tree().create_tween()
		_label_tween.tween_property(
			label_pivot,
			"rotation:z",
			label_pivot.rotation.z + PI,
			animation_duration
		)
	else:
		_label_tween = null
		label_pivot.rotation.z += PI

	var tmp: Label3D = top_label
	top_label = bottom_label
	bottom_label = tmp
