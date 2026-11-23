class_name BattleCommandResult
extends RefCounted

var success: bool = false
var error: StringName = &""
## What a move did to the board (also set on a refused move); null for other actions.
var move_outcome: MoveOutcome = null
var events: Array[BattleEvent] = []

static func rejected(error_code: StringName) -> BattleCommandResult:
	var result: BattleCommandResult = BattleCommandResult.new()
	result.error = error_code
	return result

func has_event(event_type: StringName) -> bool:
	for event: BattleEvent in events:
		if event.event_type == event_type:
			return true
	return false
