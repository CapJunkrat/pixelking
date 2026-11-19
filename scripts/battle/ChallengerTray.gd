class_name ChallengerTray
extends Control

## Your five relic and item slots under the board, as one slim panel. Relics (always
## on) wear a gold frame and a gold corner gem; items (one use) a teal frame that
## glows while one can be used now. The line above the slots names the last one
## tapped and says what it does.

signal item_requested(slot_index: int)

const SLOT_COUNT := RunState.MAX_CHALLENGER_SLOTS
const GOLD := Color("#e0b45c")
const GOLD_SOFT := Color("#f5d58f")
const INK := Color("#f1e6cf")
const MUTED := Color("#9aa8bf")
const TEAL := Color("#4fd1c5")
const PANEL := Color(0.05, 0.09, 0.16, 0.92)
const LINE := Color("#2b4166")
const SLOT_HEIGHT := 48.0

var heading: Label = null
var info_label: Label = null
var slot_row: HBoxContainer = null
var challenger_slots: Array[Button] = []
var input_enabled: bool = true
var _items: Array[ChallengerItemDef] = []
var _usable: Array[bool] = []

func _ready() -> void:
	_build()

func _build() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "TreasureTray"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = _box(PANEL, Color(GOLD, 0.35), 10)
	style.border_width_top = 2
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	heading = _label(_text("BATTLE_CHALLENGER"), 10, GOLD)
	heading.name = "Heading"
	head.add_child(heading)
	info_label = _label(_text("BATTLE_TRAY_HINT"), 10, MUTED)
	info_label.name = "InfoLabel"
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_label.clip_text = true
	head.add_child(info_label)
	column.add_child(head)
	slot_row = HBoxContainer.new()
	slot_row.name = "SlotRow"
	slot_row.add_theme_constant_override("separation", 6)
	column.add_child(slot_row)
	for index: int in range(SLOT_COUNT):
		_add_slot(index)
	_style_slots()

func _add_slot(index: int) -> void:
	var slot: Button = Button.new()
	slot.name = "ChallengerSlot%d" % index
	slot.custom_minimum_size = Vector2(0, SLOT_HEIGHT)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.focus_mode = Control.FOCUS_NONE
	slot.expand_icon = true
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_theme_constant_override("icon_max_width", 30)
	slot.pressed.connect(_on_slot_pressed.bind(index))
	var gem: Control = Control.new()
	gem.name = "Gem"
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gem.draw.connect(_draw_gem.bind(gem, index))
	slot.add_child(gem)
	slot_row.add_child(slot)
	challenger_slots.append(slot)

func slots() -> Array[Button]:
	return challenger_slots

func refresh(items: Array[ChallengerItemDef], usable_slots: Array[bool] = []) -> void:
	if challenger_slots.is_empty():
		return
	_items = items.duplicate()
	# A run saved with six slots keeps its sixth item visible.
	while challenger_slots.size() < items.size():
		_add_slot(challenger_slots.size())
	_usable = usable_slots.duplicate()
	for index: int in range(challenger_slots.size()):
		var slot: Button = challenger_slots[index]
		if index >= items.size():
			slot.icon = null
			slot.text = ""
			slot.tooltip_text = _text("BATTLE_EMPTY_SLOT")
			slot.disabled = true
			continue
		var item: ChallengerItemDef = items[index]
		slot.icon = item.icon
		slot.text = "" if item.icon != null else String(item.id).left(2).to_upper()
		slot.tooltip_text = "%s\n%s" % [_text(String(item.display_name_key)), _text(String(item.description_key))]
		# Relics stay tappable (they explain themselves); an item only while usable.
		slot.disabled = not input_enabled or (item.is_consumable() and not _can_use(index))
	_style_slots()

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	for slot: Button in challenger_slots:
		slot.disabled = not input_enabled
	_style_slots()

func _can_use(index: int) -> bool:
	if index >= _items.size():
		return false
	return _usable[index] if index < _usable.size() else _items[index].is_consumable()

func _style_slots() -> void:
	for index: int in range(challenger_slots.size()):
		var slot: Button = challenger_slots[index]
		var item: ChallengerItemDef = _items[index] if index < _items.size() else null
		var normal: StyleBoxFlat
		if item == null:
			normal = _box(Color(LINE, 0.18), Color(LINE, 0.7), 8)
		elif not item.is_consumable():
			normal = _box(Color("#221c2c"), Color(GOLD, 0.8), 8)
		elif _can_use(index) and input_enabled:
			normal = _box(Color("#10302f"), TEAL, 8)
			normal.set_border_width_all(2)
			normal.shadow_color = Color(TEAL, 0.3)
			normal.shadow_size = 3
		else:
			normal = _box(Color("#141c2a"), Color(MUTED, 0.45), 8)
		var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		hover.bg_color = normal.bg_color.lightened(0.08)
		hover.border_color = GOLD_SOFT
		slot.add_theme_stylebox_override("normal", normal)
		slot.add_theme_stylebox_override("hover", hover)
		slot.add_theme_stylebox_override("pressed", hover)
		slot.add_theme_stylebox_override("disabled", normal)
		slot.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.45) if item != null and item.is_consumable() else Color.WHITE)
		(slot.get_node("Gem") as Control).queue_redraw()

## A small gold diamond in a relic's corner: "always on".
func _draw_gem(gem: Control, index: int) -> void:
	if index >= _items.size() or _items[index].is_consumable():
		return
	var c: Vector2 = Vector2(gem.size.x - 7.0, 7.0)
	var points: PackedVector2Array = PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)])
	gem.draw_colored_polygon(points, GOLD)
	gem.draw_polyline(points + PackedVector2Array([points[0]]), Color("#3a2a10"), 1.0)

func _on_slot_pressed(index: int) -> void:
	if not input_enabled:
		return
	if index < _items.size():
		var item: ChallengerItemDef = _items[index]
		var kind: String = _text("BATTLE_TRAY_ITEM") if item.is_consumable() else _text("BATTLE_TRAY_RELIC")
		info_label.text = "%s — %s" % [_text(String(item.display_name_key)), kind]
		info_label.add_theme_color_override("font_color", TEAL if item.is_consumable() else GOLD_SOFT)
		info_label.tooltip_text = _text(String(item.description_key))
	item_requested.emit(index)

func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(4)
	return box

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
