extends Control
class_name MultiplayerMenu

signal back
signal start_game

static var default_server_address := "frogwizard.online"
const DEFAULT_HOST_NAME := "Host"
const DEFAULT_PLAYER_NAME := "Player"

enum MenuState { MAIN, HOST, JOIN, LOBBY }

var current_state: MenuState = MenuState.MAIN

@onready var _main_container = %MainContainer
@onready var _host_container = %HostContainer
@onready var _join_container = %JoinContainer
@onready var _lobby_container = %LobbyContainer

@onready var _host_port_input = %HostPortInput
@onready var _host_name_input = %HostNameInput
@onready var _host_color_picker = %HostColorPicker
@onready var _join_address_input = %JoinAddressInput
@onready var _join_port_input = %JoinPortInput
@onready var _join_name_input = %JoinNameInput
@onready var _join_color_picker = %JoinColorPicker
@onready var _player_list = %PlayerList
@onready var _lobby_title = %LobbyTitle
@onready var _start_button = %LobbyStartButton
@onready var _error_label = %ErrorLabel

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
		_error_label.visible = false
		%HostButton.grab_focus()

func _show_state(state: MenuState) -> void:
	current_state = state
	_main_container.visible = state == MenuState.MAIN
	_host_container.visible = state == MenuState.HOST
	_join_container.visible = state == MenuState.JOIN
	_lobby_container.visible = state == MenuState.LOBBY
	_error_label.visible = false

	match state:
		MenuState.MAIN:
			%HostButton.grab_focus()
		MenuState.HOST:
			_host_name_input.grab_focus()
		MenuState.JOIN:
			_join_name_input.grab_focus()
		MenuState.LOBBY:
			if NetworkManager.is_server():
				_start_button.grab_focus()
			else:
				%LobbyLeaveButton.grab_focus()

func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true

func _update_player_list() -> void:
	_player_list.clear()
	for peer_id in NetworkManager.get_player_list():
		var player_name = NetworkManager.get_player_name(peer_id)
		var suffix = " (Host)" if peer_id == 1 else ""
		var you_suffix = " (You)" if peer_id == NetworkManager.get_unique_id() else ""
		_player_list.add_item(player_name + suffix + you_suffix)

# Main menu buttons
func _on_host_pressed() -> void:
	_show_state(MenuState.HOST)
	_host_port_input.text = str(NetworkManager.DEFAULT_PORT)
	_host_name_input.text = DEFAULT_HOST_NAME

func _on_join_pressed() -> void:
	_show_state(MenuState.JOIN)
	_join_address_input.text = default_server_address
	_join_port_input.text = str(NetworkManager.DEFAULT_PORT)
	_join_name_input.text = DEFAULT_PLAYER_NAME

func _on_back_pressed() -> void:
	if current_state == MenuState.MAIN:
		back.emit()
	else:
		_show_state(MenuState.MAIN)

# Host menu buttons
func _on_host_start_pressed() -> void:
	var port = int(_host_port_input.text)
	if port <= 0 or port > 65535:
		_show_error("Invalid port number")
		return

	NetworkManager.set_local_player_name(_host_name_input.text)
	NetworkManager.set_local_player_color(_host_color_picker.color)
	var error = NetworkManager.host_game(port)
	if error != OK:
		_show_error("Failed to start server: " + str(error))
		return

	_lobby_title.text = "Lobby (Hosting)"
	_start_button.visible = true
	_update_player_list()
	_show_state(MenuState.LOBBY)

func _on_host_back_pressed() -> void:
	_show_state(MenuState.MAIN)

# Join menu buttons
func _on_join_connect_pressed() -> void:
	var address = _join_address_input.text
	var port = int(_join_port_input.text)

	if address.is_empty():
		_show_error("Please enter an address")
		return

	if port <= 0 or port > 65535:
		_show_error("Invalid port number")
		return

	NetworkManager.set_local_player_name(_join_name_input.text)
	NetworkManager.set_local_player_color(_join_color_picker.color)
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
	_lobby_title.text = "Lobby (Connected)"
	_start_button.visible = false
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
	MultiplayerEvents.emit_multiplayer_started()
	start_game.emit()
