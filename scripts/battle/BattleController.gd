extends Control

const BOARD_PIXELS := 315.0
const LIGHT := Color("#285064")
const DARK := Color("#102f45")
const GOLD := Color("#f0d8a2")
const TEAL := Color("#2ec8c2")
const DANGER := Color("#ff6338")
@onready var layout: VBoxContainer = $Margin/Layout
@onready var board_frame: Control = $Margin/Layout/BoardFrame
@onready var board_grid: GridContainer = $Margin/Layout/BoardFrame/BoardCenter/BoardGrid
@onready var settings_overlay: BattleSettingsPanel = $SettingsOverlay as BattleSettingsPanel
@onready var challenger_tray: ChallengerTray = $Margin/Layout/ChallengerPanel as ChallengerTray

var selected_square := Vector2i(-1, -1)
var legal_targets: Array[Vector2i] = []
var square_buttons: Dictionary = {}
var challenger_slots: Array[Button] = []
var turn_label: Label
var round_label: Label
var enemy_portrait: TextureRect
var battle_font: Font

func _ready() -> void:
	$Margin/Layout/Title.hide()
	$Margin/Layout/TurnLabel.hide()
	$Margin/Layout/StatusLabel.hide()
	$Margin/Layout/BackButton.hide()
	battle_font = load("res://assets/fonts/battle/PixelMplus10-Bold.ttf") as Font
	_build_top_bar()
	_build_background_vista()
	challenger_slots = challenger_tray.slots()
	board_frame.custom_minimum_size = Vector2(351, 351)
	board_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_install_board_frame_layers()
	PieceSkinManager.skin_changed.connect(_on_skin_changed)
	_build_board()
	_refresh_board()
	_refresh_challenger_slots()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_overlay.is_open():
		settings_overlay.close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if PieceSkinManager.skin_changed.is_connected(_on_skin_changed):
		PieceSkinManager.skin_changed.disconnect(_on_skin_changed)

func _install_board_frame_layers() -> void:
	var background := TextureRect.new()
	background.name = "FrameBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/ui/battle/modern_v2/board_frame_v2_351.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_frame.add_child(background)
	board_frame.move_child(background, 0)

	var overlay := TextureRect.new()
	overlay.name = "FrameOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.texture = load("res://assets/ui/battle/modern_v2/board_frame_overlay_v2.png") as Texture2D
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_frame.add_child(overlay)
func _build_top_bar() -> void:
	layout.add_theme_constant_override("separation", 6)
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bar.custom_minimum_size = Vector2(0, 54)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", -1)
	layout.add_child(bar)
	layout.move_child(bar, 0)
	var boss_panel := Control.new()
	boss_panel.name = "BossPortrait"
	boss_panel.custom_minimum_size = Vector2(52, 52)
	boss_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enemy_portrait = TextureRect.new()
	enemy_portrait.name = "Portrait"
	enemy_portrait.anchor_left = 0.5
	enemy_portrait.anchor_top = 0.5
	enemy_portrait.anchor_right = 0.5
	enemy_portrait.anchor_bottom = 0.5
	enemy_portrait.offset_left = -20.0
	enemy_portrait.offset_top = -20.0
	enemy_portrait.offset_right = 20.0
	enemy_portrait.offset_bottom = 20.0
	enemy_portrait.texture = load("res://assets/ui/battle/modern_v2/enemy_avatar_fill.png") as Texture2D
	enemy_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	enemy_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_child(enemy_portrait)
	var boss_overlay := TextureRect.new()
	boss_overlay.name = "FrameOverlay"
	boss_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_overlay.texture = load("res://assets/ui/battle/modern_v2/boss_frame_overlay.png") as Texture2D
	boss_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	boss_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_child(boss_overlay)
	bar.add_child(boss_panel)

	var enemy_panel := PanelContainer.new()
	enemy_panel.name = "EnemySegment"
	enemy_panel.custom_minimum_size = Vector2(50, 42)
	enemy_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enemy_panel.add_theme_stylebox_override("panel", _frame_style("res://assets/ui/battle/modern_v2/enemy_frame.png", 8, 5))
	var enemy_text := Label.new()
	enemy_text.text = Localization.text("BATTLE_ENEMY")
	enemy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_text.add_theme_color_override("font_color", Color("#f1dfbd"))
	enemy_text.add_theme_font_override("font", battle_font)
	enemy_text.add_theme_font_size_override("font_size", 15)
	enemy_text.add_theme_constant_override("outline_size", 1)
	enemy_text.add_theme_color_override("font_outline_color", Color("#071522"))
	enemy_panel.add_child(enemy_text)
	bar.add_child(enemy_panel)

	var turn_panel := PanelContainer.new()
	turn_panel.name = "TurnSegment"
	turn_panel.custom_minimum_size = Vector2(116, 54)
	turn_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	turn_panel.add_theme_stylebox_override("panel", _frame_style("res://assets/ui/battle/modern_v2/turn_action_frame.png", 12, 8))
	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_override("font", battle_font)
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_constant_override("outline_size", 2)
	turn_label.add_theme_color_override("font_outline_color", Color("#071522"))
	turn_panel.add_child(turn_label)
	bar.add_child(turn_panel)

	var round_panel := PanelContainer.new()
	round_panel.name = "RoundSegment"
	round_panel.custom_minimum_size = Vector2(58, 42)
	round_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	round_panel.add_theme_stylebox_override("panel", _frame_style("res://assets/ui/battle/modern_v2/turn_counter_frame.png", 8, 4))
	var round_content := HBoxContainer.new()
	round_content.alignment = BoxContainer.ALIGNMENT_CENTER
	round_content.add_theme_constant_override("separation", 2)
	round_panel.add_child(round_content)
	var round_caption := Label.new()
	round_caption.text = "T"
	round_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_caption.add_theme_color_override("font_color", Color("#f1dfbd"))
	round_caption.add_theme_font_override("font", battle_font)
	round_caption.add_theme_font_size_override("font_size", 20)
	round_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_content.add_child(round_caption)
	round_label = Label.new()
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_color_override("font_color", Color("#f1dfbd"))
	round_label.add_theme_font_override("font", battle_font)
	round_label.add_theme_font_size_override("font_size", 20)
	round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_content.add_child(round_label)
	bar.add_child(round_panel)

	var gear := Button.new()
	gear.name = "SettingsButton"
	gear.custom_minimum_size = Vector2(52, 52)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.tooltip_text = Localization.text("SETTINGS_TITLE")
	var gear_style := _frame_style("res://assets/ui/battle/modern_v2/settings_frame.png", 10, 0)
	gear.add_theme_stylebox_override("normal", gear_style)
	gear.add_theme_stylebox_override("hover", gear_style)
	gear.add_theme_stylebox_override("pressed", gear_style)
	gear.pressed.connect(settings_overlay.open)
	var gear_icon := TextureRect.new()
	gear_icon.name = "GearIcon"
	gear_icon.anchor_left = 0.5
	gear_icon.anchor_top = 0.5
	gear_icon.anchor_right = 0.5
	gear_icon.anchor_bottom = 0.5
	gear_icon.offset_left = -15.0
	gear_icon.offset_top = -15.0
	gear_icon.offset_right = 15.0
	gear_icon.offset_bottom = 15.0
	gear_icon.texture = load("res://assets/ui/battle/modern/settings_gear.png") as Texture2D
	gear_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gear_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.add_child(gear_icon)
	bar.add_child(gear)
func _build_background_vista() -> void:
	var vista := Control.new()
	vista.name = "BackgroundVista"
	vista.custom_minimum_size = Vector2(0, 50)
	vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(vista)
	layout.move_child(vista, 1)

func _build_board() -> void:
	board_grid.custom_minimum_size = Vector2(315, 315)
	board_grid.add_theme_constant_override("h_separation", 0)
	board_grid.add_theme_constant_override("v_separation", 0)
	for child in board_grid.get_children():
		child.queue_free()
	square_buttons.clear()
	var board := GameState.board
	if board == null:
		return
	board_grid.columns = board.board_size
	var cell_size := floorf(BOARD_PIXELS / board.board_size)
	for display_y in range(board.board_size):
		var y := board.board_size - 1 - display_y
		for x in range(board.board_size):
			var pos := Vector2i(x, y)
			var button := Button.new()
			button.name = "Square_%d_%d" % [x, y]
			button.custom_minimum_size = Vector2(cell_size, cell_size)
			button.focus_mode = Control.FOCUS_NONE
			button.clip_contents = true
			button.pressed.connect(_on_square_pressed.bind(pos))
			var image := TextureRect.new()
			image.name = "Piece"
			image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(image)
			var marker := TextureRect.new()
			marker.name = "MoveMarker"
			marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
			marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.hide()
			button.add_child(marker)
			board_grid.add_child(button)
			square_buttons[pos] = button

func _on_square_pressed(pos: Vector2i) -> void:
	var board := GameState.board
	if board == null:
		return
	if pos in legal_targets and GameState.try_move(selected_square, pos):
		selected_square = Vector2i(-1, -1)
		legal_targets.clear()
		_refresh_board()
		return
	var piece := board.get_piece(pos)
	if piece != null and piece.color == board.turn and piece.color == GameState.player_color:
		selected_square = pos
		legal_targets = board.get_legal_moves(pos)
	else:
		selected_square = Vector2i(-1, -1)
		legal_targets.clear()
	_refresh_board()

func _refresh_board() -> void:
	var board := GameState.board
	if board == null:
		return
	for pos in square_buttons:
		var button := square_buttons[pos] as Button
		var piece := board.get_piece(pos)
		(button.get_node("Piece") as TextureRect).texture = _piece_texture(piece)
		var marker := button.get_node("MoveMarker") as TextureRect
		marker.texture = null
		marker.hide()
		if pos == selected_square:
			marker.texture = load("res://assets/ui/battle/modern/selection_brackets.png") as Texture2D
			marker.show()
		elif pos in legal_targets:
			marker.texture = load("res://assets/ui/battle/modern/attack_ring.png" if piece != null else "res://assets/ui/battle/modern/legal_dot.png") as Texture2D
			marker.show()
		_apply_square_style(button, pos)
	turn_label.text = Localization.text("BATTLE_YOUR_TURN") if board.turn == GameState.player_color else Localization.text("BATTLE_ENEMY_TURN")
	turn_label.add_theme_color_override("font_color", Color("#33c8c2") if board.turn == GameState.player_color else Color("#f1dfbd"))
	round_label.text = str(floori(board.move_history.size() / 2.0) + 1)

func _piece_texture(piece: ChessPiece) -> Texture2D:
	if piece == null:
		return null
	var color: StringName = &"white" if piece.color == GameRules.PieceColor.WHITE else &"black"
	return PieceSkinManager.piece_texture(color, StringName(piece.def.id))

func _apply_square_style(button: Button, pos: Vector2i) -> void:
	var fill := LIGHT if (pos.x + pos.y) % 2 == 0 else DARK
	if not GameState.board.move_history.is_empty():
		var move: Dictionary = GameState.board.move_history[-1]
		if pos == move.get("from") or pos == move.get("to"):
			fill = fill.lightened(0.08)
	var normal := _style(fill, fill, 0, 0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.06)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)

func _refresh_challenger_slots() -> void:
	challenger_tray.refresh(GameState.challenger_items)

func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _board_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#071927")
	style.border_color = Color("#e7c98f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.shadow_color = Color(0.01, 0.04, 0.07, 0.8)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 4)
	style.anti_aliasing = false
	return style

func _hud_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#091c2b")
	style.border_color = Color("#e0c58d")
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.shadow_color = Color(0.01, 0.04, 0.07, 0.75)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	style.anti_aliasing = false
	return style

func _hud_segment_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b2031")
	style.border_color = Color("#705f47")
	style.border_width_right = 1
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.anti_aliasing = false
	return style

func _hud_button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.anti_aliasing = false
	return style

func _challenger_tray_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#091b2a")
	style.border_color = Color("#c7a96e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.01, 0.04, 0.07, 0.8)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 4)
	style.anti_aliasing = false
	return style

func _challenger_title_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ead49e")
	style.border_color = Color("#172f42")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.01, 0.04, 0.07, 0.65)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.anti_aliasing = false
	return style

func _treasure_slot_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f2dfb0") if hovered else Color("#d9c38f")
	style.border_color = Color("#7c6847")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0.02, 0.05, 0.07, 0.7)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	style.anti_aliasing = false
	return style
func _texture_style(path: String, margin: float) -> StyleBoxTexture:
	return _frame_style(path, margin, 0)

func _frame_style(path: String, texture_margin: float, content_margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path) as Texture2D
	style.texture_margin_left = texture_margin
	style.texture_margin_top = texture_margin
	style.texture_margin_right = texture_margin
	style.texture_margin_bottom = texture_margin
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.draw_center = true
	return style
func _on_skin_changed(_skin_id: StringName) -> void:
	_refresh_board()
