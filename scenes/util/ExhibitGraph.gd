extends Node
## Persistent graph data model tracking exhibit connections and visit history.
## Survives exhibit unloading — used by ExhibitMapOverlay for rendering.

signal graph_changed

var _nodes: Dictionary = {}  # title -> { "visited": bool }
var _edges: Array = []  # [from_title, to_title] pairs
var _edge_set: Dictionary = {}  # "from|to" -> true for dedup
var _visit_history: Array[String] = []
var _layout: Dictionary = {}  # title -> Vector2 (cached radial positions)
var _layout_dirty: bool = true
var _current_room: String = "$Lobby"


func _ready() -> void:
	SettingsEvents.set_current_room.connect(_on_room_changed)
	NetworkManager.peer_connected.connect(_sync_graph_to_peer)
	reset()


func _on_room_changed(room: Variant) -> void:
	var title: String = str(room)
	_current_room = title
	mark_visited(title)


func mark_visited(title: String) -> void:
	if not _nodes.has(title):
		_nodes[title] = { "visited": true }
		_layout_dirty = true
	elif not _nodes[title].visited:
		_nodes[title].visited = true

	if _visit_history.is_empty() or _visit_history[-1] != title:
		_visit_history.append(title)

	graph_changed.emit()


func add_edge(from: String, to: String) -> void:
	var key: String = from + "|" + to
	if _edge_set.has(key):
		return

	_edge_set[key] = true
	_edges.append([from, to])

	if not _nodes.has(from):
		_nodes[from] = { "visited": false }
		_layout_dirty = true
	if not _nodes.has(to):
		_nodes[to] = { "visited": false }
		_layout_dirty = true

	_layout_dirty = true
	graph_changed.emit()

	if NetworkManager.is_multiplayer_active():
		_broadcast_edge.rpc(from, to)


func add_edge_from_network(from: String, to: String) -> void:
	## Adds an edge locally without re-broadcasting. Used by network RPCs.
	var key: String = from + "|" + to
	if _edge_set.has(key):
		return

	_edge_set[key] = true
	_edges.append([from, to])

	if not _nodes.has(from):
		_nodes[from] = { "visited": false }
		_layout_dirty = true
	if not _nodes.has(to):
		_nodes[to] = { "visited": false }
		_layout_dirty = true

	_layout_dirty = true
	graph_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _broadcast_edge(from: String, to: String) -> void:
	add_edge_from_network(from, to)


@rpc("any_peer", "call_remote", "reliable")
func _receive_bulk_edges(edges_packed: PackedStringArray) -> void:
	## Receives a flat array of [from1, to1, from2, to2, ...] pairs.
	for i: int in range(0, edges_packed.size() - 1, 2):
		add_edge_from_network(edges_packed[i], edges_packed[i + 1])


func _sync_graph_to_peer(peer_id: int) -> void:
	## Sends all current edges to a newly connected peer.
	if _edges.is_empty():
		return
	var packed := PackedStringArray()
	for edge: Array in _edges:
		packed.append(edge[0])
		packed.append(edge[1])
	_receive_bulk_edges.rpc_id(peer_id, packed)


func get_current_room() -> String:
	return _current_room


func get_visit_history() -> Array[String]:
	return _visit_history


func get_nodes() -> Dictionary:
	return _nodes


func get_edges() -> Array:
	return _edges


func get_layout() -> Dictionary:
	if _layout_dirty:
		_recalculate_layout()
		_layout_dirty = false
	return _layout


func reset() -> void:
	_nodes.clear()
	_edges.clear()
	_edge_set.clear()
	_visit_history.clear()
	_layout.clear()
	_layout_dirty = true
	_current_room = "$Lobby"
	_nodes["$Lobby"] = { "visited": true }
	_visit_history.append("$Lobby")
	graph_changed.emit()


func _recalculate_layout() -> void:
	## BFS radial tree layout from $Lobby at center.
	_layout.clear()

	if not _nodes.has("$Lobby"):
		return

	# Build adjacency list
	var adj: Dictionary = {}
	for title: String in _nodes:
		adj[title] = []
	for edge: Array in _edges:
		var from: String = edge[0]
		var to: String = edge[1]
		if adj.has(from):
			adj[from].append(to)
		if adj.has(to):
			adj[to].append(from)

	# BFS from $Lobby
	var visited: Dictionary = {}
	var queue: Array = ["$Lobby"]
	visited["$Lobby"] = true
	var levels: Array = []  # Array of Arrays — each level is list of [title, parent]
	var parent_map: Dictionary = {}  # title -> parent_title
	parent_map["$Lobby"] = ""

	while not queue.is_empty():
		var next_queue: Array = []
		var level: Array = []
		for title: String in queue:
			level.append(title)
			for neighbor: String in adj.get(title, []):
				if not visited.has(neighbor):
					visited[neighbor] = true
					parent_map[neighbor] = title
					next_queue.append(neighbor)
		levels.append(level)
		queue = next_queue

	# Place $Lobby at center
	_layout["$Lobby"] = Vector2.ZERO

	if levels.size() <= 1:
		return

	# For each level beyond root, distribute children around their parent
	var ring_radius: float = 1.0
	var children_of: Dictionary = {}  # parent -> [children]

	for title: String in parent_map:
		var par: String = parent_map[title]
		if par == "":
			continue
		if not children_of.has(par):
			children_of[par] = []
		children_of[par].append(title)

	# Assign angular ranges via recursive subdivision
	# Root gets full circle [0, TAU)
	var angle_start: Dictionary = {}  # title -> start angle
	var angle_span: Dictionary = {}  # title -> angular span
	angle_start["$Lobby"] = 0.0
	angle_span["$Lobby"] = TAU

	# Count total descendants for proportional arc allocation
	var descendant_count: Dictionary = {}
	_count_descendants("$Lobby", children_of, descendant_count)

	for level_idx: int in range(1, levels.size()):
		for title: String in levels[level_idx]:
			var par: String = parent_map[title]
			var siblings: Array = children_of.get(par, [])
			var sibling_idx: int = siblings.find(title)
			var par_start: float = angle_start.get(par, 0.0)
			var par_span: float = angle_span.get(par, TAU)

			# Divide parent's arc among children proportionally to their descendant weight
			var total_weight: float = 0.0
			for sib: String in siblings:
				total_weight += descendant_count.get(sib, 1) + 1

			var offset: float = 0.0
			for i: int in sibling_idx:
				var sib: String = siblings[i]
				offset += (descendant_count.get(sib, 1) + 1) / total_weight * par_span

			var my_weight: float = (descendant_count.get(title, 1) + 1) / total_weight * par_span
			angle_start[title] = par_start + offset
			angle_span[title] = my_weight

			var angle: float = par_start + offset + my_weight * 0.5
			var radius: float = ring_radius * level_idx
			_layout[title] = Vector2(cos(angle), sin(angle)) * radius

	# Also place any disconnected nodes (shouldn't happen normally)
	var unplaced_idx: int = 0
	for title: String in _nodes:
		if not _layout.has(title):
			_layout[title] = Vector2(5.0 + unplaced_idx * 0.5, 5.0)
			unplaced_idx += 1


func _count_descendants(title: String, children_of: Dictionary, result: Dictionary) -> int:
	var count: int = 0
	for child: String in children_of.get(title, []):
		count += 1 + _count_descendants(child, children_of, result)
	result[title] = count
	return count
