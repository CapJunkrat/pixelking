class_name AchievementPanel
extends ColorRect

## The achievements screen on the main menu: personal records at the top, then every
## achievement with its progress (unlocked ones glow gold).

signal closed

const GOLD := Color("#e0b45c")
const GOLD_SOFT := Color("#f5d58f")
const INK := Color("#f1e6cf")
const MUTED := Color("#9aa8bf")
const PANEL_2 := Color("#172a48")
const LINE := Color("#2b4166")
## The records shown at the top, in order: stat key -> label key.
const RECORDS: Array[Array] = [
	["best_acts", "ACH_RECORD_BEST_ACTS"],
	["best_run_kills", "ACH_RECORD_RUN_KILLS"],
	["total_kills", "ACH_RECORD_TOTAL_KILLS"],
	["total_runs", "ACH_RECORD_RUNS"],
]

var title_label: Label
var progress_label: Label
var records_grid: GridContainer
var list: VBoxContainer
var back_button: Button

func build(panel_style: StyleBox) -> void:
	name = "AchievementOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.005, 0.008, 0.02, 0.94)
	hide()
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var panel: PanelContainer = PanelContainer.new()
	if panel_style != null:
		panel.add_theme_stylebox_override("panel", panel_style)
	margin.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34, 1.0))
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_color_override("font_color", MUTED)
	content.add_child(progress_label)
	records_grid = GridContainer.new()
	records_grid.name = "Records"
	records_grid.columns = 2
	records_grid.add_theme_constant_override("h_separation", 8)
	records_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(records_grid)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "AchievementScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	list = VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	DragScroll.enable(scroll)
	back_button = Button.new()
	back_button.custom_minimum_size = Vector2(0, 46)
	back_button.add_theme_font_size_override("font_size", 22)
	back_button.pressed.connect(close)
	content.add_child(back_button)

func open(run_manager: AppRunManager) -> void:
	render(run_manager)
	show()
	back_button.grab_focus()

func close() -> void:
	hide()
	closed.emit()

func render(run_manager: AppRunManager) -> void:
	title_label.text = _text("ACH_TITLE")
	back_button.text = _text("COMMON_BACK")
	var stats: Dictionary = run_manager.lifetime_stats() if run_manager != null else {}
	var unlocked: Array[String] = run_manager.unlocked_achievement_ids() if run_manager != null else []
	progress_label.text = _text("ACH_PROGRESS") % [unlocked.size(), AchievementCatalog.ENTRIES.size()]
	for child: Node in records_grid.get_children():
		child.queue_free()
	for record: Array in RECORDS:
		records_grid.add_child(_record_tile(_text(str(record[1])), int(stats.get(str(record[0]), 0))))
	for child: Node in list.get_children():
		child.queue_free()
	for entry: Dictionary in AchievementCatalog.ENTRIES:
		list.add_child(_card(entry, stats, str(entry["id"]) in unlocked))

func _record_tile(label_text: String, value: int) -> PanelContainer:
	var tile: PanelContainer = PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _box(PANEL_2, LINE))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	tile.add_child(column)
	var number: Label = _label(str(value), 20, GOLD_SOFT)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(number)
	var caption: Label = _label(label_text, 11, MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)
	return tile

func _card(entry: Dictionary, stats: Dictionary, done: bool) -> PanelContainer:
	var achievement_id: String = str(entry["id"])
	var target: int = AchievementCatalog.target_of(entry)
	var value: int = mini(AchievementCatalog.value_of(entry, stats), target)
	var card: PanelContainer = PanelContainer.new()
	card.name = "Ach_%s" % achievement_id
	card.add_theme_stylebox_override("panel", _box(PANEL_2, GOLD if done else LINE))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var star: Label = _label("★" if done else "☆", 22, GOLD if done else LINE)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(star)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 1)
	row.add_child(text)
	var title: Label = _label(_text(AchievementCatalog.title_key(achievement_id)), 15, GOLD_SOFT if done else INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	var description: String = _text(AchievementCatalog.desc_key(achievement_id))
	if "%d" in description:
		description = description % target
	var detail: Label = _label(description, 11, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(detail)
	var progress: Label = _label(_text("ACH_DONE") if done else "%d / %d" % [value, target], 12, GOLD if done else MUTED)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(progress)
	return card

func _label(value: String, font_size: int, font_color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
