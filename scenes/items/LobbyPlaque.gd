@tool
extends MeshInstance3D

@export var no_light: bool = false
@export var title_color: Color = Color.WHITE
@export var hide_titles: bool = false
@export var title_text: String = "Art"
@export var subtitle_text: String = "Featured Art Exhibits"

var max_title_length_px: int = 320
var start_font_size_title: int

func _ready() -> void:
	if no_light:
		$MeshInstance3D.visible = false
		$SpotLight3D.visible = false

	if hide_titles:
		$Title.visible = false
		$Subtitle.visible = false
	else:
		start_font_size_title = $Title.font_size
		$Title.modulate = title_color
		$Title.text = title_text
		$Subtitle.modulate = title_color
		$Subtitle.text = subtitle_text
		if not Engine.is_editor_hint():
			SettingsEvents.language_changed.connect(_resize_text)
			_resize_text()

func _exit_tree() -> void:
	if SettingsEvents.language_changed.is_connected(_resize_text):
		SettingsEvents.language_changed.disconnect(_resize_text)

func _resize_text(_lang: String = "") -> void:
	$Title.font_size = start_font_size_title
	TextUtils.resize_text_to_px($Title, max_title_length_px)
