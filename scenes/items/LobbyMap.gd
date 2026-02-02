extends MeshInstance3D

var max_length_title: int = 120
var max_search_length: int = 100
var start_font_size: int

func _ready() -> void:
	start_font_size = $Search.font_size
	GlobalMenuEvents.set_language.connect(_resize_text)
	_resize_text()

func _resize_text(_lang: String = "") -> void:
	for child in get_children():
		if child is Label3D:
			child.font_size = start_font_size

	Util.resizeTextToPx($Search, max_search_length)
	for child in get_children():
		if child is Label3D:
			Util.resizeTextToPx(child, max_length_title)
