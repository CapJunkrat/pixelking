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
	expect(skins.size() == 1 and &"carved_figurine" in skin_ids, "the carved figurines are the only piece style for now")
	expect(piece_skin_manager.get("current_skin_id") == &"carved_figurine", "carved figurines are the default skin")
	var carved: PieceSkin = load("res://assets/chess/piece_skins/carved_figurine.tres") as PieceSkin
	for color: StringName in [&"white", &"black"]:
		for piece_type: StringName in [&"lancer", &"archmage"]:
			expect(carved.has_texture(color, piece_type), "carved figurines include their own %s_%s" % [color, piece_type])
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
	var label: Control = menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/PieceSkinLabel") as Control
	var preview: Control = menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview") as Control
	expect(option.item_count == 1 and not option.visible and not label.visible and not preview.visible, "with one style the settings show no style picker")
	expect(white_preview.get_child_count() == 16 and black_preview.get_child_count() == 16, "the hidden preview is still built for when styles return")
	menu.queue_free()
	finish_test("Piece skin test")
