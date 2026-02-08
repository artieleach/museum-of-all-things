extends Node

signal change_post_processing(post_processing: String)

const _settings_ns = "graphics"
const _GROUP_MANAGED_LIGHT := &"managed_light"
const _GROUP_MANAGED_LIGHT_SKIP := &"managed_light_skip_direction_test"
const _GROUP_RENDER_DISTANCE := &"render_distance"

# Deprecated: use Constants.MANAGED_LIGHTS_* instead
const MANAGED_LIGHTS_MAX := Constants.MANAGED_LIGHTS_MAX
const MANAGED_LIGHTS_DIRECTION_THRESHOLD := Constants.MANAGED_LIGHTS_DIRECTION_THRESHOLD
const MANAGED_LIGHTS_FREQUENCY := Constants.MANAGED_LIGHTS_FREQUENCY

var _env: WorldEnvironment
var limit_fps: bool = false
var fps_limit: int = 60
var _default_settings_obj: Dictionary
var fullscreen: bool = false
var render_scale: float = 1.0
var scale_mode: int = 0
var fsr_quality: int = 5
var fsr_sharpness: float = 0.2
var post_processing: String = "none"
var render_distance_multiplier: float = 2.5
var vsync_enabled: bool = true
var light_timer: Timer
var _light_tweens: Dictionary = {}

func init() -> void:
	_env = get_tree().get_nodes_in_group("Environment")[0]

	if not _env:
		Log.error("GraphicsManager", "could not load environment node")
		return

	_default_settings_obj = _create_settings_obj()
	var loaded_settings: Variant = SettingsManager.get_settings(_settings_ns)
	if loaded_settings:
		_apply_settings(loaded_settings, _default_settings_obj)

func set_fps_limit(value: float) -> void:
	fps_limit = int(value)
	if limit_fps:
		Engine.set_max_fps(fps_limit)

func set_fullscreen(_fullscreen: bool) -> void:
	fullscreen = _fullscreen
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func set_render_scale(scale: float) -> void:
	render_scale = scale
	get_viewport().scaling_3d_scale = scale

func set_scale_mode(mode: int) -> void:
	scale_mode = mode
	get_viewport().scaling_3d_mode = mode as Viewport.Scaling3DMode

	if mode < 2:
		get_viewport().msaa_3d = Viewport.MSAA_2X
	else:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED

func set_fsr_quality(quality: int) -> void:
	fsr_quality = quality

	match quality:
		0:
			get_viewport().scaling_3d_scale = 1.0 / 1.3
		1:
			get_viewport().scaling_3d_scale = 1.0 / 1.5
		2:
			get_viewport().scaling_3d_scale = 1.0 / 1.7
		3:
			get_viewport().scaling_3d_scale = 1.0 / 2.0
		4:
			get_viewport().scaling_3d_scale = 1.0 / 3.0

func set_fsr_sharpness(sharpness: float) -> void:
	fsr_sharpness = sharpness
	get_viewport().fsr_sharpness = sharpness

func set_post_processing(_post_processing: String) -> void:
	post_processing = _post_processing
	change_post_processing.emit(post_processing)

func enable_fps_limit(enabled: bool) -> void:
	limit_fps = enabled
	if limit_fps:
		Engine.set_max_fps(fps_limit)

func set_render_distance_multiplier(value: float) -> void:
	var last_distance := render_distance_multiplier
	render_distance_multiplier = value
	if not is_equal_approx(last_distance, render_distance_multiplier):
		for node in get_tree().get_nodes_in_group(_GROUP_RENDER_DISTANCE):
			node.visibility_range_end *= render_distance_multiplier / last_distance

func set_vsync_enabled(_vsync_enabled: bool) -> void:
	vsync_enabled = _vsync_enabled
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func _on_node_added(node: Node) -> void:
	if not is_equal_approx(render_distance_multiplier, 1.0):
		if node.is_in_group(_GROUP_RENDER_DISTANCE):
			node.visibility_range_end *= render_distance_multiplier

func get_env() -> Environment:
	# we assume that they modify the settings
	if not _env:
		init()
	return _env.environment

func _apply_settings(s: Dictionary, default: Dictionary = {}) -> void:
	var e: Environment = _env.environment
	for field in ["ssr_enabled", "ssr_max_steps", "fog_enabled", "ssil_enabled", "ambient_light_energy"]:
		e[field] = s[field] if s.has(field) else default[field]
	set_vsync_enabled(s["vsync_enabled"] if s.has("vsync_enabled") else default["vsync_enabled"])
	set_fps_limit(s["fps_limit"] if s.has("fps_limit") else default["fps_limit"])
	enable_fps_limit(s["limit_fps"] if s.has("limit_fps") else default["limit_fps"])
	set_fullscreen(s["fullscreen"] if s.has("fullscreen") else default["fullscreen"])
	set_fsr_sharpness(s["fsr_sharpness"] if s.has("fsr_sharpness") else default["fsr_sharpness"])
	set_post_processing(s["post_processing"] if s.has("post_processing") else default["post_processing"])

	var mode: int = s["scale_mode"] if s.has("scale_mode") else default["scale_mode"]
	set_scale_mode(mode)
	if mode > 0:
		set_fsr_quality(s["fsr_quality"] if s.has("fsr_quality") else default["fsr_quality"])
	else:
		set_render_scale(s["render_scale"] if s.has("render_scale") else default["render_scale"])

	set_render_distance_multiplier(s["render_distance_multiplier"] if s.has("render_distance_multiplier") else default["render_distance_multiplier"])

func _create_settings_obj() -> Dictionary:
	var e: Environment = _env.environment
	return {
		"ambient_light_energy": e.ambient_light_energy,
		"ssr_enabled": e.ssr_enabled,
		"ssr_max_steps": e.ssr_max_steps,
		"ssil_enabled": e.ssil_enabled,
		"fog_enabled": e.fog_enabled,
		"fps_limit": fps_limit,
		"limit_fps": limit_fps,
		"fullscreen": fullscreen,
		"render_scale": render_scale,
		"scale_mode": scale_mode,
		"fsr_quality": fsr_quality,
		"fsr_sharpness": fsr_sharpness,
		"post_processing": post_processing,
		"vsync_enabled": vsync_enabled,
		"render_distance_multiplier": render_distance_multiplier,
	}

func restore_default_settings() -> void:
	_apply_settings(_default_settings_obj)

func save_settings() -> void:
	SettingsManager.save_settings(_settings_ns, _create_settings_obj())

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

	# When using the compatibility renderer, we need to manage the number of lights.
	if Platform.is_compatibility_renderer():
		light_timer = Timer.new()
		add_child(light_timer)
		light_timer.wait_time = MANAGED_LIGHTS_FREQUENCY
		light_timer.timeout.connect(_manage_lights)
		light_timer.start()

func _manage_lights() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var lights = get_tree().get_nodes_in_group(_GROUP_MANAGED_LIGHT)

	var light_data := []
	for light in lights:
		var p: Vector3 = light.global_position

		# For spotlights, we check a spot half the range in front of the light.
		if light is SpotLight3D:
			p = p + (-light.global_transform.basis.z * (light.spot_range / 2.0))

		var v: Vector3 = p - camera.global_position

		if not light.is_in_group(_GROUP_MANAGED_LIGHT_SKIP):
			var camera_dot = v.normalized().dot(-camera.global_transform.basis.z)
			if camera_dot < MANAGED_LIGHTS_DIRECTION_THRESHOLD:
				# This light is behind the player, so turn it off, and move on.
				_toggle_managed_light(light, false)
				continue

		var d := {
			'light': light,
			'distance': v.length(),
		}
		light_data.push_back(d)

	light_data.sort_custom(func (a, b): return a['distance'] < b['distance'])

	var enabled := 0
	for d in light_data:
		var light: Light3D = d['light']
		if enabled < MANAGED_LIGHTS_MAX:
			_toggle_managed_light(light, true)
			enabled += 1
		else:
			_toggle_managed_light(light, false)

	print_verbose("Enabled %s lights out of %s total" % [enabled, lights.size()])

func _toggle_managed_light(light: Light3D, enable: bool) -> void:
	if light.visible == enable:
		return

	var light_id: int = light.get_instance_id()
	if _light_tweens.has(light_id) and _light_tweens[light_id].is_valid():
		_light_tweens[light_id].kill()

	var tween := get_tree().create_tween().bind_node(light)
	_light_tweens[light_id] = tween
	var light_energy: float = light.light_energy

	if is_zero_approx(light_energy):
		light_energy = 3.0

	if enable:
		light.light_energy = 0.0
		light.visible = true

	tween.tween_property(light, "light_energy", light_energy if enable else 0.0, MANAGED_LIGHTS_FREQUENCY * 0.5)
	tween.tween_callback(func ():
		_light_tweens.erase(light_id)
		if not is_instance_valid(light):
			return
		light.visible = enable
		light.light_energy = light_energy
	)
