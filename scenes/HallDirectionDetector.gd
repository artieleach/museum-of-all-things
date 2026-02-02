extends Area3D

signal direction_changed(direction: String)

@export var project_dir: float = 2.0
@onready var _xr = Platform.is_xr()

var point_a: Vector3
var point_b: Vector3
var player_velocity: Vector3
var previous_direction: String
var player

func init(entry: Vector3, exit: Vector3):
	point_a = entry
	point_b = exit
	previous_direction = ""
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player") and _is_local_player(body):
		player = body if not _xr else body.get_parent().get_node("XRCamera3D")

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player") and _is_local_player(body):
		player = null

func _is_local_player(body: Node) -> bool:
	# In single player, all players are local
	if not NetworkManager.is_multiplayer_active():
		return true
	# Check for is_local property
	if "is_local" in body:
		return body.is_local
	return true

func _xz(v):
	return Vector2(v.x, v.z)

func _process(_delta: float) -> void:
	if player:
		var player_facing = -player.global_transform.basis.z.normalized()
		var p = _xz(player.global_position + player_facing * project_dir)
		var distance_to_a = _xz(point_a) - p
		var distance_to_b = _xz(point_b) - p

		var direction = "exit" if distance_to_b.length() < distance_to_a.length() else "entry"

		if direction != previous_direction:
			emit_signal("direction_changed", direction)
			previous_direction = direction
