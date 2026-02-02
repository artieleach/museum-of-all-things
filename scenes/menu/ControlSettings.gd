# Code made with love and care by Mymy/TuTiuTe
extends "res://scenes/menu/BaseSettingsPanel.gd"

const ACTION_PANEL = preload("res://scenes/menu/ActionPanel.tscn")

@onready var mapping_container: VBoxContainer = $MappingContainer
@onready var sensitivity_slider: HSlider = $MouseOptions/Sensitivity
@onready var sensitivity_value: Label = $MouseOptions/SensitivityValue
@onready var invert_y: CheckBox = $MouseOptions/InvertY
@onready var deadzone_slider: HSlider = $JoyOptions/Deadzone
@onready var deadzone_value: Label = $JoyOptions/DeadzoneValue

var remappable_actions_str := [
	"move_forward",
	"move_back",
	"strafe_left",
	"strafe_right",
	"jump",
	"crouch",
	"interact",
]
var current_joypad_id := 0

func _ready() -> void:
	_settings_namespace = "control"
	if Platform.is_web():
		_update_web_default_controls()
	populate_map_buttons()
	super._ready()

func _update_web_default_controls() -> void:
	# Change the default for crouch on the web to C rather than CTRL.
	for input_event in InputMap.action_get_events("crouch"):
		if input_event is InputEventKey:
			if input_event.physical_keycode == KEY_CTRL:
				input_event.physical_keycode = KEY_C

func populate_map_buttons() -> void:
	for action_str in remappable_actions_str:
		var action_panel := ACTION_PANEL.instantiate()
		action_panel.action_str = action_str
		action_panel.name = action_str + " Panel"
		mapping_container.add_child(action_panel)
		action_panel.update_action()
		action_panel.joypad_button_updated.connect(joypad_button_update)

func joypad_button_update(event: InputEvent) -> void:
	if current_joypad_id != event.device:
		for action_panel in mapping_container.get_children():
			if action_panel.current_joypad_event.device and\
				action_panel.current_joypad_event.device != event.device:
				action_panel.current_joypad_event.device = event.device
				action_panel.update_action()
	current_joypad_id = event.device

func update_all_maps_label() -> void:
	for action_panel in mapping_container.get_children():
		action_panel.current_keyboard_event = null
		action_panel.current_joypad_event = null
		action_panel.update_action()

func _create_settings_obj() -> Dictionary:
	var bindings_dict := {}
	for action_panel in mapping_container.get_children():
		var save_event_joy := []
		var save_event_key := []

		if action_panel.current_keyboard_event is InputEventKey:
			save_event_key = [0, [action_panel.current_keyboard_event.device, action_panel.current_keyboard_event.keycode,
			action_panel.current_keyboard_event.physical_keycode, action_panel.current_keyboard_event.unicode]]
		elif action_panel.current_keyboard_event is InputEventMouseButton:
			save_event_key = [1, action_panel.current_keyboard_event.button_index]

		if action_panel.current_joypad_event is InputEventJoypadButton:
			save_event_joy = [0, action_panel.current_joypad_event.button_index]
		elif action_panel.current_joypad_event is InputEventJoypadMotion:
			save_event_joy = [1, [action_panel.current_joypad_event.axis, signf(action_panel.current_joypad_event.axis_value)]]

		bindings_dict[action_panel.action_str] = {"key_event" : save_event_key, "joy_event" : save_event_joy}

	return {
		"bindings": bindings_dict,
		"mouse_sensitivity": sensitivity_slider.value,
		"mouse_invert_y": invert_y.button_pressed,
		"joypad_deadzone": deadzone_slider.value,
	}

func _apply_settings(settings: Dictionary) -> void:
	if settings.has("mouse_sensitivity"):
		sensitivity_slider.value = settings.mouse_sensitivity

	if settings.has("mouse_invert_y"):
		invert_y.button_pressed = settings.mouse_invert_y

	if settings.has("joypad_deadzone"):
		deadzone_slider.value = settings.joypad_deadzone

	if settings.has("bindings"):
		var bindings = settings.bindings
		for elt in bindings:
			var action_panel: PanelContainer = mapping_container.get_node_or_null(elt + " Panel")
			if not action_panel:
				continue
			var event_key: InputEvent = null
			var event_joy: InputEvent = null

			var key_event_data = bindings[elt].get("key_event", [])
			var joy_event_data = bindings[elt].get("joy_event", [])

			if key_event_data.size() >= 2 and key_event_data[0] == 0:
				var key_data = key_event_data[1]
				if key_data is Array and key_data.size() >= 4:
					event_key = InputEventKey.new()
					event_key.device = key_data[0]
					event_key.keycode = key_data[1]
					event_key.physical_keycode = key_data[2]
					event_key.unicode = key_data[3]
			elif key_event_data.size() >= 2 and key_event_data[0] == 1:
				event_key = InputEventMouseButton.new()
				event_key.button_index = key_event_data[1]

			if joy_event_data.size() >= 2 and joy_event_data[0] == 0:
				event_joy = InputEventJoypadButton.new()
				event_joy.button_index = joy_event_data[1]
			elif joy_event_data.size() >= 2 and joy_event_data[0] == 1:
				var joy_data = joy_event_data[1]
				if joy_data is Array and joy_data.size() >= 2:
					event_joy = InputEventJoypadMotion.new()
					event_joy.axis = joy_data[0]
					event_joy.axis_value = joy_data[1]

			if event_key:
				action_panel.remap_action_keyboard(event_key, false)
			if event_joy:
				action_panel.remap_action_joypad(event_joy, false)
			action_panel.update_action()

func _on_restore_defaults_button_pressed() -> void:
	InputMap.load_from_project_settings()
	if Platform.is_web():
		_update_web_default_controls()
	update_all_maps_label()
	invert_y.button_pressed = false
	sensitivity_slider.value = 1.0
	deadzone_slider.value = 0.05

func _on_invert_y_toggled(toggled_on: bool) -> void:
	GlobalMenuEvents.emit_set_invert_y(toggled_on)

func _on_sensitivity_value_changed(value: float) -> void:
	sensitivity_value.text = str(int(value * 100)) + "%"
	GlobalMenuEvents.emit_set_mouse_sensitivity(value)

func _on_deadzone_value_changed(value: float) -> void:
	deadzone_value.text = str(int(value * 100)) + "%"
	GlobalMenuEvents.emit_set_joypad_deadzone(value)
