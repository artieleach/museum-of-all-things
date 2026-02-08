extends Node
class_name PlayerPointingSystem
## Subsystem for pointing beam and floating reaction emotes.

signal reaction_fired(reaction_index: int, point_target: Vector3)

const BEAM_LENGTH: float = 100.0
const BEAM_COLOR: Color = Color(1.0, 1.0, 0.7, 0.85)
const HIGHLIGHT_ENERGY: float = 1.5
const HIGHLIGHT_RANGE: float = 3.0
const RAY_COLLISION_MASK: int = 0xFFFFFFFF

var _player: CharacterBody3D = null
var _beam_mesh: MeshInstance3D = null
var _highlight_light: OmniLight3D = null
var _endpoint_dot: MeshInstance3D = null

var is_pointing: bool = false
var point_target: Vector3 = Vector3.ZERO

var _reaction_index: int = -1
const REACTION_NAMES: Array[String] = ["!", "?", "star", "heart"]


func init(player: CharacterBody3D) -> void:
	_player = player

	# Create beam mesh (thin cylinder laser pointer)
	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.visible = false
	_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = BEAM_COLOR
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.7)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	_beam_mesh.material_override = mat
	player.add_child(_beam_mesh)

	# Create highlight light at beam end
	_highlight_light = OmniLight3D.new()
	_highlight_light.light_energy = HIGHLIGHT_ENERGY
	_highlight_light.omni_range = HIGHLIGHT_RANGE
	_highlight_light.light_color = Color(1.0, 1.0, 0.8)
	_highlight_light.visible = false
	_highlight_light.shadow_enabled = false
	player.add_child(_highlight_light)

	# Create endpoint dot (small glowing sphere)
	_endpoint_dot = MeshInstance3D.new()
	_endpoint_dot.visible = false
	_endpoint_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dot_mesh: SphereMesh = SphereMesh.new()
	dot_mesh.radius = 0.02
	dot_mesh.height = 0.04
	_endpoint_dot.mesh = dot_mesh
	var dot_mat: StandardMaterial3D = StandardMaterial3D.new()
	dot_mat.albedo_color = Color(1.0, 1.0, 0.7)
	dot_mat.emission_enabled = true
	dot_mat.emission = Color(1.0, 1.0, 0.7)
	dot_mat.emission_energy_multiplier = 6.0
	dot_mat.no_depth_test = true
	_endpoint_dot.material_override = dot_mat
	player.add_child(_endpoint_dot)


func process_pointing() -> void:
	if not _player or not _player.is_local:
		return

	var pointing_now: bool = Input.is_action_pressed("point") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if pointing_now != is_pointing:
		is_pointing = pointing_now
		_beam_mesh.visible = is_pointing
		_highlight_light.visible = is_pointing
		_endpoint_dot.visible = is_pointing

	if not is_pointing:
		_reaction_index = -1
		return

	# Raycast using physics space query for long-range detection
	var camera: Camera3D = _player.camera
	var from: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	var end: Vector3

	var space_state: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + forward * BEAM_LENGTH, RAY_COLLISION_MASK, [_player.get_rid()]
	)
	var result: Dictionary = space_state.intersect_ray(query)

	if not result.is_empty():
		end = result["position"]
		point_target = end
	else:
		end = from + forward * BEAM_LENGTH
		point_target = end

	_update_beam(from, end)
	_highlight_light.global_position = end
	_endpoint_dot.global_position = end

	# Direct reaction keys 1-4
	for i: int in REACTION_NAMES.size():
		if Input.is_action_just_pressed("reaction_%d" % (i + 1)):
			_reaction_index = i
			_fire_reaction()
			break


func _fire_reaction() -> void:
	if _reaction_index >= 0:
		reaction_fired.emit(_reaction_index, point_target)


func _update_beam(from: Vector3, to: Vector3) -> void:
	var direction: Vector3 = to - from
	var length: float = direction.length()
	if length < 0.01:
		_beam_mesh.visible = false
		return

	# Create a thin cylinder mesh for the beam
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.002
	cylinder.bottom_radius = 0.002
	cylinder.height = length
	_beam_mesh.mesh = cylinder

	# Position at midpoint, orient along direction
	_beam_mesh.global_position = (from + to) / 2.0
	_beam_mesh.look_at(to, Vector3.UP)
	_beam_mesh.rotate_object_local(Vector3.RIGHT, PI / 2.0)


func apply_network_pointing(pointing: bool, target: Vector3) -> void:
	## Apply pointing state from network sync for remote players.
	is_pointing = pointing
	point_target = target
	_beam_mesh.visible = pointing
	_highlight_light.visible = pointing
	_endpoint_dot.visible = pointing

	if pointing and _player:
		var from: Vector3 = _player.global_position + Vector3.UP * 1.5
		_update_beam(from, target)
		_highlight_light.global_position = target
		_endpoint_dot.global_position = target
