class_name FusionRecipeView
extends HBoxContainer

## A fusion recipe as pictures: material A + material B = result. Holding any of the
## three pieces asks for its card (info_requested) and letting go closes it
## (info_released). It sits inside a choice card (a Button): the pictures pass every
## touch on, so a short tap still picks the card, while the release that ends a hold
## is swallowed through consume_hold().

signal info_requested(piece_def_id: String)
signal info_released

const HOLD_SECONDS := 0.45
## A finger that moves this far is scrolling the list, not holding a piece.
const DRAG_CANCEL_PIXELS := 12.0
const PIECE_SIZE := 38.0
const SYMBOL := Color("#9aa8bf")

var recipe_id: StringName = &""
var _timer: Timer = null
var _held_id: String = ""
var _press_at: Vector2 = Vector2.ZERO
var _opened: bool = false

## Lays out `recipe`, with `texture_lookup` (piece id -> Texture2D) for the pictures.
func setup(recipe: FusionRecipeDef, texture_lookup: Callable) -> void:
	recipe_id = recipe.id
	name = "Recipe_%s" % String(recipe.id)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = HOLD_SECONDS
	_timer.timeout.connect(_on_hold)
	add_child(_timer)
	var ids: Array[String] = []
	for ingredient: StringName in recipe.ingredient_piece_def_ids:
		ids.append(String(ingredient))
	for index: int in range(ids.size()):
		if index > 0:
			add_child(_symbol("+"))
		add_child(_piece(ids[index], texture_lookup))
	add_child(_symbol("="))
	add_child(_piece(String(recipe.result_piece_def_id), texture_lookup))

## True once after a hold opened a card: the card's `pressed` that follows the release
## must not pick the choice.
func consume_hold() -> bool:
	var opened: bool = _opened
	_opened = false
	return opened

## Forgets an earlier hold whose release landed off the card (no `pressed` came).
func reset_hold() -> void:
	_opened = false

func piece_controls() -> Array[TextureRect]:
	var result: Array[TextureRect] = []
	for child: Node in get_children():
		if child is TextureRect:
			result.append(child as TextureRect)
	return result

func _piece(piece_def_id: String, texture_lookup: Callable) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.name = "Piece_%s" % piece_def_id
	picture.set_meta("piece_def_id", piece_def_id)
	picture.texture = texture_lookup.call(piece_def_id) as Texture2D if texture_lookup.is_valid() else null
	picture.custom_minimum_size = Vector2(PIECE_SIZE, PIECE_SIZE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# PASS: the picture sees the touch, then the card under it does too.
	picture.mouse_filter = Control.MOUSE_FILTER_PASS
	picture.gui_input.connect(_on_piece_input.bind(piece_def_id))
	return picture

func _symbol(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", SYMBOL)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _on_piece_input(event: InputEvent, piece_def_id: String) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_start_hold(piece_def_id, button.global_position)
		else:
			_end_hold()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and not _held_id.is_empty() and not _opened and motion.global_position.distance_to(_press_at) > DRAG_CANCEL_PIXELS:
		_end_hold()

func _start_hold(piece_def_id: String, at: Vector2) -> void:
	_opened = false
	_held_id = piece_def_id
	_press_at = at
	_timer.start()

func _end_hold() -> void:
	_held_id = ""
	_timer.stop()
	if _opened:
		info_released.emit()

func _on_hold() -> void:
	if _held_id.is_empty():
		return
	_opened = true
	info_requested.emit(_held_id)
