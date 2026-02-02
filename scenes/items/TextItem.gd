extends Node3D

static var max_chars := 2500

func init(text: String) -> void:
	var t : String = TextUtils.strip_markup(text).substr(0, max_chars)
	$Label.text = t if len(t) < max_chars else t + "..."
