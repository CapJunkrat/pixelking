extends SceneTree

const PIECE_TYPES: Array[StringName] = [&"king", &"queen", &"rook", &"bishop", &"knight", &"pawn"]

func _init() -> void:
	await process_frame
	var ok := true
	var piece_skin_manager := root.get_node("PieceSkinManager")
	var skins: Array = piece_skin_manager.available_skins()
	if skins.size() != 1 or skins[0].skin_id != &"royal_forge":
		push_error("Royal Forge skin was not discovered")
		ok = false
	for color in [&"white", &"black"]:
		for piece_type in PIECE_TYPES:
			var texture: Texture2D = piece_skin_manager.piece_texture(color, piece_type)
			if texture == null:
				push_error("Missing texture: %s_%s" % [color, piece_type])
				ok = false
			elif texture.get_width() != 64 or texture.get_height() != 64:
				push_error("Texture must be 64x64: %s_%s" % [color, piece_type])
				ok = false

	var packed_scene := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu := packed_scene.instantiate()
	root.add_child(menu)
	await process_frame
	var option := menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/PieceSkinOption") as OptionButton
	var white_preview := menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/WhitePieces") as HBoxContainer
	var black_preview := menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/BlackPieces") as HBoxContainer
	if option.item_count != 1 or option.get_item_text(0) != "Royal Forge":
		push_error("Piece skin selector was not populated")
		ok = false
	if white_preview.get_child_count() != 6 or black_preview.get_child_count() != 6:
		push_error("Piece skin preview must show both sets of six pieces")
		ok = false
	print("[PASS] Piece skin test" if ok else "[FAIL] Piece skin test")
	quit(0 if ok else 1)
