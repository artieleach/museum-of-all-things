extends Node3D

const ImageItem: PackedScene = preload("res://scenes/items/ImageItem.tscn")
const TextItem: PackedScene = preload("res://scenes/items/TextItem.tscn")
const RichTextItem: PackedScene = preload("res://scenes/items/RichTextItem.tscn")

const MarbleMaterial: Material = preload("res://assets/textures/marble21.tres")
const WhiteMaterial: Material = preload("res://assets/textures/flat_white.tres")
const WoodMaterial: Material = preload("res://assets/textures/wood_2.tres")
const BlackMaterial: Material = preload("res://assets/textures/black.tres")

@onready var _item_node: Node3D = $Item
@onready var _item: Node3D
@onready var _ceiling: Node3D = $Ceiling
@onready var _light: SpotLight3D = get_node("Item/SpotLight3D")
@onready var _frame: Node3D = get_node("Item/Frame")
@onready var _animate_item_target: Vector3 = _item_node.position + Vector3(0, 4, 0)
@onready var _animate_ceiling_target: Vector3 = _ceiling.position - Vector3(0, 2, 0)

func _start_animate() -> void:
	var tween_time: float = 0.0
	var visibility_range: float = $Item/Plaque.visibility_range_end

	# Check if any player is close enough to see/hear the animation
	for player in get_tree().get_nodes_in_group("Player"):
		if position.distance_to(player.global_position) <= visibility_range:
			tween_time = 0.5
			$SlideSound.play()
			break

	var tween: Tween = create_tween()
	var light_tween: Tween = create_tween()
	var ceiling_tween: Tween = create_tween()

	tween.tween_property(
		_item_node,
		"position",
		_animate_item_target,
		tween_time
	)

	ceiling_tween.tween_property(
		_ceiling,
		"position",
		_animate_ceiling_target,
		tween_time
	)

	if Platform.is_compatibility_renderer():
		light_tween.kill()
		_light.visible = false
	else:
		light_tween.tween_property(
			_light,
			"light_energy",
			3.0,
			tween_time
		)

	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)

	light_tween.set_trans(Tween.TRANS_LINEAR)
	light_tween.set_ease(Tween.EASE_IN_OUT)

	ceiling_tween.set_trans(Tween.TRANS_LINEAR)
	ceiling_tween.set_ease(Tween.EASE_IN_OUT)

func _on_image_item_loaded() -> void:
	var size: Vector2 = _item.get_image_size()
	if size.x > size.y:
		_frame.scale.y = size.y / float(size.x)
	else:
		_frame.scale.x = size.x / float(size.y)
	_frame.position = _item.position
	_frame.position.z = 0
	_start_animate()

func init(item_data: Dictionary) -> void:
	if item_data.has("material"):
		if item_data.material == "marble":
			$Item/Plaque.material_override = MarbleMaterial
		if item_data.material == "white":
			$Item/Plaque.material_override = WhiteMaterial
		elif item_data.material == "none":
			$Item/Plaque.visible = false
			_animate_item_target.z -= 0.05

	if item_data.type == "image":
		_item = ImageItem.instantiate()
		_item.loaded.connect(_on_image_item_loaded)
		var plate = item_data.get("plate", "")
		_item.init(item_data.get("title", ""), item_data.get("text", ""), plate if plate else "")
	elif item_data.type == "text":
		_frame.visible = false
		_item = TextItem.instantiate()
		_item.init(item_data.text)
		_start_animate()
	elif item_data.type == "rich_text":
		_frame.visible = false
		_item = RichTextItem.instantiate()
		_item.init(item_data.text)
		_start_animate()
	else:
		return
	_item.position = Vector3(0, 0, 0.07)
	_item_node.add_child(_item)
