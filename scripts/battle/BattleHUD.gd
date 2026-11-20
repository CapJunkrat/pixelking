class_name BattleHUD
extends HBoxContainer

## The battle's top bar, one slim panel: who you fight (portrait, tier, layer), whose
## turn it is (a pill that turns teal on your turn), the round, and settings.

signal settings_requested
signal debug_victory_requested
## The player gives up the bonus action a piece earned this turn.
signal end_turn_requested

const GOLD := Color("#e0b45c")
const GOLD_SOFT := Color("#f5d58f")
const INK := Color("#f1e6cf")
const MUTED := Color("#9aa8bf")
const TEAL := Color("#4fd1c5")
const ENEMY := Color("#e07a6a")
const PANEL := Color(0.05, 0.09, 0.16, 0.9)
const LINE := Color("#2b4166")
const TIER_COLORS := {&"normal_battle": Color("#e0b45c"), &"elite_battle": Color("#c58cff"), &"boss": Color("#ff8a4c")}
const AVATAR := preload("res://assets/ui/battle/modern_v2/enemy_avatar_fill.png")
const GEAR := preload("res://assets/ui/battle/modern/settings_gear.png")
const BAR_HEIGHT := 46.0

const DEBUG_VICTORY_CLICK_COUNT := 5
const DEBUG_VICTORY_CLICK_WINDOW_MSEC := 2000

var enemy_portrait: TextureRect = null
var enemy_label: Label = null
var layer_label: Label = null
var turn_segment: PanelContainer = null
var turn_label: Label = null
var round_label: Label = null
var settings_button: Button = null
var end_turn_button: Button = null
var _tier_color: Color = GOLD
var _your_turn: bool = true
var _debug_clicks: int = 0
var _debug_click_started_msec: int = 0

func _ready() -> void:
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_build()
	_load_encounter()
	_style_turn()

func _draw() -> void:
	var panel: StyleBoxFlat = _box(PANEL, Color(_tier_color, 0.55), 10)
	panel.border_width_top = 0
	panel.border_width_left = 0
	panel.border_width_right = 0
	panel.border_width_bottom = 2
	draw_style_box(panel, Rect2(Vector2.ZERO, size))

# --- building ---------------------------------------------------------------------

func _build() -> void:
	# Who you fight: a framed portrait, the battle tier and the layer. It takes whatever
	# width the turn pill and the gear leave, and a name too long for it ends in "…",
	# so the bar never grows past a 360-wide phone (long boss names, Chinese text).
	var foe: HBoxContainer = HBoxContainer.new()
	foe.name = "Foe"
	foe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foe.add_theme_constant_override("separation", 6)
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "BossPortrait"
	frame.custom_minimum_size = Vector2(36, 36)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style: StyleBoxFlat = _box(Color("#0b1422"), _tier_color, 8)
	frame_style.set_border_width_all(2)
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	enemy_portrait = TextureRect.new()
	enemy_portrait.name = "Portrait"
	enemy_portrait.texture = AVATAR
	enemy_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(enemy_portrait)
	foe.add_child(frame)
	var names: VBoxContainer = VBoxContainer.new()
	names.name = "Names"
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -2)
	enemy_label = _label(_text("BATTLE_ENEMY"), 12, _tier_color)
	enemy_label.name = "EnemyLabel"
	_let_shrink(enemy_label)
	names.add_child(enemy_label)
	layer_label = _label("", 10, MUTED)
	layer_label.name = "LayerLabel"
	layer_label.visible = false
	_let_shrink(layer_label)
	names.add_child(layer_label)
	foe.add_child(names)
	add_child(foe)

	# Whose turn: a pill in the middle, with the round beside it.
	var middle: HBoxContainer = HBoxContainer.new()
	middle.name = "Middle"
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 5)
	turn_segment = PanelContainer.new()
	turn_segment.name = "TurnSegment"
	turn_segment.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	turn_segment.gui_input.connect(_on_turn_segment_input)
	turn_label = _label("", 13, TEAL)
	turn_label.name = "TurnLabel"
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_segment.add_child(turn_label)
	# As wide as the longer of the two turn texts, so the pill keeps its size when the
	# turn changes, in any language.
	turn_label.custom_minimum_size = Vector2(_text_width(turn_label, [_text("BATTLE_YOUR_TURN"), _text("BATTLE_ENEMY_TURN")]), 0)
	middle.add_child(turn_segment)
	var round_chip: PanelContainer = PanelContainer.new()
	round_chip.name = "RoundSegment"
	round_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	round_chip.add_theme_stylebox_override("panel", _box(Color("#0b1422"), LINE, 9))
	round_label = _label("1", 11, INK)
	round_label.name = "RoundLabel"
	round_chip.add_child(round_label)
	round_chip.tooltip_text = _text("BATTLE_ROUND_HINT")
	middle.add_child(round_chip)
	add_child(middle)

	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = _text("BATTLE_END_TURN")
	end_turn_button.visible = false
	end_turn_button.focus_mode = Control.FOCUS_NONE
	end_turn_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	end_turn_button.custom_minimum_size = Vector2(0, 30)
	end_turn_button.add_theme_font_size_override("font_size", 11)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		end_turn_button.add_theme_stylebox_override(state, _box(GOLD if state != "disabled" else GOLD.darkened(0.5), GOLD_SOFT, 8))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		end_turn_button.add_theme_color_override(state, Color("#1a1408"))
	end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	add_child(end_turn_button)

	settings_button = Button.new()
	settings_button.name = "SettingsButton"
	settings_button.custom_minimum_size = Vector2(36, 36)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.tooltip_text = _text("SETTINGS_TITLE")
	settings_button.icon = GEAR
	settings_button.expand_icon = true
	settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_button.add_theme_constant_override("icon_max_width", 22)
	settings_button.add_theme_stylebox_override("normal", _box(Color("#0b1422"), LINE, 8))
	settings_button.add_theme_stylebox_override("hover", _box(Color("#13213a"), GOLD_SOFT, 8))
	settings_button.add_theme_stylebox_override("pressed", _box(Color("#0b1422"), GOLD, 8))
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	add_child(settings_button)

## The tier (Battle / Elite / Boss) and the layer, from the run when there is one.
func _load_encounter() -> void:
	var run_manager: Node = get_node_or_null("/root/RunManager")
	if run_manager == null or run_manager.get("current_run") == null:
		return
	var node: MapNodeState = run_manager.call("current_map_node") as MapNodeState
	if node == null:
		return
	var definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id)
	if definition == null or not definition.is_battle:
		return
	_tier_color = TIER_COLORS.get(definition.id, GOLD)
	enemy_label.text = _text(String(definition.display_name_key)).to_upper()
	var encounter: EncounterDef = EncounterDefDatabase.for_current(run_manager.get("current_run") as RunState)
	if encounter != null and encounter.is_boss and not encounter.display_name_key.is_empty():
		enemy_label.text = _text(String(encounter.display_name_key)).to_upper()
	enemy_label.add_theme_color_override("font_color", _tier_color)
	var map_state: Variant = (run_manager.get("current_run") as RunState).map_state
	if map_state != null:
		var act: int = (run_manager.get("current_run") as RunState).act_index + 1
		layer_label.text = _text("BATTLE_HUD_PLACE") % [act, node.layer_index + 1, (map_state as MapState).total_layers]
		layer_label.visible = true
	var frame: PanelContainer = find_child("BossPortrait", true, false) as PanelContainer
	var frame_style: StyleBoxFlat = frame.get_theme_stylebox("panel") as StyleBoxFlat
	frame_style.border_color = _tier_color
	queue_redraw()

func refresh(board: BoardState, player_color: int) -> void:
	if board == null:
		return
	_your_turn = board.turn == player_color
	_style_turn()
	round_label.text = _text("BATTLE_ROUND") % (floori(float(board.move_history.size()) / 2.0) + 1)
	if end_turn_button != null:
		end_turn_button.visible = _your_turn and board.bonus_instance_id != 0

## Teal pill on your turn, a muted coral one while the enemy thinks.
func _style_turn() -> void:
	if turn_label == null:
		return
	var accent: Color = TEAL if _your_turn else ENEMY
	turn_label.text = _text("BATTLE_YOUR_TURN") if _your_turn else _text("BATTLE_ENEMY_TURN")
	turn_label.add_theme_color_override("font_color", accent.lightened(0.15) if _your_turn else accent)
	var pill: StyleBoxFlat = _box(Color(accent, 0.16), accent, 14)
	pill.set_border_width_all(2 if _your_turn else 1)
	pill.content_margin_left = 10
	pill.content_margin_right = 10
	pill.content_margin_top = 4
	pill.content_margin_bottom = 4
	if _your_turn:
		pill.shadow_color = Color(accent, 0.35)
		pill.shadow_size = 4
	turn_segment.add_theme_stylebox_override("panel", pill)

func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## A label that may be narrower than its text: it then ends in "…" instead of
## widening its container.
func _let_shrink(label: Label) -> void:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

## The widest of `texts` in the label's own font and size, rounded up.
func _text_width(label: Label, texts: Array[String]) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var widest: float = 0.0
	for line: String in texts:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return ceilf(widest)

func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box

func _on_turn_segment_input(event: InputEvent) -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null or not bool(game_state.get("debug_mode")):
		return
	var clicked: bool = false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		clicked = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		clicked = (event as InputEventScreenTouch).pressed
	if not clicked:
		return
	var now_msec: int = Time.get_ticks_msec()
	if _debug_click_started_msec == 0 or now_msec - _debug_click_started_msec > DEBUG_VICTORY_CLICK_WINDOW_MSEC:
		_debug_click_started_msec = now_msec
		_debug_clicks = 0
	_debug_clicks += 1
	if _debug_clicks >= DEBUG_VICTORY_CLICK_COUNT:
		_debug_clicks = 0
		_debug_click_started_msec = 0
		debug_victory_requested.emit()

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
