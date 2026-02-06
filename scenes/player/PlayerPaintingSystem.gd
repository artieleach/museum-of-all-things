extends Node
class_name PlayerPaintingSystem
## Handles stealing paintings off walls, carrying them, placing them, and eating them.

signal steal_requested(exhibit_title: String, image_title: String, image_url: String, image_size: Vector2)
signal place_requested(exhibit_title: String, image_title: String, image_url: String, wall_position: Vector3, wall_normal: Vector3, image_size: Vector2)
signal eat_requested(exhibit_title: String, image_title: String)
signal eat_anim_started
signal eat_anim_cancelled

const EAT_DURATION: float = 1.0
const CARRY_FP_POSITION: Vector3 = Vector3(0.4, -0.3, -0.6)
const CARRY_TP_POSITION: Vector3 = Vector3(0.0, 0.1, -0.5)
const EAT_FP_TARGET: Vector3 = Vector3(0.0, 0.5, -0.3)
const EAT_TP_TARGET: Vector3 = Vector3(0.0, 0.1, 0.0)
const EAT_ROTATE_FRACTION: float = 0.3  # First 30% of eat is the rotation phase
const CARRY_ROTATION: Vector3 = Vector3(90, 0, 0)
const EAT_ROTATION: Vector3 = Vector3(0, 0, 0)  # Parallel with floor
const PLACE_RAY_LENGTH: float = 4.0

var _player: CharacterBody3D = null
var _raycast: RayCast3D = null

# Carry state
var _is_carrying: bool = false
var _carried_texture: Texture2D = null
var _carried_image_url: String = ""
var _carried_image_title: String = ""
var _carried_exhibit_title: String = ""
var _carried_image_size: Vector2 = Vector2.ZERO

# Eat state
var _eat_progress: float = 0.0
var _eating: bool = false
var _eat_tween: Tween = null

# Carry meshes
var _carry_mesh_fp: MeshInstance3D = null  # First-person, child of Camera3D
var _carry_mesh_tp: MeshInstance3D = null  # Third-person, child of Pivot

var _carry_material: ShaderMaterial = null


func init(player: CharacterBody3D) -> void:
	_player = player
	_raycast = player.get_node("Pivot/Camera3D/RayCast3D")

	# Create shared material for carry meshes
	var base_material: ShaderMaterial = preload("res://assets/textures/image_item.tres")
	_carry_material = base_material.duplicate()

	# Create first-person carry mesh (child of Camera3D)
	_carry_mesh_fp = MeshInstance3D.new()
	_carry_mesh_fp.name = "CarryPaintingFP"
	var fp_mesh: PlaneMesh = PlaneMesh.new()
	fp_mesh.size = Vector2(0.3, 0.3)
	_carry_mesh_fp.mesh = fp_mesh
	_carry_mesh_fp.material_override = _carry_material
	_carry_mesh_fp.position = CARRY_FP_POSITION
	# Rotate so the plane faces the camera (plane default is flat on XZ, we want it facing -Z)
	_carry_mesh_fp.rotation_degrees = Vector3(90, 0, 0)
	_carry_mesh_fp.visible = false
	_carry_mesh_fp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_node("Pivot/Camera3D").add_child(_carry_mesh_fp)

	# Create third-person carry mesh (child of Pivot)
	_carry_mesh_tp = MeshInstance3D.new()
	_carry_mesh_tp.name = "CarryPaintingTP"
	var tp_mesh: PlaneMesh = PlaneMesh.new()
	tp_mesh.size = Vector2(0.5, 0.5)
	_carry_mesh_tp.mesh = tp_mesh
	_carry_mesh_tp.material_override = _carry_material
	_carry_mesh_tp.position = CARRY_TP_POSITION
	_carry_mesh_tp.rotation_degrees = Vector3(90, 0, 0)
	_carry_mesh_tp.visible = false
	_carry_mesh_tp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_node("Pivot").add_child(_carry_mesh_tp)

	# For local player: hide TP mesh. For network player: hide FP mesh.
	if player.is_local:
		_carry_mesh_tp.visible = false
	else:
		_carry_mesh_fp.visible = false


func is_carrying() -> bool:
	return _is_carrying


func try_steal_target() -> bool:
	if not _raycast or not _raycast.is_colliding():
		return false

	var collider: Node = _raycast.get_collider()
	if not collider:
		return false

	# Check for placed paintings first
	var placed: Node = _find_placed_painting(collider)
	if placed:
		var url: String = placed.get_meta("image_url")
		var title: String = placed.get_meta("image_title")
		var exhibit: String = placed.get_meta("exhibit_title")
		var size: Vector2 = placed.get_meta("image_size")
		emit_signal("steal_requested", exhibit, title, url, size)
		return true

	# Walk up from collider to find ImageItem
	var image_item: Node = _find_image_item(collider)
	if not image_item:
		return false

	# Check that image is loaded
	if not image_item._image:
		return false

	# Walk up to find WallItem parent
	var wall_item: Node = _find_wall_item(image_item)
	if not wall_item:
		return false

	# Find exhibit title by walking up further
	var exhibit_title: String = _find_exhibit_title(wall_item)
	if exhibit_title == "":
		return false

	var image_size: Vector2 = image_item.get_image_size()
	emit_signal("steal_requested", exhibit_title, image_item.title, image_item.image_url, image_size)
	return true


func try_place_painting() -> bool:
	if not _is_carrying:
		return false

	var camera: Camera3D = _player.camera
	if not camera:
		return false

	# Raycast from camera forward to find a wall
	var space_state: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + (-camera.global_transform.basis.z) * PLACE_RAY_LENGTH

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)  # Layer 1: Static World
	query.exclude = [_player.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return false

	# Check that we hit a roughly vertical surface (wall, not floor/ceiling)
	var normal: Vector3 = result.normal
	if abs(normal.y) > 0.5:
		return false  # Too horizontal — it's a floor or ceiling

	emit_signal("place_requested", _carried_exhibit_title, _carried_image_title, _carried_image_url, result.position, normal, _carried_image_size)
	return true


func execute_steal(texture: Texture2D, url: String, title: String, exhibit_title: String, size: Vector2) -> void:
	_is_carrying = true
	_carried_texture = texture
	_carried_image_url = url
	_carried_image_title = title
	_carried_exhibit_title = exhibit_title
	_carried_image_size = size

	# Apply texture to carry material
	_carry_material.set_shader_parameter("texture_albedo", texture)

	# Scale mesh to match image aspect ratio
	var aspect: float = size.x / size.y if size.y > 0 else 1.0
	if aspect > 1.0:
		_carry_mesh_fp.mesh.size = Vector2(0.3, 0.3 / aspect)
		_carry_mesh_tp.mesh.size = Vector2(0.5, 0.5 / aspect)
	else:
		_carry_mesh_fp.mesh.size = Vector2(0.3 * aspect, 0.3)
		_carry_mesh_tp.mesh.size = Vector2(0.5 * aspect, 0.5)

	# Show appropriate mesh
	if _player.is_local:
		_carry_mesh_fp.visible = true
		_carry_mesh_fp.position = CARRY_FP_POSITION
		_carry_mesh_fp.scale = Vector3.ONE
		# Tween in from below
		var tween: Tween = _player.create_tween()
		_carry_mesh_fp.position.y = CARRY_FP_POSITION.y - 0.3
		tween.tween_property(_carry_mesh_fp, "position:y", CARRY_FP_POSITION.y, 0.2)
	else:
		_carry_mesh_tp.visible = true


func execute_drop() -> void:
	_is_carrying = false
	_carried_texture = null
	_carried_image_url = ""
	_carried_image_title = ""
	_carried_exhibit_title = ""
	_carried_image_size = Vector2.ZERO
	_eat_progress = 0.0
	_eating = false
	if _eat_tween and _eat_tween.is_valid():
		_eat_tween.kill()
	_eat_tween = null
	_carry_mesh_fp.visible = false
	_carry_mesh_tp.visible = false
	_carry_mesh_fp.position = CARRY_FP_POSITION
	_carry_mesh_fp.rotation_degrees = CARRY_ROTATION
	_carry_mesh_tp.position = CARRY_TP_POSITION
	_carry_mesh_tp.rotation_degrees = CARRY_ROTATION


func process_eat(delta: float) -> void:
	if not _is_carrying or not _player.is_local:
		return

	if Input.is_action_pressed("interact") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not _eating:
			_eating = true
			emit_signal("eat_anim_started")
		_eat_progress += delta / EAT_DURATION

		var t: float = clamp(_eat_progress, 0.0, 1.0)
		if t <= EAT_ROTATE_FRACTION:
			# Phase 1: rotate painting parallel with floor
			var rot_t: float = t / EAT_ROTATE_FRACTION
			_carry_mesh_fp.rotation_degrees = CARRY_ROTATION.lerp(EAT_ROTATION, rot_t)
		else:
			# Phase 2: slide into head
			_carry_mesh_fp.rotation_degrees = EAT_ROTATION
			var slide_t: float = (t - EAT_ROTATE_FRACTION) / (1.0 - EAT_ROTATE_FRACTION)
			_carry_mesh_fp.position = CARRY_FP_POSITION.lerp(EAT_FP_TARGET, slide_t)

		if _eat_progress >= 1.0:
			emit_signal("eat_requested", _carried_exhibit_title, _carried_image_title)
			execute_drop()
	elif _eating:
		# Released early — reset
		_eating = false
		_eat_progress = 0.0
		_carry_mesh_fp.position = CARRY_FP_POSITION
		_carry_mesh_fp.rotation_degrees = CARRY_ROTATION
		emit_signal("eat_anim_cancelled")


func show_tp_mesh(is_visible: bool) -> void:
	_carry_mesh_tp.visible = is_visible


func start_eat_tween() -> void:
	if _eat_tween and _eat_tween.is_valid():
		_eat_tween.kill()
	_carry_mesh_tp.position = CARRY_TP_POSITION
	_carry_mesh_tp.rotation_degrees = CARRY_ROTATION
	var rotate_time: float = EAT_DURATION * EAT_ROTATE_FRACTION
	var slide_time: float = EAT_DURATION * (1.0 - EAT_ROTATE_FRACTION)
	_eat_tween = _player.create_tween()
	_eat_tween.tween_property(_carry_mesh_tp, "rotation_degrees", EAT_ROTATION, rotate_time)
	_eat_tween.tween_property(_carry_mesh_tp, "position", EAT_TP_TARGET, slide_time)


func cancel_eat_tween() -> void:
	if _eat_tween and _eat_tween.is_valid():
		_eat_tween.kill()
	_eat_tween = null
	_carry_mesh_tp.position = CARRY_TP_POSITION
	_carry_mesh_tp.rotation_degrees = CARRY_ROTATION


func get_carried_image_url() -> String:
	return _carried_image_url


func get_carried_image_title() -> String:
	return _carried_image_title


func get_carried_exhibit_title() -> String:
	return _carried_exhibit_title


func get_carried_image_size() -> Vector2:
	return _carried_image_size


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _find_image_item(node: Node) -> Node:
	# Check if this node is an ImageItem (has image_url property and _image)
	if "image_url" in node and "_image" in node:
		return node
	# Check parent
	var parent: Node = node.get_parent()
	if parent and "image_url" in parent and "_image" in parent:
		return parent
	# Check grandparent (InteractionBody -> ImageItem)
	if parent:
		var grandparent: Node = parent.get_parent()
		if grandparent and "image_url" in grandparent and "_image" in grandparent:
			return grandparent
	return null


func _find_wall_item(node: Node) -> Node:
	# Walk up to find WallItem (node that has an Item child containing the ImageItem)
	var current: Node = node.get_parent()
	while current:
		# WallItem has an "Item" child that contains the image
		if current.has_node("Item") and current.has_node("Ceiling"):
			return current
		current = current.get_parent()
	return null


func _find_placed_painting(collider: Node) -> Node:
	# Walk up from collider to find a placed painting node
	var current: Node = collider
	while current:
		if current.has_meta("is_placed_painting"):
			return current
		current = current.get_parent()
	return null


func _find_exhibit_title(node: Node) -> String:
	# Walk up to find the exhibit node (direct child of Museum)
	var exhibit_node: Node = null
	var current: Node = node.get_parent()
	while current:
		if current.get_parent() and current.get_parent().name == "Museum":
			exhibit_node = current
			break
		current = current.get_parent()

	if not exhibit_node:
		return ""

	# Look up the exhibit title from Museum's _exhibits dictionary
	var museum: Node = exhibit_node.get_parent()
	if "_exhibits" in museum:
		var exhibits: Dictionary = museum._exhibits
		for title: String in exhibits:
			if exhibits[title].has("exhibit") and exhibits[title].exhibit == exhibit_node:
				return title

	return ""
