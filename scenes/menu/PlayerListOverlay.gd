extends Control

@onready var player_container = $PanelContainer/MarginContainer/VBoxContainer/PlayerListContainer

func _ready() -> void:
	NetworkManager.peer_connected.connect(_refresh)
	NetworkManager.peer_disconnected.connect(_refresh)
	NetworkManager.player_info_updated.connect(_refresh)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		_refresh()

func _refresh(_id: Variant = null) -> void:
	if not is_inside_tree():
		return

	for child in player_container.get_children():
		child.queue_free()

	for peer_id in NetworkManager.get_player_list():
		var label = Label.new()
		var player_name = NetworkManager.get_player_name(peer_id)
		var suffix = " (Host)" if peer_id == 1 else ""
		var you = " (You)" if peer_id == NetworkManager.get_unique_id() else ""
		label.text = player_name + suffix + you
		label.add_theme_color_override("font_color", NetworkManager.get_player_color(peer_id))
		player_container.add_child(label)
