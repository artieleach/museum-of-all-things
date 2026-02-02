class_name TextUtils
extends RefCounted

static var _html_tag_re: RegEx
static var _display_none_re: RegEx
static var _markup_tag_re: RegEx
static var _curly_tag_re: RegEx
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_html_tag_re = RegEx.new()
	_display_none_re = RegEx.new()
	_markup_tag_re = RegEx.new()
	_curly_tag_re = RegEx.new()
	_display_none_re.compile("<.*?display:\\s*none.*?>.+?<.*?>")
	_html_tag_re.compile("<.+?>")
	_markup_tag_re.compile("\\.\\w.+? ")
	_curly_tag_re.compile("\\{.+?\\}")
	_initialized = true

static func strip_markup(s: String) -> String:
	_ensure_initialized()
	var mid := _curly_tag_re.sub(s, "", true)
	return _markup_tag_re.sub(mid, " ", true)

static func strip_html(s: String) -> String:
	_ensure_initialized()
	var mid := _display_none_re.sub(s, "", true)
	return _html_tag_re.sub(mid, "", true).replace("\n", " ")

static func trim_to_length_sentence(s: String, lim: int) -> String:
	var pos := len(s) - 1
	while true:
		if (s.substr(pos, 2) == ". " or s[pos] == "\n") and pos < lim:
			break
		pos -= 1
		if pos < 0:
			break
	return s.substr(0, pos + 1)

static func resize_text_to_px(label: Label3D, px: float) -> void:
	var msg := TranslationServer.translate(label.text)
	while label.font.get_string_size(msg, label.horizontal_alignment, -1, label.font_size).x > px:
		label.font_size -= 1
