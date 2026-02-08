extends Node3D
class_name GhostSilhouette
## Translucent silhouette showing where someone stood still for 30+ seconds.

const VISIBILITY_RANGE: float = 30.0


func _ready() -> void:
	# Capsule mesh for silhouette
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.6
	mesh.mesh = capsule
	mesh.position.y = 0.8

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.7, 1.0, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.5, 0.9)
	mat.emission_energy_multiplier = 0.5
	mat.no_depth_test = false
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end = VISIBILITY_RANGE
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mesh)

	# Subtle breathing animation
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(mesh, "scale:y", 1.02, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mesh, "scale:y", 0.98, 2.0).set_trans(Tween.TRANS_SINE)


static func spawn_from_data(parent: Node3D, ghost_data: Dictionary) -> GhostSilhouette:
	var ghost: GhostSilhouette = GhostSilhouette.new()
	ghost.position = Vector3(ghost_data.get("x", 0), ghost_data.get("y", 0), ghost_data.get("z", 0))
	ghost.rotation.y = ghost_data.get("rot_y", 0)
	parent.add_child(ghost)
	return ghost
