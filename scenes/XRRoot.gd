extends Node3D
## XR controller setup and input handling.

const TRIGGER_TELEPORT_ACTION: String = "trigger_click"
const THUMBSTICK_TELEPORT_ACTION: String = "thumbstick_up"
const THUMBSTICK_TELEPORT_PRESSED_THRESHOLD: float = 0.8
const THUMBSTICK_TELEPORT_RELEASED_THRESHOLD: float = 0.4

@onready var _left_controller: XRController3D = $XROrigin3D/XRController3D_left
@onready var _right_controller: XRController3D = $XROrigin3D/XRController3D_right

var _thumbstick_teleport_pressed: bool = false
var _menu_active: bool = false
var _movement_style: String = "teleportation"


func _ready() -> void:
	if Platform.is_openxr():
		var interface: XRInterface = XRServer.find_interface("OpenXR")
		print("initializing XR interface OpenXR...")
		if interface and interface.initialize():
			print("initialized")
			# turn the main viewport into an ARVR viewport:
			get_viewport().use_xr = true

			# turn off v-sync
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

			# put our physics in sync with our expected frame rate:
			Engine.physics_ticks_per_second = 90
		else:
			$FailedVrAccept.popup()
			get_tree().paused = true
			return

	if Platform.is_webxr():
		var interface: XRInterface = XRServer.find_interface("WebXR")

		# WebXR is less powerful than when running natively in OpenXR, so target 72 FPS.
		interface.set_display_refresh_rate(72)
		Engine.physics_ticks_per_second = 72

		XRToolsUserSettings.webxr_primary_changed.connect(_on_webxr_primary_changed)
		_on_webxr_primary_changed(XRToolsUserSettings.get_real_webxr_primary())

	# Things we need for both OpenXR and WebXR.
	GlobalMenuEvents.hide_menu.connect(_hide_menu)
	GlobalMenuEvents.set_xr_movement_style.connect(_set_xr_movement_style)
	GlobalMenuEvents.set_movement_speed.connect(_set_xr_movement_speed)
	GlobalMenuEvents.set_xr_rotation_increment.connect(_set_xr_rotation_increment)
	GlobalMenuEvents.set_xr_smooth_rotation.connect(_set_xr_smooth_rotation)
	GlobalMenuEvents.emit_load_xr_settings()
	_left_controller.get_node("FunctionPointer/Laser").visibility_changed.connect(_laser_visible_changed)


func _failed_vr_accept_confirmed() -> void:
	get_tree().quit()


func _on_webxr_primary_changed(webxr_primary: int) -> void:
	# Default to thumbstick.
	if webxr_primary == 0:
		webxr_primary = XRToolsUserSettings.WebXRPrimary.THUMBSTICK

	var action_name: String = XRToolsUserSettings.get_webxr_primary_action(webxr_primary)
	%XRToolsMovementDirect.input_action = action_name
	%XRToolsMovementTurn.input_action = action_name


func _set_xr_movement_style(style: String) -> void:
	_movement_style = style
	if style == "teleportation":
		_left_controller.get_node("FunctionTeleport").enabled = not _menu_active
		_left_controller.get_node("XRToolsMovementDirect").enabled = false
	elif style == "direct":
		_left_controller.get_node("FunctionTeleport").enabled = false
		_left_controller.get_node("XRToolsMovementDirect").enabled = true


func _set_xr_movement_speed(speed: float) -> void:
	_left_controller.get_node("XRToolsMovementDirect").max_speed = speed


func _set_xr_rotation_increment(increment: float) -> void:
	_right_controller.get_node("XRToolsMovementTurn").step_turn_angle = increment


func _set_xr_smooth_rotation(enabled: bool) -> void:
	_right_controller.get_node("XRToolsMovementTurn").turn_mode = XRToolsMovementTurn.TurnMode.SMOOTH if enabled else XRToolsMovementTurn.TurnMode.SNAP


func _laser_visible_changed() -> void:
	if _movement_style == "teleportation":
		_left_controller.get_node("FunctionTeleport").enabled = not _left_controller.get_node("FunctionPointer/Laser").visible


func _hide_menu() -> void:
	_menu_active = false
	_right_controller.get_node("XrMenu").disable_collision()
	_right_controller.get_node("XrMenu").visible = false


func _show_menu() -> void:
	_menu_active = true
	_right_controller.get_node("XrMenu").enable_collision()
	_right_controller.get_node("XrMenu").visible = true


func _physics_process(_delta: float) -> void:
	$XROrigin3D/XRToolsPlayerBody/FootstepPlayer.set_on_floor($XROrigin3D/XRToolsPlayerBody.is_on_floor())


func _toggle_menu() -> void:
	if not _menu_active:
		_show_menu()
	else:
		_hide_menu()


func _on_xr_controller_3d_left_input_vector2_changed(name: String, value: Vector2) -> void:
	var xr_tracker: XRPositionalTracker = XRServer.get_tracker(_left_controller.tracker)

	if _thumbstick_teleport_pressed:
		if value.length() < THUMBSTICK_TELEPORT_RELEASED_THRESHOLD:
			_thumbstick_teleport_pressed = false
			xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, false)

	else:
		if value.y > THUMBSTICK_TELEPORT_PRESSED_THRESHOLD and not _left_controller.is_button_pressed(TRIGGER_TELEPORT_ACTION):
			_thumbstick_teleport_pressed = true
			xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, true)


func _on_xr_controller_3d_left_button_pressed(name: String) -> void:
	if not _thumbstick_teleport_pressed and name == TRIGGER_TELEPORT_ACTION:
		var xr_tracker: XRPositionalTracker = XRServer.get_tracker(_left_controller.tracker)
		xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, true)
	elif name in ["menu_button", "by_button"]:
		_toggle_menu()


func _on_xr_controller_3d_left_button_released(name: String) -> void:
	if not _thumbstick_teleport_pressed and name == TRIGGER_TELEPORT_ACTION:
		var xr_tracker: XRPositionalTracker = XRServer.get_tracker(_left_controller.tracker)
		xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, false)


func _on_xr_controller_3d_right_button_pressed(name: String) -> void:
	if name == "by_button":
		_toggle_menu()


func _on_xr_controller_3d_right_button_released(_name: String) -> void:
	pass
