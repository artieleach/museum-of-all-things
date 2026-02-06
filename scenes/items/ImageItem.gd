extends MeshInstance3D

signal loaded

var image_url: String
var _image: Texture2D
var text: String
var title: String
var plate_style: String
var is_stolen: bool = false

var plate_margin: float = 0.05
var max_text_height: float = 0.5

const plate_black: Material = preload("res://assets/textures/black.tres")
const plate_white: Material = preload("res://assets/textures/flat_white.tres")

const text_white: Color = Color(0.8, 0.8, 0.8)
const text_black: Color = Color(0.0, 0.0, 0.0)
const text_clear: Color = Color(0.0, 0.0, 0.0, 0.0)

func get_image_size() -> Vector2:
	return Vector2(_image.get_width(), _image.get_height())

func _update_text_plate() -> void:
	var aabb: AABB = $Label.get_aabb()
	if aabb.size.length() == 0:
		return

	if aabb.size.y > max_text_height:
		$Label.font_size -= 1
		call_deferred("_update_text_plate")
		return

	if not plate_style:
		return

	var plate: MeshInstance3D = $Label/Plate
	plate.visible = true
	plate.scale = Vector3(aabb.size.x + 2 * plate_margin, 1, aabb.size.y + 2 * plate_margin)
	plate.position.y = -(aabb.size.y / 2.0)

func _on_image_loaded(url: String, image: Texture2D, _ctx: Variant) -> void:
	if url != image_url:
		return

	DataManager.loaded_image.disconnect(_on_image_loaded)
	_image = image
	var size: Vector2 = _image.get_size()
	if size.length() > 0:
		material_override.set_shader_parameter("texture_albedo", _image)

	var label: Label3D = $Label
	label.text = TextUtils.strip_markup(text)
	call_deferred("_update_text_plate")

	var w: int = _image.get_width()
	var h: int = _image.get_height()
	var fw: float = float(w)
	var fh: float = float(h)

	if w != 0:
		var height: float = 2.0 if h > w else 2.0 * (fh / fw)
		var width: float = 2.0 if w > h else 2.0 * (fw / fh)

		mesh.size = Vector2(width, height)
		label.position.z = (height / 2.0) + 0.2
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

		_update_collision_shape(width, height)

		visible = true
		loaded.emit()

func _update_collision_shape(width: float, height: float) -> void:
	var collision_shape: CollisionShape3D = $InteractionBody/CollisionShape3D
	if collision_shape and collision_shape.shape:
		var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
		if box_shape:
			box_shape.size = Vector3(width, height, 0.1)

func interact() -> void:
	if _image and image_url:
		MultiplayerEvents.emit_skin_selected(image_url, _image)

func set_stolen(stolen: bool) -> void:
	is_stolen = stolen
	visible = not stolen
	if has_node("InteractionBody/CollisionShape3D"):
		$InteractionBody/CollisionShape3D.disabled = stolen


func _on_pointer_event(event: Variant) -> void:
	if event.event_type == "click" or (event.has("pressed") and event.pressed):
		interact()

func _on_image_complete(files: Array, _ctx: Variant) -> void:
	if files.has(title):
		var data = ExhibitFetcher.get_result(title)
		if data:
			ExhibitFetcher.images_complete.disconnect(_on_image_complete)
			ExhibitFetcher.commons_images_complete.disconnect(_on_image_complete)
			_set_image(data)

func _set_image(data: Dictionary) -> void:
	var label: Label3D = $Label
	if is_instance_valid(label) and data.has("license_short_name") and data.has("artist"):
		text += "\n"
		text += data.license_short_name + " " + TextUtils.strip_html(data.artist)
		label.text = text
		call_deferred("_update_text_plate")

	if data.has("src"):
		image_url = Util.normalize_url(data.src)
		DataManager.loaded_image.connect(_on_image_loaded)
		DataManager.request_image(data.src)

func _exit_tree() -> void:
	if ExhibitFetcher.images_complete.is_connected(_on_image_complete):
		ExhibitFetcher.images_complete.disconnect(_on_image_complete)
	if ExhibitFetcher.commons_images_complete.is_connected(_on_image_complete):
		ExhibitFetcher.commons_images_complete.disconnect(_on_image_complete)
	if DataManager.loaded_image.is_connected(_on_image_loaded):
		DataManager.loaded_image.disconnect(_on_image_loaded)


func _ready() -> void:
	if not plate_style:
		pass
	elif plate_style == "white":
		$Label.modulate = text_black
		$Label.outline_modulate = text_clear
		$Label/Plate.material_override = plate_white
	elif plate_style == "black":
		$Label.modulate = text_white
		$Label.outline_modulate = text_black
		$Label/Plate.material_override = plate_black

func init(_title: String, _text: String, _plate_style: String = "") -> void:
	text = _text
	title = _title
	plate_style = _plate_style

	var data = ExhibitFetcher.get_result(title)
	if data:
		_set_image(data)
	else:
		ExhibitFetcher.images_complete.connect(_on_image_complete)
		ExhibitFetcher.commons_images_complete.connect(_on_image_complete)
