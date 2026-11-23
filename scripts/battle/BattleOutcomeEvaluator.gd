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
	# A side with moves that all endanger its own King is stalemated as in chess. A side
	# with no action at all (frozen, turned to stone) is not judged here:
	# stuck_turn_ruling decides whether it waits, loses to a blockade or draws.
	if board.is_stalemate(board.turn) and board.has_any_executable_move(board.turn):
		return BattleOutcome.completed(-1, true, &"stalemate")
	return BattleOutcome.active()

## What happens when the side to move cannot act at all (and is not checkmated):
##   &"none"     it can act, nothing to rule;
##   &"item"     the player holds an item that would free a piece: the turn stays,
##               and the player uses it or ends the turn;
##   &"wait"     a timed freeze runs out, an egg hatches or a piece returns later:
##               the turn is skipped;
##   &"blockade" locked down for good while the other side can play on: it loses;
##   &"draw"     neither side can ever act again.
## Only lasting control (a Gorgon's stare) makes a blockade; a timed freeze only
## costs turns. `item_escape` (color -> bool) checks the player's items.
func stuck_turn_ruling(board: BoardState, item_escape: Callable = Callable()) -> StringName:
	var color: int = board.turn
	if not board.has_king(color) or board.is_in_check(color) or board.has_any_executable_move(color):
		return &"none"
	if item_escape.is_valid() and bool(item_escape.call(color)):
		return &"item"
	if board.can_recover_by_waiting(color):
		return &"wait"
	return &"blockade" if board.is_blockaded(color) else &"draw"
