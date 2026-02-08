extends Control
## Renders the exhibit graph as a minimap or full overlay.
## Cycles through: hidden -> minimap -> full -> hidden via cycle_mode().

enum Mode { HIDDEN, MINIMAP, FULL }

const MINIMAP_SIZE := Vector2(250, 250)
const MINIMAP_MARGIN := 10.0
const FULL_MARGIN := 60.0

const MINIMAP_NODE_RADIUS := 6.0
const FULL_NODE_RADIUS := 14.0

const BG_MINIMAP := Color(1, 1, 1, 0.8)
const BG_FULL := Color(0.973, 0.976, 0.98, 0.2)

const COLOR_CURRENT := Color(0.024, 0.271, 0.678)  # Wikipedia blue
const COLOR_VISITED := Color(0.420, 0.294, 0.631)  # Wikipedia purple
const COLOR_UNVISITED := Color(0.784, 0.800, 0.820, 0.5)  # Light gray
const COLOR_EDGE := Color(0.635, 0.663, 0.694, 0.6)
const COLOR_PATH := Color(0.024, 0.271, 0.678, 0.8)  # Blue path
const COLOR_LABEL := Color(0.125, 0.129, 0.133, 0.9)

var _mode: Mode = Mode.HIDDEN
var _mode_before_pause: Mode = Mode.HIDDEN
var _time: float = 0.0

# Font for labels in full mode
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	ExhibitGraph.graph_changed.connect(_on_graph_changed)
	NetworkManager.player_room_changed.connect(_on_player_room_changed)
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	if _mode == Mode.HIDDEN:
		return
	_time += delta
	queue_redraw()


func _on_graph_changed() -> void:
	if _mode != Mode.HIDDEN:
		queue_redraw()


func _on_player_room_changed(_id: int, _room: String) -> void:
	if _mode != Mode.HIDDEN:
		queue_redraw()


func is_full_mode() -> bool:
	return _mode == Mode.FULL


func set_hidden() -> void:
	_mode_before_pause = _mode
	_mode = Mode.HIDDEN
	visible = false
	queue_redraw()


func restore_after_pause() -> void:
	if _mode_before_pause == Mode.MINIMAP:
		_mode = Mode.MINIMAP
		visible = true
		queue_redraw()
	_mode_before_pause = Mode.HIDDEN


func cycle_mode() -> void:
	match _mode:
		Mode.HIDDEN:
			_mode = Mode.MINIMAP
			visible = true
		Mode.MINIMAP:
			_mode = Mode.FULL
		Mode.FULL:
			_mode = Mode.HIDDEN
			visible = false
	queue_redraw()


func _draw() -> void:
	if _mode == Mode.HIDDEN:
		return

	var layout: Dictionary = ExhibitGraph.get_layout()
	if layout.is_empty():
		return

	var nodes: Dictionary = ExhibitGraph.get_nodes()
	var edges: Array = ExhibitGraph.get_edges()
	var history: Array[String] = ExhibitGraph.get_visit_history()
	var current: String = ExhibitGraph.get_current_room()

	var node_radius: float
	var bg_color: Color
	var show_labels: bool
	var viewport_size: Vector2 = get_viewport_rect().size

	match _mode:
		Mode.MINIMAP:
			position = Vector2(MINIMAP_MARGIN, viewport_size.y - MINIMAP_SIZE.y - MINIMAP_MARGIN)
			size = MINIMAP_SIZE
			node_radius = MINIMAP_NODE_RADIUS
			bg_color = BG_MINIMAP
			show_labels = false
		Mode.FULL:
			position = Vector2(FULL_MARGIN, FULL_MARGIN)
			size = viewport_size - Vector2(FULL_MARGIN * 2, FULL_MARGIN * 2)
			node_radius = FULL_NODE_RADIUS
			bg_color = BG_FULL
			show_labels = true

	var is_minimap: bool = _mode == Mode.MINIMAP
	var map_center: Vector2 = size * 0.5
	var map_radius: float = minf(size.x, size.y) * 0.5
	if is_minimap:
		draw_circle(map_center, map_radius, bg_color)

	# Compute transform from graph space to local screen space
	var current_pos: Vector2 = layout.get(current, Vector2.ZERO)
	var graph_bounds := _get_graph_bounds(layout)
	var graph_size: Vector2 = graph_bounds.size
	if graph_size.x < 0.01:
		graph_size.x = 2.0
	if graph_size.y < 0.01:
		graph_size.y = 2.0

	var padding: float = node_radius * 3
	var usable_size: Vector2 = size - Vector2(padding * 2, padding * 2)
	var scale_factor: float = minf(usable_size.x / graph_size.x, usable_size.y / graph_size.y)
	scale_factor = minf(scale_factor, 120.0)
	var center_offset: Vector2 = size * 0.5

	# Build traversal path set for highlighting
	var path_edges: Dictionary = {}
	for i: int in range(1, history.size()):
		var key_a: String = history[i - 1] + "|" + history[i]
		var key_b: String = history[i] + "|" + history[i - 1]
		path_edges[key_a] = true
		path_edges[key_b] = true

	_draw_edges(edges, layout, current_pos, scale_factor, center_offset, path_edges, is_minimap, map_center, map_radius)
	_draw_nodes(nodes, layout, current, current_pos, scale_factor, center_offset, node_radius, is_minimap, map_center, map_radius, show_labels)
	_draw_player_dots(layout, current_pos, scale_factor, center_offset, node_radius, is_minimap, map_center, map_radius)

	if is_minimap:
		draw_arc(map_center, map_radius, 0, TAU, 64, Color(0.635, 0.663, 0.694, 0.5), 1.5, true)


func _draw_edges(edges: Array, layout: Dictionary, current_pos: Vector2, scale_factor: float, center_offset: Vector2, path_edges: Dictionary, is_minimap: bool, map_center: Vector2, map_radius: float) -> void:
	for edge: Array in edges:
		var from: String = edge[0]
		var to: String = edge[1]
		if not layout.has(from) or not layout.has(to):
			continue
		var p1: Vector2 = _graph_to_screen(layout[from], current_pos, scale_factor, center_offset)
		var p2: Vector2 = _graph_to_screen(layout[to], current_pos, scale_factor, center_offset)

		if is_minimap:
			var clipped: Array = _clip_line_to_circle(p1, p2, map_center, map_radius)
			if clipped.is_empty():
				continue
			p1 = clipped[0]
			p2 = clipped[1]

		var key: String = from + "|" + to
		var is_path: bool = path_edges.has(key)
		var edge_color: Color = COLOR_PATH if is_path else COLOR_EDGE
		var edge_width: float = 3.0 if is_path else 1.5
		draw_line(p1, p2, edge_color, edge_width, true)


func _draw_nodes(nodes: Dictionary, layout: Dictionary, current: String, current_pos: Vector2, scale_factor: float, center_offset: Vector2, node_radius: float, is_minimap: bool, map_center: Vector2, map_radius: float, show_labels: bool) -> void:
	for title: String in layout:
		if not nodes.has(title):
			continue
		var screen_pos: Vector2 = _graph_to_screen(layout[title], current_pos, scale_factor, center_offset)

		if is_minimap and screen_pos.distance_to(map_center) > map_radius - node_radius:
			continue

		var color: Color
		if title == current:
			var pulse: float = 0.7 + 0.3 * sin(_time * 3.0)
			color = COLOR_CURRENT
			color.a = pulse
		elif nodes[title].visited:
			color = COLOR_VISITED
		else:
			color = COLOR_UNVISITED

		draw_circle(screen_pos, node_radius, color)

		if show_labels and title != current:
			var label_text: String = _truncate(title, 20)
			var label_pos: Vector2 = screen_pos + Vector2(node_radius + 4, 4)
			draw_string(_font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_LABEL)

		if show_labels and title == current:
			var label_text: String = _truncate(title, 24)
			var label_pos: Vector2 = screen_pos + Vector2(node_radius + 4, 5)
			draw_string(_font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_CURRENT)


func _draw_player_dots(layout: Dictionary, current_pos: Vector2, scale_factor: float, center_offset: Vector2, node_radius: float, is_minimap: bool, map_center: Vector2, map_radius: float) -> void:
	if not NetworkManager.is_multiplayer_active():
		return
	var local_id: int = NetworkManager.get_unique_id()
	var player_list: Array = NetworkManager.get_player_list()
	var peer_index: int = 0
	for peer_id: int in player_list:
		if peer_id == local_id:
			continue
		var room: String = NetworkManager.get_player_room(peer_id)
		if not layout.has(room):
			continue
		var base_pos: Vector2 = _graph_to_screen(layout[room], current_pos, scale_factor, center_offset)

		var orbit_angle: float = _time * 1.5 + peer_index * TAU / maxf(player_list.size() - 1, 1)
		var orbit_offset: Vector2 = Vector2(cos(orbit_angle), sin(orbit_angle)) * (node_radius + 6)
		var dot_pos: Vector2 = base_pos + orbit_offset
		var dot_color: Color = NetworkManager.get_player_color(peer_id)
		if is_minimap and dot_pos.distance_to(map_center) > map_radius - 4.0:
			peer_index += 1
			continue
		draw_circle(dot_pos, 4.0, dot_color)
		peer_index += 1


func _clip_line_to_circle(p1: Vector2, p2: Vector2, center: Vector2, radius: float) -> Array:
	var d1: float = p1.distance_to(center)
	var d2: float = p2.distance_to(center)
	if d1 <= radius and d2 <= radius:
		return [p1, p2]
	var dir: Vector2 = p2 - p1
	var f: Vector2 = p1 - center
	var a: float = dir.dot(dir)
	var b: float = 2.0 * f.dot(dir)
	var c: float = f.dot(f) - radius * radius
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0:
		return []
	var sqrt_disc: float = sqrt(discriminant)
	var t1: float = (-b - sqrt_disc) / (2.0 * a)
	var t2: float = (-b + sqrt_disc) / (2.0 * a)
	var enter: float = maxf(t1, 0.0)
	var exit_t: float = minf(t2, 1.0)
	if enter > exit_t:
		return []
	return [p1 + dir * enter, p1 + dir * exit_t]


func _graph_to_screen(graph_pos: Vector2, camera_center: Vector2, scale_val: float, screen_center: Vector2) -> Vector2:
	return (graph_pos - camera_center) * scale_val + screen_center


func _get_graph_bounds(layout: Dictionary) -> Rect2:
	if layout.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for pos: Vector2 in layout.values():
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)
	# Ensure non-zero size
	if max_pos.x - min_pos.x < 0.01:
		max_pos.x = min_pos.x + 1.0
	if max_pos.y - min_pos.y < 0.01:
		max_pos.y = min_pos.y + 1.0
	return Rect2(min_pos, max_pos - min_pos)


func _truncate(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.left(max_len - 1) + "..."
