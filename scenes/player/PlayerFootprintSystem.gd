extends Node
class_name PlayerFootprintSystem
## Places fading footprint Decal3D nodes from a ring buffer on each footstep.

const POOL_SIZE: int = 50
const POOL_SIZE_MOBILE: int = 20
const FADE_DURATION: float = 120.0  # 2 minutes
const DECAL_SIZE: Vector3 = Vector3(0.3, 0.1, 0.4)

var _player: CharacterBody3D = null
var _decals: Array[Decal] = []
var _decal_idx: int = 0
var _pool_size: int = POOL_SIZE

var _stillness_timer: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
const STILLNESS_THRESHOLD: float = 0.1
const GHOST_STILLNESS_TIME: float = 30.0
var _ghost_placed_here: bool = false


func init(player: CharacterBody3D) -> void:
	_player = player
	_pool_size = POOL_SIZE_MOBILE if Platform.is_mobile() else POOL_SIZE

	# Create decal pool
	var texture: Texture2D = _create_footprint_texture()
	for i: int in _pool_size:
		var decal: Decal = Decal.new()
		decal.size = DECAL_SIZE
		decal.texture_albedo = texture
		decal.modulate = Color(0.3, 0.25, 0.2, 0.4)
		decal.visible = false
		decal.cull_mask = 1  # Only affect static world
		player.get_parent().call_deferred("add_child", decal)
		_decals.append(decal)

	_last_position = player.global_position


func place_footprint() -> void:
	if not _player or not _player.is_local:
		return
	if _decals.is_empty():
		return

	var decal: Decal = _decals[_decal_idx]
	_decal_idx = (_decal_idx + 1) % _pool_size

	decal.global_position = _player.global_position - Vector3(0, 0.05, 0)
	decal.rotation.y = _player.rotation.y
	decal.visible = true
	decal.modulate.a = 0.4

	# Fade out over time
	var tween: Tween = decal.create_tween()
	tween.tween_property(decal, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func(): decal.visible = false)


func process_stillness(delta: float) -> void:
	if not _player or not _player.is_local:
		return

	var moved: float = _player.global_position.distance_to(_last_position)
	if moved < STILLNESS_THRESHOLD:
		_stillness_timer += delta
		if _stillness_timer >= GHOST_STILLNESS_TIME and not _ghost_placed_here:
			_ghost_placed_here = true
			var room: String = _player.current_room
			if room != "Lobby":
				TraceManager.add_ghost(room, _player.global_position, _player.rotation.y)
	else:
		_stillness_timer = 0.0
		_ghost_placed_here = false
		_last_position = _player.global_position


func _create_footprint_texture() -> Texture2D:
	# Procedural small footprint texture
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Simple oval shape
	for x: int in 16:
		for y: int in 16:
			var dx: float = (x - 8.0) / 6.0
			var dy: float = (y - 8.0) / 7.0
			if dx * dx + dy * dy < 1.0:
				img.set_pixel(x, y, Color(0.3, 0.25, 0.2, 0.5))
	return ImageTexture.create_from_image(img)
