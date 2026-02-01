extends Node

@export var XrRoot : PackedScene = preload("res://scenes/XRRoot.tscn")
@export var Player : PackedScene = preload("res://scenes/Player.tscn")
@export var NetworkPlayer : PackedScene = preload("res://scenes/NetworkPlayer.tscn")
var _player
var _network_players: Dictionary = {}  # peer_id -> player node
@onready var player_list_overlay = $TabMenu/PlayerListOverlay

@export var smooth_movement = false
@export var smooth_movement_dampening = 0.001
@export var player_speed = 6

@export var starting_point = Vector3(0, 4, 0)
@export var starting_rotation = 0 #3 * PI / 2

@onready var game_started = false
@onready var menu_nav_queue = []

var webxr_interface
var webxr_is_starting = false
var _is_multiplayer_game: bool = false
var _position_sync_timer: float = 0.0
const POSITION_SYNC_INTERVAL: float = 0.05  # 20 updates per second

var _server_mode: bool = false
var _server_port: int = 7777

# Mounting state tracking
var _mount_state: Dictionary = {}  # peer_id -> mount_peer_id (-1 if not mounted)

func _parse_command_line() -> void:
	var args = OS.get_cmdline_args()
	for i in args.size():
		match args[i]:
			"--server":
				_server_mode = true
			"--port":
				if i + 1 < args.size():
					_server_port = int(args[i + 1])

func _ready():
	_parse_command_line()

	if _server_mode:
		_start_dedicated_server()
		return

	if OS.has_feature("movie"):
		$FpsLabel.visible = false

	_recreate_player()

	if Util.is_xr():
		_start_game()
	else:
		GraphicsManager.change_post_processing.connect(_change_post_processing)
		GraphicsManager.init()

	GlobalMenuEvents.return_to_lobby.connect(_on_pause_menu_return_to_lobby)
	GlobalMenuEvents.open_terminal_menu.connect(_use_terminal)
	GlobalMenuEvents.skin_selected.connect(_on_skin_selected)
	GlobalMenuEvents.skin_reset.connect(_on_skin_reset)
	GlobalMenuEvents.quit_requested.connect(_on_quit_requested)

	# Load saved skin
	_load_saved_skin()

	# Multiplayer signals
	NetworkManager.peer_connected.connect(_on_network_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_network_peer_disconnected)
	NetworkManager.server_disconnected.connect(_on_network_server_disconnected)
	NetworkManager.player_info_updated.connect(_on_network_player_info_updated)

	call_deferred("_play_sting")

	$DirectionalLight3D.visible = Util.is_compatibility_renderer()

	if not Util.is_xr():
		_pause_game()

	if Util.is_web():
		webxr_interface = XRServer.find_interface("WebXR")
		if webxr_interface:
			webxr_interface.session_supported.connect(_webxr_session_supported)
			webxr_interface.session_started.connect(_webxr_session_started)
			webxr_interface.session_ended.connect(_webxr_session_ended)
			webxr_interface.session_failed.connect(_webxr_session_failed)

		webxr_interface.is_session_supported("immersive-vr")

func _play_sting():
	$GameLaunchSting.play()

func _recreate_player() -> void:
	if _player:
		if _player is XROrigin3D:
			_player = _player.get_parent()
		remove_child(_player)
		_player.queue_free()

	_player = XrRoot.instantiate() if Util.is_xr() else Player.instantiate()
	add_child(_player)

	if Util.is_xr():
		_player = _player.get_node("XROrigin3D")
		_player.get_node("XRToolsPlayerBody").rotate_player(-starting_rotation)
	else:
		_player.get_node("Pivot/Camera3D").make_current()
		_player.rotation.y = starting_rotation
		_player.max_speed = player_speed
		_player.smooth_movement = smooth_movement
		_player.dampening = smooth_movement_dampening
		_player.position = starting_point

func _change_post_processing(post_processing: String):
	if post_processing == "crt":
		$CRTPostProcessing.visible = true
	else:
		$CRTPostProcessing.visible = false

func _start_game():
	if not Util.is_xr():
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_player.start()

	_close_menus()

	if not game_started:
		game_started = true
		$Museum.init(_player)

func _on_main_menu_start_webxr() -> void:
	# Prevent clicking the button multiple times.
	if webxr_is_starting:
		return

	if webxr_interface:
		webxr_is_starting = true
		webxr_interface.session_mode = "immersive-vr"
		webxr_interface.requested_reference_space_types = "local-floor, local"
		webxr_interface.optional_features = 'local-floor'
		if not webxr_interface.initialize():
			OS.alert("Failed to initialize WebXR")
			webxr_is_starting = false

func _pause_game():
	_player.pause()

	if game_started:
		if $CanvasLayer.visible:
			return
		_open_pause_menu()
	else:
		_open_main_menu()

func _use_terminal():
	_player.pause()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_open_terminal_menu()

func _close_menus():
	$CanvasLayer.visible = false
	$CanvasLayer/Settings.visible = false
	$CanvasLayer/MainMenu.visible = false
	$CanvasLayer/PauseMenu.visible = false
	$CanvasLayer/PopupTerminalMenu.visible = false
	$CanvasLayer/MultiplayerMenu.visible = false

func _open_settings_menu():
	_close_menus()
	$CanvasLayer.visible = true
	$CanvasLayer/Settings.visible = true

func _open_main_menu():
	_close_menus()
	$CanvasLayer.visible = true
	$CanvasLayer/MainMenu.visible = true

func _open_pause_menu():
	_close_menus()
	$CanvasLayer.visible = true
	$CanvasLayer/PauseMenu.visible = true

func _open_terminal_menu():
	_close_menus()
	$CanvasLayer.visible = true
	$CanvasLayer/PopupTerminalMenu.visible = true

func _open_multiplayer_menu():
	_close_menus()
	$CanvasLayer.visible = true
	$CanvasLayer/MultiplayerMenu.visible = true

func _on_main_menu_start_pressed():
	_start_game()

func _on_main_menu_multiplayer():
	menu_nav_queue.append(_open_main_menu)
	_open_multiplayer_menu()

func _on_multiplayer_menu_back():
	var prev = menu_nav_queue.pop_back()
	if prev:
		prev.call()
	else:
		_open_main_menu()

func _on_multiplayer_start_game():
	_is_multiplayer_game = true
	_start_multiplayer_game()

func _on_main_menu_settings():
	menu_nav_queue.append(_open_main_menu)
	_open_settings_menu()

func _on_pause_menu_settings():
	menu_nav_queue.append(_open_pause_menu)
	_open_settings_menu()

func _on_pause_menu_return_to_lobby():
	# TODO: set absolute rotation in XR
	if not Util.is_xr():
		_player.rotation.y = starting_rotation

	_player.position = starting_point
	$Museum.reset_to_lobby()

	_start_game()

func _on_settings_back():
	var prev = menu_nav_queue.pop_back()
	if prev:
		prev.call()
	else:
		_start_game()

func _input(event):

	if Input.is_action_pressed("toggle_fullscreen"):
		GlobalMenuEvents.emit_on_fullscreen_toggled(not GraphicsManager.fullscreen)

	if not game_started:
		return

	if Input.is_action_just_pressed("ui_accept"):
		GlobalMenuEvents.emit_ui_accept_pressed()

	if Input.is_action_just_pressed("ui_cancel") and $CanvasLayer.visible:
		GlobalMenuEvents.emit_ui_cancel_pressed()

	if Input.is_action_just_pressed("show_fps"):
		$FpsLabel.visible = not $FpsLabel.visible

	if event.is_action_pressed("pause") and not Util.is_xr():
		_pause_game()

	if event.is_action_pressed("free_pointer") and not Util.is_xr():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("click") and not Util.is_xr() and not $CanvasLayer.visible:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Tab key for player list overlay (only in multiplayer, not XR, not in menus)
	if _is_multiplayer_game and not Util.is_xr() and not $CanvasLayer.visible:
		if event.is_action_pressed("show_player_list"):
			player_list_overlay.visible = true
		elif event.is_action_released("show_player_list"):
			player_list_overlay.visible = false


func _process(delta: float) -> void:
	$FpsLabel.text = str(Engine.get_frames_per_second())

	# Broadcast local player position to other players
	if _is_multiplayer_game and NetworkManager.is_multiplayer_active() and _player:
		_position_sync_timer += delta
		if _position_sync_timer >= POSITION_SYNC_INTERVAL:
			_position_sync_timer = 0.0
			var pivot_rot_x = 0.0
			var pivot_pos_y = 1.35  # Default standing height
			if _player.has_node("Pivot"):
				pivot_rot_x = _player.get_node("Pivot").rotation.x
				pivot_pos_y = _player.get_node("Pivot").position.y
			var is_mounted = _player._is_mounted if _player.has_method("execute_mount") else false
			var mounted_peer_id = _player.mount_peer_id if _player.has_method("execute_mount") else -1
			_sync_player_position.rpc(
				NetworkManager.get_unique_id(),
				_player.global_position,
				_player.rotation.y,
				pivot_rot_x,
				pivot_pos_y,
				is_mounted,
				mounted_peer_id
			)

func _webxr_session_supported(session_mode, supported):
	if session_mode == 'immersive-vr' and supported:
		%MainMenu.set_webxr_enabled(true)

func _webxr_session_started():
	webxr_is_starting = false

	_recreate_player()

	# @todo This should ensure that post-processing effects are disabled

	$CanvasLayer.visible = false
	get_viewport().use_xr = true

	_start_game()

func _webxr_session_ended():
	webxr_is_starting = false
	_recreate_player()

	$CanvasLayer.visible = true
	get_viewport().use_xr = false

	_open_main_menu()

func _webxr_session_failed(message):
	webxr_is_starting = false
	OS.alert("Failed to initialize WebXR: " + message)

# Skin functions
func _on_skin_selected(url: String, texture: ImageTexture) -> void:
	# Set local player skin in NetworkManager
	NetworkManager.set_local_player_skin(url)

	# Save skin preference
	var player_settings = SettingsManager.get_settings("player")
	if player_settings == null:
		player_settings = {}
	player_settings["skin_url"] = url
	SettingsManager.save_settings("player", player_settings)

	if OS.is_debug_build():
		print("Main: Skin selected: ", url)

func _on_skin_reset() -> void:
	# Clear local player skin in NetworkManager
	NetworkManager.set_local_player_skin("")

	# Clear saved skin preference
	var player_settings = SettingsManager.get_settings("player")
	if player_settings == null:
		player_settings = {}
	player_settings["skin_url"] = ""
	SettingsManager.save_settings("player", player_settings)

	if OS.is_debug_build():
		print("Main: Skin reset")

func _load_saved_skin() -> void:
	var player_settings = SettingsManager.get_settings("player")
	if player_settings and player_settings.has("skin_url"):
		var skin_url = player_settings["skin_url"]
		if skin_url != "":
			NetworkManager.local_player_skin = skin_url
			if OS.is_debug_build():
				print("Main: Loaded saved skin: ", skin_url)

# Multiplayer functions
func _start_dedicated_server() -> void:
	print("Starting dedicated server on port %d..." % _server_port)

	# Connect multiplayer signals before hosting
	NetworkManager.peer_connected.connect(_on_network_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_network_peer_disconnected)
	NetworkManager.player_info_updated.connect(_on_network_player_info_updated)

	var error = NetworkManager.host_game(_server_port, true)
	if error != OK:
		printerr("Failed to start server: ", error)
		get_tree().quit(1)
		return

	_is_multiplayer_game = true
	game_started = true

	# Initialize museum without a local player
	$Museum.init(null)

	print("Server started successfully. Waiting for players...")

func _start_multiplayer_game():
	_start_game()

	# Spawn network players for all connected peers
	if NetworkManager.is_multiplayer_active():
		for peer_id in NetworkManager.get_player_list():
			if peer_id != NetworkManager.get_unique_id():
				_spawn_network_player(peer_id)

func _spawn_network_player(peer_id: int) -> void:
	if _network_players.has(peer_id):
		return

	var net_player = NetworkPlayer.instantiate()
	net_player.name = "NetworkPlayer_" + str(peer_id)
	net_player.is_local = false
	add_child(net_player)

	net_player.set_player_authority(peer_id)
	net_player.set_player_name(NetworkManager.get_player_name(peer_id))
	net_player.set_player_color(NetworkManager.get_player_color(peer_id))
	var skin_url = NetworkManager.get_player_skin(peer_id)
	if skin_url != "":
		net_player.set_player_skin(skin_url)
	net_player.position = starting_point

	_network_players[peer_id] = net_player

	GlobalMenuEvents.emit_player_joined(peer_id, NetworkManager.get_player_name(peer_id))

	if OS.is_debug_build():
		print("Main: Spawned network player for peer ", peer_id)

func _remove_network_player(peer_id: int) -> void:
	if _network_players.has(peer_id):
		var player_node = _network_players[peer_id]
		if is_instance_valid(player_node):
			# Handle mount cleanup before removing player
			# If disconnected player had a rider, dismount them
			if player_node._has_rider and is_instance_valid(player_node.mounted_by):
				player_node.mounted_by.execute_dismount()

			# If disconnected player was riding someone, clear mount's rider state
			if player_node._is_mounted and is_instance_valid(player_node.mounted_on):
				player_node.mounted_on._remove_rider(player_node)

			# If local player was mounted on disconnected player, dismount
			if _player and _player._is_mounted and _player.mounted_on == player_node:
				_player.execute_dismount()

			player_node.queue_free()
			_network_players.erase(peer_id)

		# Clear mount state tracking
		if _mount_state.has(peer_id):
			_mount_state.erase(peer_id)

		GlobalMenuEvents.emit_player_left(peer_id)

		if OS.is_debug_build():
			print("Main: Removed network player for peer ", peer_id)

func _on_network_peer_connected(peer_id: int) -> void:
	if _is_multiplayer_game and game_started:
		_spawn_network_player(peer_id)

		# If we're the server, tell the new player the game has already started
		if NetworkManager.is_server():
			_notify_game_started.rpc_id(peer_id)
			var current_room = $Museum.get_current_room()
			_sync_exhibit_to_peer.rpc_id(peer_id, current_room)

func _on_network_peer_disconnected(peer_id: int) -> void:
	_remove_network_player(peer_id)

func _on_network_server_disconnected() -> void:
	# Return to main menu when host disconnects
	_end_multiplayer_session()
	_open_main_menu()

func _on_quit_requested() -> void:
	if _is_multiplayer_game:
		NetworkManager.disconnect_from_game()
		_end_multiplayer_session()
		_open_main_menu()
	else:
		get_tree().quit()

func _on_network_player_info_updated(peer_id: int) -> void:
	# Update network player's name, color, and skin when info is received/changed
	if _network_players.has(peer_id):
		var net_player = _network_players[peer_id]
		if is_instance_valid(net_player):
			net_player.set_player_name(NetworkManager.get_player_name(peer_id))
			net_player.set_player_color(NetworkManager.get_player_color(peer_id))
			var skin_url = NetworkManager.get_player_skin(peer_id)
			if skin_url != "":
				net_player.set_player_skin(skin_url)
			else:
				net_player.clear_player_skin()

func _end_multiplayer_session() -> void:
	_is_multiplayer_game = false

	# Remove all network players
	for peer_id in _network_players.keys():
		_remove_network_player(peer_id)
	_network_players.clear()

	GlobalMenuEvents.emit_multiplayer_ended()

func get_local_player():
	return _player

func get_all_players() -> Array:
	var players = [_player]
	for peer_id in _network_players:
		if is_instance_valid(_network_players[peer_id]):
			players.append(_network_players[peer_id])
	return players

func is_multiplayer_game() -> bool:
	return _is_multiplayer_game

func _get_player_by_peer_id(peer_id: int) -> Node:
	if peer_id == NetworkManager.get_unique_id():
		return _player
	elif _network_players.has(peer_id):
		return _network_players[peer_id]
	return null

func _on_teleport_to_player(peer_id: int) -> void:
	var target = _get_player_by_peer_id(peer_id)
	if target and is_instance_valid(target):
		# Dismount if currently mounted
		if _player.has_method("execute_dismount") and _player._is_mounted:
			_player.execute_dismount()

		# Teleport 2 meters behind target player
		var offset = target.global_transform.basis.z * 2.0
		_player.global_position = target.global_position + offset
		_player.look_at(target.global_position, Vector3.UP)

		if OS.is_debug_build():
			print("Main: Teleported to player ", peer_id)

# Mounting system functions
func _request_mount(target: Node) -> void:
	if not _is_multiplayer_game or not NetworkManager.is_multiplayer_active():
		# Single player - just mount directly
		if is_instance_valid(target) and not target._has_rider:
			_player.execute_mount(target)
		return

	# Multiplayer - find peer_id of target
	var mount_peer_id = -1
	for peer_id in _network_players:
		if _network_players[peer_id] == target:
			mount_peer_id = peer_id
			break

	if mount_peer_id == -1:
		return  # Target not found

	# Send RPC to server
	if NetworkManager.is_server():
		_handle_mount_request(NetworkManager.get_unique_id(), mount_peer_id)
	else:
		_request_mount_rpc.rpc_id(1, NetworkManager.get_unique_id(), mount_peer_id)

func _request_dismount() -> void:
	if not _is_multiplayer_game or not NetworkManager.is_multiplayer_active():
		# Single player - dismount directly
		_player.execute_dismount()
		return

	# Multiplayer - send RPC to server
	if NetworkManager.is_server():
		_handle_dismount_request(NetworkManager.get_unique_id())
	else:
		_request_dismount_rpc.rpc_id(1, NetworkManager.get_unique_id())

func _handle_mount_request(rider_peer_id: int, mount_peer_id: int) -> void:
	# Server-side validation and execution
	var rider = _get_player_by_peer_id(rider_peer_id)
	var mount = _get_player_by_peer_id(mount_peer_id)

	if not is_instance_valid(rider) or not is_instance_valid(mount):
		return
	if rider == mount:
		return  # Can't mount self
	if mount._has_rider:
		return  # Mount already has a rider
	if rider._is_mounted:
		return  # Rider is already mounted

	# Store mount state
	_mount_state[rider_peer_id] = mount_peer_id

	# Execute locally if this is the server's player
	if rider_peer_id == NetworkManager.get_unique_id():
		_player.execute_mount(mount, mount_peer_id)
	elif _network_players.has(rider_peer_id):
		_network_players[rider_peer_id].execute_mount(mount, mount_peer_id)

	# Broadcast to all clients
	_execute_mount_sync.rpc(rider_peer_id, mount_peer_id)

func _handle_dismount_request(rider_peer_id: int) -> void:
	# Server-side validation and execution
	if not _mount_state.has(rider_peer_id) or _mount_state[rider_peer_id] == -1:
		return  # Not mounted

	# Clear mount state
	_mount_state[rider_peer_id] = -1

	# Execute locally if this is the server's player
	if rider_peer_id == NetworkManager.get_unique_id():
		_player.execute_dismount()
	elif _network_players.has(rider_peer_id):
		_network_players[rider_peer_id].execute_dismount()

	# Broadcast to all clients
	_execute_dismount_sync.rpc(rider_peer_id)

@rpc("authority", "call_remote", "reliable")
func _notify_game_started() -> void:
	# Late join: the server is telling us the game has already started
	if OS.is_debug_build():
		print("Main: Received notification that game has already started")
	_is_multiplayer_game = true
	_start_multiplayer_game()

@rpc("authority", "call_remote", "reliable")
func _sync_exhibit_to_peer(exhibit_title: String) -> void:
	# Late join: sync the current exhibit
	if OS.is_debug_build():
		print("Main: Syncing exhibit to late joiner: ", exhibit_title)
	$Museum.sync_to_exhibit(exhibit_title)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _sync_player_position(peer_id: int, pos: Vector3, rot_y: float, pivot_rot_x: float, pivot_pos_y: float = 1.35, is_mounted: bool = false, mounted_peer_id: int = -1) -> void:
	# Update the NetworkPlayer for the given peer_id
	if _network_players.has(peer_id):
		var net_player = _network_players[peer_id]
		if is_instance_valid(net_player):
			if net_player.has_method("apply_network_position"):
				net_player.apply_network_position(pos, rot_y, pivot_rot_x, pivot_pos_y)
			if net_player.has_method("apply_network_mount_state"):
				var mount_node = _get_player_by_peer_id(mounted_peer_id) if is_mounted else null
				net_player.apply_network_mount_state(is_mounted, mounted_peer_id, mount_node)

# Mount system RPCs
@rpc("any_peer", "call_remote", "reliable")
func _request_mount_rpc(rider_peer_id: int, mount_peer_id: int) -> void:
	if NetworkManager.is_server():
		_handle_mount_request(rider_peer_id, mount_peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_dismount_rpc(rider_peer_id: int) -> void:
	if NetworkManager.is_server():
		_handle_dismount_request(rider_peer_id)

@rpc("authority", "call_local", "reliable")
func _execute_mount_sync(rider_peer_id: int, mount_peer_id: int) -> void:
	var rider = _get_player_by_peer_id(rider_peer_id)
	var mount = _get_player_by_peer_id(mount_peer_id)

	if not is_instance_valid(rider) or not is_instance_valid(mount):
		return

	# Don't re-execute if we're the server (already done)
	if NetworkManager.is_server():
		return

	rider.execute_mount(mount, mount_peer_id)

	if OS.is_debug_build():
		print("Main: Mount sync - ", rider_peer_id, " mounted on ", mount_peer_id)

@rpc("authority", "call_local", "reliable")
func _execute_dismount_sync(rider_peer_id: int) -> void:
	var rider = _get_player_by_peer_id(rider_peer_id)

	if not is_instance_valid(rider):
		return

	# Don't re-execute if we're the server (already done)
	if NetworkManager.is_server():
		return

	rider.execute_dismount()

	if OS.is_debug_build():
		print("Main: Dismount sync - ", rider_peer_id)
