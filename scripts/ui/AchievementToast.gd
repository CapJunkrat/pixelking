class_name AchievementToast
extends CanvasLayer

## A banner that drops in from the top when achievements unlock, one after another,
## over whatever screen is showing. RunManager owns it.

const GOLD := Color("#e0b45c")
const GOLD_SOFT := Color("#f5d58f")
const INK := Color("#f1e6cf")
const PANEL := Color("#12203a")
const SHOW_SECONDS := 2.6

var _queue: Array[String] = []
var _busy: bool = false
var _panel: PanelContainer = null
var _title: Label = null
var _name: Label = null

func _ready() -> void:
	layer = 90
	_panel = PanelContainer.new()
	_panel.name = "Banner"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = GOLD
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", box)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 11)
	_title.add_theme_color_override("font_color", GOLD)
	column.add_child(_title)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.add_theme_font_size_override("font_size", 16)
	_name.add_theme_color_override("font_color", GOLD_SOFT)
	column.add_child(_name)
	_panel.visible = false
	add_child(_panel)

func announce(achievement_ids: Array[String]) -> void:
	_queue.append_array(achievement_ids)
	if not _busy:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty() or not is_inside_tree():
		_busy = false
		_panel.visible = false
		return
	_busy = true
	var achievement_id: String = _queue.pop_front()
	_title.text = _text("ACH_UNLOCKED")
	_name.text = "★ " + _text(AchievementCatalog.title_key(achievement_id))
	var width: float = minf(300.0, get_viewport().get_visible_rect().size.x - 32.0)
	_name.custom_minimum_size = Vector2(width - 28.0, 0)
	_panel.custom_minimum_size = Vector2(width, 0)
	_panel.reset_size()
	var screen_width: float = get_viewport().get_visible_rect().size.x
	_panel.position = Vector2((screen_width - width) * 0.5, -80.0)
	_panel.visible = true
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", &"item")
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "position:y", 28.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(SHOW_SECONDS)
	tween.tween_property(_panel, "position:y", -90.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_show_next)

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
