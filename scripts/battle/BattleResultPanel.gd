class_name BattleResultPanel
extends ColorRect

## End-of-battle screen: an animated victory / defeat emblem, why the battle ended,
## the battle in three numbers, the player's best piece and what the pieces grew into.

signal retry_requested
signal exit_requested

const GOLD := Color("#e0b45c")
const GOLD_SOFT := Color("#f5d58f")
const TEAL := Color("#4fd1c5")
const ENEMY := Color("#e07a6a")
const MUTED := Color("#9aa8bf")
const INK := Color("#f1e6cf")
const PANEL_2 := Color("#172a48")
const LINE := Color("#2b4166")

@onready var title_label: Label = $Center/Panel/Margin/Content/ResultTitle
@onready var detail_label: Label = $Center/Panel/Margin/Content/ResultDetail
@onready var retry_button: Button = $Center/Panel/Margin/Content/RetryButton
@onready var exit_button: Button = $Center/Panel/Margin/Content/ExitButton
@onready var content: VBoxContainer = $Center/Panel/Margin/Content
@onready var panel: PanelContainer = $Center/Panel

var emblem: ResultEmblem = null
var stats_row: HBoxContainer = null
var best_row: HBoxContainer = null
var growth_label: RichTextLabel = null

func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	emblem = ResultEmblem.new()
	emblem.name = "Emblem"
	emblem.custom_minimum_size = Vector2(0, 64)
	content.add_child(emblem)
	content.move_child(emblem, 0)
	stats_row = HBoxContainer.new()
	stats_row.name = "Stats"
	stats_row.add_theme_constant_override("separation", 6)
	content.add_child(stats_row)
	content.move_child(stats_row, detail_label.get_index() + 1)
	best_row = HBoxContainer.new()
	best_row.name = "BestPiece"
	best_row.add_theme_constant_override("separation", 8)
	content.add_child(best_row)
	content.move_child(best_row, stats_row.get_index() + 1)
	growth_label = RichTextLabel.new()
	growth_label.name = "Growth"
	growth_label.bbcode_enabled = true
	growth_label.fit_content = true
	growth_label.scroll_active = false
	growth_label.add_theme_font_size_override("normal_font_size", 12)
	content.add_child(growth_label)
	content.move_child(growth_label, best_row.get_index() + 1)
	stats_row.visible = false
	best_row.visible = false
	growth_label.visible = false
	hide()

func present(title_text: String, detail_text: String) -> void:
	title_label.text = title_text
	detail_label.text = detail_text
	show()
	if not is_inside_tree():
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.86, 0.86)
	panel.modulate.a = 0.0
	var pop: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(panel, "scale", Vector2.ONE, 0.32)
	pop.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)

## Fills the battle report. `mood` is "victory", "defeat" or "draw".
func show_summary(summary: BattleResultSummary, mood: String, texture_lookup: Callable, text: Callable) -> void:
	emblem.mood = mood
	emblem.queue_redraw()
	_style_button(exit_button, mood == "victory" or not retry_button.visible)
	_style_button(retry_button, mood != "victory")
	title_label.add_theme_color_override("font_color", {"victory": GOLD_SOFT, "defeat": ENEMY, "draw": MUTED}.get(mood, INK))
	if summary == null:
		return
	for child: Node in stats_row.get_children():
		child.queue_free()
	stats_row.add_child(_stat(str(summary.player_moves), text.call("RESULT_STAT_MOVES"), INK))
	stats_row.add_child(_stat(str(summary.captured), text.call("RESULT_STAT_CAPTURED"), TEAL))
	stats_row.add_child(_stat(str(summary.lost), text.call("RESULT_STAT_LOST"), ENEMY))
	stats_row.visible = true
	for child: Node in best_row.get_children():
		child.queue_free()
	best_row.visible = not summary.best_piece_id.is_empty()
	if best_row.visible:
		var icon: TextureRect = TextureRect.new()
		icon.texture = texture_lookup.call(summary.best_piece_id)
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		best_row.add_child(icon)
		var label: RichTextLabel = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.add_theme_font_size_override("normal_font_size", 12)
		label.text = "[color=#9aa8bf]%s[/color]\n[b]%s[/b] · %s" % [text.call("RESULT_BEST_PIECE"), _piece_name(summary.best_piece_id, text), text.call("RESULT_BEST_CAPTURES") % summary.best_captures]
		best_row.add_child(label)
	var lines: Array[String] = []
	for entry: Dictionary in summary.growth:
		if str(entry.get("kind", "")) == "evolved":
			lines.append("[color=#f5d58f]▲[/color] " + text.call("RESULT_GROWTH_EVOLVED") % _piece_name(str(entry.get("piece_def_id", "")), text))
		else:
			lines.append("[color=#4fd1c5]+[/color] " + text.call("RESULT_GROWTH_LEARNED") % [_piece_name(str(entry.get("piece_def_id", "")), text), _piece_name(str(entry.get("learned", "")), text)])
	growth_label.text = "\n".join(lines)
	growth_label.visible = not lines.is_empty()

## The main action is gold; the other is a quiet outline.
func _style_button(button: Button, primary: bool) -> void:
	button.custom_minimum_size = Vector2(0, 42)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = (GOLD if primary else PANEL_2).lightened(0.08 if state == "hover" else 0.0)
		box.border_color = GOLD if primary or state != "normal" else LINE
		box.set_border_width_all(1)
		box.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, box)
	var font: Color = Color("#1a1408") if primary else INK
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, font)

func _stat(value: String, caption: String, color: Color) -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_2
	style.border_color = LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var number: Label = Label.new()
	number.text = value
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 20)
	number.add_theme_color_override("font_color", color)
	var label: Label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", MUTED)
	column.add_child(number)
	column.add_child(label)
	box.add_child(column)
	return box

func _piece_name(piece_id: String, text: Callable) -> String:
	var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
	return text.call(String(definition.display_name_key)) if definition != null else piece_id

func set_retry_visible(visible_value: bool) -> void:
	retry_button.visible = visible_value

func set_exit_text(value: String) -> void:
	exit_button.text = value

## A crown with turning rays for a victory, a broken crown for a defeat.
class ResultEmblem extends Control:

	var mood: String = "victory"
	var _age: float = 0.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_age += delta
		queue_redraw()

	func _draw() -> void:
		var centre: Vector2 = Vector2(size.x * 0.5, size.y * 0.5)
		var unit: float = 4.0
		var gold: Color = Color("#e0b45c")
		var color: Color = gold if mood == "victory" else (Color("#e07a6a") if mood == "defeat" else Color("#9aa8bf"))
		if mood == "victory":
			for index: int in range(16):
				var angle: float = TAU * index / 16.0 + _age * 0.35
				var inner: Vector2 = centre + Vector2(cos(angle), sin(angle)) * unit * 6.5
				var outer: Vector2 = centre + Vector2(cos(angle), sin(angle)) * unit * (index % 2 * 1.5 + 8.5)
				draw_line(inner, outer, Color(gold, 0.45), 2.0)
		draw_circle(centre, unit * 6.0, Color("#060c16"))
		draw_arc(centre, unit * 6.0, 0.0, TAU, 40, color, 2.0)
		# A crown: a band with three points; cracked after a defeat.
		var w: float = unit * 6.5
		var h: float = unit * 3.5
		var base: float = centre.y + unit * 2.2
		var crown: PackedVector2Array = PackedVector2Array([
			Vector2(centre.x - w * 0.5, base), Vector2(centre.x - w * 0.5, base - h),
			Vector2(centre.x - w * 0.25, base - h * 0.45), Vector2(centre.x, base - h * 1.25),
			Vector2(centre.x + w * 0.25, base - h * 0.45), Vector2(centre.x + w * 0.5, base - h),
			Vector2(centre.x + w * 0.5, base),
		])
		draw_colored_polygon(crown, color)
		draw_rect(Rect2(centre.x - w * 0.5, base - unit * 0.8, w, unit * 0.8), color.darkened(0.3))
		if mood == "defeat":
			draw_polyline(PackedVector2Array([Vector2(centre.x - unit * 0.5, base - h * 1.2), Vector2(centre.x + unit * 0.6, base - h * 0.6), Vector2(centre.x - unit * 0.4, base - h * 0.3), Vector2(centre.x + unit * 0.4, base + unit * 0.2)]), Color("#060c16"), 2.0)
