class_name Platform
extends RefCounted

static func is_openxr() -> bool:
	return ProjectSettings.get_setting_with_override("xr/openxr/enabled")

static func is_webxr() -> bool:
	var webxr_interface: WebXRInterface = XRServer.find_interface("WebXR")
	return webxr_interface != null and webxr_interface.is_initialized()

static func is_xr() -> bool:
	return is_openxr() or is_webxr()

static func is_web() -> bool:
	return OS.get_name() == "Web"

static func is_mobile() -> bool:
	return OS.has_feature("mobile")

static func is_using_threads() -> bool:
	return OS.has_feature("threads")

static func is_compatibility_renderer() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"

static func is_meta_quest() -> bool:
	return OS.has_feature("meta_quest")

static func get_max_slots_per_exhibit() -> int:
	return Constants.MAX_SLOTS_MOBILE if (is_mobile() or is_web()) else Constants.MAX_SLOTS_DESKTOP
