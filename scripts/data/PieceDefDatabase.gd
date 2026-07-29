extends RefCounted
class_name PieceDefDatabase

## P1阶段:标准6种棋子的定义直接在代码里构建。
## P4/P5阶段(特殊棋子/Roguelike内容扩充)时,可以把这里换成
## "扫描 res://resources/piece_defs/*.tres 目录自动加载"的方式,
## 对外接口 get_def(id) 保持不变,不影响 MoveGenerator / BoardState。

static var _cache: Dictionary = {}

static func get_def(id: String) -> PieceDef:
	if _cache.is_empty():
		_build_all()
	return _cache.get(id, null)

static func _build_all() -> void:
	_cache["pawn"] = _pawn()
	_cache["knight"] = _knight()
	_cache["bishop"] = _bishop()
	_cache["rook"] = _rook()
	_cache["queen"] = _queen()
	_cache["king"] = _king()

static func _pawn() -> PieceDef:
	var d := PieceDef.new()
	d.id = "pawn"
	d.display_name = "兵"
	d.is_pawn = true
	d.base_value = 1
	return d

static func _knight() -> PieceDef:
	var d := PieceDef.new()
	d.id = "knight"
	d.display_name = "马"
	d.jump_offsets = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
		Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)
	]
	d.base_value = 3
	return d

static func _bishop() -> PieceDef:
	var d := PieceDef.new()
	d.id = "bishop"
	d.display_name = "象"
	d.slide_directions = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	d.max_slide_distance = 8
	d.base_value = 3
	return d

static func _rook() -> PieceDef:
	var d := PieceDef.new()
	d.id = "rook"
	d.display_name = "车"
	d.slide_directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	d.max_slide_distance = 8
	d.base_value = 5
	return d

static func _queen() -> PieceDef:
	var d := PieceDef.new()
	d.id = "queen"
	d.display_name = "后"
	d.slide_directions = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	d.max_slide_distance = 8
	d.base_value = 9
	return d

static func _king() -> PieceDef:
	var d := PieceDef.new()
	d.id = "king"
	d.display_name = "王"
	d.slide_directions = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	d.max_slide_distance = 1
	d.is_king = true
	d.base_value = 1000
	return d
