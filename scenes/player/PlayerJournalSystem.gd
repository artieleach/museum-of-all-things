extends Node
class_name PlayerJournalSystem
## Subsystem for pinning items to the explorer's journal via raycast.

var _player: CharacterBody3D = null
var _raycast: RayCast3D = null


func init(player: CharacterBody3D) -> void:
	_player = player
	_raycast = player.get_node("Pivot/Camera3D/RayCast3D")


func try_pin_item() -> void:
	if not _player or not _player.is_local:
		return
	if not _raycast or not _raycast.is_colliding():
		return

	var collider: Node = _raycast.get_collider()
	if not collider:
		return

	# Check if the collider or its parent is an image or text item
	var item: Node = _find_pinnable_item(collider)
	if not item:
		return

	var exhibit_title: String = _player.current_room
	if exhibit_title == "Lobby":
		return

	if item.has_method("get_image_url") and item.get_image_url() != "":
		JournalManager.pin_item(exhibit_title, "image", {
			"url": item.get_image_url(),
			"caption": item.get_image_title() if item.has_method("get_image_title") else "",
		})
	elif item.has_method("get_text_content"):
		JournalManager.pin_item(exhibit_title, "text", {
			"excerpt": item.get_text_content(),
		})


func _find_pinnable_item(node: Node) -> Node:
	# Check node and parent chain for pinnable item
	var check: Node = node
	for _i: int in 3:
		if not check:
			break
		if check.has_method("get_image_url") or check.has_method("get_text_content"):
			return check
		check = check.get_parent()
	return null
