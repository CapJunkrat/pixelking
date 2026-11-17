class_name NewPiecesGallery
extends Control

const PIECES: Array[StringName] = [&"assassin", &"royal_guard", &"catapult", &"bowman", &"portal_mage", &"unicorn_cavalry", &"centaur", &"manticore", &"gryphon", &"gorgon"]
const SKINS: Array[StringName] = [&"royal_forge", &"modern_parchment"]

func _ready() -> void:
	var title: Label = Label.new()
	title.text = "NEW PIECES · ACTUAL 39px BOARD CELLS"
	title.position = Vector2(18, 10)
	title.size = Vector2(324, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(82, 46)
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)
	var manager: Node = get_node("/root/PieceSkinManager")
	for skin_id: StringName in SKINS:
		manager.call("set_skin", skin_id)
		for color: StringName in [&"white", &"black"]:
			for piece_id: StringName in PIECES:
				var cell: ColorRect = ColorRect.new()
				cell.custom_minimum_size = Vector2(39, 39)
				var index: int = grid.get_child_count()
				cell.color = Color("#285064") if (index + index / 5) % 2 == 0 else Color("#102f45")
				grid.add_child(cell)
				var image: TextureRect = TextureRect.new()
				image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				image.texture = manager.call("piece_texture", color, piece_id) as Texture2D
				cell.add_child(image)
	manager.call("set_skin", PieceSkinManager.DEFAULT_SKIN_ID)
