class_name BattleCommandResult
extends RefCounted

var success: bool = false
var error: StringName = &""
var legacy_result: Dictionary = {}
var events: Array[BattleEvent] = []

static func rejected(error_code: StringName) -> BattleCommandResult:
	var result: BattleCommandResult = BattleCommandResult.new()
	result.error = error_code
	return result
