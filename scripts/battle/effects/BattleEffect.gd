class_name BattleEffect
extends RefCounted

var effect_id: StringName:
	get:
		return _effect_id
var effect_type: StringName:
	get:
		return _effect_type
var owner_color: int:
	get:
		return _owner_color
var priority: int:
	get:
		return _priority
var board_position: Vector2i:
	get:
		return _board_position
var source_instance_id: int:
	get:
		return _source_instance_id
var payload: Dictionary:
	get:
		return _payload.duplicate(true)
var enqueue_order: int:
	get:
		return _enqueue_order

var _effect_id: StringName = &""
var _effect_type: StringName = &"noop"
var _owner_color: int = GameRules.PieceColor.WHITE
var _priority: int = 0
var _board_position: Vector2i = Vector2i(-1, -1)
var _source_instance_id: int = 0
var _payload: Dictionary = {}
var _enqueue_order: int = 0

func _init(
	p_effect_id: StringName = &"",
	p_effect_type: StringName = &"noop",
	p_owner_color: int = GameRules.PieceColor.WHITE,
	p_priority: int = 0,
	p_board_position: Vector2i = Vector2i(-1, -1),
	p_source_instance_id: int = 0,
	p_payload: Dictionary = {}
) -> void:
	_effect_id = p_effect_id
	_effect_type = p_effect_type
	_owner_color = p_owner_color
	_priority = p_priority
	_board_position = p_board_position
	_source_instance_id = p_source_instance_id
	_payload = p_payload.duplicate(true)

func assign_enqueue_order(value: int) -> void:
	if _enqueue_order == 0:
		_enqueue_order = value

func clone_runtime() -> BattleEffect:
	var copy: BattleEffect = BattleEffect.new(
		_effect_id,
		_effect_type,
		_owner_color,
		_priority,
		_board_position,
		_source_instance_id,
		_payload
	)
	copy.assign_enqueue_order(_enqueue_order)
	return copy

func repetition_key() -> String:
	return "%s:%d" % [String(_effect_id), _source_instance_id]
