class_name BattleCommandProcessor
extends RefCounted

var board: BoardState

func _init(p_board: BoardState = null) -> void:
	board = p_board

func execute(action: BattleAction) -> BattleCommandResult:
	if board == null:
		return BattleCommandResult.rejected(&"missing_board")
	if action == null:
		return BattleCommandResult.rejected(&"missing_action")
	if action.actor_color != board.turn:
		return BattleCommandResult.rejected(&"wrong_turn")
	match action.action_type:
		BattleAction.ActionType.MOVE:
			return _execute_move(action as MoveAction)
		_:
			return BattleCommandResult.rejected(&"unsupported_action")

func _execute_move(action: MoveAction) -> BattleCommandResult:
	if action == null:
		return BattleCommandResult.rejected(&"invalid_move_action")
	var move_result: Dictionary = board.make_move(action.from, action.to, action.promotion_id)
	var result: BattleCommandResult = BattleCommandResult.new()
	result.success = bool(move_result.get("success", false))
	result.error = StringName(str(move_result.get("error", "")))
	result.legacy_result = move_result.duplicate(true)
	return result
