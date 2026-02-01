extends Control

signal back
signal start_game

enum MenuState { MAIN, HOST, JOIN, LOBBY }

var current_state: MenuState = MenuState.MAIN

@onready var main_container = $MarginContainer/MainContainer
@onready var host_container = $MarginContainer/HostContainer
@onready var join_container = $MarginContainer/JoinContainer
@onready var lobby_container = $MarginContainer/LobbyContainer

@onready var host_port_input = $MarginContainer/HostContainer/PortInput
@onready var host_name_input = $MarginContainer/HostContainer/NameInput
@onready var host_color_picker = $MarginContainer/HostContainer/ColorPicker
@onready var join_address_input = $MarginContainer/JoinContainer/AddressInput
@onready var join_port_input = $MarginContainer/JoinContainer/PortInput
@onready var join_name_input = $MarginContainer/JoinContainer/NameInput
@onready var join_color_picker = $MarginContainer/JoinContainer/ColorPicker
@onready var player_list = $MarginContainer/LobbyContainer/PlayerList
@onready var lobby_title = $MarginContainer/LobbyContainer/Title
@onready var start_button = $MarginContainer/LobbyContainer/Start
@onready var error_label = $MarginContainer/ErrorLabel

func _ready() -> void:
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	_show_state(MenuState.MAIN)

func _on_visibility_changed() -> void:
	if visible:
		_show_state(MenuState.MAIN)
		error_label.visible = false
		$MarginContainer/MainContainer/Host.grab_focus()

func _show_state(state: MenuState) -> void:
	current_state = state
	main_container.visible = state == MenuState.MAIN
	host_container.visible = state == MenuState.HOST
	join_container.visible = state == MenuState.JOIN
	lobby_container.visible = state == MenuState.LOBBY
	error_label.visible = false

	match state:
		MenuState.MAIN:
			$MarginContainer/MainContainer/Host.grab_focus()
		MenuState.HOST:
			host_name_input.grab_focus()
		MenuState.JOIN:
			join_name_input.grab_focus()
		MenuState.LOBBY:
			if NetworkManager.is_server():
				start_button.grab_focus()
			else:
				$MarginContainer/LobbyContainer/Leave.grab_focus()

func _show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = true

func _update_player_list() -> void:
	player_list.clear()
	for peer_id in NetworkManager.get_player_list():
		var player_name = NetworkManager.get_player_name(peer_id)
		var suffix = " (Host)" if peer_id == 1 else ""
		var you_suffix = " (You)" if peer_id == NetworkManager.get_unique_id() else ""
		player_list.add_item(player_name + suffix + you_suffix)

# Main menu buttons
func _on_host_pressed() -> void:
	_show_state(MenuState.HOST)
	host_port_input.text = str(NetworkManager.DEFAULT_PORT)
	host_name_input.text = "Host"

func _on_join_pressed() -> void:
	_show_state(MenuState.JOIN)
	join_address_input.text = "frogwizard.online"
	join_port_input.text = str(NetworkManager.DEFAULT_PORT)
	join_name_input.text = "Player"

func _on_back_pressed() -> void:
	if current_state == MenuState.MAIN:
		emit_signal("back")
	else:
		_show_state(MenuState.MAIN)

# Host menu buttons
func _on_host_start_pressed() -> void:
	var port = int(host_port_input.text)
	if port <= 0 or port > 65535:
		_show_error("Invalid port number")
		return

	NetworkManager.set_local_player_name(host_name_input.text)
	NetworkManager.set_local_player_color(host_color_picker.color)
	var error = NetworkManager.host_game(port)
	if error != OK:
		_show_error("Failed to start server: " + str(error))
		return

	lobby_title.text = "Lobby (Hosting)"
	start_button.visible = true
	_update_player_list()
	_show_state(MenuState.LOBBY)

func _on_host_back_pressed() -> void:
	_show_state(MenuState.MAIN)

# Join menu buttons
func _on_join_connect_pressed() -> void:
	var address = join_address_input.text
	var port = int(join_port_input.text)

	if address.is_empty():
		_show_error("Please enter an address")
		return

	if port <= 0 or port > 65535:
		_show_error("Invalid port number")
		return

	NetworkManager.set_local_player_name(join_name_input.text)
	NetworkManager.set_local_player_color(join_color_picker.color)
	var error = NetworkManager.join_game(address, port)
	if error != OK:
		_show_error("Failed to connect: " + str(error))
		return

	# Wait for connection result - will be handled by signals

func _on_join_back_pressed() -> void:
	_show_state(MenuState.MAIN)

# Lobby buttons
func _on_lobby_start_pressed() -> void:
	if NetworkManager.is_server():
		_start_multiplayer_game.rpc()

func _on_lobby_leave_pressed() -> void:
	NetworkManager.disconnect_from_game()
	_show_state(MenuState.MAIN)

# Network callbacks
func _on_peer_connected(_id: int) -> void:
	_update_player_list()

func _on_peer_disconnected(_id: int) -> void:
	_update_player_list()

func _on_connection_succeeded() -> void:
	lobby_title.text = "Lobby (Connected)"
	start_button.visible = false
	_update_player_list()
	_show_state(MenuState.LOBBY)

func _on_connection_failed() -> void:
	_show_error("Connection failed")
	_show_state(MenuState.JOIN)

func _on_server_disconnected() -> void:
	_show_error("Disconnected from server")
	_show_state(MenuState.MAIN)

@rpc("authority", "call_local", "reliable")
func _start_multiplayer_game() -> void:
	GlobalMenuEvents.emit_multiplayer_started()
	emit_signal("start_game")
