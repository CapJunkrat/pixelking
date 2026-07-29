class_name PieceSkin
extends Resource

@export var skin_id: StringName
@export var display_name: String
@export_dir var texture_root: String

func texture(color: StringName, piece_type: StringName) -> Texture2D:
	var path := "%s/%s_%s.png" % [texture_root, color, piece_type]
	if not ResourceLoader.exists(path):
		push_warning("Missing piece skin texture: %s" % path)
		return null
	return load(path) as Texture2D
