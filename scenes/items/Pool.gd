extends Node3D

@export var light: bool = true

func _ready() -> void:
	if not light:
		$OmniLight3D.queue_free()
