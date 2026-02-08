extends VBoxContainer

signal resume

enum ScaleMode { BILINEAR, FSR1, FSR2 }

var post_processing_options: Array[String] = ["none", "crt"]

# Display options
@onready var scale_mode: OptionButton = %ScaleMode
@onready var fsr_quality: OptionButton = %FSRQuality
@onready var sharpness_scale: HSlider = %SharpnessScale
@onready var sharpness_scale_value: Label = %SharpnessScaleValue
@onready var render_scale: HSlider = %RenderScale
@onready var render_scale_value: Label = %RenderScaleValue
@onready var fullscreen: Button = %Fullscreen

# Light options
@onready var ambient_light: HSlider = %AmbientLight
@onready var ambient_light_value: Label = %AmbientLightValue
@onready var enable_ssil: CheckBox = %EnableSSIL

# Reflection options
@onready var reflection_quality: HSlider = %ReflectionQuality
@onready var reflection_quality_value: Label = %ReflectionQualityValue
@onready var enable_reflections: CheckBox = %EnableReflections

# Fog options
@onready var enable_fog: CheckBox = %EnableFog

# FPS options
@onready var max_fps: HSlider = %MaxFPS
@onready var max_fps_value: Label = %MaxFPSValue
@onready var vsync: CheckBox = %VSync

# Render distance options
@onready var render_distance: HSlider = %RenderDistance
@onready var render_distance_value: Label = %RenderDistanceValue

# Post-processing options
@onready var post_processing_effect: OptionButton = %PostProcessingEffect

var _loaded_settings: bool = false

func _ready() -> void:
	UIEvents.fullscreen_toggled.connect(_on_fullscreen_toggled)
	_load_settings()

	if scale_mode.selected == ScaleMode.BILINEAR:
		get_tree().set_group("fsr_options", "visible", false)
	else:
		render_scale.hide()

func ui_cancel_pressed() -> void:
	if visible:
		call_deferred("_on_resume_pressed")

func _on_visibility_changed() -> void:
	if visible and is_inside_tree():
		_load_settings()
	elif _loaded_settings and not is_visible_in_tree():
		GraphicsManager.save_settings()

func _load_settings() -> void:
	var e = GraphicsManager.get_env()
	_loaded_settings = true

	render_distance.value = GraphicsManager.render_distance_multiplier
	if GraphicsManager.limit_fps:
		max_fps.value = GraphicsManager.fps_limit
	else:
		max_fps.value = max_fps.min_value
	_update_fps_label()
	vsync.button_pressed = GraphicsManager.vsync_enabled
	fullscreen.button_pressed = GraphicsManager.fullscreen
	render_scale.value = GraphicsManager.render_scale
	scale_mode.selected = GraphicsManager.scale_mode
	fsr_quality.selected = GraphicsManager.fsr_quality
	sharpness_scale.value = GraphicsManager.fsr_sharpness
	reflection_quality.value = e.ssr_max_steps
	enable_reflections.button_pressed = e.ssr_enabled
	ambient_light.value = e.ambient_light_energy
	enable_ssil.button_pressed = e.ssil_enabled
	enable_fog.button_pressed = e.fog_enabled
	var post_processing = GraphicsManager.post_processing
	var idx = post_processing_options.find(post_processing)
	post_processing_effect.select(idx if idx >= 0 else 0)

	_update_scaling()

func _on_restore_pressed() -> void:
	GraphicsManager.restore_default_settings()
	_load_settings()

func _on_resume_pressed() -> void:
	GraphicsManager.save_settings()
	resume.emit()

func _on_reflection_quality_value_changed(value: float) -> void:
	GraphicsManager.get_env().ssr_max_steps = int(value)
	reflection_quality_value.text = str(int(value))

func _on_enable_reflections_toggled(toggled_on: bool) -> void:
	GraphicsManager.get_env().ssr_enabled = toggled_on

func _on_enable_ssil_toggled(toggled_on: bool) -> void:
	GraphicsManager.get_env().ssil_enabled = toggled_on

func _on_ambient_light_value_changed(value: float) -> void:
	GraphicsManager.get_env().ambient_light_energy = value
	ambient_light_value.text = "%3.2f" % value

func _on_max_fps_value_changed(value: float) -> void:
	var is_unlimited = value <= max_fps.min_value
	GraphicsManager.enable_fps_limit(not is_unlimited)
	if not is_unlimited:
		GraphicsManager.set_fps_limit(value)
	_update_fps_label()

func _update_fps_label() -> void:
	if max_fps.value <= max_fps.min_value:
		max_fps_value.text = "Unlimited"
	else:
		max_fps_value.text = str(int(max_fps.value))

func _on_vsync_toggled(toggled_on: bool) -> void:
	GraphicsManager.set_vsync_enabled(toggled_on)

func _on_enable_fog_toggled(toggled_on: bool) -> void:
	GraphicsManager.get_env().fog_enabled = toggled_on

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	GraphicsManager.set_fullscreen(toggled_on)
	fullscreen.set_pressed_no_signal(toggled_on)

func _update_scaling() -> void:
	var selected_scale_mode: int = scale_mode.selected
	GraphicsManager.set_scale_mode(selected_scale_mode)

	# Show render scale if bilinear, FSR options otherwise
	render_scale.visible = (selected_scale_mode == ScaleMode.BILINEAR)
	get_tree().set_group("fsr_options", "visible", (selected_scale_mode != ScaleMode.BILINEAR))

	if selected_scale_mode == ScaleMode.BILINEAR:
		GraphicsManager.set_render_scale(render_scale.value)
		return

	# FSR
	if selected_scale_mode == ScaleMode.FSR1:  # FSR 1 has no "ultra performance"
		fsr_quality.set_item_disabled(0, false)
		fsr_quality.set_item_disabled(4, true)
	if selected_scale_mode == ScaleMode.FSR2:  # FSR 2 has no "ultra quality"
		fsr_quality.set_item_disabled(0, true)
		fsr_quality.set_item_disabled(4, false)

	GraphicsManager.set_fsr_quality(fsr_quality.selected)

	var current_scale = get_viewport().scaling_3d_scale
	render_scale.value = current_scale
	render_scale_value.text = "%.0f %%\n" % (current_scale * 100)

func _on_render_scale_value_changed(value: float) -> void:
	render_scale_value.text = "%d %%\n" % (value * 100)
	_update_scaling()

func _on_scale_mode_value_changed(value: int) -> void:
	match value:
		ScaleMode.FSR1:
			fsr_quality.select(0)
		ScaleMode.FSR2:
			fsr_quality.select(1)

	_update_scaling()

func _on_fsr_quality_item_selected(index: int) -> void:
	_update_scaling()

func _on_sharpness_scale_value_changed(value: float) -> void:
	GraphicsManager.set_fsr_sharpness(value)
	sharpness_scale_value.text = str(value)

func _on_post_processing_effect_item_selected(index: int) -> void:
	GraphicsManager.set_post_processing(post_processing_options[index])

func _on_render_distance_value_changed(value: float) -> void:
	render_distance_value.text = "%dm" % int(value * 30)
	GraphicsManager.set_render_distance_multiplier(value)
