extends Area3D
## Detects which direction (entry/exit) the player is facing within a hall.

signal direction_changed(direction: String)

@export var project_dir: float = 2.0

@onready var _xr: bool = Platform.is_xr()

var _point_a: Vector3 = Vector3.ZERO
var _point_b: Vector3 = Vector3.ZERO
var _previous_direction: String = ""
var player: Node3D = null


func init(entry: Vector3, exit: Vector3) -> void:
	_point_a = entry
	_point_b = exit
	_previous_direction = ""
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


func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _process(_delta: float) -> void:
	if player:
		var player_facing: Vector3 = -player.global_transform.basis.z.normalized()
		var p: Vector2 = _xz(player.global_position + player_facing * project_dir)
		var distance_to_a: Vector2 = _xz(_point_a) - p
		var distance_to_b: Vector2 = _xz(_point_b) - p

		var direction: String = "exit" if distance_to_b.length() < distance_to_a.length() else "entry"

		if direction != _previous_direction:
			emit_signal("direction_changed", direction)
			_previous_direction = direction
