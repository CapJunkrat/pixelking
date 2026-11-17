class_name BattleOutcome
extends RefCounted

var finished: bool:
	get:
		return _finished
var winner: int:
	get:
		return _winner
var draw: bool:
	get:
		return _draw
var reason: StringName:
	get:
		return _reason

var _finished: bool = false
var _winner: int = -1
var _draw: bool = false
var _reason: StringName = &""

func _init(p_finished: bool = false, p_winner: int = -1, p_draw: bool = false, p_reason: StringName = &"") -> void:
	_finished = p_finished
	_winner = p_winner
	_draw = p_draw
	_reason = p_reason

static func active() -> BattleOutcome:
	return BattleOutcome.new()

static func completed(p_winner: int, p_draw: bool, p_reason: StringName) -> BattleOutcome:
	return BattleOutcome.new(true, p_winner, p_draw, p_reason)
