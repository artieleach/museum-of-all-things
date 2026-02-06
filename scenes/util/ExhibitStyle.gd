class_name ExhibitStyle
extends RefCounted

static var FLOOR_LIST: Array[int] = [Constants.FLOOR_WOOD, Constants.FLOOR_MARBLE, Constants.FLOOR_CARPET]
static var FOG_LIST: Array[Color] = [Color.WHITE, Color.WHITE, Color.BLACK]
static var ITEM_MATERIAL_LIST: Array[String] = ["wood", "marble", "none"]
static var PLATE_STYLE_LIST: Array[String] = ["white", "black"]

static func gen_floor(title: String) -> int:
	return FLOOR_LIST[hash(title) % len(FLOOR_LIST)]

static func gen_fog(title: String) -> Color:
	return FOG_LIST[hash(title) % len(FOG_LIST)]

static func gen_item_material(title: String) -> String:
	return ITEM_MATERIAL_LIST[hash(title + ":material") % len(ITEM_MATERIAL_LIST)]

static func gen_plate_style(title: String) -> String:
	var material := gen_item_material(title)
	if material == "none":
		return "white"
	return PLATE_STYLE_LIST[hash(title + ":plate") % len(PLATE_STYLE_LIST)]
