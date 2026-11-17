class_name BattleOutcomeEvaluator
extends RefCounted

func evaluate(board: BoardState, player_color: int, turn_limit: int) -> BattleOutcome:
	if board == null:
		return BattleOutcome.active()
	if not board.has_king(GameRules.PieceColor.WHITE):
		return BattleOutcome.completed(GameRules.PieceColor.BLACK, false, &"king_captured")
	if not board.has_king(GameRules.PieceColor.BLACK):
		return BattleOutcome.completed(GameRules.PieceColor.WHITE, false, &"king_captured")
	if turn_limit > 0 and board.move_history.size() >= turn_limit:
		return BattleOutcome.completed(GameRules.opposite(player_color), false, &"objective_turn_limit")
	if board.is_checkmate(board.turn):
		return BattleOutcome.completed(GameRules.opposite(board.turn), false, &"checkmate")
	if board.has_only_king(GameRules.PieceColor.WHITE) and board.has_only_king(GameRules.PieceColor.BLACK):
		return BattleOutcome.completed(-1, true, &"two_lone_kings")
	var lone_king_loser: int = board.get_lone_king_loser()
	if lone_king_loser >= 0:
		return BattleOutcome.completed(GameRules.opposite(lone_king_loser), false, &"lone_king")
	if board.is_stalemate(board.turn):
		return BattleOutcome.completed(-1, true, &"stalemate")
	return BattleOutcome.active()
