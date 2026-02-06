extends Node

signal items_complete

var ignore_sections: Array[String] = [
	"references",
	"see also",
	"notes",
	"further reading",
	"external links",
	"external link s",
	"bibliography",
	"gallery",
	"sources",
]

var IMAGE_REGEX: RegEx = RegEx.new()
var s2_re: RegEx = RegEx.new()
var template_re: RegEx = RegEx.new()
var links_re: RegEx = RegEx.new()
var extlinks_re: RegEx = RegEx.new()
var em_re: RegEx = RegEx.new()
var tag_re: RegEx = RegEx.new()
var whitespace_re: RegEx = RegEx.new()
var nl_re: RegEx = RegEx.new()
var alt_re: RegEx = RegEx.new()
var tokenizer: RegEx = RegEx.new()
var image_name_re: RegEx = RegEx.new()
var image_field_re: RegEx = RegEx.new()
var exclude_image_re: RegEx = RegEx.new()

var max_len_soft: int = 1000
var text_item_fmt: String = "[color=black][b][font_size=48]%s[/font_size][/b]\n\n%s"
var section_fmt: String = "[p][b][font_size=36]%s[/font_size][/b][/p]\n\n"
var p_fmt: String = "[p]%s[/p]\n\n"

var processor_thread: Thread
var PROCESSOR_QUEUE: String = "ItemProcessor"

func _ready() -> void:
	IMAGE_REGEX.compile("\\.(png|jpg|jpeg|webp|svg)$")
	s2_re.compile("^==[^=]")
	template_re.compile("\\{\\{.*?\\}\\}")
	links_re.compile("\\[\\[([^|\\]]*?\\|)?(.*?)\\]\\]")
	extlinks_re.compile("\\[http[^\\s]*\\s(.*?)\\]")
	em_re.compile("'{2,}")
	tag_re.compile("<[^>]+>")
	whitespace_re.compile("[\t ]+")
	nl_re.compile("\n+")
	alt_re.compile("alt=(.+?)\\|")
	#image_field_re.compile("(photo|image\\|?)[^_\\|]*?=(.+?)(\\||$)")
	image_field_re.compile("[\\|=]\\s*([^\\n|=]+\\.\\w{,4})")
	#image_field_re.compile("photo")
	tokenizer.compile("[^\\{\\}\\[\\]<>]+|[\\{\\}\\[\\]<>]")
	image_name_re.compile("^([iI]mage:|[fF]ile:)")
	exclude_image_re.compile("\\bicon\\b|\\blogo\\b|blue pencil")

	if Platform.is_using_threads():
		processor_thread = Thread.new()
		processor_thread.start(_processor_thread_loop)

func _exit_tree() -> void:
	WorkQueue.set_quitting()
	if processor_thread:
		processor_thread.wait_to_finish()

func _processor_thread_loop() -> void:
	while not WorkQueue.get_quitting():
		_processor_thread_item()

func _process(_delta: float) -> void:
	if not Platform.is_using_threads():
		_processor_thread_item()

func _processor_thread_item() -> void:
		var item: Variant = WorkQueue.process_queue(PROCESSOR_QUEUE)
		if item:
			_create_items(item[0], item[1], item[2])

func _seeded_shuffle(new_seed: String, arr: Array, bias: bool = false) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(new_seed)
	if not bias:
		CollectionUtils.shuffle(rng, arr)
	else:
		CollectionUtils.biased_shuffle(rng, arr, 2.0)

func _to_link_case(s: String) -> String:
	if len(s) > 0:
		return s[0].to_upper() + s.substr(1)
	else:
		return ""

func _add_text_item(items: Array, title: String, subtitle: String, text: String) -> void:
	if (
		not ignore_sections.has(title.to_lower().strip_edges()) and
		len(text) > 20
	):
		var t: String = ((section_fmt % subtitle) + "\n" + text) if subtitle != "" else text
		items.append({
			"type": "rich_text",
			"material": "marble",
			"text": text_item_fmt % [title, t]
		})

func _clean_section(s: String) -> String:
	return s.replace("=", "").strip_edges()

var trim_filename_front: int = len("File:")
func _clean_filename(s: String) -> String:
	return IMAGE_REGEX.sub(s.substr(trim_filename_front), "")

func _create_text_items(title: String, extract: String) -> Array:
	var items: Array = []
	var lines: PackedStringArray = extract.split("\n")

	var current_title: String = title
	var current_subtitle: String = ""
	var current_text: String = ""
	var current_text_has_content: bool = false

	for line: String in lines:
		var over_lim: bool = len(current_text) > max_len_soft
		if line == "":
			continue
		elif s2_re.search(line):
			if current_text_has_content:
				_add_text_item(items, current_title, current_subtitle, current_text)
			current_title = _clean_section(line)
			current_subtitle = ""
			current_text = ""
			current_text_has_content = false
		else:
			if line.begins_with("="):
				var sec: String = section_fmt % _clean_section(line)
				if len(current_text) + len(sec) > max_len_soft and current_text_has_content:
					_add_text_item(items, current_title, current_subtitle, current_text)
					current_subtitle = _clean_section(line)
					current_text = ""
					current_text_has_content = false
				else:
					current_text += sec
			elif not over_lim:
				var stripped: String = line.strip_edges()
				if len(stripped) > 0:
					current_text_has_content = true
					current_text += p_fmt % stripped

	if current_text_has_content:
		_add_text_item(items, current_title, current_subtitle, current_text)

	return items

func _wikitext_to_extract(wikitext: String) -> String:
	wikitext = template_re.sub(wikitext, "", true)
	wikitext = links_re.sub(wikitext, "$2", true)
	wikitext = extlinks_re.sub(wikitext, "$1", true)
	wikitext = em_re.sub(wikitext, "", true)
	wikitext = tag_re.sub(wikitext, "", true)
	wikitext = whitespace_re.sub(wikitext, " ", true)
	wikitext = nl_re.sub(wikitext, "\n", true)
	return wikitext.strip_edges()

func _parse_wikitext(wikitext: String) -> Array:
	var tokens: Array[RegExMatch] = tokenizer.search_all(wikitext)
	var link: String = ""
	var links: Array = []

	var depth_chars: Dictionary = {
		"<": ">",
		"[": "]",
		"{": "}",
	}

	var depth: Array[String] = []
	var dc: Variant
	var dl: int
	var in_link: bool
	var t: String
	var in_tag: bool
	var tag: String = ""
	var html_tag: Variant = null
	var html: Array[String] = []
	var template: Array[String] = []
	var in_template: bool

	for m: RegExMatch in tokens:
		t = m.get_string(0)
		dc = depth_chars.get(t)
		dl = len(depth)
		in_link = dl > 1 and depth[0] == "]" and depth[1] == "]"
		in_tag = dl > 0 and depth[dl - 1] == ">"
		in_template = dl > 1 and depth[0] == "}" and depth[1] == "}"

		if dc:
			depth.push_back(dc)
		elif dl == 0:
			if html_tag:
				html.append(t)
		elif t == depth[dl - 1]:
			depth.pop_back()
			# recalc whether we're in a link/tag/etc
			# not the nicest looking but it works
			dc = depth_chars.get(t)
			dl = len(depth)
			in_link = dl > 1 and depth[0] == "]" and depth[1] == "]"
			in_tag = dl > 0 and depth[dl - 1] == ">"
			in_template = dl > 1 and depth[0] == "}" and depth[1] == "}"
		elif in_tag:
			tag += t
		elif in_link:
			link += t
		elif in_template:
			template.append(t)

		if not in_link and len(link) > 0:
			links.append(["link", link])
			link = ""

		if not in_template and len(template) > 0:
			links.append(["template", "".join(template)])
			template.clear()

		if not in_tag and len(tag) > 0:
			# we don't handle nested tags for now
			if tag[0] == "!" or tag[len(tag) - 1] == "/":
				pass
			elif not tag[0] == "/":
				html_tag = tag
			else:
				if len(html) > 0 and html_tag.strip_edges().begins_with("gallery"):
					var html_str: String = "".join(html)
					var gallery_lines: PackedStringArray = html_str.split("\n")
					for gallery_line: String in gallery_lines:
						links.append(["link", gallery_line])
				html.clear()
				html_tag = null
			tag = ""

	return links

func commons_images_to_items(title: String, images: Array, extra_text: Array) -> Array:
	var items: Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var material: String = ExhibitStyle.gen_item_material(title)
	var plate: String = ExhibitStyle.gen_plate_style(title)

	rng.seed = hash(title + ":commons_shuffler")
	_seeded_shuffle(title + ":commons_images", images)

	for image: String in images:
		var il: int = len(items)
		if il > 0 and items[il - 1].type != "text":
			if len(extra_text) > 0 and rng.randi() % 2 == 0:
				items.append(extra_text.pop_front())

		if image and IMAGE_REGEX.search(image) and not exclude_image_re.search(image.to_lower()):
			items.append({
				"type": "image",
				"material": material,
				"plate": plate,
				"title": image,
				"text": _clean_filename(image),
			})

	return items

func create_items(title: String, result: Dictionary, prev_title: String = "") -> void:
	WorkQueue.add_item(PROCESSOR_QUEUE, [title, result, prev_title])

func _create_items(title: String, result: Dictionary, prev_title: String) -> void:
	var text_items: Array = []
	var image_items: Array = []
	var doors: Array = []
	var doors_used: Dictionary = {}
	var material: String = ExhibitStyle.gen_item_material(title)
	var plate: String = ExhibitStyle.gen_plate_style(title)

	if result and result.has("wikitext") and result.has("extract"):
		var wikitext: String = result.wikitext

		Util.t_start()
		var links: Array = _parse_wikitext(wikitext)
		Util.t_end("_parse_wikitext")

		# we are using the extract returned from API until my parser works better
		text_items.append_array(_create_text_items(title, result.extract))

		for link_entry: Array in links:
			var type: String = link_entry[0]
			var link: String = link_entry[1]

			var target: String = _to_link_case(image_name_re.sub(link.get_slice("|", 0), "File:"))
			var caption: RegExMatch = alt_re.search(link)

			if target.begins_with("File:") and IMAGE_REGEX.search(target):
				image_items.append({
					"type": "image",
					"material": material,
					"plate": plate,
					"title": target,
					"text": caption.get_string(1) if caption else _clean_filename(target),
				})

			elif type == "template":
				var other_images: Array[RegExMatch] = image_field_re.search_all(link)
				if len(other_images) > 0:
					for img_match: RegExMatch in other_images:
						var image_title: String = image_name_re.sub(img_match.get_string(1), "File:")
						if image_title.find("\n") >= 0:
							print("newline in file name ", image_title)
						if not image_title or not IMAGE_REGEX.search(image_title):
							continue
						if not image_title.begins_with("File:"):
							image_title = "File:" + image_title
						image_items.append({
							"type": "image",
							"material": material,
							"plate": plate,
							"title": image_title,
							"text": caption.get_string(1) if caption else _clean_filename(image_title),
						})

			elif type == "link" and target and target.find(":") < 0:
				var door: String = _to_link_case(target.get_slice("#", 0))
				if not doors_used.has(door) and door != title and door != prev_title and len(door) > 0:
					doors.append(door)
					doors_used[door] = true

	# keep first item and first door intact
	var front_text: Variant = text_items.pop_front()
	var front_door: Variant = doors.pop_front()
	_seeded_shuffle(title + ":text_items", text_items)
	_seeded_shuffle(title + ":image_items", image_items)
	_seeded_shuffle(title + ":doors", doors, true)
	text_items.push_front(front_text)
	doors.push_front(front_door)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(title + ":shuffler")

	# ensure that there aren't too many text items in a row
	var items: Array = []

	if len(text_items) > 0:
		items.append(text_items.pop_front())

	while len(image_items) > 0:
		var il: int = len(items)
		if il > 0 and items[il - 1].type != "text":
			if len(text_items) > 0 and rng.randi() % 2 == 0:
				items.append(text_items.pop_front())
		items.append(image_items.pop_front())

	call_deferred("emit_signal", "items_complete", {
		"title": title,
		"doors": doors,
		"items": items,
		"extra_text": text_items,
	})
