class_name BattleStatus
extends RefCounted

enum State { ACTIVE, FINISHED }

var state: State = State.ACTIVE
var winner: int = -1
var draw: bool = false
var reason: StringName = &""
var finished_action_id: int = 0

func is_finished() -> bool:
	return state == State.FINISHED

func finish(outcome: BattleOutcome, action_id: int) -> bool:
	if is_finished() or outcome == null or not outcome.finished:
		return false
	state = State.FINISHED
	winner = outcome.winner
	draw = outcome.draw
	reason = outcome.reason
	finished_action_id = action_id
	return true

func clone_runtime() -> BattleStatus:
	var copy: BattleStatus = BattleStatus.new()
	copy.state = state
	copy.winner = winner
	copy.draw = draw
	copy.reason = reason
	copy.finished_action_id = finished_action_id
	return copy
