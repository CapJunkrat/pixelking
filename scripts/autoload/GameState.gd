extends Node

## 全局游戏状态单例。
## P1阶段:只持有当前这一局棋的 BoardState,供任何脚本访问。
## P4阶段(Roguelike框架)会在这里扩展:gold、relics、recruited_pieces、wave_index 等。

var board: BoardState = null

## 玩家在Roguelike里操控的一方(P4阶段引入敌我概念后会用到)
var player_color: int = GameRules.PieceColor.WHITE

func _ready() -> void:
	start_new_game()

func start_new_game() -> void:
	board = BoardState.new()

## 尝试走一步棋。返回 true 表示走子成功。
## 这是给UI层/AI层调用的统一入口,内部负责校验合法性、执行、广播事件。
func try_move(from: Vector2i, to: Vector2i, promotion_id: String = "queen") -> bool:
	if board == null:
		return false
	var result := board.make_move(from, to, promotion_id)
	if not result.get("success", false):
		return false

	EventBus.move_made.emit(from, to, result)
	EventBus.turn_changed.emit(board.turn)

	if result.get("checkmate", false):
		EventBus.checkmate.emit(board.turn)
	elif result.get("stalemate", false):
		EventBus.stalemate.emit(board.turn)
	elif result.get("check", false):
		EventBus.check_declared.emit(board.turn)

	return true
