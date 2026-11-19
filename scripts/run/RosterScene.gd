class_name RosterScene
extends Control

## Your army and items between battles. Two rows of piece tiles (battle line and
## reserve) and one of item slots; tapping a tile explains it in the card below,
## which also moves a piece between the battle line and the reserve.

const GOLD := Color("#e0b45c")
const GOLD_SOFT := Color("#f5d58f")
const INK := Color("#f1e6cf")
const MUTED := Color("#9aa8bf")
const TEAL := Color("#4fd1c5")
const ENEMY := Color("#e07a6a")
const PANEL := Color(0.05, 0.09, 0.15, 0.92)
const PANEL_2 := Color("#172a48")
const LINE := Color("#2b4166")
const RARITY_COLORS := [Color("#9aa8bf"), Color("#3fb6d8"), Color("#c58cff"), Color("#ff8a4c"), Color("#ff5d7a")]
const RARITY_KEYS := ["RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY", "RARITY_MYTHIC"]
const COLUMNS := 6
const LINE_SLOTS := 6
const RESERVE_SLOTS := 5
const TILE_HEIGHT := 52.0

@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var line_grid: GridContainer = null
var reserve_grid: GridContainer = null
var item_row: HBoxContainer = null
var line_count: Label = null
var reserve_count: Label = null
var detail_card: PanelContainer = null
var detail_scroll: ScrollContainer = null
var detail_body: VBoxContainer = null
var move_button: Button = null
var status_label: Label = null
## "piece:<instance id>", "item:<item id>" or "" (nothing chosen).
var selected: String = ""
var _icon_cache: Dictionary = {}

func _ready() -> void:
	_build()
	if run_manager.current_run == null or not run_manager.opening_draft_complete():
		_show_status(_text("ROSTER_NO_ACTIVE_RUN"))
		return
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not selected.is_empty():
			_select(selected)
		else:
			_return_to_run()

# --- building ---------------------------------------------------------------------

func _build() -> void:
	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 8)
	$SafeArea.add_child(layout)

	var title: Label = _label(_text("ROSTER_TITLE"), 24, GOLD_SOFT)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color("#0b1422"))
	layout.add_child(title)

	var line_section: Array = _section("LineSection", _text("ROSTER_ACTIVE"), TEAL)
	line_count = line_section[1]
	line_grid = _grid("LineGrid")
	(line_section[2] as VBoxContainer).add_child(line_grid)
	layout.add_child(line_section[0])

	var reserve_section: Array = _section("ReserveSection", _text("ROSTER_RESERVE"), MUTED)
	reserve_count = reserve_section[1]
	reserve_grid = _grid("ReserveGrid")
	(reserve_section[2] as VBoxContainer).add_child(reserve_grid)
	layout.add_child(reserve_section[0])

	var item_section: Array = _section("ItemSection", _text("ROSTER_ITEMS"), GOLD)
	(item_section[1] as Label).visible = false
	item_row = HBoxContainer.new()
	item_row.name = "ItemRow"
	item_row.add_theme_constant_override("separation", 5)
	(item_section[2] as VBoxContainer).add_child(item_row)
	layout.add_child(item_section[0])

	# The explanation card fills what is left; its text scrolls (drag it) when long.
	detail_card = PanelContainer.new()
	detail_card.name = "DetailCard"
	detail_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card_style: StyleBoxFlat = _box(PANEL, LINE, 8)
	card_style.set_content_margin_all(10)
	detail_card.add_theme_stylebox_override("panel", card_style)
	var card_column: VBoxContainer = VBoxContainer.new()
	card_column.add_theme_constant_override("separation", 8)
	detail_card.add_child(card_column)
	detail_scroll = ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_body = VBoxContainer.new()
	detail_body.name = "DetailBody"
	detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_body.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(detail_body)
	card_column.add_child(detail_scroll)
	DragScroll.enable(detail_scroll)
	status_label = _label("", 11, ENEMY)
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.visible = false
	card_column.add_child(status_label)
	move_button = _button("", PANEL_2, TEAL, INK)
	move_button.name = "MoveButton"
	move_button.custom_minimum_size = Vector2(0, 40)
	move_button.visible = false
	move_button.pressed.connect(_move_selected)
	card_column.add_child(move_button)
	layout.add_child(detail_card)

	var back: Button = _button(_text("ROSTER_RETURN"), PANEL_2, GOLD, INK)
	back.name = "BackButton"
	back.pressed.connect(_return_to_run)
	layout.add_child(back)

## A framed section: [panel, count label, content column].
func _section(node_name: String, title: String, accent: Color) -> Array:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = node_name
	var style: StyleBoxFlat = _box(PANEL, Color(accent, 0.45), 8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	var name_label: Label = _label(title.to_upper(), 11, accent)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var count: Label = _label("", 11, MUTED)
	count.name = "Count"
	head.add_child(count)
	column.add_child(head)
	return [panel, count, column]

func _grid(node_name: String) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.name = node_name
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	return grid

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
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

func _button(text: String, fill: Color, border: Color, font: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _box(fill, border, 6))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.1), GOLD_SOFT, 6))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.1), GOLD_SOFT, 6))
	button.add_theme_stylebox_override("focus", _box(fill, GOLD_SOFT, 6))
	button.add_theme_stylebox_override("disabled", _box(fill.darkened(0.4), LINE, 6))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, font)
	return button

# --- rendering --------------------------------------------------------------------

func _render() -> void:
	var run: RunState = run_manager.current_run
	var active: Array[PieceInstanceState] = run_manager.roster_service.active_pieces(run)
	var reserve: Array[PieceInstanceState] = run_manager.roster_service.reserve_pieces(run)
	if selected.begins_with("piece:") and run.get_piece_state(int(selected.trim_prefix("piece:"))) == null:
		selected = ""
	_clear(line_grid)
	# The King plus the battle line (one more place with the War Banner).
	for index: int in range(maxi(LINE_SLOTS, run.max_active_pieces() + 1)):
		line_grid.add_child(_piece_tile(active[index] if index < active.size() else null, true))
	_clear(reserve_grid)
	for index: int in range(RESERVE_SLOTS):
		reserve_grid.add_child(_piece_tile(reserve[index] if index < reserve.size() else null, false))
	line_count.text = "%d/%d" % [maxi(0, active.size() - 1), run.max_active_pieces()]
	reserve_count.text = "%d/%d" % [reserve.size(), RunState.MAX_RESERVE_PIECES]
	_clear(item_row)
	for index: int in range(maxi(RunState.MAX_CHALLENGER_SLOTS, run.challenger_slots.size())):
		item_row.add_child(_item_tile(ChallengerItemDatabase.get_def(run.challenger_slots[index]) if index < run.challenger_slots.size() else null))
	_render_detail()

func _piece_tile(piece: PieceInstanceState, on_line: bool) -> Button:
	var tile: Button = Button.new()
	tile.custom_minimum_size = Vector2(0, TILE_HEIGHT)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.focus_mode = Control.FOCUS_NONE
	if piece == null:
		tile.name = "Empty"
		tile.disabled = true
		var empty: StyleBoxFlat = _box(Color(PANEL_2, 0.3), Color(LINE, 0.6), 6)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			tile.add_theme_stylebox_override(state, empty)
		return tile
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id))
	tile.name = "Piece_%d" % piece.instance_id
	tile.set_meta("instance_id", piece.instance_id)
	tile.tooltip_text = _piece_name(piece)
	tile.icon = _icon(piece_skin_manager.call("piece_texture", &"white", piece.piece_def_id) as Texture2D)
	tile.expand_icon = true
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_theme_constant_override("icon_max_width", 30)
	var chosen: bool = selected == "piece:%d" % piece.instance_id
	var border: Color = GOLD_SOFT if chosen else (GOLD if piece.is_king else (Color(TEAL, 0.7) if on_line else LINE))
	var fill: Color = Color("#2a2a1e") if chosen else (Color("#12333a") if on_line else PANEL_2)
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = _box(fill.lightened(0.06) if state == "hover" else fill, border, 6)
		if chosen:
			style.set_border_width_all(2)
		tile.add_theme_stylebox_override(state, style)
	tile.pressed.connect(_select.bind("piece:%d" % piece.instance_id))
	# A thin rarity stripe along the bottom edge.
	var stripe: ColorRect = ColorRect.new()
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.color = RARITY_COLORS[clampi(int(definition.rarity), 0, RARITY_COLORS.size() - 1)] if definition != null else MUTED
	stripe.anchor_left = 0.2
	stripe.anchor_right = 0.8
	stripe.anchor_top = 1.0
	stripe.anchor_bottom = 1.0
	stripe.offset_top = -5
	stripe.offset_bottom = -3
	tile.add_child(stripe)
	return tile

func _item_tile(item: ChallengerItemDef) -> Button:
	var tile: Button = Button.new()
	tile.custom_minimum_size = Vector2(0, 40)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.focus_mode = Control.FOCUS_NONE
	tile.expand_icon = true
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_theme_constant_override("icon_max_width", 26)
	if item == null:
		tile.disabled = true
		var empty: StyleBoxFlat = _box(Color(PANEL_2, 0.3), Color(LINE, 0.6), 6)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			tile.add_theme_stylebox_override(state, empty)
		return tile
	tile.name = "Item_%s" % item.id
	tile.icon = item.icon
	var chosen: bool = selected == "item:%s" % item.id
	var border: Color = GOLD_SOFT if chosen else (Color(GOLD, 0.5) if not item.is_consumable() else LINE)
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = _box(Color("#1a1626") if state != "hover" else Color("#241f33"), border, 6)
		if chosen:
			style.set_border_width_all(2)
		tile.add_theme_stylebox_override(state, style)
	tile.pressed.connect(_select.bind("item:%s" % item.id))
	return tile

func _render_detail() -> void:
	_clear(detail_body)
	detail_scroll.scroll_vertical = 0
	move_button.visible = false
	if selected.begins_with("piece:"):
		_render_piece_detail(run_manager.current_run.get_piece_state(int(selected.trim_prefix("piece:"))))
	elif selected.begins_with("item:"):
		_render_item_detail(ChallengerItemDatabase.get_def(StringName(selected.trim_prefix("item:"))))
	else:
		var hint: Label = _label(_text("ROSTER_SUBTITLE"), 12, MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_body.add_child(hint)

func _render_piece_detail(piece: PieceInstanceState) -> void:
	if piece == null:
		return
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id))
	if definition == null:
		return
	var on_line: bool = piece.instance_id in run_manager.current_run.active_piece_ids
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var grid: GridContainer = PieceRulePreview.make_grid(String(piece.piece_def_id), 7, 9.0, true)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(grid)
	var facts: VBoxContainer = VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_theme_constant_override("separation", 2)
	facts.add_child(_label(_piece_name(piece), 15, GOLD_SOFT))
	var rarity: int = clampi(int(definition.rarity), 0, RARITY_KEYS.size() - 1)
	facts.add_child(_label("%s · %s" % [_text(RARITY_KEYS[rarity]), _text("PREBATTLE_VALUE") % definition.base_value], 11, RARITY_COLORS[rarity]))
	var where: String = _text("ROSTER_KING_LOCKED") if piece.is_king else _text("ROSTER_ON_LINE" if on_line else "ROSTER_IN_RESERVE")
	facts.add_child(_label(where, 11, TEAL if on_line else MUTED))
	row.add_child(facts)
	detail_body.add_child(row)
	var lines: Array[String] = [_text(PieceRulePreview.move_key(definition)), _text(PieceRulePreview.attack_key(definition))]
	for key: String in PieceRulePreview.ability_keys(definition):
		if key != "CODEX_TRAIT_NONE":
			lines.append("[color=#f5d58f]%s[/color]" % _text(key))
	detail_body.add_child(_rich("\n".join(lines)))
	if not piece.is_king:
		move_button.text = _text("ROSTER_TO_RESERVE" if on_line else "ROSTER_TO_LINE")
		move_button.visible = true

func _render_item_detail(item: ChallengerItemDef) -> void:
	if item == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var picture: TextureRect = TextureRect.new()
	picture.texture = item.icon
	picture.custom_minimum_size = Vector2(44, 44)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(picture)
	var facts: VBoxContainer = VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_child(_label(_text(String(item.display_name_key)), 15, GOLD_SOFT))
	var usage: Label = _label(_text("ITEM_USAGE_CONSUMABLE") if item.is_consumable() else _text("ITEM_USAGE_PERSISTENT"), 11, MUTED)
	usage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.add_child(usage)
	row.add_child(facts)
	detail_body.add_child(row)
	detail_body.add_child(_rich(_text(String(item.description_key))))

func _rich(text: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 12)
	label.add_theme_color_override("default_color", INK)
	label.text = text
	return label

# --- actions ------------------------------------------------------------------------

## Explains the tapped tile; tapping it again clears the card.
func _select(key: String) -> void:
	selected = "" if selected == key else key
	status_label.visible = false
	_render()

func _move_selected() -> void:
	if not selected.begins_with("piece:"):
		return
	var instance_id: int = int(selected.trim_prefix("piece:"))
	var to_line: bool = instance_id not in run_manager.current_run.active_piece_ids
	if run_manager.move_roster_piece(instance_id, to_line) != OK:
		_show_status(_text("ROSTER_CAPACITY_ERROR"))
		_nudge(line_grid if to_line else reserve_grid)
		return
	status_label.visible = false
	_render()

func _return_to_run() -> void:
	get_tree().change_scene_to_file(run_manager.resume_scene_path())

# --- helpers ------------------------------------------------------------------------

func _show_status(message: String) -> void:
	status_label.text = message
	status_label.visible = true

## A quick shake and red flash: "that side is full".
func _nudge(target: Control) -> void:
	if target == null or not is_inside_tree():
		return
	var rest: Vector2 = target.position
	var tween: Tween = create_tween()
	target.modulate = Color(1.0, 0.55, 0.5)
	for offset: float in [5.0, -5.0, 3.0, -3.0, 0.0]:
		tween.tween_property(target, "position:x", rest.x + offset, 0.04)
	tween.tween_property(target, "modulate", Color.WHITE, 0.15)

func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

## Crops a piece picture to its visible figure, so every piece fills its tile alike.
func _icon(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if _icon_cache.has(texture):
		return _icon_cache[texture]
	var image: Image = texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	var used: Rect2i = image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return texture
	var cropped: AtlasTexture = AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = Rect2(used.grow(1).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
	_icon_cache[texture] = cropped
	return cropped

func _piece_name(piece: PieceInstanceState) -> String:
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id))
	return _text(String(definition.display_name_key)) if definition != null else String(piece.piece_def_id)

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
