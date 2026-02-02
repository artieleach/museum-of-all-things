extends Node

## GlobalMenuEvents - DEPRECATED facade
##
## This file exists for backwards compatibility. Prefer using the domain-specific
## event buses directly:
## - UIEvents: ui_cancel_pressed, ui_accept_pressed, hide_menu, terminal events, quit
## - SettingsEvents: fullscreen, XR settings, input settings
## - MultiplayerEvents: player_joined, player_left, multiplayer lifecycle, skins
## - GameplayEvents: return_to_lobby, language, race events

# Child event buses (instantiated as autoloads would create circular dependencies)
var _ui_events := UIEvents.new()
var _settings_events := SettingsEvents.new()
var _multiplayer_events := MultiplayerEvents.new()
var _gameplay_events := GameplayEvents.new()

# Provide access to new event buses for incremental migration
var ui: UIEvents:
	get: return _ui_events
var settings: SettingsEvents:
	get: return _settings_events
var mp: MultiplayerEvents:
	get: return _multiplayer_events
var gameplay: GameplayEvents:
	get: return _gameplay_events

func _ready() -> void:
	# Forward signals from new buses to legacy signals for backwards compatibility
	_ui_events.ui_cancel_pressed.connect(func(): ui_cancel_pressed.emit())
	_ui_events.ui_accept_pressed.connect(func(): ui_accept_pressed.emit())
	_ui_events.hide_menu.connect(func(): hide_menu.emit())
	_ui_events.open_terminal_menu.connect(func(): open_terminal_menu.emit())
	_ui_events.terminal_result_ready.connect(func(e, p): terminal_result_ready.emit(e, p))
	_ui_events.set_custom_door.connect(func(t): set_custom_door.emit(t))
	_ui_events.reset_custom_door.connect(func(): reset_custom_door.emit())
	_ui_events.quit_requested.connect(func(): quit_requested.emit())

	_settings_events.fullscreen_toggled.connect(func(e): _on_fullscreen_toggled.emit(e))
	_settings_events.set_current_room.connect(func(r): set_current_room.emit(r))
	_settings_events.set_xr_movement_style.connect(func(s): set_xr_movement_style.emit(s))
	_settings_events.set_movement_speed.connect(func(s): set_movement_speed.emit(s))
	_settings_events.set_xr_rotation_increment.connect(func(i): set_xr_rotation_increment.emit(i))
	_settings_events.set_xr_smooth_rotation.connect(func(e): set_xr_smooth_rotation.emit(e))
	_settings_events.load_xr_settings.connect(func(): load_xr_settings.emit())
	_settings_events.set_invert_y.connect(func(e): set_invert_y.emit(e))
	_settings_events.set_mouse_sensitivity.connect(func(f): set_mouse_sensitivity.emit(f))
	_settings_events.set_joypad_deadzone.connect(func(v): set_joypad_deadzone.emit(v))

	_multiplayer_events.player_joined.connect(func(id, player_name): player_joined.emit(id, player_name))
	_multiplayer_events.player_left.connect(func(id): player_left.emit(id))
	_multiplayer_events.multiplayer_started.connect(func(): multiplayer_started.emit())
	_multiplayer_events.multiplayer_ended.connect(func(): multiplayer_ended.emit())
	_multiplayer_events.skin_selected.connect(func(u, t): skin_selected.emit(u, t))
	_multiplayer_events.skin_reset.connect(func(): skin_reset.emit())

	_gameplay_events.return_to_lobby.connect(func(): return_to_lobby.emit())
	_gameplay_events.language_changed.connect(func(l): set_language.emit(l))
	_gameplay_events.race_started.connect(func(t): race_started.emit(t))
	_gameplay_events.race_ended.connect(func(id, player_name): race_ended.emit(id, player_name))

# =============================================================================
# LEGACY SIGNALS - Deprecated, prefer using domain-specific event buses
# =============================================================================

# UI Events
signal ui_cancel_pressed
signal ui_accept_pressed
signal hide_menu
signal open_terminal_menu
signal terminal_result_ready(error: bool, page: String)
signal set_custom_door(title: String)
signal reset_custom_door
signal quit_requested

# Settings Events
signal _on_fullscreen_toggled(enabled: bool)
signal set_current_room(room: Variant)
signal set_xr_movement_style(style: Variant)
signal set_movement_speed(speed: float)
signal set_xr_rotation_increment(increment: Variant)
signal set_xr_smooth_rotation(enabled: bool)
signal load_xr_settings
signal set_invert_y(enabled: bool)
signal set_mouse_sensitivity(factor: float)
signal set_joypad_deadzone(value: float)

# Multiplayer Events
signal player_joined(peer_id: int, player_name: String)
signal player_left(peer_id: int)
signal multiplayer_started
signal multiplayer_ended
signal skin_selected(url: String, texture: ImageTexture)
signal skin_reset

# Gameplay Events
signal return_to_lobby
signal set_language(language: String)
signal race_started(target_article: String)
signal race_ended(winner_peer_id: int, winner_name: String)

# =============================================================================
# LEGACY EMIT FUNCTIONS - Deprecated, prefer using domain-specific event buses
# =============================================================================

func emit_ui_cancel_pressed() -> void:
	_ui_events.emit_ui_cancel_pressed()

func emit_ui_accept_pressed() -> void:
	_ui_events.emit_ui_accept_pressed()

func emit_hide_menu() -> void:
	_ui_events.emit_hide_menu()

func emit_return_to_lobby() -> void:
	_gameplay_events.emit_return_to_lobby()

func emit_set_current_room(room: Variant) -> void:
	_settings_events.emit_set_current_room(room)

func emit_on_fullscreen_toggled(enabled: bool) -> void:
	_settings_events.emit_fullscreen_toggled(enabled)

func emit_set_xr_movement_style(style: Variant) -> void:
	_settings_events.emit_set_xr_movement_style(style)

func emit_set_movement_speed(speed: float) -> void:
	_settings_events.emit_set_movement_speed(speed)

func emit_set_xr_rotation_increment(increment: Variant) -> void:
	_settings_events.emit_set_xr_rotation_increment(increment)

func emit_set_xr_smooth_rotation(enabled: bool) -> void:
	_settings_events.emit_set_xr_smooth_rotation(enabled)

func emit_load_xr_settings() -> void:
	_settings_events.emit_load_xr_settings()

func emit_open_terminal_menu() -> void:
	_ui_events.emit_open_terminal_menu()

func emit_terminal_result_ready(error: bool, page: String) -> void:
	_ui_events.emit_terminal_result_ready(error, page)

func emit_set_custom_door(title: String) -> void:
	_ui_events.emit_set_custom_door(title)

func emit_reset_custom_door() -> void:
	_ui_events.emit_reset_custom_door()

func emit_set_invert_y(enabled: bool) -> void:
	_settings_events.emit_set_invert_y(enabled)

func emit_set_mouse_sensitivity(factor: float) -> void:
	_settings_events.emit_set_mouse_sensitivity(factor)

func emit_set_joypad_deadzone(value: float) -> void:
	_settings_events.emit_set_joypad_deadzone(value)

func emit_set_language(language: String) -> void:
	_gameplay_events.emit_language_changed(language)

func emit_player_joined(peer_id: int, player_name: String) -> void:
	_multiplayer_events.emit_player_joined(peer_id, player_name)

func emit_player_left(peer_id: int) -> void:
	_multiplayer_events.emit_player_left(peer_id)

func emit_multiplayer_started() -> void:
	_multiplayer_events.emit_multiplayer_started()

func emit_multiplayer_ended() -> void:
	_multiplayer_events.emit_multiplayer_ended()

func emit_skin_selected(url: String, texture: ImageTexture) -> void:
	_multiplayer_events.emit_skin_selected(url, texture)

func emit_skin_reset() -> void:
	_multiplayer_events.emit_skin_reset()

func emit_quit_requested() -> void:
	_ui_events.emit_quit_requested()

func emit_race_started(target_article: String) -> void:
	_gameplay_events.emit_race_started(target_article)

func emit_race_ended(winner_peer_id: int, winner_name: String) -> void:
	_gameplay_events.emit_race_ended(winner_peer_id, winner_name)
