class_name PathMapView
extends Control

signal node_selected(node_id: StringName)

const VIEW_WIDTH := 328.0
const LAYER_HEIGHT := 108.0
const CARD_SIZE := Vector2(98, 84)
const PATH_COLOR := Color("#dbc06f")
const LOCKED_PATH_COLOR := Color("#33495c")

var map_state: MapState = null
var available_node_ids: Array[StringName] = []
var visited_node_ids: Array[StringName] = []
var current_node_id: StringName = &""
var _node_rects: Dictionary = {}

func display_map(
	value: MapState,
	available_ids: Array[StringName],
	visited_ids: Array[StringName],
	current_id: StringName
) -> void:
	map_state = value
	available_node_ids = available_ids.duplicate()
	visited_node_ids = visited_ids.duplicate()
	current_node_id = current_id
	_rebuild()

func node_vertical_center(node_id: StringName) -> float:
	var rect: Rect2 = _node_rects.get(node_id, Rect2())
	return rect.get_center().y

func node_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in get_children():
		if child is Button and child.is_in_group("map_node_cards"):
			result.append(child as Button)
	return result

func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	_node_rects.clear()
	if map_state == null:
		custom_minimum_size = Vector2(VIEW_WIDTH, 0)
		queue_redraw()
		return
	custom_minimum_size = Vector2(VIEW_WIDTH, map_state.total_layers * LAYER_HEIGHT + 20.0)
	for node: MapNodeState in map_state.nodes:
		var layer_nodes: Array[MapNodeState] = map_state.nodes_in_layer(node.layer_index)
		var rect: Rect2 = Rect2(_node_position(node, layer_nodes.size()), CARD_SIZE)
		_node_rects[node.node_id] = rect
		var button: Button = _create_node_button(node)
		button.position = rect.position
		button.size = rect.size
		add_child(button)
	queue_redraw()

func _create_node_button(node: MapNodeState) -> Button:
	var definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id)
	var button: Button = Button.new()
	button.name = "Node_%s" % String(node.node_id).get_file()
	button.add_to_group("map_node_cards")
	button.set_meta("node_id", node.node_id)
	button.set_meta("node_type_id", node.node_type_id)
	button.set_meta("layer_index", node.layer_index)
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = node.node_id not in available_node_ids
	button.text = "%s  %s\n%s\n%s" % [
		definition.icon_text,
		_text(String(definition.display_name_key)),
		_text(String(definition.enemy_hint_key)),
		_text(String(definition.reward_hint_key)),
	]
	button.tooltip_text = "%s\n%s" % [
		_text(String(definition.description_key)),
		_text(String(definition.reward_hint_key)),
	]
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("#eee5cc"))
	button.add_theme_color_override("font_disabled_color", Color("#77828a"))
	var accent: Color = _node_color(node.node_type_id)
	var visited: bool = node.node_id in visited_node_ids
	button.add_theme_stylebox_override("normal", _card_style(Color("#142435") if not visited else Color("#26313a"), accent, 2))
	button.add_theme_stylebox_override("hover", _card_style(Color("#1d3b50"), accent.lightened(0.2), 3))
	button.add_theme_stylebox_override("focus", _card_style(Color("#1d3b50"), accent.lightened(0.2), 3))
	button.add_theme_stylebox_override("pressed", _card_style(Color("#0b1824"), accent, 2))
	button.add_theme_stylebox_override("disabled", _card_style(Color("#0b141e"), Color("#3e4a52"), 1))
	button.pressed.connect(func() -> void: node_selected.emit(node.node_id))
	return button

func _node_position(node: MapNodeState, layer_node_count: int) -> Vector2:
	var cell_width: float = VIEW_WIDTH / float(layer_node_count)
	var x_position: float = cell_width * (float(node.lane_index) + 0.5) - CARD_SIZE.x * 0.5
	var display_layer: int = map_state.total_layers - 1 - node.layer_index
	var y_position: float = float(display_layer) * LAYER_HEIGHT + 10.0
	return Vector2(x_position, y_position)

func _draw() -> void:
	if map_state == null:
		return
	for node: MapNodeState in map_state.nodes:
		var source_rect: Rect2 = _node_rects.get(node.node_id, Rect2())
		for target_id: StringName in node.outgoing_node_ids:
			var target_rect: Rect2 = _node_rects.get(target_id, Rect2())
			var selected_path: bool = node.node_id in visited_node_ids and target_id in visited_node_ids
			var color: Color = PATH_COLOR if selected_path else LOCKED_PATH_COLOR
			var width: float = 4.0 if selected_path else 2.0
			draw_line(source_rect.get_center(), target_rect.get_center(), color, width, false)

func _node_color(node_type_id: StringName) -> Color:
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

func _card_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style
