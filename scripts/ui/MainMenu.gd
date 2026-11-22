class_name MainMenu
extends Control

@onready var title_logo: TextureRect = $SafeArea/Layout/Header/TitleLogo
@onready var settings_overlay: ColorRect = $SettingsOverlay
@onready var battle_placeholder: ColorRect = $BattlePlaceholder
@onready var overwrite_confirmation: ColorRect = $OverwriteConfirmation
@onready var overwrite_cancel_button: Button = $OverwriteConfirmation/Center/Panel/Content/Actions/CancelButton
@onready var overwrite_confirm_button: Button = $OverwriteConfirmation/Center/Panel/Content/Actions/ConfirmButton
@onready var new_game_button: Button = $SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton
@onready var continue_button: Button = $SafeArea/Layout/MenuPanel/MenuButtons/ContinueButton
@onready var language_option: OptionButton = $SettingsOverlay/SettingsPanel/SettingsContent/LanguageOption
@onready var piece_skin_option: OptionButton = $SettingsOverlay/SettingsPanel/SettingsContent/PieceSkinOption
@onready var white_skin_preview: GridContainer = $SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/WhitePieces
@onready var black_skin_preview: GridContainer = $SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/BlackPieces
@onready var music_slider: HSlider = $SettingsOverlay/SettingsPanel/SettingsContent/MusicSlider
@onready var sound_slider: HSlider = $SettingsOverlay/SettingsPanel/SettingsContent/SoundSlider
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")
@onready var settings_manager: AppSettingsManager = get_node("/root/SettingsManager") as AppSettingsManager
@onready var audio_manager: AppAudioManager = get_node("/root/AudioManager") as AppAudioManager
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager

const PIECE_TYPES: Array[StringName] = [&"king", &"queen", &"rook", &"bishop", &"knight", &"pawn", &"assassin", &"royal_guard", &"catapult", &"bowman", &"portal_mage", &"unicorn_cavalry", &"centaur", &"manticore", &"gryphon", &"gorgon"]
const INTRO_BUTTON_DELAY := 0.15
const DEBUG_TITLE_CLICK_COUNT := 7
const DEBUG_TITLE_CLICK_WINDOW_MSEC := 3000

var codex_button: Button
var codex_overlay: ColorRect
var codex_grid: GridContainer
var codex_title_label: Label
var codex_progress_label: Label
var codex_back_button: Button
var codex_details: PieceInfoPanel
var codex_hint_label: Label
var achievement_button: Button
var achievement_overlay: AchievementPanel
var debug_badge: Label
## Asked before every new journey: Easy or Medium. Built from a copy of the overwrite
## confirmation so it shares its look.
var difficulty_picker: ColorRect
var difficulty_easy_button: Button
var difficulty_medium_button: Button
var difficulty_back_button: Button
var _picker_allows_overwrite: bool = false
var _intro_tween: Tween
var _intro_playing: bool = false
var _debug_title_clicks: int = 0
var _debug_title_click_started_msec: int = 0

func _ready() -> void:
	_build_codex_controls()
	_build_difficulty_picker()
	$SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	$SafeArea/Layout/MenuPanel/MenuButtons/SettingsButton.pressed.connect(_on_settings_pressed)
	codex_button.pressed.connect(_open_codex)
	achievement_button.pressed.connect(_open_achievements)
	title_logo.gui_input.connect(_on_title_logo_input)
	codex_back_button.pressed.connect(_close_codex)
	_setup_menu_button_visuals()
	$SettingsOverlay/SettingsPanel/SettingsContent/BackButton.pressed.connect(_close_settings)
	$BattlePlaceholder/BattleContent/BackButton.pressed.connect(_close_battle_placeholder)
	language_option.item_selected.connect(_on_language_selected)
	piece_skin_option.item_selected.connect(_on_piece_skin_selected)
	piece_skin_manager.skin_changed.connect(_on_piece_skin_changed)
	Localization.locale_changed.connect(_apply_locale)
	_populate_languages()
	_apply_locale(Localization.current_locale)
	_populate_piece_skins()
	_build_skin_preview()
	_setup_audio_controls()
	_setup_run_controls()
	_refresh_run_buttons()
	_play_intro()

func _unhandled_input(event: InputEvent) -> void:
	if _intro_playing and event.is_pressed():
		_finish_intro(true)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if difficulty_picker.visible:
			_close_difficulty_picker()
		elif overwrite_confirmation.visible:
			_close_overwrite_confirmation()
		elif settings_overlay.visible:
			_close_settings()
		elif codex_overlay.visible and codex_details.is_open():
			codex_details.close()
		elif codex_overlay.visible:
			_close_codex()
		elif achievement_overlay.visible:
			achievement_overlay.close()
		elif battle_placeholder.visible:
			_close_battle_placeholder()

func _build_codex_controls() -> void:
	var menu_buttons: VBoxContainer = $SafeArea/Layout/MenuPanel/MenuButtons
	var settings_button: Button = menu_buttons.get_node("SettingsButton") as Button
	codex_button = settings_button.duplicate() as Button
	codex_button.name = "CodexButton"
	menu_buttons.add_child(codex_button)
	var codex_label: Label = codex_button.get_node("Content/Group/Label") as Label
	codex_label.text = "MENU_CODEX"

	# Achievements: a menu button after the codex and its own full-screen page.
	achievement_button = settings_button.duplicate() as Button
	achievement_button.name = "AchievementButton"
	menu_buttons.add_child(achievement_button)
	var achievement_icon: TextureRect = achievement_button.get_node("Content/Group/Icon") as TextureRect
	achievement_icon.texture = piece_skin_manager.call("piece_texture", &"white", &"king") as Texture2D
	achievement_overlay = AchievementPanel.new()
	achievement_overlay.build($SettingsOverlay/SettingsPanel.get_theme_stylebox("panel").duplicate())
	add_child(achievement_overlay)
	achievement_overlay.closed.connect(func() -> void: achievement_button.grab_focus())

	codex_overlay = ColorRect.new()
	codex_overlay.name = "CodexOverlay"
	codex_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	codex_overlay.color = Color(0.005, 0.008, 0.02, 0.94)
	codex_overlay.hide()
	add_child(codex_overlay)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 22)
	codex_overlay.add_child(margin)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", $SettingsOverlay/SettingsPanel.get_theme_stylebox("panel").duplicate())
	margin.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	codex_title_label = Label.new()
	codex_title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34, 1.0))
	codex_title_label.add_theme_font_size_override("font_size", 26)
	codex_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(codex_title_label)
	codex_progress_label = Label.new()
	codex_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(codex_progress_label)
	codex_hint_label = Label.new()
	codex_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codex_hint_label.add_theme_font_size_override("font_size", 11)
	codex_hint_label.add_theme_color_override("font_color", Color(0.6, 0.66, 0.75, 1.0))
	content.add_child(codex_hint_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CodexScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Only ever scrolls up and down: the cards share the width, so the page cannot
	# slide sideways under a finger.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	codex_grid = GridContainer.new()
	codex_grid.columns = 2
	codex_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_grid.add_theme_constant_override("h_separation", 8)
	codex_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(codex_grid)
	DragScroll.enable(scroll)

	codex_details = PieceInfoPanel.new()
	codex_details.name = "CodexDetails"
	codex_overlay.add_child(codex_details)

	codex_back_button = Button.new()
	codex_back_button.custom_minimum_size = Vector2(0, 46)
	codex_back_button.add_theme_font_size_override("font_size", 22)
	content.add_child(codex_back_button)

	debug_badge = Label.new()
	debug_badge.name = "DebugBadge"
	debug_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.32, 1.0))
	debug_badge.add_theme_font_size_override("font_size", 12)
	debug_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_badge.visible = GameState.debug_mode
	$SafeArea/Layout/Header.add_child(debug_badge)

func _on_title_logo_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var clicked: bool = false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		clicked = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		clicked = (event as InputEventScreenTouch).pressed
	if not clicked or GameState.debug_mode:
		return
	var now_msec: int = Time.get_ticks_msec()
	if _debug_title_click_started_msec == 0 or now_msec - _debug_title_click_started_msec > DEBUG_TITLE_CLICK_WINDOW_MSEC:
		_debug_title_click_started_msec = now_msec
		_debug_title_clicks = 0
	_debug_title_clicks += 1
	if _debug_title_clicks < DEBUG_TITLE_CLICK_COUNT:
		return
	GameState.enable_debug_mode()
	debug_badge.show()
	debug_badge.text = Localization.text("DEBUG_ENABLED")
	_debug_title_clicks = 0
	_debug_title_click_started_msec = 0
	if codex_overlay.visible:
		_render_codex()

func _open_codex() -> void:
	_render_codex()
	codex_overlay.show()
	codex_back_button.grab_focus()

func _open_achievements() -> void:
	achievement_overlay.open(run_manager)

func _close_codex() -> void:
	codex_overlay.hide()
	codex_button.grab_focus()

func _render_codex() -> void:
	for child: Node in codex_grid.get_children():
		child.queue_free()
	var discovered: Array[String] = run_manager.discovered_piece_ids()
	var all_ids: Array[String] = []
	for piece_id: String in PieceDefDatabase.all_ids():
		var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
		if definition != null and not definition.is_egg:
			all_ids.append(piece_id)
	all_ids.sort_custom(_codex_order)
	var shown_count: int = all_ids.size() if GameState.debug_mode else discovered.size()
	codex_progress_label.text = Localization.text("CODEX_DEBUG_COMPLETE") if GameState.debug_mode else Localization.text("CODEX_PROGRESS") % [shown_count, all_ids.size()]
	for piece_id: String in all_ids:
		codex_grid.add_child(_make_codex_card(piece_id, GameState.debug_mode or piece_id in discovered))

## Every codex card has the same size: both portraits, the name, the rarity (also the
## border colour) and a few one-word traits. Tapping a found piece opens its details.
const CODEX_CARD_HEIGHT := 140.0
const CODEX_MAX_TAGS := 4

## Rarest first; within a rarity the more valuable piece first, then by id.
func _codex_order(a: String, b: String) -> bool:
	var first: PieceDef = PieceDefDatabase.get_def(a)
	var second: PieceDef = PieceDefDatabase.get_def(b)
	if first.rarity != second.rarity:
		return first.rarity > second.rarity
	if first.base_value != second.base_value:
		return first.base_value > second.base_value
	return a < b

func _make_codex_card(piece_id: String, revealed: bool) -> PanelContainer:
	var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
	var accent: Color = PieceRulePreview.rarity_color(definition) if revealed and definition != null else Color(0.3, 0.32, 0.38, 1.0)
	var card: PanelContainer = PanelContainer.new()
	card.name = "Codex_%s" % piece_id
	card.custom_minimum_size = Vector2(0, CODEX_CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.075, 0.08, 0.14, 0.98)
	card_style.set_border_width_all(1)
	card_style.border_width_top = 3
	card_style.border_color = accent.darkened(0.15)
	card_style.set_corner_radius_all(4)
	card_style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", card_style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 3)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(layout)
	if not revealed or definition == null:
		var unknown_label: Label = Label.new()
		unknown_label.text = Localization.text("CODEX_UNKNOWN")
		unknown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		unknown_label.add_theme_color_override("font_color", Color(0.55, 0.56, 0.62, 1.0))
		unknown_label.add_theme_font_size_override("font_size", 56)
		layout.add_child(unknown_label)
		return card
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_codex_card_input.bind(definition))
	var portraits: HBoxContainer = HBoxContainer.new()
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	portraits.add_theme_constant_override("separation", 4)
	portraits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(portraits)
	for color: StringName in [&"white", &"black"]:
		var portrait: TextureRect = TextureRect.new()
		portrait.custom_minimum_size = Vector2(44, 44)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.texture = piece_skin_manager.piece_texture(color, StringName(piece_id))
		portraits.add_child(portrait)
	var name_label: Label = _codex_label(Localization.text(String(definition.display_name_key)), 15, Color(0.95, 0.91, 0.8, 1.0))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(name_label)
	layout.add_child(_codex_label(Localization.text(PieceRulePreview.rarity_key(definition)), 10, accent))
	var tags: HFlowContainer = HFlowContainer.new()
	tags.name = "Tags"
	tags.alignment = FlowContainer.ALIGNMENT_CENTER
	tags.add_theme_constant_override("h_separation", 3)
	tags.add_theme_constant_override("v_separation", 3)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(tags)
	var tag_keys: Array[String] = PieceRulePreview.tag_keys(definition)
	for key: String in tag_keys.slice(0, CODEX_MAX_TAGS):
		tags.add_child(_codex_tag(Localization.text(key)))
	return card

func _codex_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _codex_tag(text: String) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.2, 0.3, 1.0)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(_codex_label(text, 10, Color(0.96, 0.84, 0.56, 1.0)))
	return chip

## A tap (not a drag-scroll) on a found piece opens its details: the finger must lift
## close to where it went down.
const CODEX_TAP_SLOP := 12.0
var _codex_press_point: Vector2 = Vector2.INF

func _on_codex_card_input(event: InputEvent, definition: PieceDef) -> void:
	# Touches arrive as emulated mouse buttons too; only those carry a screen position,
	# which tells a tap from a drag that scrolled the card away under the finger.
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse.pressed:
		_codex_press_point = mouse.global_position
	elif _codex_press_point != Vector2.INF and mouse.global_position.distance_to(_codex_press_point) <= CODEX_TAP_SLOP:
		_codex_press_point = Vector2.INF
		open_codex_details(definition)

func open_codex_details(definition: PieceDef) -> void:
	codex_details.show_definition(definition)

func _rarity_text(rarity: PieceDef.Rarity) -> String:
	match rarity:
		PieceDef.Rarity.RARE:
			return Localization.text("RARITY_RARE")
		PieceDef.Rarity.EPIC:
			return Localization.text("RARITY_EPIC")
		PieceDef.Rarity.LEGENDARY:
			return Localization.text("RARITY_LEGENDARY")
		PieceDef.Rarity.MYTHIC:
			return Localization.text("RARITY_MYTHIC")
		_:
			return Localization.text("RARITY_COMMON")

func _populate_languages() -> void:
	language_option.clear()
	var selected_index := 0
	for locale_variant: Variant in Localization.locale_codes():
		var locale: String = str(locale_variant)
		var info: Dictionary = Localization.locale_info(locale)
		var index: int = language_option.item_count
		language_option.add_item(info.get("label", locale))
		language_option.set_item_metadata(index, locale)
		language_option.set_item_disabled(index, not info.get("enabled", false))
		if locale == Localization.current_locale:
			selected_index = index
	language_option.select(selected_index)

func _apply_locale(_locale: String) -> void:
	title_logo.texture = Localization.title_texture()
	$SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton/Content/Group/Label.text = Localization.text("MENU_NEW_GAME")
	$SafeArea/Layout/MenuPanel/MenuButtons/ContinueButton/Content/Group/Label.text = Localization.text("MENU_CONTINUE")
	$SafeArea/Layout/MenuPanel/MenuButtons/SettingsButton/Content/Group/Label.text = Localization.text("MENU_SETTINGS")
	var codex_label: Label = codex_button.get_node("Content/Group/Label") as Label
	codex_label.text = Localization.text("MENU_CODEX")
	(achievement_button.get_node("Content/Group/Label") as Label).text = Localization.text("MENU_ACHIEVEMENTS")
	codex_title_label.text = Localization.text("CODEX_TITLE")
	codex_hint_label.text = Localization.text("CODEX_TAP_HINT")
	codex_back_button.text = Localization.text("COMMON_BACK")
	debug_badge.text = Localization.text("DEBUG_ENABLED")
	$SettingsOverlay/SettingsPanel/SettingsContent/Title.text = Localization.text("SETTINGS_TITLE")
	$SettingsOverlay/SettingsPanel/SettingsContent/LanguageLabel.text = Localization.text("SETTINGS_LANGUAGE")
	$SettingsOverlay/SettingsPanel/SettingsContent/MusicLabel.text = Localization.text("SETTINGS_MUSIC")
	$SettingsOverlay/SettingsPanel/SettingsContent/SoundLabel.text = Localization.text("SETTINGS_SOUND")
	$SettingsOverlay/SettingsPanel/SettingsContent/PieceSkinLabel.text = Localization.text("SETTINGS_PIECE_SKIN")
	$SettingsOverlay/SettingsPanel/SettingsContent/PreviewLabel.text = Localization.text("SETTINGS_SKIN_PREVIEW")
	$SettingsOverlay/SettingsPanel/SettingsContent/BackButton.text = Localization.text("COMMON_BACK")
	$BattlePlaceholder/BattleContent/Title.text = Localization.text("JOURNEY_TITLE")
	$BattlePlaceholder/BattleContent/Description.text = Localization.text("JOURNEY_DESCRIPTION")
	$BattlePlaceholder/BattleContent/BackButton.text = Localization.text("JOURNEY_BACK")
	$OverwriteConfirmation/Center/Panel/Content/Title.text = Localization.text("MENU_OVERWRITE_TITLE")
	$OverwriteConfirmation/Center/Panel/Content/Message.text = Localization.text("MENU_OVERWRITE_MESSAGE")
	$OverwriteConfirmation/Center/Panel/Content/Warning.text = Localization.text("MENU_OVERWRITE_WARNING")
	overwrite_cancel_button.text = Localization.text("COMMON_CANCEL")
	overwrite_confirm_button.text = Localization.text("MENU_OVERWRITE_CONFIRM")
	var picker: Node = difficulty_picker.get_node("Center/Panel/Content")
	(picker.get_node("Title") as Label).text = Localization.text("MENU_DIFFICULTY_TITLE")
	(picker.get_node("Message") as Label).text = Localization.text("MENU_DIFFICULTY_MESSAGE")
	(picker.get_node("Warning") as Label).text = Localization.text("MENU_DIFFICULTY_WARNING")
	difficulty_easy_button.text = Localization.text("DIFFICULTY_EASY")
	difficulty_medium_button.text = Localization.text("DIFFICULTY_MEDIUM")
	difficulty_back_button.text = Localization.text("COMMON_CANCEL")

func _setup_menu_button_visuals() -> void:
	for child in $SafeArea/Layout/MenuPanel/MenuButtons.get_children():
		var button := child as Button
		if button == null:
			continue
		button.mouse_entered.connect(_refresh_menu_button.bind(button))
		button.mouse_exited.connect(_refresh_menu_button.bind(button))
		button.focus_entered.connect(_refresh_menu_button.bind(button))
		button.focus_exited.connect(_refresh_menu_button.bind(button))
		button.button_down.connect(_refresh_menu_button.bind(button))
		button.button_up.connect(_refresh_menu_button.bind(button))
		_refresh_menu_button(button)

func _refresh_menu_button(button: Button) -> void:
	var label := button.get_node("Content/Group/Label") as Label
	var icon := button.get_node("Content/Group/Icon") as TextureRect
	if button.disabled:
		label.add_theme_color_override("font_color", Color(0.48, 0.48, 0.5, 1.0))
		icon.modulate = Color(0.48, 0.48, 0.5, 1.0)
		return
	var highlighted := button.is_hovered() or button.has_focus() or button.button_pressed
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.85, 0.4, 1.0) if highlighted else Color(0.94, 0.9, 0.78, 1.0)
	)
	icon.modulate = Color(1.15, 1.08, 0.88, 1.0) if highlighted else Color.WHITE

func _on_language_selected(index: int) -> void:
	var locale: String = str(language_option.get_item_metadata(index))
	Localization.set_locale(locale)

func _setup_audio_controls() -> void:
	for slider: HSlider in [music_slider, sound_slider]:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
	music_slider.set_value_no_signal(audio_manager.music_volume())
	sound_slider.set_value_no_signal(audio_manager.sfx_volume())
	music_slider.value_changed.connect(_on_music_volume_changed)
	sound_slider.value_changed.connect(_on_sfx_volume_changed)
	settings_manager.music_volume_changed.connect(_sync_music_slider)
	settings_manager.sfx_volume_changed.connect(_sync_sfx_slider)

func _on_music_volume_changed(value: float) -> void:
	audio_manager.set_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	audio_manager.set_sfx_volume(value)

func _sync_music_slider(value: float) -> void:
	music_slider.set_value_no_signal(value)

func _sync_sfx_slider(value: float) -> void:
	sound_slider.set_value_no_signal(value)

func _build_difficulty_picker() -> void:
	difficulty_picker = overwrite_confirmation.duplicate() as ColorRect
	difficulty_picker.name = "DifficultyPicker"
	difficulty_picker.hide()
	add_child(difficulty_picker)
	var content: VBoxContainer = difficulty_picker.get_node("Center/Panel/Content") as VBoxContainer
	difficulty_easy_button = content.get_node("Actions/CancelButton") as Button
	difficulty_medium_button = content.get_node("Actions/ConfirmButton") as Button
	difficulty_easy_button.name = "EasyButton"
	difficulty_medium_button.name = "MediumButton"
	difficulty_back_button = Button.new()
	difficulty_back_button.name = "BackButton"
	difficulty_back_button.flat = true
	difficulty_back_button.custom_minimum_size = Vector2(0, 36)
	difficulty_back_button.add_theme_font_size_override("font_size", 16)
	content.add_child(difficulty_back_button)
	difficulty_easy_button.pressed.connect(_on_difficulty_chosen.bind(EnemyMoveSelector.DIFFICULTY_EASY))
	difficulty_medium_button.pressed.connect(_on_difficulty_chosen.bind(EnemyMoveSelector.DIFFICULTY_MEDIUM))
	difficulty_back_button.pressed.connect(_close_difficulty_picker)

func _show_difficulty_picker(allow_overwrite: bool) -> void:
	_picker_allows_overwrite = allow_overwrite
	difficulty_picker.show()
	difficulty_easy_button.grab_focus()

func _close_difficulty_picker() -> void:
	difficulty_picker.hide()
	_focus_new_game_button()

func _on_difficulty_chosen(difficulty: String) -> void:
	difficulty_picker.hide()
	_start_random_journey(_picker_allows_overwrite, difficulty)

func _setup_run_controls() -> void:
	overwrite_cancel_button.pressed.connect(_close_overwrite_confirmation)
	overwrite_confirm_button.pressed.connect(_confirm_overwrite)
	run_manager.active_run_changed.connect(_on_active_run_changed)

func _focus_new_game_button() -> void:
	if new_game_button.focus_mode != Control.FOCUS_NONE:
		new_game_button.grab_focus()

func _show_overwrite_confirmation() -> void:
	overwrite_confirmation.show()
	overwrite_cancel_button.grab_focus()

func _close_overwrite_confirmation() -> void:
	overwrite_confirmation.hide()
	_focus_new_game_button()

func _confirm_overwrite() -> void:
	overwrite_confirmation.hide()
	_show_difficulty_picker(true)

func _refresh_run_buttons() -> void:
	continue_button.disabled = not run_manager.can_continue()
	_refresh_menu_button(continue_button)

func _on_active_run_changed(_run_state: RunState) -> void:
	_refresh_run_buttons()

func _start_random_journey(allow_overwrite: bool = false, difficulty: String = EnemyMoveSelector.DIFFICULTY_EASY) -> void:
	var run_seed: int = _debug_seed_override()
	if run_seed == 0:
		run_seed = _generate_random_seed()
	if not run_manager.create_run(run_seed, RunState.MODE_STANDARD, allow_overwrite, difficulty):
		push_error(Localization.text("SAVE_ERROR"))
		return
	get_tree().change_scene_to_file(run_manager.resume_scene_path())

func _generate_random_seed() -> int:
	var generated: int = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	return absi(generated) if generated != 0 else 1

## Developer-only deterministic entry: launch with `-- --seed=12345`.
## It is intentionally absent from the player-facing menu.
func _debug_seed_override() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--seed="):
			continue
		var value: String = argument.trim_prefix("--seed=")
		if value.is_valid_int() and value.to_int() != 0:
			return value.to_int()
	return 0

func _play_intro() -> void:
	modulate.a = 1.0
	_intro_playing = true
	title_logo.modulate.a = 0.0

	var buttons: Array[Button] = []
	for child in $SafeArea/Layout/MenuPanel/MenuButtons.get_children():
		var button := child as Button
		if button == null:
			continue
		buttons.append(button)
		button.modulate.a = 0.0
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE

	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(title_logo, "modulate:a", 1.0, 0.70).set_delay(0.10)

	for index in buttons.size():
		var button := buttons[index]
		var delay := 0.55 + index * INTRO_BUTTON_DELAY
		_intro_tween.tween_property(button, "modulate:a", 1.0, 0.60).set_delay(delay)

	_intro_tween.chain().tween_callback(_finish_intro)

func _finish_intro(skip_tween: bool = false) -> void:
	if not _intro_playing:
		return
	_intro_playing = false
	if skip_tween and is_instance_valid(_intro_tween):
		_intro_tween.kill()
	_intro_tween = null

	title_logo.modulate.a = 1.0

	for child in $SafeArea/Layout/MenuPanel/MenuButtons.get_children():
		var button := child as Button
		if button == null:
			continue
		button.modulate.a = 1.0
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_ALL

	new_game_button.grab_focus()
	_play_title_float()

func _populate_piece_skins() -> void:
	piece_skin_option.clear()
	var selected_index := 0
	for skin in piece_skin_manager.available_skins():
		var index := piece_skin_option.item_count
		piece_skin_option.add_item(skin.display_name)
		piece_skin_option.set_item_metadata(index, skin.skin_id)
		if skin.skin_id == piece_skin_manager.current_skin_id:
			selected_index = index
	piece_skin_option.select(selected_index)
	# With a single style there is nothing to pick: the picker and its preview stay
	# hidden until a second style exists.
	var has_choice: bool = piece_skin_option.item_count > 1
	for node_name: String in ["PieceSkinLabel", "PieceSkinOption", "PreviewLabel", "SkinPreview"]:
		($SettingsOverlay/SettingsPanel/SettingsContent.get_node(node_name) as Control).visible = has_choice

func _build_skin_preview() -> void:
	for row in [white_skin_preview, black_skin_preview]:
		for child in row.get_children():
			child.queue_free()
	for piece_type in PIECE_TYPES:
		white_skin_preview.add_child(_make_preview_piece(&"white", piece_type))
		black_skin_preview.add_child(_make_preview_piece(&"black", piece_type))

func _make_preview_piece(color: StringName, piece_type: StringName) -> TextureRect:
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(30, 30)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.texture = piece_skin_manager.piece_texture(color, piece_type)
	preview.tooltip_text = "%s %s" % [String(color).capitalize(), String(piece_type).capitalize()]
	return preview

func _on_piece_skin_selected(index: int) -> void:
	piece_skin_manager.set_skin(StringName(piece_skin_option.get_item_metadata(index)))

func _on_piece_skin_changed(_skin_id: StringName) -> void:
	_build_skin_preview()

func _play_title_float() -> void:
	var start_y := title_logo.position.y
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_logo, "position:y", start_y - 3.0, 1.5)
	tween.tween_property(title_logo, "position:y", start_y, 1.5)

func _on_new_game_pressed() -> void:
	if run_manager.can_continue():
		_show_overwrite_confirmation()
		return
	_show_difficulty_picker(false)

func _on_continue_pressed() -> void:
	var error: Error = run_manager.ensure_opening_draft_pending()
	if error != OK:
		push_error(Localization.text("SAVE_ERROR"))
		return
	get_tree().change_scene_to_file(run_manager.resume_scene_path())

func _close_battle_placeholder() -> void:
	battle_placeholder.visible = false
	new_game_button.grab_focus()

func _on_settings_pressed() -> void:
	settings_overlay.visible = true
	$SettingsOverlay/SettingsPanel/SettingsContent/LanguageOption.grab_focus()

func _close_settings() -> void:
	settings_overlay.visible = false
	$SafeArea/Layout/MenuPanel/MenuButtons/SettingsButton.grab_focus()

