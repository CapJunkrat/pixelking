extends Node

## 全局游戏状态单例。
## 当前持有对局棋盘和挑战者物品；后续 Roguelike 阶段将在此扩展金币、遗物、招募棋子与波次等状态。
var board: BoardState = null

## Persistent and consumable objects share the same challenger inventory.
var challenger_items: Array[ChallengerItemDef] = []

## 玩家在 Roguelike 对局中控制的一方。
var player_color: int = GameRules.PieceColor.WHITE

func _ready() -> void:
	start_new_game()

func start_new_game() -> void:
	board = BoardState.new()
	board.remove_all_pawns()
	challenger_items.clear()

## 尝试走一步棋，返回 true 表示成功。
## UI 与 AI 都通过此入口执行合法性校验、更新状态并广播事件。
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
