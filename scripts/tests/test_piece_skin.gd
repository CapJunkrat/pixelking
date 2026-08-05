extends SceneTree

const PIECE_TYPES: Array[StringName] = [&"king", &"queen", &"rook", &"bishop", &"knight", &"pawn"]

func _init() -> void:
	await process_frame
	var ok := true
	var piece_skin_manager := root.get_node("PieceSkinManager")
	var skins: Array = piece_skin_manager.available_skins()
	var skin_ids: Array[StringName] = []
	for skin in skins:
		skin_ids.append(skin.skin_id)
	if skins.size() != 2 or &"royal_forge" not in skin_ids or &"modern_parchment" not in skin_ids:
		push_error("Both Royal Forge and Modern Parchment skins must be discovered")
		ok = false
	for skin in skins:
		for color in [&"white", &"black"]:
			for piece_type in PIECE_TYPES:
				var texture: Texture2D = skin.texture(color, piece_type)
				if texture == null:
					push_error("Missing texture in %s: %s_%s" % [skin.skin_id, color, piece_type])
					ok = false
				elif texture.get_width() != texture.get_height() or texture.get_width() < 64:
					push_error("Texture must be square and at least 64px: %s_%s" % [color, piece_type])
					ok = false

	var packed_scene := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu := packed_scene.instantiate()
	root.add_child(menu)
	await process_frame
	var option := menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/PieceSkinOption") as OptionButton
	var white_preview := menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/WhitePieces") as HBoxContainer
	var black_preview := menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/BlackPieces") as HBoxContainer
	var option_names: Array[String] = []
	for index in option.item_count:
		option_names.append(option.get_item_text(index))
	if option.item_count != 2 or "Royal Forge" not in option_names or "Modern Parchment" not in option_names:
		push_error("Piece skin selector was not populated")
		ok = false
	if white_preview.get_child_count() != 6 or black_preview.get_child_count() != 6:
		push_error("Piece skin preview must show both sets of six pieces")
		ok = false
	print("[PASS] Piece skin test" if ok else "[FAIL] Piece skin test")
	quit(0 if ok else 1)
