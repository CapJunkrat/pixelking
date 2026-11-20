class_name PieceSummaryCard
extends PanelContainer

## Content-sized comparison card. Details and commit are SIBLING buttons; neither
## a parent Button nor a parent pointer handler can recruit while inspecting.
signal detail_requested(definition: PieceDef)
signal action_requested

var _definition: PieceDef

func configure(definition: PieceDef, action_text: String = "", enabled: bool = true) -> void:
	_definition = definition
	set_meta("piece_def_id", definition.id)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#12203a")
	style.border_color = Color("#2b4166")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var facts: Dictionary = PiecePresentation.describe(definition)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var picture: TextureRect = TextureRect.new()
	var skins: Node = Engine.get_main_loop().root.get_node("PieceSkinManager")
	picture.texture = skins.call("piece_texture", &"white", StringName(definition.id)) as Texture2D
	picture.custom_minimum_size = Vector2(40, 40)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(picture)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(PieceDetailContent._label(facts.name, 16, Color("#f1e6cf")))
	var rarities: Array[String] = ["RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY", "RARITY_MYTHIC"]
	titles.add_child(PieceDetailContent._label(_t(rarities[definition.rarity]), 12, Color("#e0b45c")))
	header.add_child(titles)
	body.add_child(header)
	var summary: Label = PieceDetailContent._label(facts.summary, 13, Color("#a5b2c6"))
	summary.name = "Summary"
	body.add_child(summary)
	var chips: VBoxContainer = VBoxContainer.new()
	chips.add_theme_constant_override("separation", 3)
	# Full rules remain in detail; labels are short and measured by containers.
	for entry: Dictionary in facts.traits:
		chips.add_child(PieceDetailContent._label("• " + str(entry.label), 12, Color("#f5d58f")))
	if chips.get_child_count() > 0:
		body.add_child(chips)
	else:
		chips.free()
	var details: Button = _button(_t("INFO_DETAILS") + " →")
	details.name = "DetailsButton"
	details.pressed.connect(func() -> void: detail_requested.emit(_definition))
	body.add_child(details)
	if not action_text.is_empty():
		var action: Button = _button(action_text)
		action.name = "ActionButton"
		action.disabled = not enabled
		action.pressed.connect(func() -> void: action_requested.emit())
		body.add_child(action)

static func _t(key: String) -> String:
	return str(Engine.get_main_loop().root.get_node("Localization").call("text", key))

static func _button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("#f5d58f"))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#172a48")
	style.border_color = Color("#e0b45c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(6)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	return button
