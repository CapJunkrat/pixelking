class_name BattleCommandProcessor
extends RefCounted

const EVENT_ACTION_STARTED: StringName = &"action_started"
const EVENT_ACTION_REJECTED: StringName = &"action_rejected"
const EVENT_PIECE_MOVED: StringName = &"piece_moved"
const EVENT_PIECE_CAPTURED: StringName = &"piece_captured"
const EVENT_CASTLED: StringName = &"castled"
const EVENT_PROMOTED: StringName = &"promoted"
const EVENT_TURN_CHANGED: StringName = &"turn_changed"
const EVENT_CHECK_DECLARED: StringName = &"check_declared"
const EVENT_BATTLE_ENDED: StringName = &"battle_ended"

var board: BoardState
var event_history: Array[BattleEvent] = []
var _next_action_id: int = 1
var _next_sequence: int = 1

func _init(p_board: BoardState = null) -> void:
	board = p_board

func execute(action: BattleAction) -> BattleCommandResult:
	var action_id: int = _next_action_id
	_next_action_id += 1
	if board == null:
		return _rejected(action_id, &"missing_board")
	if action == null:
		return _rejected(action_id, &"missing_action")
	if action.actor_color != board.turn:
		return _rejected(action_id, &"wrong_turn")
	match action.action_type:
		BattleAction.ActionType.MOVE:
			return _execute_move(action as MoveAction, action_id)
		_:
			return _rejected(action_id, &"unsupported_action")

func _execute_move(action: MoveAction, action_id: int) -> BattleCommandResult:
	if action == null:
		return _rejected(action_id, &"invalid_move_action")
	var moving_piece: ChessPiece = board.get_piece(action.from)
	var capture_position: Vector2i = action.to
	var captured_piece: ChessPiece = board.get_piece(action.to)
	if moving_piece != null and moving_piece.def.is_pawn and captured_piece == null and action.to == board.en_passant_target:
		capture_position = Vector2i(action.to.x, action.from.y)
		captured_piece = board.get_piece(capture_position)

	var move_result: Dictionary = board.make_move(action.from, action.to, action.promotion_id)
	if not bool(move_result.get("success", false)):
		var error_code: StringName = StringName(str(move_result.get("error", "invalid_move")))
		var rejected: BattleCommandResult = _rejected(action_id, error_code)
		rejected.legacy_result = move_result.duplicate(true)
		return rejected

	var result: BattleCommandResult = BattleCommandResult.new()
	result.success = true
	result.legacy_result = move_result.duplicate(true)
	result.events.append(_event(EVENT_ACTION_STARTED, action_id, {
		"action_type": "move",
		"actor_color": action.actor_color,
	}))
	result.events.append(_event(EVENT_PIECE_MOVED, action_id, {
		"from": action.from,
		"to": action.to,
		"piece_def_id": moving_piece.get_id() if moving_piece != null else "",
		"instance_id": moving_piece.instance_id if moving_piece != null else 0,
		"color": action.actor_color,
	}))
	if bool(move_result.get("captured", false)) and captured_piece != null:
		result.events.append(_event(EVENT_PIECE_CAPTURED, action_id, {
			"position": capture_position,
			"piece_def_id": captured_piece.get_id(),
			"instance_id": captured_piece.instance_id,
			"color": captured_piece.color,
		}))
	if bool(move_result.get("castled", false)):
		result.events.append(_event(EVENT_CASTLED, action_id, {"from": action.from, "to": action.to}))
	if bool(move_result.get("promoted", false)):
		result.events.append(_event(EVENT_PROMOTED, action_id, {
			"position": action.to,
			"piece_def_id": action.promotion_id,
			"color": action.actor_color,
		}))
	result.events.append(_event(EVENT_TURN_CHANGED, action_id, {"turn": board.turn}))
	_append_terminal_events(result.events, action_id)
	return result

func _append_terminal_events(events: Array[BattleEvent], action_id: int) -> void:
	if board.is_checkmate(board.turn):
		events.append(_event(EVENT_CHECK_DECLARED, action_id, {"color": board.turn, "checkmate": true}))
		events.append(_battle_ended(action_id, GameRules.opposite(board.turn), false, &"checkmate"))
		return
	if board.has_only_king(GameRules.PieceColor.WHITE) and board.has_only_king(GameRules.PieceColor.BLACK):
		events.append(_battle_ended(action_id, -1, true, &"two_lone_kings"))
		return
	var lone_king_loser: int = board.get_lone_king_loser()
	if lone_king_loser >= 0:
		events.append(_battle_ended(action_id, GameRules.opposite(lone_king_loser), false, &"lone_king"))
		return
	if board.is_stalemate(board.turn):
		events.append(_battle_ended(action_id, -1, true, &"stalemate"))
		return
	if board.is_in_check(board.turn):
		events.append(_event(EVENT_CHECK_DECLARED, action_id, {"color": board.turn, "checkmate": false}))

func _battle_ended(action_id: int, winner: int, draw: bool, reason: StringName) -> BattleEvent:
	return _event(EVENT_BATTLE_ENDED, action_id, {
		"winner": winner,
		"draw": draw,
		"reason": String(reason),
	})

func _rejected(action_id: int, error_code: StringName) -> BattleCommandResult:
	var result: BattleCommandResult = BattleCommandResult.rejected(error_code)
	result.events.append(_event(EVENT_ACTION_REJECTED, action_id, {"error": String(error_code)}))
	return result

func _event(event_type: StringName, action_id: int, payload: Dictionary = {}) -> BattleEvent:
	var event: BattleEvent = BattleEvent.new(event_type, _next_sequence, action_id, payload)
	_next_sequence += 1
	event_history.append(event)
	return event
