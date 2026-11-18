class_name PieceInstanceState
extends RefCounted

var instance_id: int = 0
var piece_def_id: StringName = &""
var is_king: bool = false
## Run-wide growth: captures made in won battles, and moves learned (chameleon).
var capture_count: int = 0
var learned_def_ids: Array[String] = []

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
		"capture_count": capture_count,
		"learned_def_ids": learned_def_ids.duplicate(),
	}

func load_from_dictionary(data: Dictionary) -> bool:
	if not data.has("instance_id") or not data.has("piece_def_id") or not data.has("is_king"):
		return false
	instance_id = int(data.get("instance_id", 0))
	piece_def_id = StringName(str(data.get("piece_def_id", "")))
	is_king = bool(data.get("is_king", false))
	capture_count = maxi(0, int(data.get("capture_count", 0)))
	learned_def_ids.clear()
	var learned_value: Variant = data.get("learned_def_ids", [])
	if learned_value is Array:
		for entry: Variant in learned_value as Array:
			if PieceDefDatabase.get_def(str(entry)) != null:
				learned_def_ids.append(str(entry))
	return is_valid()

func to_chess_piece(color: int) -> ChessPiece:
	if not is_valid():
		return null
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece_def_id))
	var piece: ChessPiece = ChessPiece.create_with_instance_id(definition, color, instance_id)
	apply_growth_to(piece)
	return piece

func apply_growth_to(piece: ChessPiece) -> void:
	piece.capture_count = capture_count
	piece.learned_def_ids = learned_def_ids.duplicate()

## Keeps what a won battle taught this piece: captures, learned moves, evolved form.
func absorb_growth(record: Dictionary) -> void:
	capture_count = maxi(capture_count, int(record.get("capture_count", capture_count)))
	var learned_value: Variant = record.get("learned", learned_def_ids)
	if learned_value is Array:
		learned_def_ids.clear()
		for entry: Variant in learned_value as Array:
			learned_def_ids.append(str(entry))
	var evolved: PieceDef = PieceDefDatabase.get_def(str(record.get("def_id", "")))
	if evolved != null and evolved.is_king == is_king:
		piece_def_id = StringName(evolved.id)
