class_name PieceInstanceState
extends RefCounted

var instance_id: int = 0
var piece_def_id: StringName = &""
var is_king: bool = false
var is_protected: bool = false

func _init(p_instance_id: int = 0, p_piece_def_id: StringName = &"", p_is_king: bool = false) -> void:
	instance_id = p_instance_id
	piece_def_id = p_piece_def_id
	is_king = p_is_king

func is_valid() -> bool:
	if instance_id <= 0 or piece_def_id.is_empty():
		return false
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece_def_id))
	if definition == null:
		return false
	return definition.is_king == is_king

func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"piece_def_id": String(piece_def_id),
		"is_king": is_king,
		"is_protected": is_protected,
	}

func load_from_dictionary(data: Dictionary) -> bool:
	if not data.has("instance_id") or not data.has("piece_def_id") or not data.has("is_king"):
		return false
	instance_id = int(data.get("instance_id", 0))
	piece_def_id = StringName(str(data.get("piece_def_id", "")))
	is_king = bool(data.get("is_king", false))
	is_protected = bool(data.get("is_protected", false))
	return is_valid()

func to_chess_piece(color: int) -> ChessPiece:
	if not is_valid():
		return null
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece_def_id))
	return ChessPiece.create_with_instance_id(definition, color, instance_id)
