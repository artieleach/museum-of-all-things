extends Node
class_name PaintingController
## Handles painting steal/place/eat request processing and RPC synchronization across peers.

var _main: Node = null
var _multiplayer_controller: MultiplayerController = null

# Server state
var _carry_state: Dictionary = {}      # peer_id -> { exhibit_title, image_title, image_url, image_size }
var _stolen_paintings: Dictionary = {}  # "exhibit_title:image_title" -> peer_id
var _placed_paintings: Array[Node] = []  # Tracked placed painting nodes


func init(main: Node, multiplayer_controller: MultiplayerController) -> void:
	_main = main
	_multiplayer_controller = multiplayer_controller


# =============================================================================
# STEAL
# =============================================================================

func request_steal(exhibit_title: String, image_title: String, image_url: String, image_size: Vector2, local_player: Node) -> void:
	if not _multiplayer_controller.is_multiplayer_game() or not NetworkManager.is_multiplayer_active():
		# Singleplayer — execute directly
		_execute_steal_local(exhibit_title, image_title, image_url, image_size, local_player)
		return

	var peer_id: int = NetworkManager.get_unique_id()
	if NetworkManager.is_server():
		handle_steal_request(peer_id, exhibit_title, image_title, image_url, image_size, local_player)
	else:
		_main._request_steal_painting_rpc.rpc_id(1, peer_id, exhibit_title, image_title, image_url, image_size)


func handle_steal_request(peer_id: int, exhibit_title: String, image_title: String, image_url: String, image_size: Vector2, local_player: Node) -> void:
	# Server-side validation
	var painting_key: String = exhibit_title + ":" + image_title
	if _stolen_paintings.has(painting_key):
		return  # Already stolen
	if _carry_state.has(peer_id):
		return  # Already carrying

	# Record state
	_carry_state[peer_id] = {
		"exhibit_title": exhibit_title,
		"image_title": image_title,
		"image_url": image_url,
		"image_size": image_size
	}
	_stolen_paintings[painting_key] = peer_id

	# Execute on server
	_apply_steal(peer_id, exhibit_title, image_title, image_url, image_size, local_player)

	# Broadcast to all clients
	_main._execute_steal_sync.rpc(peer_id, exhibit_title, image_title, image_url, image_size)


func execute_steal_sync(peer_id: int, exhibit_title: String, image_title: String, image_url: String, image_size: Vector2, local_player: Node) -> void:
	if NetworkManager.is_server():
		return  # Already done
	_apply_steal(peer_id, exhibit_title, image_title, image_url, image_size, local_player)


func _apply_steal(peer_id: int, exhibit_title: String, image_title: String, image_url: String, image_size: Vector2, local_player: Node) -> void:
	var texture: Texture2D = null

	# Check for a placed painting first, then fall back to WallItem
	var placed: Node = _find_and_remove_placed_painting(image_title)
	if placed:
		var mat: ShaderMaterial = placed.material_override as ShaderMaterial
		if mat:
			texture = mat.get_shader_parameter("texture_albedo")
		placed.queue_free()
	else:
		var wall_item: Node = _find_wall_item_by_image_title(exhibit_title, image_title)
		if wall_item:
			wall_item.set_stolen(true)
			var image_item: Node = wall_item.get_image_item()
			if image_item and "_image" in image_item:
				texture = image_item._image

	# Apply carry visual to the player
	var player: Node = _multiplayer_controller.get_player_by_peer_id(peer_id, local_player)
	if not is_instance_valid(player):
		return

	if "_painting_system" in player and player._painting_system:
		player._painting_system.execute_steal(texture, image_url, image_title, exhibit_title, image_size)


func _execute_steal_local(exhibit_title: String, image_title: String, image_url: String, image_size: Vector2, local_player: Node) -> void:
	# Singleplayer path
	var painting_key: String = exhibit_title + ":" + image_title
	_stolen_paintings[painting_key] = 0
	_carry_state[0] = {
		"exhibit_title": exhibit_title,
		"image_title": image_title,
		"image_url": image_url,
		"image_size": image_size
	}

	var texture: Texture2D = null
	var placed: Node = _find_and_remove_placed_painting(image_title)
	if placed:
		var mat: ShaderMaterial = placed.material_override as ShaderMaterial
		if mat:
			texture = mat.get_shader_parameter("texture_albedo")
		placed.queue_free()
	else:
		var wall_item: Node = _find_wall_item_by_image_title(exhibit_title, image_title)
		if wall_item:
			wall_item.set_stolen(true)
			var image_item: Node = wall_item.get_image_item()
			if image_item and "_image" in image_item:
				texture = image_item._image

	if "_painting_system" in local_player and local_player._painting_system:
		local_player._painting_system.execute_steal(texture, image_url, image_title, exhibit_title, image_size)


# =============================================================================
# PLACE
# =============================================================================

func request_place(exhibit_title: String, image_title: String, image_url: String, wall_position: Vector3, wall_normal: Vector3, image_size: Vector2, local_player: Node) -> void:
	if not _multiplayer_controller.is_multiplayer_game() or not NetworkManager.is_multiplayer_active():
		_execute_place_local(exhibit_title, image_title, image_url, wall_position, wall_normal, image_size, local_player)
		return

	var peer_id: int = NetworkManager.get_unique_id()
	if NetworkManager.is_server():
		handle_place_request(peer_id, exhibit_title, image_title, image_url, wall_position, wall_normal, image_size, local_player)
	else:
		_main._request_place_painting_rpc.rpc_id(1, peer_id, exhibit_title, image_title, image_url, wall_position, wall_normal, image_size)


func handle_place_request(peer_id: int, exhibit_title: String, image_title: String, image_url: String, wall_position: Vector3, wall_normal: Vector3, image_size: Vector2, local_player: Node) -> void:
	if not _carry_state.has(peer_id):
		return  # Not carrying

	var state: Dictionary = _carry_state[peer_id]
	var painting_key: String = state.exhibit_title + ":" + state.image_title
	_stolen_paintings.erase(painting_key)
	_carry_state.erase(peer_id)

	_apply_place(peer_id, exhibit_title, image_title, image_url, wall_position, wall_normal, image_size, local_player)
	_main._execute_place_sync.rpc(peer_id, exhibit_title, image_title, image_url, wall_position, wall_normal, image_size)


func execute_place_sync(peer_id: int, exhibit_title: String, image_title: String, image_url: String, wall_position: Vector3, wall_normal: Vector3, image_size: Vector2, local_player: Node) -> void:
	if NetworkManager.is_server():
		return
	_apply_place(peer_id, exhibit_title, image_title, image_url, wall_position, wall_normal, image_size, local_player)


func _apply_place(peer_id: int, exhibit_title: String, image_title: String, image_url: String, wall_position: Vector3, wall_normal: Vector3, image_size: Vector2, local_player: Node) -> void:
	# Get texture from player before dropping
	var texture: Texture2D = null
	var player: Node = _multiplayer_controller.get_player_by_peer_id(peer_id, local_player)
	if is_instance_valid(player) and "_painting_system" in player and player._painting_system:
		texture = player._painting_system._carried_texture
		player._painting_system.execute_drop()

	_create_placed_painting(wall_position, wall_normal, image_size, texture, exhibit_title, image_title, image_url)


func _execute_place_local(exhibit_title: String, image_title: String, image_url: String, wall_position: Vector3, wall_normal: Vector3, image_size: Vector2, local_player: Node) -> void:
	var texture: Texture2D = null
	if "_painting_system" in local_player and local_player._painting_system:
		texture = local_player._painting_system._carried_texture

	if _carry_state.has(0):
		var state: Dictionary = _carry_state[0]
		var painting_key: String = state.exhibit_title + ":" + state.image_title
		_stolen_paintings.erase(painting_key)
		_carry_state.erase(0)

	_create_placed_painting(wall_position, wall_normal, image_size, texture, exhibit_title, image_title, image_url)

	if "_painting_system" in local_player and local_player._painting_system:
		local_player._painting_system.execute_drop()


func _create_placed_painting(wall_position: Vector3, wall_normal: Vector3, image_size: Vector2, texture: Texture2D, exhibit_title: String, image_title: String, image_url: String) -> void:
	var painting: MeshInstance3D = MeshInstance3D.new()
	painting.name = "PlacedPainting"
	var plane_mesh: PlaneMesh = PlaneMesh.new()

	# Scale to match aspect ratio
	var aspect: float = image_size.x / image_size.y if image_size.y > 0 else 1.0
	var width: float
	var height: float
	if aspect > 1.0:
		width = 1.5
		height = 1.5 / aspect
	else:
		width = 1.5 * aspect
		height = 1.5
	plane_mesh.size = Vector2(width, height)

	painting.mesh = plane_mesh

	var material: ShaderMaterial = preload("res://assets/textures/image_item.tres").duplicate()
	painting.material_override = material

	# Apply texture immediately if available, otherwise request it
	if texture:
		material.set_shader_parameter("texture_albedo", texture)
	else:
		var cb: Callable = _on_placed_painting_image_loaded.bind(painting, material, image_url)
		DataManager.loaded_image.connect(cb)
		DataManager.request_image(image_url)

	painting.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Add picture frame
	var frame_mesh: ArrayMesh = preload("res://assets/models/frame.obj")
	var frame_material: Material = preload("res://assets/textures/black.tres")
	var frame: MeshInstance3D = MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = frame_mesh
	frame.material_override = frame_material
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Frame model is sized for 2.0-unit images; placed paintings use 1.5 max
	var frame_scale: float = 0.75
	frame.scale = Vector3(frame_scale, frame_scale, frame_scale)
	# Adjust frame scale for aspect ratio (same logic as WallItem._on_image_item_loaded)
	if aspect > 1.0:
		frame.scale.y *= 1.0 / aspect
	else:
		frame.scale.x *= aspect
	# Rotate frame so it faces +Y (wall normal) instead of its default +Z
	frame.rotation_degrees = Vector3(-90, 0, 0)
	# Position frame slightly in front of the painting surface (local +Y = wall normal)
	frame.position = Vector3(0, 0.03, 0)
	painting.add_child(frame)

	# Store metadata for re-stealing
	painting.set_meta("is_placed_painting", true)
	painting.set_meta("exhibit_title", exhibit_title)
	painting.set_meta("image_title", image_title)
	painting.set_meta("image_url", image_url)
	painting.set_meta("image_size", image_size)

	# Add collision body so raycast can hit it (Layer 21 = Pointable Objects = 1048576)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1048576
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, 0.1, height)
	shape.shape = box
	body.add_child(shape)
	painting.add_child(body)

	_main.add_child(painting)
	_placed_paintings.append(painting)

	# Position off the wall enough for the frame to clear
	painting.global_position = wall_position + wall_normal * 0.06

	# Orient so PlaneMesh lies flat against wall (PlaneMesh face normal is +Y)
	var y_axis: Vector3 = wall_normal
	var x_axis: Vector3
	if abs(wall_normal.dot(Vector3.UP)) > 0.9:
		x_axis = Vector3.FORWARD.cross(wall_normal).normalized()
	else:
		x_axis = Vector3.UP.cross(wall_normal).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis)
	painting.basis = Basis(x_axis, y_axis, z_axis)


func _on_placed_painting_image_loaded(url: String, image: Texture2D, _ctx: Variant, painting: MeshInstance3D, material: ShaderMaterial, target_url: String) -> void:
	if url != Util.normalize_url(target_url):
		return
	if is_instance_valid(painting) and is_instance_valid(material):
		material.set_shader_parameter("texture_albedo", image)
	DataManager.loaded_image.disconnect(_on_placed_painting_image_loaded.bind(painting, material, target_url))


# =============================================================================
# EAT
# =============================================================================

func request_eat(exhibit_title: String, image_title: String, local_player: Node) -> void:
	if not _multiplayer_controller.is_multiplayer_game() or not NetworkManager.is_multiplayer_active():
		_execute_eat_local(exhibit_title, image_title, local_player)
		return

	var peer_id: int = NetworkManager.get_unique_id()
	if NetworkManager.is_server():
		handle_eat_request(peer_id, exhibit_title, image_title, local_player)
	else:
		_main._request_eat_painting_rpc.rpc_id(1, peer_id, exhibit_title, image_title)


func handle_eat_request(peer_id: int, exhibit_title: String, image_title: String, local_player: Node) -> void:
	if not _carry_state.has(peer_id):
		return

	var state: Dictionary = _carry_state[peer_id]
	var painting_key: String = state.exhibit_title + ":" + state.image_title
	_stolen_paintings.erase(painting_key)
	_carry_state.erase(peer_id)

	_apply_eat(peer_id, local_player)
	_main._execute_eat_sync.rpc(peer_id)


func execute_eat_sync(peer_id: int, local_player: Node) -> void:
	if NetworkManager.is_server():
		return
	_apply_eat(peer_id, local_player)


func _apply_eat(peer_id: int, local_player: Node) -> void:
	var player: Node = _multiplayer_controller.get_player_by_peer_id(peer_id, local_player)
	if is_instance_valid(player) and "_painting_system" in player and player._painting_system:
		# For network players, tween the TP mesh to zero then drop
		if not player.is_local:
			var tp_mesh: MeshInstance3D = player._painting_system._carry_mesh_tp
			if is_instance_valid(tp_mesh) and tp_mesh.visible:
				var tween: Tween = player.create_tween()
				tween.tween_property(tp_mesh, "scale", Vector3.ZERO, 0.5)
				tween.tween_callback(player._painting_system.execute_drop)
				return
		player._painting_system.execute_drop()


func _execute_eat_local(exhibit_title: String, image_title: String, local_player: Node) -> void:
	if _carry_state.has(0):
		var state: Dictionary = _carry_state[0]
		var painting_key: String = state.exhibit_title + ":" + state.image_title
		_stolen_paintings.erase(painting_key)
		_carry_state.erase(0)

	if "_painting_system" in local_player and local_player._painting_system:
		local_player._painting_system.execute_drop()


# =============================================================================
# DISCONNECT HANDLING
# =============================================================================

func on_player_disconnected(peer_id: int, local_player: Node) -> void:
	if not _carry_state.has(peer_id):
		return

	var state: Dictionary = _carry_state[peer_id]
	var painting_key: String = state.exhibit_title + ":" + state.image_title

	# Restore the painting on the wall
	var wall_item: Node = _find_wall_item_by_image_title(state.exhibit_title, state.image_title)
	if wall_item:
		wall_item.set_stolen(false)

	_stolen_paintings.erase(painting_key)
	_carry_state.erase(peer_id)


# =============================================================================
# HELPERS
# =============================================================================

func _find_and_remove_placed_painting(image_title: String) -> Node:
	for i: int in range(_placed_paintings.size() - 1, -1, -1):
		var p: Node = _placed_paintings[i]
		if not is_instance_valid(p):
			_placed_paintings.remove_at(i)
			continue
		if p.has_meta("image_title") and p.get_meta("image_title") == image_title:
			_placed_paintings.remove_at(i)
			return p
	return null


func _find_wall_item_by_image_title(exhibit_title: String, image_title: String) -> Node:
	if not _main.has_node("Museum"):
		return null

	var museum: Node = _main.get_node("Museum")

	# Search through exhibit's children for WallItems containing the matching ImageItem
	for child: Node in museum.get_children():
		# Check if this child could be the exhibit (match by name or iterate all)
		for wall_item: Node in child.get_children():
			if wall_item.has_method("get_image_item"):
				var image_item: Node = wall_item.get_image_item()
				if image_item and "title" in image_item and image_item.title == image_title:
					return wall_item

	return null
