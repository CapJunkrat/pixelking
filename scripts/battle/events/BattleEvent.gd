class_name BattleEvent
extends RefCounted

# The event payload becomes immutable to consumers because every read returns a deep copy.
var event_type: StringName:
	get:
		return _event_type
var sequence: int:
	get:
		return _sequence
var action_id: int:
	get:
		return _action_id
var payload: Dictionary:
	get:
		return _payload.duplicate(true)

var _event_type: StringName = &""
var _sequence: int = 0
var _action_id: int = 0
var _payload: Dictionary = {}

func _init(
	p_event_type: StringName = &"",
	p_sequence: int = 0,
	p_action_id: int = 0,
	p_payload: Dictionary = {}
) -> void:
	_event_type = p_event_type
	_sequence = p_sequence
	_action_id = p_action_id
	_payload = p_payload.duplicate(true)

func to_dictionary() -> Dictionary:
	return {
		"type": String(_event_type),
		"sequence": _sequence,
		"action_id": _action_id,
		"payload": _payload.duplicate(true),
	}
