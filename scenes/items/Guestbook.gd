extends StaticBody3D
class_name Guestbook
## Interactable guestbook pedestal for leaving short messages.

signal guestbook_opened(exhibit_title: String)

var _exhibit_title: String = ""


func _ready() -> void:
	collision_layer = 1 | (1 << 20)  # Layer 1 + Layer 21 (Pointable)

	# Visual: a pedestal with a book on top
	var pedestal_mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.5, 1.0, 0.5)
	pedestal_mesh.mesh = box
	pedestal_mesh.position.y = 0.5
	var ped_mat: StandardMaterial3D = StandardMaterial3D.new()
	ped_mat.albedo_color = Color(0.6, 0.55, 0.45)
	pedestal_mesh.material_override = ped_mat
	add_child(pedestal_mesh)

	# Book on top
	var book_mesh: MeshInstance3D = MeshInstance3D.new()
	var book_box: BoxMesh = BoxMesh.new()
	book_box.size = Vector3(0.35, 0.06, 0.25)
	book_mesh.mesh = book_box
	book_mesh.position.y = 1.03
	var book_mat: StandardMaterial3D = StandardMaterial3D.new()
	book_mat.albedo_color = Color(0.4, 0.25, 0.15)
	book_mesh.material_override = book_mat
	add_child(book_mesh)

	# Label
	var label: Label3D = Label3D.new()
	label.text = "Guestbook"
	label.font_size = 32
	label.position = Vector3(0, 1.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.95, 0.85)
	add_child(label)

	# Collision
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.5, 1.1, 0.5)
	col.shape = shape
	col.position.y = 0.55
	add_child(col)


func init_exhibit(title: String) -> void:
	_exhibit_title = title


func interact() -> void:
	guestbook_opened.emit(_exhibit_title)
