class_name RunInteractionScene
extends Control

## Shops, events, rest sites, battle rewards and the Run summary. Each choice is a card
## that shows what it gives (a piece, an item, gold, a retry), what it costs and how
## risky it is. After an event or rest choice the outcome is shown before moving on.

const GOLD := Color("#e0b45c")
const GOLD_SOFT := Color("#f5d58f")
const INK := Color("#f1e6cf")
const MUTED := Color("#9aa8bf")
const TEAL := Color("#4fd1c5")
const DANGER := Color("#e07a6a")
const PANEL := Color("#12203a")
const PANEL_2 := Color("#172a48")
const LINE := Color("#2b4166")
## Which map icon heads each kind of interaction.
const RARITY_KEYS: Array[String] = ["RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY", "RARITY_MYTHIC"]
const RARITY_COLORS: Array[Color] = [Color("#b8c0cc"), Color("#5aa8ff"), Color("#b77cff"), Color("#f5c860"), Color("#ff6a5a")]
const HEADER_ICON := {"shop": &"shop", "event": &"event", "rest": &"rest", "battle_reward": &"normal_battle", "run_summary": &"boss", "roster_overflow": &"normal_battle", "fusion_confirmation": &"shop"}

@onready var title_label: Label = $SafeArea/Layout/Title
@onready var status_label: Label = $SafeArea/Layout/Status
@onready var choices: VBoxContainer = $SafeArea/Layout/Choices
@onready var leave_button: Button = $SafeArea/Layout/LeaveButton
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager
@onready var localization: Node = get_node("/root/Localization")
@onready var piece_skin_manager: Node = get_node_or_null("/root/PieceSkinManager")

var _badge: Control = null
var _badge_type: StringName = &"event"
var _gold_label: Label = null
var _outcome: PanelContainer = null
var _vignette: EventVignette = null

func _ready() -> void:
	_build()
	leave_button.pressed.connect(_on_leave)
	_render()

func _build() -> void:
	var layout: VBoxContainer = $SafeArea/Layout
	layout.add_theme_constant_override("separation", 10)
	var top: HBoxContainer = HBoxContainer.new()
	top.name = "TopBar"
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var purse: PanelContainer = PanelContainer.new()
	purse.add_theme_stylebox_override("panel", _box(PANEL_2, GOLD, 12, 10))
	_gold_label = _label("", 14, GOLD_SOFT)
	_gold_label.name = "GoldLabel"
	purse.add_child(_gold_label)
	top.add_child(purse)
	layout.add_child(top)
	layout.move_child(top, 0)
	_badge = Control.new()
	_badge.name = "Badge"
	_badge.custom_minimum_size = Vector2(0, 64)
	_badge.draw.connect(_draw_badge)
	layout.add_child(_badge)
	layout.move_child(_badge, 1)
	_vignette = EventVignette.new()
	_vignette.name = "EventScene"
	_vignette.visible = false
	layout.add_child(_vignette)
	layout.move_child(_vignette, 2)
	title_label.add_theme_color_override("font_color", GOLD_SOFT)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.add_theme_font_size_override("font_size", 13)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ChoiceScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var index: int = choices.get_index()
	layout.remove_child(choices)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 8)
	scroll.add_child(choices)
	DragScroll.enable(scroll)
	layout.add_child(scroll)
	layout.move_child(scroll, index)
	_style_button(leave_button, false)
	_outcome = PanelContainer.new()
	_outcome.name = "Outcome"
	_outcome.visible = false
	_outcome.add_theme_stylebox_override("panel", _box(PANEL, GOLD, 8, 14))
	layout.add_child(_outcome)
	layout.move_child(_outcome, scroll.get_index() + 1)

func _render() -> void:
	for child: Node in choices.get_children():
		child.queue_free()
	if run_manager.current_run == null or run_manager.current_run.pending_choice.is_empty():
		title_label.text = _localized("INTERACTION_NONE")
		status_label.text = _localized("INTERACTION_NONE_DETAIL")
		leave_button.text = _localized("INTERACTION_CONTINUE")
		_gold_label.text = ""
		return
	var run: RunState = run_manager.current_run
	var pending: Dictionary = run.pending_choice
	var type: String = str(pending.get("type", "interaction"))
	_badge_type = HEADER_ICON.get(type, &"event")
	_badge.queue_redraw()
	var event_def: EventDef = RunContentDatabase.event_def(StringName(str(pending.get("event_id", "")))) if type == "event" else null
	_vignette.visible = event_def != null
	_badge.visible = event_def == null
	if event_def != null:
		_vignette.show_event(event_def)
	var title_key: String = str(pending.get("title_key", ""))
	title_label.text = _formatted(title_key, pending.get("title_args", [])) if not title_key.is_empty() else _c(str(pending.get("title", type.replace("_", " ").capitalize())))
	var description: String = _c(str(pending.get("description", "Choose one option.")))
	var description_key: String = str(pending.get("description_key", ""))
	if not description_key.is_empty():
		var keyed: String = _formatted(description_key, pending.get("description_args", []))
		description = keyed if description.is_empty() else "%s\n\n%s" % [keyed, description]
	status_label.text = description
	_gold_label.text = _localized("INTERACTION_GOLD") % run.gold
	for option_value: Variant in pending.get("options", []) as Array:
		if option_value is Dictionary:
			choices.add_child(_card(option_value as Dictionary))
	leave_button.visible = (bool(pending.get("allow_leave", false)) or type in RunContentService.LEAVABLE_TYPES or type == "run_summary") and not pending.has("shop_return") and not pending.has("slot_return")
	leave_button.text = _localized("INTERACTION_FINISH_RUN") if type == "run_summary" else _localized("INTERACTION_WALK_AWAY" if type in ["event", "rest"] else "INTERACTION_LEAVE")

## One choice: a picture, what it is, what it does, and its price or risk.
func _card(option: Dictionary) -> Button:
	var payload: Dictionary = option.get("payload", {}) as Dictionary
	var enabled: bool = bool(option.get("enabled", true))
	var kind: String = str(payload.get("kind", ""))
	var card: Button = Button.new()
	card.name = "Choice_%s" % str(option.get("id", ""))
	card.set_meta("choice_id", str(option.get("id", "")))
	card.disabled = not enabled
	card.custom_minimum_size = Vector2(0, 66)
	card.focus_mode = Control.FOCUS_ALL
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill: Color = PANEL_2.lightened(0.07) if state == "hover" else (PANEL if state == "disabled" else PANEL_2)
		var border: Color = GOLD if state in ["hover", "focus", "pressed"] else LINE
		card.add_theme_stylebox_override(state, _box(fill, border, 8, 8))
	card.pressed.connect(_submit.bind(str(option.get("id", ""))))
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Control = _option_icon(kind, payload)
	icon.custom_minimum_size = Vector2(50, 50)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label_key: String = str(option.get("label_key", ""))
	var title: String = _localized(label_key) if not label_key.is_empty() else _c(str(option.get("label", option.get("id", "Option"))))
	title = title.split(" — ")[0]
	# The card's own text stays for accessibility and tests; the visible copy is the row below.
	card.text = title
	# Clipped, so a long name never widens the page (the row below wraps it instead).
	card.clip_text = true
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		card.add_theme_color_override(key, Color(0, 0, 0, 0))
	var name_label: Label = _label(title, 14, INK if enabled else MUTED)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(name_label)
	var detail: String = _detail(kind, payload)
	if not detail.is_empty():
		var detail_label: Label = _label(detail, 11, MUTED)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(detail_label)
	row.add_child(text)
	var tags: VBoxContainer = VBoxContainer.new()
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Recruits show how rare they are.
	if kind == "piece":
		var piece_def: PieceDef = PieceDefDatabase.get_def(str(payload.get("piece_def_id", "")))
		if piece_def != null:
			var rarity: int = clampi(piece_def.rarity, 0, RARITY_COLORS.size() - 1)
			tags.add_child(_chip(_localized(RARITY_KEYS[rarity]), RARITY_COLORS[rarity]))
	var price: int = int(payload.get("price", payload.get("cost", 0)))
	if price > 0:
		var afford: bool = run_manager.current_run.gold >= price
		tags.add_child(_chip("%d G" % price, GOLD if afford else DANGER))
	var chance: float = float(payload.get("chance", 1.0))
	if chance < 1.0:
		tags.add_child(_chip("%d%%" % int(roundf(chance * 100.0)), DANGER))
	for paid: Variant in payload.get("pay", []) as Array:
		match str((paid as Dictionary).get("kind", "")):
			"lose_item":
				tags.add_child(_chip(_localized("INTERACTION_TAG_ITEM"), DANGER))
			"lose_retry":
				tags.add_child(_chip(_localized("INTERACTION_TAG_RETRY"), DANGER))
	if tags.get_child_count() > 0:
		row.add_child(tags)
	card.add_child(row)
	# A Button does not grow with its children, so size it from the text it carries.
	# Chinese characters are about twice as wide as Latin letters.
	var width_factor: float = 1.8 if localization != null and bool(localization.call("is_chinese")) else 1.0
	var title_lines: int = ceili(float(title.length()) * width_factor / 30.0)
	var detail_lines: int = ceili(float(detail.length()) * width_factor / 40.0)
	card.custom_minimum_size.y = maxf(66.0, 16.0 + title_lines * 19.0 + detail_lines * 15.0)
	return card

func _detail(kind: String, payload: Dictionary) -> String:
	if payload.has("detail"):
		return _c(str(payload["detail"]))
	if payload.has("detail_key"):
		return _localized(str(payload["detail_key"]))
	match kind:
		"piece":
			var definition: PieceDef = PieceDefDatabase.get_def(str(payload.get("piece_def_id", "")))
			return _localized(PieceRulePreview.move_key(definition)) if definition != null else ""
		"relic", "item":
			var item: ChallengerItemDef = ChallengerItemDatabase.get_def(StringName(str(payload.get("relic_id", payload.get("item_id", "")))))
			return _localized(String(item.description_key)) if item != null else ""
		SlotReplaceService.PICK:
			var held: ChallengerItemDef = ChallengerItemDatabase.get_def(StringName(str(payload.get("slot_id", ""))))
			return _localized(String(held.description_key)) if held != null else ""
		"gold":
			return _localized("INTERACTION_GOLD_DETAIL") % int(payload.get("amount", 0))
		"restore_retry":
			return _localized("INTERACTION_RETRY_DETAIL")
		"fusion":
			var recipe: FusionRecipeDef = FusionRecipeDatabase.get_def(StringName(str(payload.get("recipe_id", ""))))
			return _localized(String(recipe.description_key)) if recipe != null else ""
	return ""

func _option_icon(kind: String, payload: Dictionary) -> Control:
	var texture: Texture2D = null
	match kind:
		"piece", "train", "transform", "shop_replace_confirm":
			texture = _piece_texture(str(payload.get("piece_def_id", "")))
		"shop_replace_pick":
			texture = _piece_texture(str(payload.get("replaced_def_id", "")))
		"relic", "item":
			var item: ChallengerItemDef = ChallengerItemDatabase.get_def(StringName(str(payload.get("relic_id", payload.get("item_id", "")))))
			texture = item.icon if item != null else null
		SlotReplaceService.PICK:
			var held: ChallengerItemDef = ChallengerItemDatabase.get_def(StringName(str(payload.get("slot_id", ""))))
			texture = held.icon if held != null else null
		"fusion":
			var recipe: FusionRecipeDef = FusionRecipeDatabase.get_def(StringName(str(payload.get("recipe_id", ""))))
			texture = _piece_texture(String(recipe.result_piece_def_id)) if recipe != null else null
	if texture != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return picture
	var glyph: Control = Control.new()
	glyph.draw.connect(_draw_glyph.bind(glyph, kind))
	return glyph

## Coins for gold, a heart for a retry, a question mark for anything else.
func _draw_glyph(glyph: Control, kind: String) -> void:
	var centre: Vector2 = glyph.size * 0.5
	match kind:
		"gold":
			for index: int in range(3):
				var at: Vector2 = centre + Vector2(-8.0 + index * 8.0, 6.0 - index * 5.0)
				glyph.draw_circle(at, 9.0, Color("#7a5a1c"))
				glyph.draw_circle(at, 7.5, GOLD)
				glyph.draw_rect(Rect2(at + Vector2(-1.0, -4.0), Vector2(2.0, 8.0)), Color("#7a5a1c"))
		"restore_retry":
			glyph.draw_circle(centre + Vector2(-6.0, -4.0), 8.0, DANGER)
			glyph.draw_circle(centre + Vector2(6.0, -4.0), 8.0, DANGER)
			glyph.draw_colored_polygon(PackedVector2Array([centre + Vector2(-13.5, -1.0), centre + Vector2(13.5, -1.0), centre + Vector2(0.0, 14.0)]), DANGER)
		_:
			PathMapView.paint_icon(glyph, &"event", centre, MUTED, 3.0)

func _draw_badge() -> void:
	var centre: Vector2 = _badge.size * 0.5
	var color: Color = PathMapView.node_color(_badge_type)
	_badge.draw_circle(centre, 29.0, Color("#060c16"))
	_badge.draw_arc(centre, 29.0, 0.0, TAU, 40, color, 2.0)
	PathMapView.paint_icon(_badge, _badge_type, centre, color, 4.0)

func _submit(choice_id: String) -> void:
	var was_type: String = str(run_manager.current_run.pending_choice.get("type", "")) if run_manager.current_run != null else ""
	var error: Error = run_manager.submit_run_interaction(choice_id)
	if error != OK:
		status_label.text = _localized("INTERACTION_UNAVAILABLE")
		_sfx(&"error")
		return
	# Coins only when a purchase went through, not on the steps of a party-full purchase.
	var purchased: bool = was_type == "shop" and (run_manager.current_run == null or run_manager.current_run.pending_choice.is_empty())
	_sfx(&"coins" if purchased else &"confirm")
	var outcome: String = ""
	# (Not while a relic or item to give up is still being picked.)
	if run_manager.current_run != null and was_type in ["event", "rest"] and run_manager.current_run.pending_choice.is_empty():
		outcome = str(run_manager.current_run.run_statistics.get("last_outcome", ""))
	if not outcome.is_empty():
		_show_outcome(outcome)
		return
	_route_after_commit()

## What happened, with a Continue button, before leaving an event or rest site: a
## lucky or unlucky banner for risky choices, what was gained, and what it cost.
func _show_outcome(text: String) -> void:
	for child: Node in choices.get_children():
		child.queue_free()
	leave_button.visible = false
	for child: Node in _outcome.get_children():
		child.queue_free()
	var info: Dictionary = {}
	if run_manager.current_run != null:
		info = run_manager.current_run.run_statistics.get("last_outcome_info", {}) as Dictionary
	var success: bool = bool(info.get("success", true))
	var accent: Color = (TEAL if success else DANGER) if bool(info.get("risky", false)) else GOLD
	_outcome.add_theme_stylebox_override("panel", _box(PANEL, accent, 8, 14))
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "OutcomeColumn"
	column.add_theme_constant_override("separation", 10)
	if bool(info.get("risky", false)):
		var banner: Label = _label(_localized("INTERACTION_LUCKY" if success else "INTERACTION_UNLUCKY"), 13, accent)
		banner.name = "OutcomeBanner"
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(banner)
	var kind: String = str(info.get("kind", "nothing"))
	var icon: Control = _option_icon(kind, info) if kind in ["piece", "train", "transform", "relic", "item", "gold", "restore_retry"] else null
	if icon != null:
		icon.name = "OutcomeIcon"
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
	var label: Label = _label(_c(text), 15, INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var changes: HBoxContainer = HBoxContainer.new()
	changes.name = "OutcomeChanges"
	changes.alignment = BoxContainer.ALIGNMENT_CENTER
	changes.add_theme_constant_override("separation", 6)
	var gold_delta: int = int(info.get("gold_delta", 0))
	if gold_delta != 0:
		changes.add_child(_chip(_localized("INTERACTION_GOLD_DELTA") % gold_delta, GOLD if gold_delta > 0 else DANGER))
	for lost: Variant in info.get("lost", []) as Array:
		changes.add_child(_chip(_localized("INTERACTION_LOST") % _c(str(lost)), DANGER))
	if changes.get_child_count() > 0:
		column.add_child(changes)
	var next: Button = Button.new()
	next.name = "ContinueButton"
	next.text = _localized("INTERACTION_CONTINUE")
	_style_button(next, true)
	next.pressed.connect(_route_after_commit)
	column.add_child(next)
	_outcome.add_child(column)
	_outcome.visible = true
	if run_manager.current_run != null:
		_gold_label.text = _localized("INTERACTION_GOLD") % run_manager.current_run.gold
	next.grab_focus()

func _on_leave() -> void:
	if run_manager.current_run != null and str(run_manager.current_run.pending_choice.get("type", "")) == "run_summary":
		var finish_error: Error = run_manager.finish_run_summary()
		if finish_error != OK:
			status_label.text = _localized("INTERACTION_FINISH_ERROR") % error_string(finish_error)
			return
		get_tree().change_scene_to_file(AppSceneRoutes.MAIN_MENU)
		return
	if run_manager.current_run != null and not run_manager.current_run.pending_choice.is_empty():
		var error: Error = run_manager.leave_run_interaction()
		if error != OK:
			status_label.text = _localized("INTERACTION_CANNOT_LEAVE")
			return
	_route_after_commit()

func _route_after_commit() -> void:
	_outcome.visible = false
	if run_manager.current_run == null:
		get_tree().change_scene_to_file(AppSceneRoutes.MAIN_MENU)
	elif not run_manager.current_run.pending_choice.is_empty():
		_render()
	else:
		get_tree().change_scene_to_file(run_manager.resume_scene_path())

func _piece_texture(piece_id: String) -> Texture2D:
	if piece_skin_manager == null or piece_id.is_empty():
		return null
	return piece_skin_manager.call("piece_texture", &"white", StringName(piece_id)) as Texture2D

func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _chip(text: String, color: Color) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _box(Color(color, 0.18), color, 4, 5))
	chip.add_child(_label(text, 11, color))
	return chip

func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = maxi(2, margin / 2)
	box.content_margin_bottom = maxi(2, margin / 2)
	return box

func _style_button(button: Button, primary: bool) -> void:
	button.custom_minimum_size = Vector2(0, 44)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, _box((GOLD if primary else PANEL_2).lightened(0.08 if state == "hover" else 0.0), GOLD if primary or state != "normal" else LINE, 6, 8))
	var font: Color = Color("#1a1408") if primary else INK
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, font)

## Content stored as English text, in the current language.
func _c(text: String) -> String:
	return str(localization.call("content", text)) if localization != null else text

func _localized(key: String) -> String:
	return str(localization.call("text", key)) if localization != null else key

## A localized text with its %-placeholders filled from `args` (when there are any).
func _formatted(key: String, args: Variant) -> String:
	var text: String = _localized(key)
	if args is Array and not (args as Array).is_empty():
		return text % (args as Array)
	return text

func _sfx(name: StringName) -> void:
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", name)
