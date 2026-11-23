class_name PreBattleScene
extends Control

## The one screen between choosing a battle on the map and fighting it. It shows the
## enemy formation and what each enemy piece does, compares both sides' strength, lets
## the player swap pieces between the battle line and the reserve, and starts the fight.
## Pieces are placed automatically (DeploymentFormation); there is no deployment step.

const GOLD := Color("#e0b45c")
const GOLD_SOFT := Color("#f5d58f")
const INK := Color("#f1e6cf")
const MUTED := Color("#9aa8bf")
const TEAL := Color("#4fd1c5")
const ENEMY := Color("#e07a6a")
const PANEL := Color("#12203a")
const PANEL_2 := Color("#172a48")
const LINE := Color("#2b4166")
const TIER_COLORS := {&"normal_battle": Color("#e0b45c"), &"elite_battle": Color("#c58cff"), &"boss": Color("#ff8a4c")}
const PATTERN_COLORS := {"move": Color("#3fb6d8"), "attack": Color("#e07a6a"), "both": Color("#b07ae0")}
const PATTERN_SIZE := 7
## The area under the enemy icons: your reserve and items, or the explanation of
## what you tapped. Fixed, so the board never moves when an explanation opens.
const INFO_HEIGHT := 84.0
const RESERVE_SLOT_HEIGHT := 54.0
const ITEM_SLOT_HEIGHT := 44.0
## A touch that moves less than this is a tap (it closes the explanation).
const TIP_ID := "prebattle_arrange"

@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var board_view: DeploymentBoardView = null
var tier_label: Label = null
var layer_label: Label = null
var limit_label: Label = null
var pattern_panel: PanelContainer = null
## Holds the enemy piece explanation; shown instead of the line-up while one is chosen.
var pattern_scroll: ScrollContainer = null
var lineup_box: VBoxContainer = null
var count_label: Label = null
var count_badge: PanelContainer = null
## Your items and relics, as in battle; tapping one explains it in the info area.
var item_strip: HBoxContainer = null
var tip_bubble: Control = null
## Pieces' pictures cropped to the figure, so every icon fills its box the same way.
var _icon_cache: Dictionary = {}
var bench_row: HBoxContainer = null
var status_label: Label = null
var back_button: Button = null
var fight_button: Button = null
var focus_id: String = ""
## Arranging by hand is always on: tap one of your pieces, then a square in your two
## ranks. 0 while no piece is picked up.
var arrange_selected: int = 0
## A reserve piece picked up while the battle line is full; tapping a piece on the
## board then trades the two.
var reserve_held: int = 0
var _starting: bool = false

func _ready() -> void:
	_build()
	if run_manager.current_run == null:
		_show_status(_text("PREBATTLE_NO_RUN"))
		fight_button.disabled = true
		return
	if run_manager.begin_deployment() != OK:
		_show_status(_text("PREBATTLE_INVALID_NODE"))
		fight_button.disabled = true
		return
	_render()
	_show_first_time_tip()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not focus_id.is_empty():
			_focus(focus_id)
		else:
			_return_to_map()

# --- building ---------------------------------------------------------------------

func _build() -> void:
	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 6)
	$SafeArea.add_child(layout)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	tier_label = _label("", 11, Color("#0b1422"))
	tier_label.name = "TierLabel"
	var tier_box: PanelContainer = PanelContainer.new()
	tier_box.name = "TierChip"
	tier_box.add_child(tier_label)
	head.add_child(tier_box)
	layer_label = _label("", 12, MUTED)
	layer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(layer_label)
	limit_label = _label("", 12, Color("#ff8a4c"))
	limit_label.name = "TurnLimit"
	limit_label.visible = false
	head.add_child(limit_label)
	# How many of your pieces are on the board, out of how many may be.
	count_badge = PanelContainer.new()
	count_badge.name = "LineBadge"
	var badge_row: HBoxContainer = HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 3)
	var badge_icon: TextureRect = TextureRect.new()
	badge_icon.name = "BadgeIcon"
	badge_icon.custom_minimum_size = Vector2(14, 16)
	badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge_row.add_child(badge_icon)
	count_label = _label("", 12, INK)
	count_label.name = "LineCount"
	badge_row.add_child(count_label)
	count_badge.add_child(badge_row)
	head.add_child(count_badge)
	layout.add_child(head)

	board_view = DeploymentBoardView.new()
	board_view.name = "BoardFrame"
	board_view.custom_minimum_size = Vector2(0, 220)
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Nothing is placed by hand here, so the board shows no deployment zone.
	board_view.deploy_rows = 0
	board_view.square_pressed.connect(_on_square_pressed)
	layout.add_child(board_view)

	# Under the board: the details of the tapped piece (or item), filling the space
	# down to the reserve. It scrolls when the text is long. The reserve and the item
	# bar below it are always shown.
	board_view.size_flags_stretch_ratio = 3.0
	pattern_scroll = ScrollContainer.new()
	pattern_scroll.name = "PatternScroll"
	pattern_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pattern_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pattern_scroll.size_flags_stretch_ratio = 1.0
	pattern_scroll.custom_minimum_size = Vector2(0, INFO_HEIGHT)
	pattern_panel = PanelContainer.new()
	pattern_panel.name = "PiecePattern"
	pattern_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pattern_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pattern_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	pattern_scroll.add_child(pattern_panel)
	layout.add_child(pattern_scroll)
	DragScroll.enable(pattern_scroll)

	lineup_box = VBoxContainer.new()
	lineup_box.name = "Lineup"
	lineup_box.add_theme_constant_override("separation", 6)
	# Your battle line is the board itself; only the reserve is listed. Pick up a piece
	# on the board and tap a reserve slot to bench it (or swap it with that piece).
	bench_row = HBoxContainer.new()
	bench_row.name = "ReserveRow"
	bench_row.add_theme_constant_override("separation", 5)
	lineup_box.add_child(bench_row)
	layout.add_child(lineup_box)
	item_strip = HBoxContainer.new()
	item_strip.name = "ItemStrip"
	item_strip.add_theme_constant_override("separation", 5)
	layout.add_child(item_strip)

	status_label = _label("", 12, ENEMY)
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.visible = false
	layout.add_child(status_label)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 8)
	back_button = _button(_text("PREBATTLE_BACK"), PANEL_2, LINE, INK)
	back_button.name = "BackButton"
	back_button.size_flags_stretch_ratio = 1.0
	back_button.pressed.connect(_return_to_map)
	fight_button = _button(_text("PREBATTLE_FIGHT"), GOLD, GOLD, Color("#1a1408"))
	fight_button.name = "FightButton"
	fight_button.size_flags_stretch_ratio = 1.6
	fight_button.pressed.connect(_start_battle)
	actions.add_child(back_button)
	actions.add_child(fight_button)
	layout.add_child(actions)

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
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_focus_color", font)
	return button

# --- rendering --------------------------------------------------------------------

func _render() -> void:
	var run: RunState = run_manager.current_run
	var node: MapNodeState = run_manager.current_map_node()
	var node_def: MapNodeDef = Content.map_node(node.node_type_id) if node != null else null
	var encounter: EncounterDef = EncounterGenerator.encounter_for_current(run)
	if node_def != null:
		var tier_color: Color = TIER_COLORS.get(node_def.id, GOLD)
		var tier_name: String = _text(String(node_def.display_name_key))
		if encounter != null and encounter.is_boss and not encounter.display_name_key.is_empty():
			tier_name = _text(String(encounter.display_name_key))
		tier_label.text = " %s " % tier_name.to_upper()
		(tier_label.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _box(tier_color, tier_color, 4))
	if node != null and run.map_state != null:
		layer_label.text = "%s · %s" % [_text("MAP_ACT") % (run.act_index + 1), _text("MAP_PROGRESS") % [node.layer_index + 1, run.map_state.total_layers]]
	_render_board()
	_render_pattern()
	limit_label.visible = encounter != null and encounter.turn_limit > 0
	if limit_label.visible:
		limit_label.text = _text("PREBATTLE_TURN_LIMIT") % encounter.turn_limit
	_render_lineup()
	_render_items()

func _render_board() -> void:
	var deployment: DeploymentState = run_manager.current_run.deployment_state
	var pieces: Dictionary = {}
	var focus_square: Vector2i = DeploymentBoardView.NO_SQUARE
	if arrange_selected > 0:
		focus_square = deployment.player_position(arrange_selected)
	# The two ranks you may use light up only while a piece is in hand.
	board_view.deploy_rows = DeploymentState.PLAYER_ROWS if arrange_selected > 0 else 0
	board_view.rocks = {}
	for rock: Vector2i in deployment.rocks:
		board_view.rocks[rock] = true
	for placement: Dictionary in deployment.enemy_placements:
		var square: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
		var id: String = str(placement.get("piece_def_id", ""))
		pieces[square] = {"texture": _texture(&"black", id), "player": false}
		if id == focus_id and focus_square == DeploymentBoardView.NO_SQUARE:
			focus_square = square
	for instance_id: int in run_manager.current_run.active_piece_ids:
		var piece: PieceInstanceState = run_manager.current_run.get_piece_state(instance_id)
		pieces[deployment.player_position(instance_id)] = {"texture": _texture(&"white", String(piece.piece_def_id)), "player": true}
	board_view.hints = _threat_hints() if arrange_selected <= 0 else {}
	board_view.show_position(deployment.board_size, pieces, focus_square)

func _render_pattern() -> void:
	for child: Node in pattern_panel.get_children():
		pattern_panel.remove_child(child)
		child.queue_free()
	pattern_scroll.scroll_vertical = 0
	if focus_id.is_empty():
		# Until something is tapped: what this space is for.
		pattern_panel.add_theme_stylebox_override("panel", _box(Color(PANEL, 0.6), LINE, 6))
		var hint: Label = _label(_text("PREBATTLE_DETAILS_HINT"), 12, MUTED)
		hint.name = "DetailsHint"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pattern_panel.add_child(hint)
		return
	if focus_id.begins_with("item:"):
		pattern_panel.add_theme_stylebox_override("panel", _box(Color("#1a1626"), GOLD, 6))
		_render_item_card(StringName(focus_id.trim_prefix("item:")))
		return
	var own: PieceInstanceState = null
	var piece_id: String = focus_id
	if focus_id.begins_with("own:"):
		own = run_manager.current_run.get_piece_state(int(focus_id.trim_prefix("own:")))
		if own == null:
			focus_id = ""
			_render_pattern()
			return
		piece_id = String(own.piece_def_id)
	var definition: PieceDef = Content.piece(piece_id)
	if definition == null:
		return
	var enemy: bool = own == null
	pattern_panel.add_theme_stylebox_override("panel", _box(Color("#1d1a2b") if enemy else Color("#12283a"), ENEMY if enemy else TEAL, 6))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var side: VBoxContainer = VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.mouse_filter = Control.MOUSE_FILTER_PASS
	var picture: TextureRect = TextureRect.new()
	picture.texture = _texture(&"black" if enemy else &"white", piece_id)
	picture.custom_minimum_size = Vector2(36, 36)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	side.add_child(picture)
	var grid: GridContainer = GridContainer.new()
	grid.columns = PATTERN_SIZE
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	var pattern: Dictionary = PieceRulePreview.pattern(piece_id, PATTERN_SIZE)
	var half: int = PATTERN_SIZE / 2
	# Enemy pieces advance down the board, so their pattern is shown mirrored.
	for row_index: int in range(PATTERN_SIZE):
		var y: int = (row_index - half) if enemy else (half - row_index)
		for x: int in range(-half, half + 1):
			var cell: ColorRect = ColorRect.new()
			cell.custom_minimum_size = Vector2(6, 6)
			var kind: String = str(pattern.get(Vector2i(x, y), ""))
			cell.color = GOLD if x == 0 and y == 0 else PATTERN_COLORS.get(kind, Color("#2a3550"))
			grid.add_child(cell)
	side.add_child(grid)
	row.add_child(side)
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 11)
	text.add_theme_font_size_override("bold_font_size", 12)
	var accent: String = (ENEMY if enemy else GOLD_SOFT).to_html(false)
	var owner: String = _text("LOG_ENEMY_TAG") if enemy else _text("LOG_YOURS_TAG")
	var lines: Array[String] = ["[b][color=#%s]%s[/color][/b]  [color=#9aa8bf]%s[/color]" % [accent, _piece_name(piece_id), owner]]
	lines.append(_text(PieceRulePreview.move_key(definition)))
	lines.append(_text(PieceRulePreview.attack_key(definition)))
	for key: String in PieceRulePreview.ability_keys(definition):
		if key != "CODEX_TRAIT_NONE":
			lines.append("[color=#f5d58f]%s[/color]" % _text(key))
	if own != null and own.capture_count > 0:
		lines.append("[color=#4fd1c5]%s[/color]" % (_text("PREBATTLE_CAPTURES") % own.capture_count))
	text.text = "\n".join(lines)
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(text)
	pattern_panel.add_child(row)

## Where every enemy piece of the chosen kind can move (blue) or capture (red) from
## where it stands now, rocks and all.
func _threat_hints() -> Dictionary:
	var hints: Dictionary = {}
	if focus_id.is_empty() or focus_id.begins_with("item:") or focus_id.begins_with("own:"):
		return hints
	var board: BoardState = _preview_board()
	if board == null:
		return hints
	for placement: Dictionary in run_manager.current_run.deployment_state.enemy_placements:
		if str(placement.get("piece_def_id", "")) != focus_id:
			continue
		var square: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
		for target: Vector2i in MoveGenerator.generate_pseudo_legal(board, square):
			if board.is_rock(target):
				continue
			var occupant: ChessPiece = board.get_piece(target)
			if occupant == null:
				hints[target] = "move"
			elif occupant.color == GameRules.PieceColor.WHITE:
				hints[target] = "attack"
		for target: Vector2i in MoveGenerator.get_attack_squares(board, square):
			var occupant: ChessPiece = board.get_piece(target)
			if occupant == null or occupant.color == GameRules.PieceColor.WHITE:
				hints[target] = "attack" if occupant != null or not hints.has(target) else hints[target]
	return hints

## The coming battle's opening position, for previews.
func _preview_board() -> BoardState:
	var run: RunState = run_manager.current_run
	var deployment: DeploymentState = run.deployment_state
	var board: BoardState = BoardState.new(deployment.board_size, false)
	board.clear_for_setup()
	for instance_id: int in run.active_piece_ids:
		var piece: PieceInstanceState = run.get_piece_state(instance_id)
		if piece != null:
			board.place_piece_for_setup(deployment.player_position(instance_id), piece.to_chess_piece(GameRules.PieceColor.WHITE))
	for placement: Dictionary in deployment.enemy_placements:
		var definition: PieceDef = Content.piece(str(placement.get("piece_def_id", "")))
		if definition != null:
			board.place_piece_for_setup(DeploymentState.position_from_value(placement.get("position", {})), ChessPiece.new(definition, GameRules.PieceColor.BLACK))
	if not board.finalize_setup(GameRules.PieceColor.BLACK):
		return null
	board.set_rocks(deployment.rocks)
	return board

func _render_items() -> void:
	for child: Node in item_strip.get_children():
		item_strip.remove_child(child)
		child.queue_free()
	var slots: Array[StringName] = run_manager.current_run.challenger_slots
	for index: int in range(maxi(RunState.MAX_CHALLENGER_SLOTS, slots.size())):
		var slot: Button = Button.new()
		slot.custom_minimum_size = Vector2(0, ITEM_SLOT_HEIGHT)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_constant_override("icon_max_width", 24)
		var item: ChallengerItemDef = Content.challenger_item(slots[index]) if index < slots.size() else null
		var chosen: bool = item != null and focus_id == "item:%s" % item.id
		var border: Color = GOLD if chosen else (Color(GOLD, 0.45) if item != null and not item.is_consumable() else LINE)
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			slot.add_theme_stylebox_override(state, _box(Color("#1a1626") if item != null else Color(PANEL_2, 0.35), border, 6))
		if item == null:
			slot.disabled = true
		else:
			slot.name = "Item_%s" % item.id
			slot.icon = item.icon
			slot.pressed.connect(_focus.bind("item:%s" % item.id))
		item_strip.add_child(slot)

func _render_item_card(item_id: StringName) -> void:
	var item: ChallengerItemDef = Content.challenger_item(item_id)
	if item == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var picture: TextureRect = TextureRect.new()
	picture.texture = item.icon
	picture.custom_minimum_size = Vector2(40, 40)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(picture)
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 11)
	var usage: String = _text("ITEM_USAGE_CONSUMABLE") if item.is_consumable() else _text("ITEM_USAGE_PERSISTENT")
	text.text = "%s\n[color=#9aa8bf]%s[/color]" % [_text(String(item.description_key)), usage]
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(text)
	text.text = "[b][color=#f5d58f]%s[/color][/b]\n%s" % [_text(String(item.display_name_key)), text.text]
	pattern_panel.add_child(row)

func _render_lineup() -> void:
	for child: Node in bench_row.get_children():
		bench_row.remove_child(child)
		child.queue_free()
	var run: RunState = run_manager.current_run
	for instance_id: int in run.reserve_piece_ids:
		bench_row.add_child(_slot(run.get_piece_state(instance_id), false))
	for index: int in range(bench_row.get_child_count(), RunState.MAX_RESERVE_PIECES):
		bench_row.add_child(_empty_reserve_slot(index))
	var on_board: int = _active_non_king()
	var full: bool = on_board >= run.max_active_pieces()
	count_label.text = "%d/%d" % [on_board, run.max_active_pieces()]
	count_label.add_theme_color_override("font_color", Color("#1a1408") if full else INK)
	count_badge.add_theme_stylebox_override("panel", _box(GOLD if full else PANEL_2, GOLD if full else LINE, 10))
	(count_badge.find_child("BadgeIcon", true, false) as TextureRect).texture = _icon(_texture(&"white", "pawn"))

## An open reserve place. With a piece picked up on the board, tapping it benches it.
func _empty_reserve_slot(index: int) -> Button:
	var button: Button = Button.new()
	button.name = "ReserveSlot_%d" % index
	button.custom_minimum_size = Vector2(44, RESERVE_SLOT_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var holding: bool = _holding_benchable()
	var border: Color = GOLD_SOFT if holding else LINE
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _box(Color(PANEL_2, 0.4), border, 6))
	button.disabled = not holding
	button.pressed.connect(_bench_held)
	if holding:
		# A small down arrow: "put it here".
		var arrow: Control = Control.new()
		arrow.name = "BenchArrow"
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		arrow.draw.connect(func() -> void:
			var c: Vector2 = arrow.size * 0.5
			arrow.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -2), c + Vector2(7, -2), c + Vector2(0, 7)]), Color(GOLD_SOFT, 0.7))
			arrow.draw_rect(Rect2(c + Vector2(-2.5, -9), Vector2(5, 8)), Color(GOLD_SOFT, 0.7)))
		button.add_child(arrow)
	return button

func _slot(piece: PieceInstanceState, active: bool) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(44, RESERVE_SLOT_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var border: Color = LINE
	var fill: Color = PANEL_2
	if piece == null:
		button.disabled = true
		button.add_theme_stylebox_override("disabled", _box(Color(PANEL_2, 0.4), LINE, 6))
		return button
	button.name = "Piece_%d" % piece.instance_id
	button.icon = _icon(_texture(&"white", String(piece.piece_def_id)))
	button.add_theme_constant_override("icon_max_width", 30)
	button.tooltip_text = _piece_name(String(piece.piece_def_id))
	if piece.is_king:
		border = GOLD
	elif piece.instance_id == reserve_held:
		border = GOLD
		fill = Color("#3a2e12")
	elif active:
		border = TEAL
		fill = Color("#12333a")
	elif _holding_benchable():
		border = GOLD_SOFT
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _box(fill if state != "hover" else fill.lightened(0.08), border if state != "hover" else GOLD_SOFT, 6))
	if piece.is_king:
		button.disabled = true
	else:
		button.pressed.connect(_on_reserve_pressed.bind(piece.instance_id))
	return button

# --- actions ------------------------------------------------------------------------

func _focus(id: String) -> void:
	focus_id = "" if focus_id == id else id
	_render_board()
	_render_pattern()
	_render_items()

func _on_square_pressed(square: Vector2i) -> void:
	# A repeat tap that stepped to another piece stacked under the same spot only
	# picks that piece: whatever was in hand is put back first.
	if board_view.last_tap_cycled:
		arrange_selected = 0
		reserve_held = 0
	if _arrange_at(square):
		return
	# Any other tap puts the piece in hand back down.
	if arrange_selected > 0:
		_put_down()
	for placement: Dictionary in run_manager.current_run.deployment_state.enemy_placements:
		if DeploymentState.position_from_value(placement.get("position", {})) == square:
			focus_id = ""
			_focus(str(placement.get("piece_def_id", "")))
			return
	# A tap on an empty square closes an open explanation.
	if not focus_id.is_empty():
		_focus(focus_id)

## Handles a tap that picks up, moves or puts down one of your pieces. Returns false when the
## tap was not about arranging.
func _arrange_at(square: Vector2i) -> bool:
	var deployment: DeploymentState = run_manager.current_run.deployment_state
	var own: int = deployment.player_at(square)
	if reserve_held > 0:
		return _swap_in_held_reserve(own)
	if arrange_selected <= 0:
		if own <= 0:
			return false
		arrange_selected = own
		_show_own(own)
		_render_board()
		_render_lineup()
		return true
	if own == arrange_selected:
		_put_down()
		return true
	if not DeploymentState.is_player_zone(square, run_manager.current_run.deployment_state.board_size):
		return false
	if run_manager.move_deployed_piece(arrange_selected, square) != OK:
		_nudge(board_view)
		return true
	_put_down()
	return true

func _put_down() -> void:
	arrange_selected = 0
	_render_board()
	_render_lineup()

func _holding_benchable() -> bool:
	if arrange_selected <= 0:
		return false
	var piece: PieceInstanceState = run_manager.current_run.get_piece_state(arrange_selected)
	return piece != null and not piece.is_king

## Sends the piece in hand to the reserve.
func _bench_held() -> void:
	if not _holding_benchable():
		return
	var held: int = arrange_selected
	arrange_selected = 0
	_toggle_piece(held, false)

## Shows one of your pieces in the details area.
func _show_own(instance_id: int) -> void:
	focus_id = "own:%d" % instance_id
	_render_pattern()

## A reserve piece: swapped with the piece in hand onto its square, or sent into the
## line. With the line full it is picked up instead, to be traded for a board piece.
func _on_reserve_pressed(instance_id: int) -> void:
	_show_own(instance_id)
	if _holding_benchable():
		var held: int = arrange_selected
		arrange_selected = 0
		if run_manager.swap_roster_pieces(held, instance_id) != OK:
			_nudge(bench_row)
		_render()
		return
	if reserve_held == instance_id:
		reserve_held = 0
		_render_lineup()
		return
	if _active_non_king() >= run_manager.current_run.max_active_pieces():
		reserve_held = instance_id
		_render_lineup()
		return
	reserve_held = 0
	_toggle_piece(instance_id, true)

## With a reserve piece in hand, a tap on one of your board pieces trades the two; a
## tap on the King shakes; any other tap puts the reserve piece back.
func _swap_in_held_reserve(own: int) -> bool:
	var incoming: int = reserve_held
	if own <= 0:
		reserve_held = 0
		_render_lineup()
		return false
	var piece: PieceInstanceState = run_manager.current_run.get_piece_state(own)
	if piece == null or piece.is_king:
		_nudge(board_view)
		return true
	reserve_held = 0
	if run_manager.swap_roster_pieces(own, incoming) != OK:
		_nudge(bench_row)
	_show_own(incoming)
	_render()
	return true

func _toggle_piece(instance_id: int, to_active: bool) -> void:
	if to_active and _active_non_king() >= run_manager.current_run.max_active_pieces():
		_nudge(count_badge)
		return
	if not to_active and run_manager.current_run.reserve_piece_ids.size() >= RunState.MAX_RESERVE_PIECES:
		_render_board()
		_render_lineup()
		_nudge(bench_row)
		return
	if run_manager.move_roster_piece(instance_id, to_active) != OK:
		_nudge(bench_row)
		return
	_render()

func _active_non_king() -> int:
	var count: int = 0
	for instance_id: int in run_manager.current_run.active_piece_ids:
		var piece: PieceInstanceState = run_manager.current_run.get_piece_state(instance_id)
		if piece != null and not piece.is_king:
			count += 1
	return count

## Confirms the automatic formation and starts the battle, with the preview board
## growing into the battle board.
func _start_battle() -> void:
	if _starting:
		return
	if run_manager.confirm_deployment() != OK or run_manager.start_current_battle() != OK:
		_show_status(_text("PREBATTLE_START_ERROR"))
		return
	_starting = true
	fight_button.disabled = true
	back_button.disabled = true
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file(AppSceneRoutes.BATTLE)
		return
	# Everything but the board slides away; the battle screen then grows out of the
	# board exactly where it stands (BattleController._play_intro).
	arrange_selected = 0
	reserve_held = 0
	focus_id = ""
	_render_board()
	var leaving: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var layout: Control = $SafeArea/Layout
	for child: Node in layout.get_children():
		if child == board_view or not child is Control:
			continue
		var part: Control = child as Control
		var drop: float = -24.0 if part.get_index() < board_view.get_index() else 24.0
		leaving.parallel().tween_property(part, "modulate:a", 0.0, 0.22)
		leaving.parallel().tween_property(part, "position:y", part.position.y + drop, 0.22)
	await leaving.finished
	await get_tree().process_frame
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set("entry_board_rect", board_view.get_global_rect())
		var frame: Image = get_viewport().get_texture().get_image()
		game_state.set("entry_snapshot", ImageTexture.create_from_image(frame) if frame != null else null)
	get_tree().change_scene_to_file(AppSceneRoutes.BATTLE)

## Steps back to the map. The battle stays chosen, so tapping it on the map comes
## straight back here.
func _return_to_map() -> void:
	if _starting:
		return
	run_manager.leave_deployment()
	get_tree().change_scene_to_file(AppSceneRoutes.PATH_MAP)

## Says "not possible" without words: a quick shake and a red flash.
func _nudge(target: Control) -> void:
	if target == null or not is_inside_tree():
		return
	var rest: Vector2 = target.position
	var tween: Tween = create_tween()
	target.modulate = Color(1.0, 0.55, 0.5)
	for offset: float in [5.0, -5.0, 3.0, -3.0, 0.0]:
		tween.tween_property(target, "position:x", rest.x + offset, 0.04)
	tween.tween_property(target, "modulate", Color.WHITE, 0.15)

## Crops a piece picture to its visible figure (cached), so a Pawn and a Queen fill
## their boxes alike instead of the Pawn floating small in empty space.
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

## Shown once ever: how to move pieces and bench them. Any tap closes it for good.
func _show_first_time_tip() -> void:
	var settings: Node = get_node_or_null("/root/SettingsManager")
	if settings == null or bool(settings.call("has_seen_tip", TIP_ID)):
		return
	tip_bubble = Control.new()
	tip_bubble.name = "TipBubble"
	tip_bubble.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tip_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	tip_bubble.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_dismiss_tip())
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tip_bubble.add_child(shade)
	var bubble: PanelContainer = PanelContainer.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = _box(PANEL, GOLD, 10)
	style.set_content_margin_all(12)
	bubble.add_theme_stylebox_override("panel", style)
	var text: Label = _label(_text("PREBATTLE_FIRST_TIP"), 13, INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(250, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.add_child(text)
	var ok: Label = _label(_text("PREBATTLE_FIRST_TIP_OK"), 11, GOLD_SOFT)
	ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(ok)
	bubble.add_child(column)
	tip_bubble.add_child(bubble)
	add_child(tip_bubble)
	# Sit just above your two ranks, pointing down at them.
	await get_tree().process_frame
	if not is_instance_valid(bubble):
		return
	var board_rect: Rect2 = board_view.get_global_rect()
	var bubble_size: Vector2 = bubble.get_combined_minimum_size()
	bubble.size = bubble_size
	bubble.global_position = Vector2(board_rect.get_center().x - bubble_size.x * 0.5, board_rect.end.y - board_rect.size.y * 0.42 - bubble_size.y)
	var pointer: Control = Control.new()
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.position = bubble.position + Vector2(bubble_size.x * 0.5, bubble_size.y)
	pointer.draw.connect(func() -> void:
		pointer.draw_colored_polygon(PackedVector2Array([Vector2(-9, -1), Vector2(9, -1), Vector2(0, 10)]), GOLD))
	tip_bubble.add_child(pointer)

func _dismiss_tip() -> void:
	if tip_bubble != null and is_instance_valid(tip_bubble):
		tip_bubble.queue_free()
	tip_bubble = null
	var settings: Node = get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.call("mark_tip_seen", TIP_ID)

func _show_status(message: String) -> void:
	status_label.text = message
	status_label.visible = true

func _texture(color: StringName, piece_id: String) -> Texture2D:
	return piece_skin_manager.call("piece_texture", color, StringName(piece_id)) as Texture2D

func _piece_name(piece_id: String) -> String:
	var definition: PieceDef = Content.piece(piece_id)
	return _text(String(definition.display_name_key)) if definition != null else piece_id

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
