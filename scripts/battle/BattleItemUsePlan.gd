class_name BattleItemUsePlan
extends RefCounted

var expected_item_id: StringName:
	get:
		return _expected_item_id
var slot_index: int:
	get:
		return _slot_index
var staged_board: BoardState:
	get:
		return _staged_board
var staged_items: Array[ChallengerItemDef]:
	get:
		return _staged_items
var staged_processor: BattleCommandProcessor:
	get:
		return _staged_processor
var result: BattleCommandResult:
	get:
		return _result

var _expected_item_id: StringName = &""
var _slot_index: int = -1
var _staged_board: BoardState = null
var _staged_items: Array[ChallengerItemDef] = []
var _staged_processor: BattleCommandProcessor = null
var _result: BattleCommandResult = null

func _init(
	p_expected_item_id: StringName = &"",
	p_slot_index: int = -1,
	p_staged_board: BoardState = null,
	p_staged_items: Array[ChallengerItemDef] = [],
	p_staged_processor: BattleCommandProcessor = null,
	p_result: BattleCommandResult = null
) -> void:
	_expected_item_id = p_expected_item_id
	_slot_index = p_slot_index
	_staged_board = p_staged_board
	_staged_items = p_staged_items
	_staged_processor = p_staged_processor
	_result = p_result

func is_valid() -> bool:
	return (
		not _expected_item_id.is_empty()
		and _slot_index >= 0
		and _staged_board != null
		and _staged_processor != null
		and _result != null
		and _result.success
		and _staged_processor.board == _staged_board
		and _staged_processor.challenger_items == _staged_items
	)
