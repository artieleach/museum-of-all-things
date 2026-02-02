@tool
extends Node3D

const material_black: Material = preload("res://assets/textures/black.tres")
const pole_mesh: Mesh = preload("res://assets/models/railing_pole.obj")

@export var railing_length: float = 4.0

var multimesh_instance: MultiMeshInstance3D

func _ready() -> void:
	multimesh_instance = MultiMeshInstance3D.new()
	pole_mesh.surface_set_material(0, material_black)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = int(railing_length) + 1
	multimesh.mesh = pole_mesh
	multimesh_instance.multimesh = multimesh
	add_child(multimesh_instance)

	var collision_shape: BoxShape3D = BoxShape3D.new()
	collision_shape.size = Vector3(railing_length + 0.1, 1.1, 0.1)

	$Railing.scale.x = railing_length + 0.1
	$StaticBody3D/CollisionShape3D.shape = collision_shape

	for i: int in range(0, int(railing_length) + 1, 1):
		var tform: Transform3D = Transform3D()
		var x_offset: float = -railing_length / 2.0 + i
		tform.origin = Vector3(x_offset, 0, 0)

		multimesh.set_instance_transform(i, tform)
