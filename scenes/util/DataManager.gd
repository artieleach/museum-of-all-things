extends Node

signal loaded_image(url: String, image: Image)
signal image_load_error(url: String, error: String)

const COMMON_HEADERS: Array[String] = ["accept: image/png, image/jpeg; charset=utf-8"]
const TEXTURE_QUEUE: String = "Textures"
const TEXTURE_FRAME_PACING: int = 6
const SUPPORTED_IMAGE_FORMATS: Array[String] = ["PNG", "JPEG", "SVG", "WebP"]

var _in_flight: Dictionary = {}
var _xr: bool = false
var _fs_lock := Mutex.new()
var _texture_load_thread_pool_size: int = 5
var _texture_load_thread_pool: Array[Thread] = []

func _ready() -> void:
	_xr = Platform.is_xr()
	WorkQueue.setup_queue(TEXTURE_QUEUE, TEXTURE_FRAME_PACING)

	if not Platform.is_web():
		var cache_dir: String = CacheControl.cache_dir
		var dir := DirAccess.open(cache_dir)
		if not dir:
			var err := DirAccess.make_dir_recursive_absolute(cache_dir)
			if err != OK:
				push_error("DataManager: Failed to create cache directory '%s': %s" % [cache_dir, error_string(err)])
			elif OS.is_debug_build():
				print("cache directory created at '%s'" % cache_dir)

	if Platform.is_using_threads():
		for _i in range(_texture_load_thread_pool_size):
			var thread := Thread.new()
			thread.start(_texture_load_thread_loop)
			_texture_load_thread_pool.append(thread)

func _exit_tree():
	WorkQueue.set_quitting()
	for thread in _texture_load_thread_pool:
		thread.wait_to_finish()

func _texture_load_thread_loop():
	while not WorkQueue.get_quitting():
		_texture_load_item()

func _process(_delta: float) -> void:
	if not Platform.is_using_threads():
		_texture_load_item()

func _texture_load_item():
	var item = WorkQueue.process_queue(TEXTURE_QUEUE)
	if not item:
		return

	match item.type:
		"request":
				var data = _read_url(item.url)

				if data:
					_load_image(item.url, data, item.ctx)
				else:
					var request_url = item.url
					request_url += ('&' if '?' in request_url else '?') + "origin=*"

					var handle_result = func(result):
						if result[0] != OK:
							push_error("failed to fetch image ", result[1], " ", item.url)
						else:
							data = result[3]
							_write_url(item.url, data)
							_load_image(item.url, data, item.ctx)

					if Platform.is_web():
						RequestSync.request_async(request_url, COMMON_HEADERS).completed.connect(handle_result)
					else:
						handle_result.call(RequestSync.request(request_url, COMMON_HEADERS))

		"load":
			var data: PackedByteArray = item.data

			var fmt := _detect_image_type(data)
			if fmt not in SUPPORTED_IMAGE_FORMATS:
				_emit_error(item.url, "Unsupported image format: %s" % fmt)
				return

			var image := Image.new()
			var err: Error = OK
			match fmt:
				"PNG":
					err = image.load_png_from_buffer(data)
				"JPEG":
					err = image.load_jpg_from_buffer(data)
				"SVG":
					err = image.load_svg_from_buffer(data)
				"WebP":
					err = image.load_webp_from_buffer(data)

			if err != OK:
				_emit_error(item.url, "Failed to load %s image: %s" % [fmt, error_string(err)])
				return

			if image.get_width() == 0:
				_emit_error(item.url, "Image has zero width")
				return

			_generate_mipmaps(item.url, image, item.ctx)

		"generate_mipmaps":
			var image = item.image
			image.generate_mipmaps()
			_create_and_emit_texture(item.url, image, item.ctx)

		"create_and_emit_texture":
			var texture = ImageTexture.create_from_image(item.image)
			_emit_image(item.url, texture, item.ctx)

func _get_hash(input: String) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(input.to_utf8_buffer())
	var hash_result = context.finish()
	return hash_result.hex_encode()

func _detect_image_type(data: PackedByteArray) -> String:
	if data.size() < 8:
		return "Unknown"	# Insufficient data to determine type

	# Convert to hexadecimal strings for easy comparison
	var header = data.slice(0, 8)
	var hex_header = ""
	for byte in header:
		hex_header += ("%02x" % byte).to_lower()

	# Check PNG signature
	if hex_header.begins_with("89504e470d0a1a0a"):
		return "PNG"

	# Check JPEG signature
	if hex_header.begins_with("ffd8ff"):
		return "JPEG"

	# Check WebP signature (RIFF and WEBP)
	if hex_header.begins_with("52494646"):	# "RIFF"
		if data.size() >= 12:
			var riff_type = data.slice(8, 12).get_string_from_ascii()
			if riff_type == "WEBP":
				return "WebP"

	# Check SVG (look for '<?xml' or '<svg')
	if data.size() >= 5:
		var xml_start = data.slice(0, 5).get_string_from_utf8()
		if xml_start.begins_with("<?xml") or xml_start.begins_with("<svg"):
			return "SVG"
	return "Unknown"

func _write_url(url: String, data: PackedByteArray) -> Error:
	if Platform.is_web():
		return ERR_UNAVAILABLE
	_fs_lock.lock()
	var filename := _get_hash(url)
	var file_path: String = CacheControl.cache_dir + filename
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if not f:
		var err := FileAccess.get_open_error()
		push_error("DataManager: Failed to write file '%s': %s" % [file_path, error_string(err)])
		_fs_lock.unlock()
		return err
	f.store_buffer(data)
	f.close()
	_fs_lock.unlock()
	return OK

func _read_url(url: String) -> Variant:
	if Platform.is_web():
		return null
	_fs_lock.lock()
	var filename := _get_hash(url)
	var file_path : String = CacheControl.cache_dir + filename
	var f := FileAccess.open(file_path, FileAccess.READ)
	if not f:
		_fs_lock.unlock()
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	_fs_lock.unlock()
	return data

func _url_exists(url: String) -> bool:
	if Platform.is_web():
		return false
	_fs_lock.lock()
	var filename := _get_hash(url)
	var res := FileAccess.file_exists(CacheControl.cache_dir + filename)
	_fs_lock.unlock()
	return res

func load_json_data(url: String) -> Variant:
	var data: Variant = _read_url(url)
	if not data:
		return null
	var json_str: String = data.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_str)
	if parsed == null and not json_str.is_empty():
		push_error("DataManager: Failed to parse JSON from cache for '%s'" % url)
	return parsed

func save_json_data(url: String, json: Dictionary) -> Error:
	if Platform.is_web():
		return ERR_UNAVAILABLE
	var data := JSON.stringify(json).to_utf8_buffer()
	return _write_url(url, data)

func _emit_image(url: String, texture: ImageTexture, ctx: Variant) -> void:
	if texture == null:
		return
	call_deferred("emit_signal", "loaded_image", url, texture, ctx)

func _emit_error(url: String, error_msg: String) -> void:
	call_deferred("emit_signal", "image_load_error", url, error_msg)

func request_image(url: String, ctx: Variant = null) -> void:
	WorkQueue.add_item(TEXTURE_QUEUE, {
		"type": "request",
		"url": url,
		"ctx": ctx
	})

func _load_image(url: String, data: PackedByteArray, ctx: Variant = null) -> void:
	WorkQueue.add_item(TEXTURE_QUEUE, {
		"type": "load",
		"url": url,
		"data": data,
		"ctx": ctx,
	}, null, true)

func _generate_mipmaps(url: String, image: Image, ctx: Variant = null) -> void:
	WorkQueue.add_item(TEXTURE_QUEUE, {
		"type": "generate_mipmaps",
		"url": url,
		"image": image,
		"ctx": ctx,
	}, null, true)

func _create_and_emit_texture(url: String, image: Image, ctx: Variant = null) -> void:
	WorkQueue.add_item(TEXTURE_QUEUE, {
		"type": "create_and_emit_texture",
		"url": url,
		"image": image,
		"ctx": ctx,
	}, null, true)
