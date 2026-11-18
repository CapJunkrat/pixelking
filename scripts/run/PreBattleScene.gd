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
const LINEUP_SLOTS := 6

@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var board_view: DeploymentBoardView = null
var tier_label: Label = null
var layer_label: Label = null
var title_label: Label = null
var hint_label: Label = null
var power_me: Label = null
var power_foe: Label = null
var power_fill: ColorRect = null
var power_track: Control = null
var foe_box: HFlowContainer = null
var pattern_panel: PanelContainer = null
var facts_label: RichTextLabel = null
var count_label: Label = null
var active_row: HBoxContainer = null
var bench_row: HBoxContainer = null
var status_label: Label = null
var back_button: Button = null
var fight_button: Button = null
var focus_id: String = ""
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
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
	layout.add_child(head)
	title_label = _label("", 22, INK)
	title_label.name = "TitleLabel"
	layout.add_child(title_label)
	hint_label = _label("", 12, MUTED)
	layout.add_child(hint_label)

	board_view = DeploymentBoardView.new()
	board_view.name = "BoardFrame"
	board_view.custom_minimum_size = Vector2(0, 220)
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Nothing is placed by hand here, so the board shows no deployment zone.
	board_view.deploy_rows = 0
	board_view.square_pressed.connect(_on_square_pressed)
	layout.add_child(board_view)

	var power: HBoxContainer = HBoxContainer.new()
	power.add_theme_constant_override("separation", 8)
	power_me = _label("", 12, INK)
	power_foe = _label("", 12, INK)
	power_track = Control.new()
	power_track.custom_minimum_size = Vector2(0, 8)
	power_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track_bg: ColorRect = ColorRect.new()
	track_bg.color = ENEMY
	track_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	power_track.add_child(track_bg)
	power_fill = ColorRect.new()
	power_fill.color = TEAL
	power_fill.anchor_bottom = 1.0
	power_track.add_child(power_fill)
	power.add_child(power_me)
	power.add_child(power_track)
	power.add_child(power_foe)
	layout.add_child(power)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Details"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	scroll.add_child(details)
	layout.add_child(scroll)

	details.add_child(_label(_text("PREBATTLE_ENEMIES"), 12, MUTED))
	foe_box = HFlowContainer.new()
	foe_box.name = "EnemyPieces"
	foe_box.add_theme_constant_override("h_separation", 5)
	foe_box.add_theme_constant_override("v_separation", 5)
	details.add_child(foe_box)
	pattern_panel = PanelContainer.new()
	pattern_panel.name = "PiecePattern"
	pattern_panel.add_theme_stylebox_override("panel", _box(Color("#1d1a2b"), ENEMY, 6))
	pattern_panel.visible = false
	details.add_child(pattern_panel)
	facts_label = RichTextLabel.new()
	facts_label.bbcode_enabled = true
	facts_label.fit_content = true
	facts_label.scroll_active = false
	facts_label.add_theme_font_size_override("normal_font_size", 13)
	details.add_child(facts_label)

	var lineup_head: HBoxContainer = HBoxContainer.new()
	var lineup_title: Label = _label(_text("PREBATTLE_LINEUP"), 12, MUTED)
	lineup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lineup_head.add_child(lineup_title)
	count_label = _label("", 12, INK)
	lineup_head.add_child(count_label)
	details.add_child(lineup_head)
	active_row = HBoxContainer.new()
	active_row.name = "ActiveRow"
	active_row.add_theme_constant_override("separation", 5)
	details.add_child(active_row)
	details.add_child(_label(_text("PREBATTLE_RESERVE"), 12, MUTED))
	bench_row = HBoxContainer.new()
	bench_row.name = "ReserveRow"
	bench_row.add_theme_constant_override("separation", 5)
	details.add_child(bench_row)
	var note: Label = _label(_text("PREBATTLE_FORMATION_NOTE"), 11, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(note)

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
	var node_def: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id) if node != null else null
	var encounter: EncounterDef = EncounterDefDatabase.get_def(node_def.encounter_def_id) if node_def != null else null
	if node_def != null:
		var tier_color: Color = TIER_COLORS.get(node_def.id, GOLD)
		tier_label.text = " %s " % _text(String(node_def.display_name_key)).to_upper()
		(tier_label.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _box(tier_color, tier_color, 4))
		title_label.text = _text(String(node_def.enemy_hint_key))
		hint_label.text = _text(String(node_def.description_key))
	if node != null and run.map_state != null:
		layer_label.text = _text("MAP_PROGRESS") % [node.layer_index + 1, run.map_state.total_layers]
	_render_board()
	_render_power()
	_render_foes()
	_render_pattern()
	_render_facts(node_def, encounter)
	_render_lineup()

func _render_board() -> void:
	var deployment: DeploymentState = run_manager.current_run.deployment_state
	var pieces: Dictionary = {}
	var focus_square: Vector2i = DeploymentBoardView.NO_SQUARE
	for placement: Dictionary in deployment.enemy_placements:
		var square: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
		var id: String = str(placement.get("piece_def_id", ""))
		pieces[square] = {"texture": _texture(&"black", id), "player": false}
		if id == focus_id and focus_square == DeploymentBoardView.NO_SQUARE:
			focus_square = square
	for instance_id: int in run_manager.current_run.active_piece_ids:
		var piece: PieceInstanceState = run_manager.current_run.get_piece_state(instance_id)
		pieces[deployment.player_position(instance_id)] = {"texture": _texture(&"white", String(piece.piece_def_id)), "player": true}
	board_view.show_position(deployment.board_size, pieces, focus_square)

func _render_power() -> void:
	var mine: int = 0
	for instance_id: int in run_manager.current_run.active_piece_ids:
		var piece: PieceInstanceState = run_manager.current_run.get_piece_state(instance_id)
		if piece != null and not piece.is_king:
			mine += PieceDefDatabase.get_def(String(piece.piece_def_id)).base_value
	var theirs: int = 0
	for placement: Dictionary in run_manager.current_run.deployment_state.enemy_placements:
		var definition: PieceDef = PieceDefDatabase.get_def(str(placement.get("piece_def_id", "")))
		if definition != null and not definition.is_king:
			theirs += definition.base_value
	power_me.text = _text("PREBATTLE_POWER_MINE") % mine
	power_foe.text = _text("PREBATTLE_POWER_THEIRS") % theirs
	power_fill.anchor_right = float(mine) / float(maxi(1, mine + theirs))

func _render_foes() -> void:
	for child: Node in foe_box.get_children():
		child.queue_free()
	var counts: Dictionary = {}
	var order: Array[String] = []
	for placement: Dictionary in run_manager.current_run.deployment_state.enemy_placements:
		var id: String = str(placement.get("piece_def_id", ""))
		if not counts.has(id):
			order.append(id)
		counts[id] = int(counts.get(id, 0)) + 1
	for id: String in order:
		var chip: Button = Button.new()
		chip.name = "Enemy_%s" % id
		chip.icon = _texture(&"black", id)
		chip.custom_minimum_size = Vector2(0, 34)
		chip.add_theme_constant_override("icon_max_width", 26)
		chip.add_theme_font_size_override("font_size", 12)
		chip.text = _piece_name(id) + (" ×%d" % counts[id] if int(counts[id]) > 1 else "")
		chip.toggle_mode = true
		chip.button_pressed = id == focus_id
		var selected: bool = id == focus_id
		chip.add_theme_stylebox_override("normal", _box(Color("#2a1e2a") if selected else PANEL_2, ENEMY if selected else LINE, 5))
		chip.add_theme_stylebox_override("pressed", _box(Color("#2a1e2a"), ENEMY, 5))
		chip.add_theme_stylebox_override("hover", _box(PANEL_2.lightened(0.08), GOLD_SOFT, 5))
		chip.pressed.connect(_focus.bind(id))
		foe_box.add_child(chip)

func _render_pattern() -> void:
	for child: Node in pattern_panel.get_children():
		child.queue_free()
	pattern_panel.visible = not focus_id.is_empty()
	if focus_id.is_empty():
		return
	var definition: PieceDef = PieceDefDatabase.get_def(focus_id)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var grid: GridContainer = GridContainer.new()
	grid.columns = PATTERN_SIZE
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	var pattern: Dictionary = PieceRulePreview.pattern(focus_id, PATTERN_SIZE)
	var half: int = PATTERN_SIZE / 2
	# Enemy pieces advance down the board, so their pattern is shown mirrored.
	for y: int in range(-half, half + 1):
		for x: int in range(-half, half + 1):
			var cell: ColorRect = ColorRect.new()
			cell.custom_minimum_size = Vector2(11, 11)
			var kind: String = str(pattern.get(Vector2i(x, y), ""))
			cell.color = GOLD if x == 0 and y == 0 else PATTERN_COLORS.get(kind, Color("#2a3550"))
			grid.add_child(cell)
	row.add_child(grid)
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 11)
	var lines: Array[String] = ["[b]%s[/b] · %s" % [_piece_name(focus_id), _text("PREBATTLE_VALUE") % definition.base_value]]
	lines.append(_text(PieceRulePreview.move_key(definition)))
	lines.append(_text(PieceRulePreview.attack_key(definition)))
	for key: String in PieceRulePreview.ability_keys(definition):
		if key != "CODEX_TRAIT_NONE":
			lines.append("[color=#f5d58f]%s[/color]" % _text(key))
	text.text = "\n".join(lines)
	row.add_child(text)
	pattern_panel.add_child(row)

func _render_facts(node_def: MapNodeDef, encounter: EncounterDef) -> void:
	var lines: Array[String] = []
	if node_def != null:
		lines.append("[color=#9aa8bf]%s[/color]  %s" % [_text("PREBATTLE_REWARD"), _text(String(node_def.reward_hint_key))])
	if encounter != null and encounter.turn_limit > 0:
		lines.append("[color=#9aa8bf]%s[/color]  [color=#ff8a4c]%s[/color]" % [_text("PREBATTLE_LIMIT"), _text("PREBATTLE_TURN_LIMIT") % encounter.turn_limit])
	facts_label.text = "\n".join(lines)

func _render_lineup() -> void:
	for row: HBoxContainer in [active_row, bench_row]:
		for child: Node in row.get_children():
			child.queue_free()
	var run: RunState = run_manager.current_run
	var active_count: int = 0
	for instance_id: int in run.active_piece_ids:
		var piece: PieceInstanceState = run.get_piece_state(instance_id)
		if piece == null:
			continue
		if not piece.is_king:
			active_count += 1
		active_row.add_child(_slot(piece, true))
	for _i: int in range(active_row.get_child_count(), LINEUP_SLOTS):
		active_row.add_child(_slot(null, true))
	for instance_id: int in run.reserve_piece_ids:
		bench_row.add_child(_slot(run.get_piece_state(instance_id), false))
	for _i: int in range(bench_row.get_child_count(), LINEUP_SLOTS):
		bench_row.add_child(_slot(null, false))
	count_label.text = "%d / %d" % [active_count, run_manager.current_run.max_active_pieces()]

func _slot(piece: PieceInstanceState, active: bool) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(44, 44)
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
	button.icon = _texture(&"white", String(piece.piece_def_id))
	button.tooltip_text = _piece_name(String(piece.piece_def_id))
	if piece.is_king:
		border = GOLD
	elif active:
		border = TEAL
		fill = Color("#12333a")
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _box(fill if state != "hover" else fill.lightened(0.08), border if state != "hover" else GOLD_SOFT, 6))
	if piece.is_king:
		button.disabled = true
	else:
		button.pressed.connect(_toggle_piece.bind(piece.instance_id, not active))
	return button

# --- actions ------------------------------------------------------------------------

func _focus(id: String) -> void:
	focus_id = "" if focus_id == id else id
	_render_board()
	_render_foes()
	_render_pattern()

func _on_square_pressed(square: Vector2i) -> void:
	for placement: Dictionary in run_manager.current_run.deployment_state.enemy_placements:
		if DeploymentState.position_from_value(placement.get("position", {})) == square:
			focus_id = ""
			_focus(str(placement.get("piece_def_id", "")))
			return

func _toggle_piece(instance_id: int, to_active: bool) -> void:
	if to_active and _active_non_king() >= run_manager.current_run.max_active_pieces():
		_show_status(_text("PREBATTLE_LINEUP_FULL"))
		return
	if not to_active and run_manager.current_run.reserve_piece_ids.size() >= RunState.MAX_RESERVE_PIECES:
		_show_status(_text("PREBATTLE_RESERVE_FULL"))
		return
	if run_manager.move_roster_piece(instance_id, to_active) != OK:
		_show_status(_text("PREBATTLE_LINEUP_ERROR"))
		return
	status_label.visible = false
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
	board_view.pivot_offset = board_view.size * 0.5
	var zoom: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	zoom.tween_property(board_view, "scale", Vector2(1.25, 1.25), 0.3)
	zoom.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	zoom.tween_callback(func() -> void: get_tree().change_scene_to_file(AppSceneRoutes.BATTLE))

func _return_to_map() -> void:
	if not _starting:
		get_tree().change_scene_to_file(AppSceneRoutes.PATH_MAP)

func _show_status(message: String) -> void:
	status_label.text = message
	status_label.visible = true

func _texture(color: StringName, piece_id: String) -> Texture2D:
	return piece_skin_manager.call("piece_texture", color, StringName(piece_id)) as Texture2D

func _piece_name(piece_id: String) -> String:
	var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
	return _text(String(definition.display_name_key)) if definition != null else piece_id

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
