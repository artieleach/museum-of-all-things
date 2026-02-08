extends Node3D


func open() -> void:
	set_open(true)

func close() -> void:
	set_open(false)

func set_open(open: bool = true, instant: bool = false) -> void:
	$Plane.visible = not open
	if is_visible() and not instant:
		var density_tween = get_tree().create_tween()
		var opacity_tween = get_tree().create_tween()

		density_tween.tween_property(
			$FogVolume.material,
			"shader_param/density",
			0.0 if open else 1.0,
			0.5
		)
	else:
		$FogVolume.material.density = 0.0 if open else 1.0
