class_name PieceDetailContent
extends VBoxContainer

## Shared complete, readable content. Embed in an existing ScrollContainer or use
## PieceInfoPanel for the modal version. `live_status` is never inferred from a def.
func show_definition(definition: PieceDef, context: String = "", live_status: Array[String] = [], facing_up: bool = true) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	name = "DetailContent"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var facts: Dictionary = PiecePresentation.describe(definition)
	if facts.is_empty():
		return
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = get_node("/root/PieceSkinManager").call("piece_texture", &"white" if facing_up else &"black", StringName(definition.id)) as Texture2D
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(portrait)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_label(facts.name, 20, Color("#f5d58f")))
	titles.add_child(_label(context if not context.is_empty() else _t("PREBATTLE_VALUE") % definition.base_value, 12, Color("#9aa8bf")))
	header.add_child(titles)
	add_child(header)
	add_child(_label(_t("INFO_BASE"), 12, Color("#9aa8bf")))
	var chips: HFlowContainer = HFlowContainer.new()
	for entry: Dictionary in facts.traits:
		chips.add_child(_label("• " + str(entry.label), 13, Color("#e0b45c")))
	add_child(chips)
	_heading("INFO_MOVEMENT")
	var diagram: GridContainer = PieceRulePreview.make_grid(definition.id, 7, 19.0, facing_up)
	diagram.name = "MovementDiagram"
	diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(diagram)
	add_child(_label(_t("INFO_DIAGRAM"), 12, Color("#9aa8bf")))
	add_child(_label(facts.movement, 14, Color("#8fd8ee")))
	_heading("INFO_CAPTURE")
	add_child(_label(facts.capture, 14, Color("#f0a397")))
	if not facts.traits.is_empty():
		_heading("INFO_ABILITIES")
		for entry: Dictionary in facts.traits:
			add_child(_label(str(entry.label), 14, Color("#f5d58f")))
			add_child(_label(str(entry.rule), 14, Color("#f1e6cf")))
	_heading("INFO_EXCEPTIONS")
	for exception: String in facts.exceptions:
		add_child(_label(exception, 14, Color("#f1e6cf")))
	if not live_status.is_empty():
		_heading("INFO_STATUS")
		var status: Label = _label("\n".join(live_status), 14, Color("#4fd1c5"))
		status.name = "LiveStatus"
		add_child(status)

static func _t(key: String) -> String:
	return str(Engine.get_main_loop().root.get_node("Localization").call("text", key))

func _heading(key: String) -> void:
	add_child(HSeparator.new())
	add_child(_label(_t(key), 16, Color("#e0b45c")))

static func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
