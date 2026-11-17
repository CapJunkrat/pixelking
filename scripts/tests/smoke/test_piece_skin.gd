class_name TestPieceSkin
extends SceneTreeTestCase

const PIECE_TYPES: Array[StringName] = [&"king", &"queen", &"rook", &"bishop", &"knight", &"pawn"]
const NEW_PIECE_TYPES: Array[StringName] = [&"assassin", &"royal_guard", &"catapult", &"bowman", &"portal_mage", &"unicorn_cavalry", &"centaur", &"manticore", &"gryphon", &"gorgon"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var piece_skin_manager: Node = root.get_node("PieceSkinManager")
	var skins: Array = piece_skin_manager.call("available_skins") as Array
	var skin_ids: Array[StringName] = []
	for skin_value: Variant in skins:
		var skin: PieceSkin = skin_value as PieceSkin
		skin_ids.append(skin.skin_id)
	expect(skins.size() == 2 and &"royal_forge" in skin_ids and &"modern_parchment" in skin_ids, "both built-in piece skins are available")
	for skin_value: Variant in skins:
		var skin: PieceSkin = skin_value as PieceSkin
		for color: StringName in [&"white", &"black"]:
			for piece_type: StringName in PIECE_TYPES + NEW_PIECE_TYPES:
				var texture: Texture2D = skin.texture(color, piece_type)
				expect(texture != null, "%s contains %s_%s" % [skin.skin_id, color, piece_type])
				if texture != null:
					expect(texture.get_width() == texture.get_height() and texture.get_width() >= 64, "%s_%s is square pixel art" % [color, piece_type])
	var packed_scene: PackedScene = load(AppSceneRoutes.MAIN_MENU) as PackedScene
	var menu: Control = packed_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	var option: OptionButton = menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/PieceSkinOption") as OptionButton
	var white_preview: GridContainer = menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/WhitePieces") as GridContainer
	var black_preview: GridContainer = menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/BlackPieces") as GridContainer
	var option_names: Array[String] = []
	for index: int in option.item_count:
		option_names.append(option.get_item_text(index))
	expect(option.item_count == 2 and "Royal Forge" in option_names and "Modern Parchment" in option_names, "piece skin selector lists both skins")
	expect(white_preview.get_child_count() == 16 and black_preview.get_child_count() == 16, "settings preview includes all catalogued piece skins")
	menu.queue_free()
	finish_test("Piece skin test")
