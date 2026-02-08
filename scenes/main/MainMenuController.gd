extends Node
class_name MainMenuController
## Handles menu navigation, opening/closing, and navigation stack.

enum Menu { NONE, MAIN, PAUSE, SETTINGS, TERMINAL, MULTIPLAYER }

signal game_start_requested
signal multiplayer_start_requested

var _main: Node = null
var _menu_layer: CanvasLayer = null
var _menu_nav_queue: Array = []


func init(main: Node, canvas_layer: CanvasLayer) -> void:
	_main = main
	_menu_layer = canvas_layer


func get_nav_queue() -> Array:
	return _menu_nav_queue


func open_menu(menu: Menu) -> void:
	_menu_layer.visible = menu != Menu.NONE
	_menu_layer.get_node("MainMenu").visible = menu == Menu.MAIN
	_menu_layer.get_node("PauseMenu").visible = menu == Menu.PAUSE
	_menu_layer.get_node("Settings").visible = menu == Menu.SETTINGS
	_menu_layer.get_node("PopupTerminalMenu").visible = menu == Menu.TERMINAL
	_menu_layer.get_node("MultiplayerMenu").visible = menu == Menu.MULTIPLAYER


func close_menus() -> void:
	open_menu(Menu.NONE)


func open_main_menu() -> void:
	open_menu(Menu.MAIN)


func open_pause_menu() -> void:
	open_menu(Menu.PAUSE)


func open_settings_menu() -> void:
	open_menu(Menu.SETTINGS)


func open_terminal_menu() -> void:
	open_menu(Menu.TERMINAL)


func open_multiplayer_menu() -> void:
	open_menu(Menu.MULTIPLAYER)


func is_menu_visible() -> bool:
	return _menu_layer.visible


func on_main_menu_settings() -> void:
	_menu_nav_queue.append(open_main_menu)
	open_settings_menu()


func on_pause_menu_settings() -> void:
	_menu_nav_queue.append(open_pause_menu)
	open_settings_menu()


func on_main_menu_multiplayer() -> void:
	_menu_nav_queue.append(open_main_menu)
	open_multiplayer_menu()


func on_multiplayer_menu_back() -> void:
	var prev: Callable = _menu_nav_queue.pop_back()
	if prev:
		prev.call()
	else:
		open_main_menu()


func on_settings_back() -> void:
	var prev: Callable = _menu_nav_queue.pop_back()
	if prev:
		prev.call()
	else:
		game_start_requested.emit()


func on_multiplayer_start_game() -> void:
	multiplayer_start_requested.emit()
