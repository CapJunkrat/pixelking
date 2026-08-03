extends RefCounted
class_name GameRules

enum PieceColor { WHITE, BLACK }

static func opposite(color: int) -> int:
	return PieceColor.BLACK if color == PieceColor.WHITE else PieceColor.WHITE

static func color_key(color: int) -> StringName:
	return &"COLOR_WHITE" if color == PieceColor.WHITE else &"COLOR_BLACK"
