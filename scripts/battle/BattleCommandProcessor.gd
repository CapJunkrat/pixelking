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

func evaluate_terminal_state() -> BattleCommandResult:
	if status.is_finished():
		return null
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
			"was_king": captured_piece.def.is_king,
		}))
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
	var bonus_candidate: bool = (
		moving_piece != null
		and moving_piece.def.extra_move_on_capture
		and bool(move_result.get("captured", false))
	)
	if bonus_candidate:
		# Terminal rules are evaluated while the captured side owns the response turn.
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
			result.legacy_result["extra_move_granted"] = true
			result.events.append(_event(EVENT_EXTRA_MOVE_GRANTED, action_id, {
				"color": action.actor_color,
				"instance_id": moving_piece.instance_id,
			}))
			result.events.append(_event(EVENT_TURN_CHANGED, action_id, {"turn": board.turn}))
	else:
		result.events.append(_event(EVENT_TURN_CHANGED, action_id, {"turn": board.turn}))
		_append_terminal_events(result.events, action_id)
	return result

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
