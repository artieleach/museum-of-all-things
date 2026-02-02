extends Node
class_name PlayerSkinSystem
## Handles player skin loading and application: URL-based textures and shader configuration.

var _player: CharacterBody3D = null
var skin_url: String = ""
var _skin_texture: ImageTexture = null


func init(player: CharacterBody3D) -> void:
	_player = player


func set_player_skin(url: String, texture: ImageTexture = null) -> void:
	skin_url = url
	if texture:
		_apply_skin_texture(texture)
	elif url != "":
		# Request texture via DataManager
		if not DataManager.loaded_image.is_connected(_on_skin_image_loaded):
			DataManager.loaded_image.connect(_on_skin_image_loaded)
		DataManager.request_image(url)


func _on_skin_image_loaded(url: String, texture: ImageTexture, _ctx: Variant) -> void:
	if url != skin_url:
		return
	DataManager.loaded_image.disconnect(_on_skin_image_loaded)
	_apply_skin_texture(texture)


func _apply_skin_texture(texture: ImageTexture) -> void:
	_skin_texture = texture
	if not _player or not _player.has_node("BodyMesh"):
		return

	var mesh_instance: MeshInstance3D = _player.get_node("BodyMesh") as MeshInstance3D
	var material: Material = mesh_instance.get_surface_override_material(0)
	if material and material is ShaderMaterial:
		var shader_mat: ShaderMaterial = material.duplicate() as ShaderMaterial
		shader_mat.set_shader_parameter("texture_albedo", texture)
		shader_mat.set_shader_parameter("has_texture", true)
		mesh_instance.set_surface_override_material(0, shader_mat)


func clear_player_skin() -> void:
	skin_url = ""
	_skin_texture = null
	if not _player or not _player.has_node("BodyMesh"):
		return

	var mesh_instance: MeshInstance3D = _player.get_node("BodyMesh") as MeshInstance3D
	var material: Material = mesh_instance.get_surface_override_material(0)
	if material and material is ShaderMaterial:
		var shader_mat: ShaderMaterial = material.duplicate() as ShaderMaterial
		shader_mat.set_shader_parameter("has_texture", false)
		mesh_instance.set_surface_override_material(0, shader_mat)


func get_skin_url() -> String:
	return skin_url


func get_skin_texture() -> ImageTexture:
	return _skin_texture
