class_name PathMapView
extends Control

## The Crown Road: a night-time journey map drawn in code. Nodes are icon medallions
## joined by winding roads, the player's king stands on the current node and hops along
## the road when a new node is chosen. Display only; route rules live in RunManager.

signal node_selected(node_id: StringName)
signal token_arrived

const VIEW_WIDTH := 328.0
const LAYER_HEIGHT := 92.0
const TOP_SPACE := 104.0
const BOTTOM_SPACE := 84.0
const NODE_RADIUS := 21.0
const BOSS_RADIUS := 27.0
const HIT_SIZE := Vector2(60, 66)
const ICON_PIXEL := 2.0
const TRAVEL_SECONDS := 0.55

const SKY_TOP := Color("#1a2744")
const SKY_LOW := Color("#0c1826")
const GROUND := Color("#0b1620")
const SILHOUETTE := Color("#070d16")
const TREE := Color("#0f2230")
const ROAD_LOCKED := Color("#2c4054")
const ROAD_OPEN := Color("#f3dc8c")
const ROAD_WALKED := Color("#d9b85a")
const GOLD := Color("#f1c75c")
const CREAM := Color("#fff3d2")

const ICONS := {
	&"normal_battle": [
		"........##",
		".......###",
		"......###.",
		".....###..",
		"#...###...",
		"##.###....",
		".####.....",
		"..###.....",
		".##.##....",
		"##...#....",
	],
	&"elite_battle": [
		"..######..",
		".########.",
		"##########",
		"##..##..##",
		"##..##..##",
		"##########",
		".###..###.",
		"..######..",
		"..#.##.#..",
		"..#.##.#..",
	],
	&"shop": [
		"...#..#...",
		"....##....",
		"...####...",
		"..######..",
		".########.",
		".###..###.",
		".##.##.##.",
		".###..###.",
		".########.",
		"..######..",
	],
	&"event": [
		"..######..",
		".###..###.",
		".##....##.",
		".......##.",
		".....###..",
		"....###...",
		"....##....",
		"..........",
		"....##....",
		"....##....",
	],
	&"rest": [
		"....#.....",
		"...##.....",
		"...###.#..",
		"..####.##.",
		"..#######.",
		".###.####.",
		".##...###.",
		"..##.###..",
		"#..####..#",
		".########.",
	],
	&"boss": [
		"....##....",
		"#...##...#",
		"##.####.##",
		"##########",
		"##########",
		"##########",
		"..........",
		"##########",
		"##########",
		"..........",
	],
}

var map_state: MapState = null
var available_node_ids: Array[StringName] = []
var visited_node_ids: Array[StringName] = []
var current_node_id: StringName = &""

var _centers: Dictionary = {}
## Nodes the player can still reach from where they stand.
var _reachable: Dictionary = {}
var _camp: Vector2 = Vector2.ZERO
var _trees: PackedVector2Array = PackedVector2Array()
var _stars: PackedVector2Array = PackedVector2Array()
var _time: float = 0.0
var _token_texture: Texture2D = null
var _token_node: StringName = &"__unset__"
var _travel_from: Vector2 = Vector2.ZERO
var _travel_to: Vector2 = Vector2.ZERO
var _travel_progress: float = 1.0

func _ready() -> void:
	var skins: Node = get_node_or_null("/root/PieceSkinManager")
	if skins != null:
		_token_texture = skins.call("piece_texture", &"white", &"king") as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_rebuild)

func display_map(
	value: MapState,
	available_ids: Array[StringName],
	visited_ids: Array[StringName],
	current_id: StringName
) -> void:
	var first_display: bool = map_state == null or _token_node == &"__unset__"
	var previous_stand: Vector2 = _token_stand(_token_node) if not first_display else Vector2.ZERO
	map_state = value
	available_node_ids = available_ids.duplicate()
	visited_node_ids = visited_ids.duplicate()
	current_node_id = current_id
	_rebuild()
	if not first_display and current_id != _token_node:
		_travel_from = previous_stand
		_travel_to = _token_stand(current_id)
		_travel_progress = 0.0
	_token_node = current_id

func is_travelling() -> bool:
	return _travel_progress < 1.0

func node_vertical_center(node_id: StringName) -> float:
	if node_id.is_empty():
		return _camp.y
	return (_centers.get(node_id, _camp) as Vector2).y

func node_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in get_children():
		if child is Button and child.is_in_group("map_node_cards") and not child.is_queued_for_deletion():
			result.append(child as Button)
	return result

# --- layout -----------------------------------------------------------------

func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	_centers.clear()
	if map_state == null:
		custom_minimum_size = Vector2(VIEW_WIDTH, 0)
		queue_redraw()
		return
	var width: float = maxf(size.x, VIEW_WIDTH)
	var height: float = TOP_SPACE + map_state.total_layers * LAYER_HEIGHT + BOTTOM_SPACE
	custom_minimum_size = Vector2(VIEW_WIDTH, height)
	_camp = Vector2(width * 0.5, height - 34.0)
	for node: MapNodeState in map_state.nodes:
		var center: Vector2 = _node_center(node, map_state.nodes_in_layer(node.layer_index).size(), width)
		_centers[node.node_id] = center
		var button: Button = _create_node_button(node)
		button.position = center - HIT_SIZE * 0.5 + Vector2(0.0, 4.0)
		button.size = HIT_SIZE
		add_child(button)
	_scatter_scenery(width, height)
	_find_reachable()
	queue_redraw()

func _find_reachable() -> void:
	_reachable.clear()
	var frontier: Array[StringName] = []
	if current_node_id.is_empty():
		for node: MapNodeState in map_state.nodes_in_layer(0):
			frontier.append(node.node_id)
	else:
		frontier.append(current_node_id)
	while not frontier.is_empty():
		var node_id: StringName = frontier.pop_back()
		if _reachable.has(node_id):
			continue
		_reachable[node_id] = true
		var node: MapNodeState = map_state.get_node(node_id)
		if node != null:
			for target_id: StringName in node.outgoing_node_ids:
				frontier.append(target_id)

func _node_center(node: MapNodeState, layer_node_count: int, width: float) -> Vector2:
	var display_layer: int = map_state.total_layers - 1 - node.layer_index
	var y_position: float = TOP_SPACE + (display_layer + 0.5) * LAYER_HEIGHT
	if node.layer_index == map_state.total_layers - 1:
		return Vector2(width * 0.5, TOP_SPACE + LAYER_HEIGHT * 0.3)
	var usable: float = width - 72.0
	var x_position: float = 36.0 + usable * (float(node.lane_index) + 0.5) / float(layer_node_count)
	# A stable per-node nudge so the road winds instead of sitting on a grid.
	var seed_value: int = hash(String(node.node_id))
	var nudge: Vector2 = Vector2(float(seed_value % 23) - 11.0, float((seed_value / 23) % 19) - 9.0)
	return Vector2(x_position, y_position) + nudge

func _scatter_scenery(width: float, height: float) -> void:
	_trees = PackedVector2Array()
	_stars = PackedVector2Array()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(map_state.map_id))
	for _index: int in range(34):
		_stars.append(Vector2(rng.randf_range(4.0, width - 4.0), rng.randf_range(2.0, TOP_SPACE + 60.0)))
	for _index: int in range(90):
		var spot: Vector2 = Vector2(rng.randf_range(8.0, width - 8.0), rng.randf_range(TOP_SPACE + 30.0, height - 12.0))
		var clear: bool = spot.distance_to(_camp) > 46.0
		for center: Variant in _centers.values():
			if spot.distance_to(center as Vector2) < NODE_RADIUS + 20.0:
				clear = false
				break
		if clear:
			_trees.append(spot)

func _create_node_button(node: MapNodeState) -> Button:
	var definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id)
	var button: Button = Button.new()
	button.name = "Node_%s" % String(node.node_id).get_file()
	button.add_to_group("map_node_cards")
	button.set_meta("node_id", node.node_id)
	button.set_meta("node_type_id", node.node_type_id)
	button.set_meta("layer_index", node.layer_index)
	button.focus_mode = Control.FOCUS_ALL
	# Let drags pass through to the scroll container so the map scrolls under a finger.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.disabled = node.node_id not in available_node_ids
	button.tooltip_text = "%s\n%s\n%s" % [
		_text(String(definition.display_name_key)),
		_text(String(definition.enemy_hint_key)),
		_text(String(definition.reward_hint_key)),
	]
	# The medallion is drawn by this view; the button is only the touch target.
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus.border_color = Color(GOLD, 0.8)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(func() -> void: node_selected.emit(node.node_id))
	return button

# --- animation --------------------------------------------------------------

func _process(delta: float) -> void:
	if map_state == null or not is_visible_in_tree():
		return
	_time += delta
	if _travel_progress < 1.0:
		_travel_progress = minf(1.0, _travel_progress + delta / TRAVEL_SECONDS)
		if _travel_progress >= 1.0:
			token_arrived.emit()
	queue_redraw()

func _token_stand(node_id: StringName) -> Vector2:
	if node_id.is_empty() or not _centers.has(node_id):
		return _camp + Vector2(-26.0, 6.0)
	return (_centers[node_id] as Vector2) + Vector2(-_radius_of(node_id) * 0.95, 8.0)

func _radius_of(node_id: StringName) -> float:
	var node: MapNodeState = map_state.get_node(node_id) if map_state != null else null
	return BOSS_RADIUS if node != null and node.node_type_id == &"boss" else NODE_RADIUS

# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	if map_state == null:
		return
	_draw_backdrop()
	_draw_roads()
	for node: MapNodeState in map_state.nodes:
		_draw_medallion(node)
	_draw_token()

func _draw_backdrop() -> void:
	var width: float = maxf(size.x, VIEW_WIDTH)
	var height: float = custom_minimum_size.y
	var sky_height: float = TOP_SPACE + 70.0
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(width, 0.0), Vector2(width, sky_height), Vector2(0.0, sky_height)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	draw_polygon(
		PackedVector2Array([Vector2(0.0, sky_height), Vector2(width, sky_height), Vector2(width, height), Vector2(0.0, height)]),
		PackedColorArray([SKY_LOW, SKY_LOW, GROUND, GROUND]))
	for index: int in range(_stars.size()):
		var twinkle: float = 0.45 + 0.35 * sin(_time * 1.7 + index * 1.3)
		draw_rect(Rect2(_stars[index], Vector2(1.0, 1.0)), Color(0.85, 0.9, 1.0, twinkle))
	draw_circle(Vector2(width - 46.0, 30.0), 13.0, Color(0.93, 0.9, 0.74, 0.9))
	draw_circle(Vector2(width - 41.0, 27.0), 12.0, SKY_TOP)
	_draw_castle(Vector2(width * 0.5, TOP_SPACE + LAYER_HEIGHT * 0.3 + 4.0))
	for spot: Vector2 in _trees:
		draw_colored_polygon(PackedVector2Array([spot + Vector2(0.0, -11.0), spot + Vector2(5.0, 0.0), spot + Vector2(-5.0, 0.0)]), TREE)
		draw_colored_polygon(PackedVector2Array([spot + Vector2(0.0, -16.0), spot + Vector2(4.0, -6.0), spot + Vector2(-4.0, -6.0)]), TREE.lightened(0.05))
		draw_rect(Rect2(spot + Vector2(-1.0, 0.0), Vector2(2.0, 3.0)), SILHOUETTE)
	_draw_camp()

## The boss keep: the road ends at its gate, where the boss medallion sits.
func _draw_castle(gate: Vector2) -> void:
	var base: float = gate.y + 34.0
	draw_colored_polygon(PackedVector2Array([Vector2(gate.x - 150.0, base), Vector2(gate.x - 90.0, base - 14.0), Vector2(gate.x + 90.0, base - 14.0), Vector2(gate.x + 150.0, base)]), SILHOUETTE)
	draw_rect(Rect2(gate.x - 56.0, gate.y - 46.0, 112.0, base - gate.y + 46.0), SILHOUETTE)
	for offset: float in [-78.0, 56.0]:
		draw_rect(Rect2(gate.x + offset, gate.y - 76.0, 22.0, base - gate.y + 76.0), SILHOUETTE)
		for tooth: int in range(3):
			draw_rect(Rect2(gate.x + offset + tooth * 8.0, gate.y - 82.0, 6.0, 6.0), SILHOUETTE)
		draw_rect(Rect2(gate.x + offset + 9.0, gate.y - 60.0, 4.0, 7.0), Color(GOLD, 0.55 + 0.2 * sin(_time * 2.3 + offset)))
		draw_line(Vector2(gate.x + offset + 11.0, gate.y - 82.0), Vector2(gate.x + offset + 11.0, gate.y - 98.0), SILHOUETTE, 1.0)
		var wave: float = sin(_time * 3.0 + offset) * 1.5
		draw_colored_polygon(PackedVector2Array([Vector2(gate.x + offset + 12.0, gate.y - 98.0), Vector2(gate.x + offset + 23.0, gate.y - 95.0 + wave), Vector2(gate.x + offset + 12.0, gate.y - 91.0)]), Color("#b23a3a"))
	for tooth: int in range(7):
		draw_rect(Rect2(gate.x - 56.0 + tooth * 17.0, gate.y - 52.0, 10.0, 6.0), SILHOUETTE)
	for window: float in [-38.0, 34.0]:
		draw_rect(Rect2(gate.x + window, gate.y - 30.0, 4.0, 8.0), Color(GOLD, 0.5 + 0.2 * sin(_time * 1.9 + window)))

func _draw_camp() -> void:
	draw_colored_polygon(PackedVector2Array([_camp + Vector2(8.0, 8.0), _camp + Vector2(26.0, -16.0), _camp + Vector2(44.0, 8.0)]), Color("#3a2f4a"))
	draw_colored_polygon(PackedVector2Array([_camp + Vector2(21.0, 8.0), _camp + Vector2(26.0, -4.0), _camp + Vector2(31.0, 8.0)]), SILHOUETTE)
	var flicker: float = 0.75 + 0.25 * sin(_time * 11.0)
	draw_circle(_camp + Vector2(0.0, 2.0), 15.0 * flicker, Color(1.0, 0.6, 0.2, 0.12))
	draw_line(_camp + Vector2(-6.0, 8.0), _camp + Vector2(6.0, 5.0), Color("#3b2a20"), 2.0)
	draw_line(_camp + Vector2(-6.0, 5.0), _camp + Vector2(6.0, 8.0), Color("#3b2a20"), 2.0)
	draw_colored_polygon(PackedVector2Array([_camp + Vector2(-4.0, 5.0), _camp + Vector2(0.0, -6.0 - 3.0 * flicker), _camp + Vector2(4.0, 5.0)]), Color("#f08a2c"))
	draw_colored_polygon(PackedVector2Array([_camp + Vector2(-2.0, 5.0), _camp + Vector2(0.0, -1.0 - 2.0 * flicker), _camp + Vector2(2.0, 5.0)]), Color("#ffe08a"))

func _draw_roads() -> void:
	var start_open: bool = current_node_id.is_empty()
	for node: MapNodeState in map_state.nodes_in_layer(0):
		var open: bool = start_open and node.node_id in available_node_ids
		var walked: bool = node.node_id in visited_node_ids
		_draw_road(_camp + Vector2(0.0, -8.0), _centers[node.node_id], walked, open, start_open)
	for node: MapNodeState in map_state.nodes:
		for target_id: StringName in node.outgoing_node_ids:
			if not _centers.has(target_id):
				continue
			var walked: bool = node.node_id in visited_node_ids and target_id in visited_node_ids
			var open: bool = node.node_id == current_node_id and target_id in available_node_ids
			_draw_road(_centers[node.node_id], _centers[target_id], walked, open, _reachable.has(node.node_id))

func _road_points(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var lift: float = (start.y - finish.y) * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(25):
		points.append(start.bezier_interpolate(start + Vector2(0.0, -lift), finish + Vector2(0.0, lift), finish, index / 24.0))
	return points

func _draw_road(start: Vector2, finish: Vector2, walked: bool, open: bool, reachable: bool) -> void:
	var points: PackedVector2Array = _road_points(start, finish)
	if walked:
		draw_polyline(points, Color(SILHOUETTE, 0.8), 6.0)
		draw_polyline(points, ROAD_WALKED, 3.0)
		return
	# Dashes march toward the nodes the player can reach next.
	var march: int = int(_time * 7.0) if open else 0
	# Roads the player has passed by, or can no longer reach, fade into the background.
	var color: Color = ROAD_OPEN if open else Color(ROAD_LOCKED, 0.85 if reachable else 0.28)
	for index: int in range(points.size() - 1):
		if posmod(index - march, 3) != 2:
			draw_line(points[index], points[index + 1], color, 3.0 if open else (1.5 if reachable else 1.0))

func _draw_medallion(node: MapNodeState) -> void:
	var center: Vector2 = _centers[node.node_id]
	var radius: float = BOSS_RADIUS if node.node_type_id == &"boss" else NODE_RADIUS
	var accent: Color = node_color(node.node_type_id)
	var available: bool = node.node_id in available_node_ids
	var visited: bool = node.node_id in visited_node_ids
	var is_current: bool = node.node_id == current_node_id
	var ring: Color = accent.darkened(0.5).lerp(Color("#3a4650"), 0.5)
	var disc: Color = Color("#0c1520")
	var icon: Color = Color("#5d6a73")
	var label: Color = Color("#6f7c85")
	if visited and not available:
		ring = Color("#8b7a45")
		disc = Color("#232a30")
		icon = Color("#9a9274")
		label = Color("#9a9274")
	if available:
		var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
		center.y -= 2.0 * pulse
		draw_circle(center, radius + 5.0 + 3.0 * pulse, Color(accent, 0.12 + 0.14 * pulse))
		ring = accent.lightened(0.15)
		disc = Color("#1b3247")
		icon = CREAM
		label = CREAM
	elif not visited and not _reachable.has(node.node_id):
		ring = Color("#222c35")
		icon = Color("#35414b")
		label = Color("#3d4a54")
	_draw_ground_shadow(_centers[node.node_id] + Vector2(0.0, radius + 3.0), radius)
	draw_circle(center + Vector2(0.0, 2.0), radius, SILHOUETTE)
	draw_circle(center, radius, GOLD if is_current else ring)
	draw_circle(center, radius - 3.0, disc)
	draw_arc(center, radius - 4.5, PI * 1.05, PI * 1.75, 12, Color(1.0, 1.0, 1.0, 0.1 if not available else 0.22), 1.5)
	_draw_icon(node.node_type_id, center, icon, 2.5 if node.node_type_id == &"boss" else ICON_PIXEL)
	if visited and not available:
		var badge: Vector2 = center + Vector2(radius * 0.72, -radius * 0.72)
		draw_circle(badge, 6.0, SILHOUETTE)
		draw_circle(badge, 5.0, ROAD_WALKED)
		draw_polyline(PackedVector2Array([badge + Vector2(-2.5, 0.0), badge + Vector2(-0.5, 2.0), badge + Vector2(3.0, -2.0)]), SILHOUETTE, 1.5)
	var font: Font = get_theme_default_font()
	if font != null:
		var definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id)
		var caption: String = _text(String(definition.display_name_key))
		var anchor: Vector2 = Vector2(_centers[node.node_id].x - 40.0, _centers[node.node_id].y + radius + 14.0)
		draw_string_outline(font, anchor, caption, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 10, 3, SILHOUETTE)
		draw_string(font, anchor, caption, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 10, label)

func _draw_ground_shadow(center: Vector2, radius: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(16):
		var angle: float = TAU * step / 16.0
		points.append(center + Vector2(cos(angle) * radius * 0.9, sin(angle) * radius * 0.28))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.35))

func _draw_icon(node_type_id: StringName, center: Vector2, color: Color, pixel: float) -> void:
	paint_icon(self, node_type_id, center, color, pixel)

## Paints a node type's pixel icon on any canvas (the map, the node details popup).
static func paint_icon(canvas: CanvasItem, node_type_id: StringName, center: Vector2, color: Color, pixel: float) -> void:
	var rows: Array = ICONS.get(node_type_id, ICONS[&"event"])
	var origin: Vector2 = (center - Vector2(rows[0].length(), rows.size()) * pixel * 0.5).round()
	for pass_index: int in range(2):
		var shift: Vector2 = Vector2(0.0, pixel) if pass_index == 0 else Vector2.ZERO
		var paint: Color = Color(SILHOUETTE, 0.7) if pass_index == 0 else color
		for row: int in range(rows.size()):
			var line: String = rows[row]
			for column: int in range(line.length()):
				if line[column] == "#":
					canvas.draw_rect(Rect2(origin + shift + Vector2(column, row) * pixel, Vector2(pixel, pixel)), paint)

## The player's king: stands beside the current node and hops along the road to the next.
func _draw_token() -> void:
	if _token_texture == null:
		return
	var stand: Vector2 = _token_stand(current_node_id)
	var hop: float = 0.0
	var squash: Vector2 = Vector2.ONE
	if _travel_progress < 1.0:
		var eased: float = _travel_progress * _travel_progress * (3.0 - 2.0 * _travel_progress)
		var road: PackedVector2Array = _road_points(_travel_from, _travel_to)
		var along: float = eased * (road.size() - 1)
		var index: int = mini(int(along), road.size() - 2)
		stand = road[index].lerp(road[index + 1], along - index)
		hop = absf(sin(_travel_progress * PI * 2.0)) * 16.0
	else:
		var breathe: float = sin(_time * 2.4)
		squash = Vector2(1.0 + 0.02 * breathe, 1.0 - 0.02 * breathe)
	var used: Rect2i = PieceChunks.of(_token_texture).used
	var height: float = 40.0
	var scale_value: float = height / float(used.size.y)
	var drawn: Vector2 = Vector2(used.size) * scale_value * squash
	_draw_ground_shadow(stand, 11.0 * (1.0 - hop / 40.0))
	draw_texture_rect_region(_token_texture, Rect2(stand + Vector2(-drawn.x * 0.5, -drawn.y - hop), drawn), Rect2(used))

static func node_color(node_type_id: StringName) -> Color:
	match node_type_id:
		&"elite_battle":
			return Color("#b875e8")
		&"shop":
			return Color("#edc35c")
		&"event":
			return Color("#55c5d8")
		&"rest":
			return Color("#6acb83")
		&"boss":
			return Color("#e45b55")
		_:
			return Color("#aab6bf")

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
