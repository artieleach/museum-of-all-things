extends StaticBody3D
class_name SecretWall
## Interactable cracked wall that slides open to reveal a secret room.

signal opened

var _is_open: bool = false
var _slide_dir: Vector3 = Vector3.RIGHT
var _original_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	_original_pos = position
	collision_layer = 1 | (1 << 20)  # Layer 1 (Static World) + Layer 21 (Pointable)

	# Visual: slightly different colored wall to hint at secret
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(3.8, 3.6, 0.4)
	mesh.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.5, 0.45)
	mesh.material_override = mat
	add_child(mesh)

	# Collision shape
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.8, 3.6, 0.4)
	col.shape = shape
	add_child(col)


func init(slide_direction: Vector3) -> void:
	_slide_dir = slide_direction.normalized()


func interact() -> void:
	if _is_open:
		return
	_is_open = true

	# Slide the wall open
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", _original_pos + _slide_dir * 4.0, 1.5)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Dust particles
	var particles: GPUParticles3D = GPUParticles3D.new()
	var proc_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc_mat.direction = Vector3(0, 1, 0)
	proc_mat.spread = 45.0
	proc_mat.initial_velocity_min = 0.5
	proc_mat.initial_velocity_max = 1.5
	proc_mat.gravity = Vector3(0, -2, 0)
	proc_mat.color = Color(0.7, 0.65, 0.5, 0.6)
	particles.process_material = proc_mat
	particles.amount = 30
	particles.lifetime = 2.0
	particles.one_shot = true
	particles.emitting = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	particles.draw_pass_1 = quad
	add_child(particles)

	# Clean up particles after emission
	get_tree().create_timer(3.0).timeout.connect(particles.queue_free)

	opened.emit()
