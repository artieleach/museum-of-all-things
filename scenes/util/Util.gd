extends Node

## Util - DEPRECATED facade
##
## This autoload exists for backwards compatibility. Prefer using the focused
## utility classes directly:
## - Platform: is_xr, is_web, is_mobile, is_using_threads, etc.
## - GridUtils: vecToRot, gridToWorld, worldToGrid, cell_neighbors, etc.
## - TextUtils: strip_markup, strip_html, trim_to_length_sentence, resizeTextToPx
## - ExhibitStyle: gen_floor, gen_fog, gen_item_material, gen_plate_style
## - CollectionUtils: shuffle, biased_shuffle
## - Constants: FLOOR_*, GRID_CELL_SIZE, etc.

# =============================================================================
# LEGACY CONSTANTS - Deprecated, use Constants class
# =============================================================================

const FLOOR_WOOD := Constants.FLOOR_WOOD
const FLOOR_CARPET := Constants.FLOOR_CARPET
const FLOOR_MARBLE := Constants.FLOOR_MARBLE

# =============================================================================
# LEGACY GRID FUNCTIONS - Deprecated, use GridUtils class
# =============================================================================

func vecToRot(vec: Vector3) -> float:
	return GridUtils.vec_to_rot(vec)

func vecToOrientation(grid: Variant, vec: Vector3) -> int:
	return GridUtils.vec_to_orientation(grid, vec)

func gridToWorld(vec: Vector3) -> Vector3:
	return GridUtils.grid_to_world(vec)

func worldToGrid(vec: Vector3) -> Vector3:
	return GridUtils.world_to_grid(vec)

func cell_neighbors(grid: Variant, pos: Vector3, id: int) -> Array[Vector3]:
	return GridUtils.cell_neighbors(grid, pos, id)

func only_types_in_cells(grid: Variant, cells: Array, types: Array, p: bool = false) -> bool:
	return GridUtils.only_types_in_cells(grid, cells, types, p)

func safe_overwrite(grid: Variant, pos: Vector3) -> bool:
	return GridUtils.safe_overwrite(grid, pos)

# =============================================================================
# LEGACY TEXT FUNCTIONS - Deprecated, use TextUtils class
# =============================================================================

func resizeTextToPx(t: Label3D, px: float) -> void:
	TextUtils.resize_text_to_px(t, px)

func strip_markup(s: String) -> String:
	return TextUtils.strip_markup(s)

func strip_html(s: String) -> String:
	return TextUtils.strip_html(s)

func trim_to_length_sentence(s: String, lim: int) -> String:
	return TextUtils.trim_to_length_sentence(s, lim)

# =============================================================================
# LEGACY PLATFORM FUNCTIONS - Deprecated, use Platform class
# =============================================================================

func is_openxr() -> bool:
	return Platform.is_openxr()

func is_webxr() -> bool:
	return Platform.is_webxr()

func is_xr() -> bool:
	return Platform.is_xr()

func is_web() -> bool:
	return Platform.is_web()

func is_mobile() -> bool:
	return Platform.is_mobile()

func is_using_threads() -> bool:
	return Platform.is_using_threads()

func is_compatibility_renderer() -> bool:
	return Platform.is_compatibility_renderer()

func is_meta_quest() -> bool:
	return Platform.is_meta_quest()

func get_max_slots_per_exhibit() -> int:
	return Platform.get_max_slots_per_exhibit()

# =============================================================================
# LEGACY EXHIBIT STYLE FUNCTIONS - Deprecated, use ExhibitStyle class
# =============================================================================

var FLOOR_LIST: Array[int]:
	get: return ExhibitStyle.FLOOR_LIST
var FOG_LIST: Array[Color]:
	get: return ExhibitStyle.FOG_LIST
var ITEM_MATERIAL_LIST: Array[String]:
	get: return ExhibitStyle.ITEM_MATERIAL_LIST
var PLATE_STYLE_LIST: Array[String]:
	get: return ExhibitStyle.PLATE_STYLE_LIST

func gen_floor(title: String) -> int:
	return ExhibitStyle.gen_floor(title)

func gen_fog(title: String) -> Color:
	return ExhibitStyle.gen_fog(title)

func gen_item_material(title: String) -> String:
	return ExhibitStyle.gen_item_material(title)

func gen_plate_style(title: String) -> Variant:
	return ExhibitStyle.gen_plate_style(title)

# =============================================================================
# LEGACY COLLECTION FUNCTIONS - Deprecated, use CollectionUtils class
# =============================================================================

func shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	CollectionUtils.shuffle(rng, arr)

func biased_shuffle(rng: RandomNumberGenerator, arr: Array, sd_to_start: float) -> void:
	CollectionUtils.biased_shuffle(rng, arr, sd_to_start)

# =============================================================================
# CORE UTIL FUNCTIONS - Keep here as they're general-purpose
# =============================================================================

func coalesce(a: Variant, b: Variant) -> Variant:
	return a if a else b

func clear_listeners(n: Node, sig_name: String) -> void:
	var list := n.get_signal_connection_list(sig_name)
	for c in list:
		c.signal.disconnect(c.callable)

func normalize_url(url: String) -> String:
	if url.begins_with("//"):
		return "https:" + url
	else:
		return url

func delay_msec(msecs: int) -> void:
	# Will only delay if we're not on the main thread.
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		return
	OS.delay_msec(msecs)

# =============================================================================
# TIMING UTILITIES
# =============================================================================

var _time_start: int = 0

func t_start() -> void:
	_time_start = Time.get_ticks_usec()

func t_end(msg: String) -> void:
	var _time_end := Time.get_ticks_usec()
	var elapsed := _time_end - _time_start
	print("elapsed=%s msg=%s" % [elapsed / 1000000.0, msg])
