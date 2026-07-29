extends RefCounted
class_name GameRules

enum PieceColor { WHITE, BLACK }

static func opposite(color: int) -> int:
	return PieceColor.BLACK if color == PieceColor.WHITE else PieceColor.WHITE

static func color_name(color: int) -> String:
	return "白方" if color == PieceColor.WHITE else "黑方"
