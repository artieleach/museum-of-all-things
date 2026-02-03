extends Node
## Main game controller handling initialization and delegating to subsystems.

@export var Player: PackedScene = preload("res://scenes/Player.tscn")
@export var NetworkPlayer: PackedScene = preload("res://scenes/NetworkPlayer.tscn")
@export var smooth_movement: bool = false
@export var smooth_movement_dampening: float = 0.001
@export var player_speed: int = 6
@export var starting_point: Vector3 = Vector3(0, 4, 0)
@export var starting_rotation: float = 0

var _player: Node = null

# Subsystems
var _menu_controller: MainMenuController = null
var _multiplayer_controller: MultiplayerController = null
var _mount_controller: MountController = null

@onready var player_list_overlay: Control = $TabMenu/PlayerListOverlay
@onready var game_started: bool = false


func _debug_log(message: String) -> void:
	if OS.is_debug_build():
		print(message)


func _parse_command_line() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i: int in args.size():
		match args[i]:
			"--server":
				_multiplayer_controller.set_server_mode(true)
			"--port":
				if i + 1 < args.size():
					_multiplayer_controller.set_server_mode(
						_multiplayer_controller.is_server_mode(),
						int(args[i + 1])
					)


func _ready() -> void:
	# Initialize subsystems first
	_menu_controller = MainMenuController.new()
	_menu_controller.init(self, $CanvasLayer)
	_menu_controller.game_start_requested.connect(_start_game)
	_menu_controller.multiplayer_start_requested.connect(_on_multiplayer_start_game)
	add_child(_menu_controller)

	_multiplayer_controller = MultiplayerController.new()
	_multiplayer_controller.init(self, NetworkPlayer, starting_point)
	add_child(_multiplayer_controller)

	_mount_controller = MountController.new()
	_mount_controller.init(self, _multiplayer_controller)
	add_child(_mount_controller)

	_parse_command_line()

	if _multiplayer_controller.is_server_mode():
		_start_dedicated_server()
		return

	if OS.has_feature("movie"):
		$FpsLabel.visible = false

	_recreate_player()

	GraphicsManager.change_post_processing.connect(_change_post_processing)
	GraphicsManager.init()

	GameplayEvents.return_to_lobby.connect(_on_pause_menu_return_to_lobby)
	MultiplayerEvents.skin_selected.connect(_on_skin_selected)
	MultiplayerEvents.skin_reset.connect(_on_skin_reset)
	UIEvents.open_terminal_menu.connect(_use_terminal)
	UIEvents.quit_requested.connect(_on_quit_requested)

	# Race signals
	$CanvasLayer/PauseMenu.start_race.connect(_on_start_race_pressed)
	RaceManager.race_started.connect(_on_race_started)
	ExhibitFetcher.random_complete.connect(_on_random_article_complete)

	# Load saved skin
	_load_saved_skin()

	# Multiplayer signals
	NetworkManager.peer_connected.connect(_on_network_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_network_peer_disconnected)
	NetworkManager.server_disconnected.connect(_on_network_server_disconnected)
	NetworkManager.player_info_updated.connect(_on_network_player_info_updated)

	call_deferred("_play_sting")

	$DirectionalLight3D.visible = Platform.is_compatibility_renderer()

	_pause_game()


func _play_sting() -> void:
	$GameLaunchSting.play()


func _recreate_player() -> void:
	if _player:
		remove_child(_player)
		_player.queue_free()

	_player = Player.instantiate()
	add_child(_player)
	_player.get_node("Pivot/Camera3D").make_current()
	_player.rotation.y = starting_rotation
	_player.max_speed = player_speed
	_player.smooth_movement = smooth_movement
	_player.dampening = smooth_movement_dampening
	_player.position = starting_point


func _change_post_processing(post_processing: String) -> void:
	$CRTPostProcessing.visible = post_processing == "crt"


func _start_game() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_player.start()
	_menu_controller.close_menus()
	if not game_started:
		game_started = true
		$Museum.init(_player)


func _pause_game() -> void:
	_player.pause()
	if game_started:
		if $CanvasLayer.visible:
			return
		_menu_controller.open_pause_menu()
	else:
		_menu_controller.open_main_menu()


func _use_terminal() -> void:
	_player.pause()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_menu_controller.open_terminal_menu()


# =============================================================================
# MENU CALLBACKS
# =============================================================================

func _on_main_menu_start_pressed() -> void:
	_start_game()


func _on_main_menu_multiplayer() -> void:
	_menu_controller.on_main_menu_multiplayer()


func _on_multiplayer_menu_back() -> void:
	_menu_controller.on_multiplayer_menu_back()


func _on_multiplayer_start_game() -> void:
	_multiplayer_controller.set_multiplayer_game(true)
	_start_multiplayer_game()


func _on_main_menu_settings() -> void:
	_menu_controller.on_main_menu_settings()


func _on_pause_menu_settings() -> void:
	_menu_controller.on_pause_menu_settings()


func _on_pause_menu_return_to_lobby() -> void:
	_player.rotation.y = starting_rotation
	_player.position = starting_point
	$Museum.reset_to_lobby()
	_start_game()


func _on_settings_back() -> void:
	_menu_controller.on_settings_back()


# =============================================================================
# INPUT HANDLING
# =============================================================================
func _input(event: InputEvent) -> void:
	if Input.is_action_pressed("toggle_fullscreen"):
		UIEvents.fullscreen_toggled.emit(not GraphicsManager.fullscreen)

	if not game_started:
		return

	if Input.is_action_just_pressed("ui_accept"):
		UIEvents.emit_ui_accept_pressed()

	if Input.is_action_just_pressed("ui_cancel") and $CanvasLayer.visible:
		UIEvents.emit_ui_cancel_pressed()

	if Input.is_action_just_pressed("show_fps"):
		$FpsLabel.visible = not $FpsLabel.visible

	if event.is_action_pressed("pause"):
		_pause_game()

	if event.is_action_pressed("free_pointer"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("click") and not $CanvasLayer.visible:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Tab key for player list overlay
	if _multiplayer_controller.is_multiplayer_game() and not $CanvasLayer.visible:
		if event.is_action_pressed("show_player_list"):
			player_list_overlay.visible = true
		elif event.is_action_released("show_player_list"):
			player_list_overlay.visible = false


func _process(delta: float) -> void:
	$FpsLabel.text = str(Engine.get_frames_per_second())

	# Broadcast local player position to other players
	if _multiplayer_controller.process_position_sync(delta, _player):
		var pivot_rot_x: float = 0.0
		var pivot_pos_y: float = 1.35
		if _player.has_node("Pivot"):
			pivot_rot_x = _player.get_node("Pivot").rotation.x
			pivot_pos_y = _player.get_node("Pivot").position.y
		var is_mounted: bool = _player._is_mounted if _player.has_method("execute_mount") else false
		var mounted_peer_id: int = _player.mount_peer_id if _player.has_method("execute_mount") else -1
		# If mounted, use mount's room to stay synced during room transitions
		var current_room: String = "$Lobby"
		if is_mounted and is_instance_valid(_player.mounted_on) and "current_room" in _player.mounted_on:
			current_room = _player.mounted_on.current_room
		elif "current_room" in _player:
			current_room = _player.current_room
		_sync_player_position.rpc(
			NetworkManager.get_unique_id(),
			_player.global_position,
			_player.rotation.y,
			pivot_rot_x,
			pivot_pos_y,
			is_mounted,
			mounted_peer_id,
			current_room
		)


# =============================================================================
# SKIN FUNCTIONS
# =============================================================================
func _save_skin_preference(url: String) -> void:
	var player_settings: Dictionary = SettingsManager.get_settings("player")
	if player_settings == null:
		player_settings = {}
	player_settings["skin_url"] = url
	SettingsManager.save_settings("player", player_settings)


func _on_skin_selected(url: String, _texture: ImageTexture) -> void:
	NetworkManager.set_local_player_skin(url)
	_save_skin_preference(url)
	_debug_log("Main: Skin selected: " + url)


func _on_skin_reset() -> void:
	NetworkManager.set_local_player_skin("")
	_save_skin_preference("")
	_debug_log("Main: Skin reset")


func _load_saved_skin() -> void:
	var player_settings: Dictionary = SettingsManager.get_settings("player")
	if player_settings and player_settings.has("skin_url"):
		var skin_url: String = player_settings["skin_url"]
		if skin_url != "":
			NetworkManager.local_player_skin = skin_url
			_debug_log("Main: Loaded saved skin: " + skin_url)


# =============================================================================
# RACE FUNCTIONS
# =============================================================================
func _on_start_race_pressed() -> void:
	if RaceManager.is_race_active():
		return

	if NetworkManager.is_server():
		_debug_log("Main: Fetching random article for race...")
		ExhibitFetcher.fetch_random({ "race": true })
	else:
		_debug_log("Main: Sending _request_race_start RPC to server (my id: %d, multiplayer active: %s)" % [multiplayer.get_unique_id(), NetworkManager.is_multiplayer_active()])
		_request_race_start.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_race_start() -> void:
	_debug_log("Main: _request_race_start RPC received from peer %d" % multiplayer.get_remote_sender_id())
	if not NetworkManager.is_server():
		return
	if RaceManager.is_race_active():
		return
	_debug_log("Main: Race start requested by peer, fetching random article...")
	ExhibitFetcher.fetch_random({ "race": true })


func _on_random_article_complete(title: String, context: Dictionary) -> void:
	if not context or not context.has("race") or not context.race:
		return

	if title == null or title == "":
		push_error("Main: Failed to fetch random article for race")
		return
	_debug_log("Main: Starting race to '%s'" % title)
	RaceManager.start_race(title)


func _on_race_started(target_article: String) -> void:
	_debug_log("Main: Race started, teleporting to lobby")
	if _player == null:
		return
	_menu_controller.close_menus()

	# Teleport local player to starting point
	_player.position = starting_point

	# Reset to lobby
	$Museum.reset_to_lobby()

	# Start game (close menus, capture mouse)
	_start_game()

	GameplayEvents.emit_race_started(target_article)


# =============================================================================
# MULTIPLAYER FUNCTIONS
# =============================================================================
func _start_dedicated_server() -> void:
	print("Starting dedicated server on port %d..." % _multiplayer_controller.get_server_port())

	# Connect multiplayer signals before hosting
	NetworkManager.peer_connected.connect(_on_network_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_network_peer_disconnected)
	NetworkManager.player_info_updated.connect(_on_network_player_info_updated)

	# Connect race signals (needed for RPC handling)
	RaceManager.race_started.connect(_on_race_started)
	ExhibitFetcher.random_complete.connect(_on_random_article_complete)

	var error: Error = NetworkManager.host_game(_multiplayer_controller.get_server_port(), true)
	if error != OK:
		printerr("Failed to start server: ", error)
		get_tree().quit(1)
		return

	_multiplayer_controller.set_multiplayer_game(true)
	game_started = true

	# Initialize museum without a local player
	$Museum.init(null)

	print("Server started successfully. Waiting for players...")


func _start_multiplayer_game() -> void:
	_start_game()
	if NetworkManager.is_multiplayer_active():
		for peer_id: int in NetworkManager.get_player_list():
			if peer_id != NetworkManager.get_unique_id():
				_multiplayer_controller.spawn_network_player(peer_id)


func _on_network_peer_connected(peer_id: int) -> void:
	if _multiplayer_controller.is_multiplayer_game() and game_started:
		_multiplayer_controller.spawn_network_player(peer_id)

		# If we're the server, tell the new player the game has already started
		if NetworkManager.is_server():
			_notify_game_started.rpc_id(peer_id)
			# Don't sync exhibit - late joiners start in lobby and navigate naturally
			# Room-based visibility will correctly show/hide players based on their actual room


func _on_network_peer_disconnected(peer_id: int) -> void:
	_multiplayer_controller.remove_network_player(peer_id, _player, _mount_controller.get_mount_state())


func _on_network_server_disconnected() -> void:
	# Return to main menu when host disconnects
	_multiplayer_controller.end_multiplayer_session()
	_menu_controller.open_main_menu()


func _on_quit_requested() -> void:
	if _multiplayer_controller.is_multiplayer_game():
		NetworkManager.disconnect_from_game()
		_multiplayer_controller.end_multiplayer_session()
		_menu_controller.open_main_menu()
	else:
		get_tree().quit()


func _on_network_player_info_updated(peer_id: int) -> void:
	_multiplayer_controller.update_player_info(peer_id)


func get_local_player() -> Node:
	return _player


func get_all_players() -> Array:
	return _multiplayer_controller.get_all_players(_player)


func is_multiplayer_game() -> bool:
	return _multiplayer_controller.is_multiplayer_game()


func _get_player_by_peer_id(peer_id: int) -> Node:
	return _multiplayer_controller.get_player_by_peer_id(peer_id, _player)


# =============================================================================
# MOUNT SYSTEM
# =============================================================================
func _request_mount(target: Node) -> void:
	_mount_controller.request_mount(target, _player)


func _request_dismount() -> void:
	_mount_controller.request_dismount(_player)


# =============================================================================
# MULTIPLAYER RPCS
# =============================================================================
@rpc("authority", "call_remote", "reliable")
func _notify_game_started() -> void:
	_debug_log("Main: Received notification that game has already started")
	_multiplayer_controller.set_multiplayer_game(true)
	_start_multiplayer_game()


@rpc("authority", "call_remote", "reliable")
func _sync_exhibit_to_peer(exhibit_title: String) -> void:
	_debug_log("Main: Syncing exhibit to late joiner: " + exhibit_title)
	$Museum.sync_to_exhibit(exhibit_title)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _sync_player_position(peer_id: int, pos: Vector3, rot_y: float, pivot_rot_x: float, pivot_pos_y: float = 1.35, is_mounted: bool = false, mounted_peer_id: int = -1, current_room: String = "$Lobby") -> void:
	_multiplayer_controller.apply_network_position(peer_id, pos, rot_y, pivot_rot_x, pivot_pos_y, is_mounted, mounted_peer_id, _player, current_room)


@rpc("any_peer", "call_remote", "reliable")
func _request_mount_rpc(rider_peer_id: int, mount_peer_id: int) -> void:
	if NetworkManager.is_server():
		_mount_controller.handle_mount_request(rider_peer_id, mount_peer_id, _player)


@rpc("any_peer", "call_remote", "reliable")
func _request_dismount_rpc(rider_peer_id: int) -> void:
	if NetworkManager.is_server():
		_mount_controller.handle_dismount_request(rider_peer_id, _player)


@rpc("authority", "call_local", "reliable")
func _execute_mount_sync(rider_peer_id: int, mount_peer_id: int) -> void:
	_mount_controller.execute_mount_sync(rider_peer_id, mount_peer_id, _player)


@rpc("authority", "call_local", "reliable")
func _execute_dismount_sync(rider_peer_id: int) -> void:
	_mount_controller.execute_dismount_sync(rider_peer_id, _player)
