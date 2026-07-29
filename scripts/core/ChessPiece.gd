extends RefCounted
class_name ChessPiece

## 棋盘上的一枚棋子实例。
## 注意:def 是"这是什么棋子"(数据定义,可共享),
## 而 has_moved / instance_id 等是"这一枚具体棋子"的状态。

var def: PieceDef
var color: int  # GameRules.PieceColor.WHITE / BLACK
var has_moved: bool = false

## 全局自增实例id,方便未来遗物/升级系统追踪"这一枚具体棋子"
static var _next_instance_id: int = 1
var instance_id: int = 0

func _init(p_def: PieceDef = null, p_color: int = 0) -> void:
	def = p_def
	color = p_color
	instance_id = _next_instance_id
	_next_instance_id += 1

func duplicate_piece() -> ChessPiece:
	var copy := ChessPiece.new(def, color)
	copy.has_moved = has_moved
	# 注意:duplicate_piece 会分配一个新的 instance_id,
	# 因为它通常用于"模拟一步棋"这种临时场景,不代表真的产生了新棋子。
	return copy

func get_id() -> String:
	return def.id if def != null else "?"
