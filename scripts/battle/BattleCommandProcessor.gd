class_name BattleCommandProcessor
extends RefCounted

const EVENT_ACTION_STARTED: StringName = &"action_started"
const EVENT_ACTION_REJECTED: StringName = &"action_rejected"
const EVENT_ITEM_USED: StringName = &"item_used"
const EVENT_PIECE_MOVED: StringName = &"piece_moved"
const EVENT_PIECE_CAPTURED: StringName = &"piece_captured"
const EVENT_CASTLED: StringName = &"castled"
const EVENT_PROMOTED: StringName = &"promoted"
const EVENT_EFFECT_APPLIED: StringName = &"effect_applied"
const EVENT_EFFECT_SETTLEMENT_ABORTED: StringName = &"effect_settlement_aborted"
const EVENT_TURN_CHANGED: StringName = &"turn_changed"
const EVENT_EXTRA_MOVE_GRANTED: StringName = &"extra_move_granted"
const EVENT_CHECK_DECLARED: StringName = &"check_declared"
const EVENT_BATTLE_ENDED: StringName = &"battle_ended"
## Piece abilities (docs §27). Payloads carry board squares and instance ids.
const EVENT_PIECE_DESTROYED: StringName = &"piece_destroyed"
const EVENT_SHELL_BROKEN: StringName = &"shell_broken"
const EVENT_SHIELD_GRANTED: StringName = &"shield_granted"
const EVENT_KING_SWAPPED: StringName = &"king_swapped"
const EVENT_PIECE_EVOLVED: StringName = &"piece_evolved"
const EVENT_MOVE_LEARNED: StringName = &"move_learned"
const EVENT_FORM_CHANGED: StringName = &"form_changed"
const EVENT_PIECE_REVIVED: StringName = &"piece_revived"
const EVENT_LAST_STAND: StringName = &"last_stand"
const EVENT_TURN_ENDED_EARLY: StringName = &"turn_ended_early"
## A turn never holds more than this many actions.
const MAX_ACTIONS_PER_TURN := 2

var board: BoardState
var challenger_items: Array[ChallengerItemDef]
var player_color: int = GameRules.PieceColor.WHITE
var event_history: Array[BattleEvent] = []
var effect_queue: BattleEffectQueue = BattleEffectQueue.new()
var status: BattleStatus = BattleStatus.new()
var outcome_evaluator: BattleOutcomeEvaluator = BattleOutcomeEvaluator.new()
## Optional generic objective: the player must win before this many plies.
var turn_limit: int = 0
var _next_action_id: int = 1
var _next_sequence: int = 1
var _item_used_turn_key: int = -1

func _init(
	p_board: BoardState = null,
	p_challenger_items: Array[ChallengerItemDef] = [],
	p_player_color: int = GameRules.PieceColor.WHITE,
	p_turn_limit: int = 0
) -> void:
	board = p_board
	challenger_items = p_challenger_items
	player_color = p_player_color
	turn_limit = p_turn_limit

func queue_effect(effect: BattleEffect) -> bool:
	return effect_queue.enqueue(effect)

func execute(action: BattleAction) -> BattleCommandResult:
	var action_id: int = _next_action_id
	_next_action_id += 1
	if status.is_finished():
		return _rejected(action_id, &"battle_already_finished")
	if board == null:
		return _rejected(action_id, &"missing_board")
	if action == null:
		return _rejected(action_id, &"missing_action")
	if action.actor_color != board.turn:
		return _rejected(action_id, &"wrong_turn")
	match action.action_type:
		BattleAction.ActionType.MOVE:
			return _execute_move(action as MoveAction, action_id)
		BattleAction.ActionType.USE_ITEM:
			return _execute_use_item(action as UseItemAction, action_id)
		BattleAction.ActionType.END_TURN:
			return _execute_end_turn(action, action_id)
		_:
			return _rejected(action_id, &"unsupported_action")

func can_use_item(slot_index: int, actor_color: int) -> bool:
	if status.is_finished() or board == null or actor_color != player_color or board.turn != player_color:
		return false
	if _item_used_turn_key == board.turn_serial:
		return false
	if slot_index < 0 or slot_index >= challenger_items.size():
		return false
	var item: ChallengerItemDef = challenger_items[slot_index]
	return item != null and item.is_consumable()

func stage_item_use(action: UseItemAction) -> BattleItemUsePlan:
	var validation_error: StringName = _validate_item_action(action)
	if not validation_error.is_empty():
		return null
	var staged_board: BoardState = board.clone_runtime()
	var staged_items: Array[ChallengerItemDef] = []
	staged_items.assign(challenger_items)
	var staged_processor: BattleCommandProcessor = _clone_runtime(staged_board, staged_items)
	var staged_action: UseItemAction = UseItemAction.new(action.slot_index, action.actor_color, action.target_position)
	var staged_result: BattleCommandResult = staged_processor.execute(staged_action)
	if not staged_result.success:
		return null
	return BattleItemUsePlan.new(
		challenger_items[action.slot_index].id,
		action.slot_index,
		staged_board,
		staged_items,
		staged_processor,
		staged_result
	)

func reject_external(error_code: StringName) -> BattleCommandResult:
	var action_id: int = _next_action_id
	_next_action_id += 1
	return _rejected(action_id, error_code)

func can_end_turn(actor_color: int) -> bool:
	return not status.is_finished() and board != null and board.turn == actor_color and board.bonus_instance_id != 0

func evaluate_terminal_state() -> BattleCommandResult:
	if status.is_finished():
		return null
	var stand: Array[BattleEvent] = []
	_try_last_stand(stand, _next_action_id)
	if not stand.is_empty():
		_next_action_id += 1
		var saved: BattleCommandResult = BattleCommandResult.new()
		saved.success = true
		saved.events = stand
		return saved
	var outcome: BattleOutcome = outcome_evaluator.evaluate(board, player_color, turn_limit)
	if not outcome.finished:
		return null
	var action_id: int = _next_action_id
	_next_action_id += 1
	var result: BattleCommandResult = BattleCommandResult.new()
	result.success = true
	_complete_battle(result.events, action_id, outcome)
	return result

func force_finish(winner: int, draw: bool, reason: StringName = &"debug_forced") -> BattleCommandResult:
	var action_id: int = _next_action_id
	_next_action_id += 1
	if status.is_finished():
		return _rejected(action_id, &"battle_already_finished")
	var outcome: BattleOutcome = BattleOutcome.completed(winner, draw, reason)
	var result: BattleCommandResult = BattleCommandResult.new()
	result.success = true
	result.legacy_result = {"success": true, "forced_finish": true}
	_complete_battle(result.events, action_id, outcome)
	return result

func _execute_use_item(action: UseItemAction, action_id: int) -> BattleCommandResult:
	var validation_error: StringName = _validate_item_action(action)
	if not validation_error.is_empty():
		return _rejected(action_id, validation_error)
	var item: ChallengerItemDef = challenger_items[action.slot_index]
	var effect_payload: Dictionary = item.effect_payload.duplicate(true)
	if board.in_bounds(action.target_position):
		effect_payload["position"] = action.target_position
	queue_effect(BattleEffect.new(
		item.id,
		item.effect_type,
		action.actor_color,
		item.effect_priority,
		action.target_position,
		0,
		effect_payload
	))
	_item_used_turn_key = board.turn_serial
	challenger_items.remove_at(action.slot_index)
	var result: BattleCommandResult = BattleCommandResult.new()
	result.success = true
	result.legacy_result = {"success": true, "item_used": true}
	result.events.append(_event(EVENT_ACTION_STARTED, action_id, {
		"action_type": "use_item",
		"actor_color": action.actor_color,
	}))
	result.events.append(_event(EVENT_ITEM_USED, action_id, {
		"item_id": String(item.id),
		"slot_index": action.slot_index,
	}))
	_settle_effects(result.events, action_id, action.actor_color)
	_append_terminal_events(result.events, action_id)
	return result

func _validate_item_action(action: UseItemAction) -> StringName:
	if action == null:
		return &"invalid_item_action"
	if not can_use_item(action.slot_index, action.actor_color):
		return &"item_unavailable"
	var item: ChallengerItemDef = challenger_items[action.slot_index]
	if item.effect_type == &"remove_piece":
		if not board.in_bounds(action.target_position):
			return &"item_target_required"
		var target_piece: ChessPiece = board.get_piece(action.target_position)
		if target_piece == null or target_piece.color == action.actor_color or target_piece.def.is_king:
			return &"invalid_item_target"
	return &""

func _clone_runtime(staged_board: BoardState, staged_items: Array[ChallengerItemDef]) -> BattleCommandProcessor:
	var copy: BattleCommandProcessor = BattleCommandProcessor.new(staged_board, staged_items, player_color, turn_limit)
	copy._next_action_id = _next_action_id
	copy._next_sequence = _next_sequence
	copy._item_used_turn_key = _item_used_turn_key
	copy.event_history.assign(event_history)
	copy.effect_queue = effect_queue.clone_runtime()
	copy.status = status.clone_runtime()
	return copy

func _execute_move(action: MoveAction, action_id: int) -> BattleCommandResult:
	if action == null:
		return _rejected(action_id, &"invalid_move_action")
	var moving_piece: ChessPiece = board.get_piece(action.from)
	var capture_position: Vector2i = action.to
	var captured_piece: ChessPiece = board.get_piece(action.to)
	if moving_piece != null and moving_piece.def.is_pawn and captured_piece == null and action.to == board.en_passant_target:
		capture_position = Vector2i(action.to.x, action.from.y)
		captured_piece = board.get_piece(capture_position)

	var prior_actions: int = board.actions_this_turn
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
	var landing: Vector2i = move_result.get("landing", action.to)
	result.events.append(_event(EVENT_PIECE_MOVED, action_id, {
		"from": action.from,
		"to": landing if board.in_bounds(landing) else action.to,
		"target": action.to,
		"piece_def_id": moving_piece.get_id() if moving_piece != null else "",
		"instance_id": moving_piece.instance_id if moving_piece != null else 0,
		"color": action.actor_color,
		"action_kind": str(move_result.get("action_kind", "")),
		"ranged": bool(move_result.get("ranged", false)),
	}))
	if bool(move_result.get("captured", false)) and captured_piece != null:
		result.events.append(_event(EVENT_PIECE_CAPTURED, action_id, {
			"position": capture_position,
			"piece_def_id": captured_piece.get_id(),
			"instance_id": captured_piece.instance_id,
			"color": captured_piece.color,
			"was_king": captured_piece.def.is_king,
		}))
	_append_ability_events(result.events, action_id, action, move_result)
	if bool(move_result.get("castled", false)):
		result.events.append(_event(EVENT_CASTLED, action_id, {"from": action.from, "to": action.to}))
	if bool(move_result.get("promoted", false)):
		result.events.append(_event(EVENT_PROMOTED, action_id, {
			"position": action.to,
			"piece_def_id": action.promotion_id,
			"color": action.actor_color,
		}))
	_settle_effects(result.events, action_id, action.actor_color)
	_refresh_legacy_terminal_flags(result.legacy_result)
	# moving_piece.def may have changed form; the ability belongs to the piece that acted.
	var acted_def: PieceDef = PieceDefDatabase.get_def(str(move_result.get("moved_def_id", ""))) if move_result.has("moved_def_id") else null
	if acted_def == null and moving_piece != null:
		acted_def = moving_piece.def
	var bonus_candidate: bool = (
		moving_piece != null
		and acted_def != null
		and prior_actions + 1 < MAX_ACTIONS_PER_TURN
		and board.get_piece(landing) == moving_piece
		and (acted_def.extra_move_always or (acted_def.extra_move_on_capture and bool(move_result.get("captured", false))))
	)
	if bonus_candidate:
		# Terminal rules are evaluated while the captured side owns the response turn.
		_try_last_stand(result.events, action_id)
		var outcome: BattleOutcome = outcome_evaluator.evaluate(board, player_color, turn_limit)
		if outcome.finished:
			result.events.append(_event(EVENT_TURN_CHANGED, action_id, {"turn": board.turn}))
			if outcome.reason == &"checkmate":
				result.events.append(_event(EVENT_CHECK_DECLARED, action_id, {"color": board.turn, "checkmate": true}))
			_complete_battle(result.events, action_id, outcome)
		else:
			if board.is_in_check(board.turn):
				result.events.append(_event(EVENT_CHECK_DECLARED, action_id, {"color": board.turn, "checkmate": false}))
			board.turn = action.actor_color
			board.turn_serial = maxi(0, board.turn_serial - 1)
			board.actions_this_turn = prior_actions + 1
			board.bonus_instance_id = moving_piece.instance_id
			if board.get_executable_moves(landing).is_empty():
				# Nothing left to do with the bonus action: the turn simply passes.
				_pass_turn()
				result.events.append(_event(EVENT_TURN_CHANGED, action_id, {"turn": board.turn}))
				_append_revivals(result.events, action_id)
				_append_terminal_events(result.events, action_id)
				return result
			result.legacy_result["extra_move_granted"] = true
			result.events.append(_event(EVENT_EXTRA_MOVE_GRANTED, action_id, {
				"color": action.actor_color,
				"instance_id": moving_piece.instance_id,
			}))
			result.events.append(_event(EVENT_TURN_CHANGED, action_id, {"turn": board.turn}))
	else:
		result.events.append(_event(EVENT_TURN_CHANGED, action_id, {"turn": board.turn}))
		_append_revivals(result.events, action_id)
		_append_terminal_events(result.events, action_id)
	return result

func _execute_end_turn(action: BattleAction, action_id: int) -> BattleCommandResult:
	if not can_end_turn(action.actor_color):
		return _rejected(action_id, &"no_bonus_action")
	_pass_turn()
	var result: BattleCommandResult = BattleCommandResult.new()
	result.success = true
	result.legacy_result = {"success": true, "turn_ended": true}
	result.events.append(_event(EVENT_ACTION_STARTED, action_id, {"action_type": "end_turn", "actor_color": action.actor_color}))
	result.events.append(_event(EVENT_TURN_ENDED_EARLY, action_id, {"color": action.actor_color}))
	result.events.append(_event(EVENT_TURN_CHANGED, action_id, {"turn": board.turn}))
	_append_revivals(result.events, action_id)
	_append_terminal_events(result.events, action_id)
	return result

func _pass_turn() -> void:
	board.turn = GameRules.opposite(board.turn)
	board.turn_serial += 1
	board.bonus_instance_id = 0
	board.actions_this_turn = 0

func _append_revivals(events: Array[BattleEvent], action_id: int) -> void:
	for revived: Dictionary in board.process_revivals(board.turn):
		events.append(_event(EVENT_PIECE_REVIVED, action_id, revived))

func _append_ability_events(events: Array[BattleEvent], action_id: int, action: MoveAction, move_result: Dictionary) -> void:
	for entry: Dictionary in move_result.get("removed", []):
		if str(entry.get("cause", "")) != "capture":
			events.append(_event(EVENT_PIECE_DESTROYED, action_id, entry))
	for entry: Dictionary in move_result.get("shells", []):
		events.append(_event(EVENT_SHELL_BROKEN, action_id, entry))
	var shielded: Array = move_result.get("shielded", [])
	if not shielded.is_empty():
		events.append(_event(EVENT_SHIELD_GRANTED, action_id, {"positions": shielded}))
	if bool(move_result.get("swapped_with_king", false)):
		events.append(_event(EVENT_KING_SWAPPED, action_id, {"from": action.from, "to": action.to, "color": action.actor_color}))
	var landing: Vector2i = move_result.get("landing", action.to)
	if not str(move_result.get("learned", "")).is_empty():
		events.append(_event(EVENT_MOVE_LEARNED, action_id, {"position": landing, "learned": str(move_result.get("learned", ""))}))
	if not str(move_result.get("evolved_into", "")).is_empty():
		events.append(_event(EVENT_PIECE_EVOLVED, action_id, {"position": landing, "piece_def_id": str(move_result.get("evolved_into", "")), "color": action.actor_color}))
	if not str(move_result.get("form_changed", "")).is_empty():
		events.append(_event(EVENT_FORM_CHANGED, action_id, {"position": landing, "piece_def_id": str(move_result.get("form_changed", "")), "color": action.actor_color}))

## Shield King: the first time it would be checkmated, every non-King piece giving
## check is destroyed instead and the battle goes on.
func _try_last_stand(events: Array[BattleEvent], action_id: int) -> void:
	var color: int = board.turn
	if not board.has_king(color):
		return
	var king_square: Vector2i = board.king_pos[color]
	var king: ChessPiece = board.get_piece(king_square)
	if king == null or not king.def.survives_checkmate_once or king.has_used(&"last_stand") or not board.is_checkmate(color):
		return
	var attackers: Array[Vector2i] = []
	for x: int in range(board.board_size):
		for y: int in range(board.board_size):
			var square: Vector2i = Vector2i(x, y)
			var occupant: ChessPiece = board.get_piece(square)
			if occupant != null and occupant.color != color and not occupant.def.is_king and king_square in MoveGenerator.get_attack_squares(board, square):
				attackers.append(square)
	king.used_abilities[&"last_stand"] = true
	var removed: Array = []
	for square: Vector2i in attackers:
		var occupant: ChessPiece = board.get_piece(square)
		removed.append({"position": square, "piece_def_id": occupant.def.id, "instance_id": occupant.instance_id, "color": occupant.color})
		board.set_piece(square, null)
	events.append(_event(EVENT_LAST_STAND, action_id, {"position": king_square, "color": color, "removed": removed}))

func _settle_effects(events: Array[BattleEvent], action_id: int, acting_color: int) -> void:
	var settlement: Dictionary = effect_queue.settle(acting_color, _apply_effect)
	var applied: Array = settlement.get("applied", []) as Array
	for effect_value: Variant in applied:
		var effect: BattleEffect = effect_value as BattleEffect
		if effect == null:
			continue
		events.append(_event(EVENT_EFFECT_APPLIED, action_id, {
			"effect_id": String(effect.effect_id),
			"effect_type": String(effect.effect_type),
			"owner_color": effect.owner_color,
			"position": effect.board_position,
			"source_instance_id": effect.source_instance_id,
		}))
	if not bool(settlement.get("success", false)):
		events.append(_event(EVENT_EFFECT_SETTLEMENT_ABORTED, action_id, {
			"error": str(settlement.get("error", "unknown")),
		}))

func _apply_effect(effect: BattleEffect) -> Array[BattleEffect]:
	var generated: Array[BattleEffect] = []
	match effect.effect_type:
		&"noop":
			pass
		&"remove_piece":
			var data: Dictionary = effect.payload
			var position_value: Variant = data.get("position", effect.board_position)
			if position_value is Vector2i:
				var position: Vector2i = position_value
				var target: ChessPiece = board.get_piece(position)
				if target != null and not target.def.is_king:
					board.set_piece(position, null)
	return generated

func _refresh_legacy_terminal_flags(move_result: Dictionary) -> void:
	move_result["check"] = board.is_in_check(board.turn)
	move_result["checkmate"] = board.is_checkmate(board.turn) if bool(move_result["check"]) else false
	move_result["stalemate"] = board.is_stalemate(board.turn) if not bool(move_result["check"]) else false

func _append_terminal_events(events: Array[BattleEvent], action_id: int) -> void:
	_try_last_stand(events, action_id)
	var outcome: BattleOutcome = outcome_evaluator.evaluate(board, player_color, turn_limit)
	if outcome.finished:
		if outcome.reason == &"checkmate":
			events.append(_event(EVENT_CHECK_DECLARED, action_id, {"color": board.turn, "checkmate": true}))
		_complete_battle(events, action_id, outcome)
		return
	if board.is_in_check(board.turn):
		events.append(_event(EVENT_CHECK_DECLARED, action_id, {"color": board.turn, "checkmate": false}))

func _complete_battle(events: Array[BattleEvent], action_id: int, outcome: BattleOutcome) -> void:
	if status.finish(outcome, action_id):
		events.append(_battle_ended(action_id, outcome.winner, outcome.draw, outcome.reason))

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
