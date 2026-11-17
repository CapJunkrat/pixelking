class_name BattleEffectQueue
extends RefCounted

const MAX_EFFECTS_PER_SETTLEMENT := 256
const MAX_SAME_SOURCE_REPEATS := 32

var _pending: Array[BattleEffect] = []
var _next_enqueue_order: int = 1

func enqueue(effect: BattleEffect) -> bool:
	if effect == null:
		return false
	effect.assign_enqueue_order(_next_enqueue_order)
	_next_enqueue_order += 1
	_pending.append(effect)
	return true

func pending_count() -> int:
	return _pending.size()

func clear() -> void:
	_pending.clear()

func clone_runtime() -> BattleEffectQueue:
	var copy: BattleEffectQueue = BattleEffectQueue.new()
	copy._next_enqueue_order = _next_enqueue_order
	for effect: BattleEffect in _pending:
		copy._pending.append(effect.clone_runtime())
	return copy

func settle(current_side: int, apply_effect: Callable = Callable()) -> Dictionary:
	var applied: Array[BattleEffect] = []
	var repeats: Dictionary[String, int] = {}
	while not _pending.is_empty():
		if applied.size() >= MAX_EFFECTS_PER_SETTLEMENT:
			_pending.clear()
			return {"success": false, "error": "max_effects_exceeded", "applied": applied}
		_pending.sort_custom(func(left: BattleEffect, right: BattleEffect) -> bool: return _comes_before(left, right, current_side))
		var effect: BattleEffect = _pending.pop_front() as BattleEffect
		var key: String = effect.repetition_key()
		var repeat_count: int = int(repeats.get(key, 0)) + 1
		repeats[key] = repeat_count
		if repeat_count > MAX_SAME_SOURCE_REPEATS:
			_pending.clear()
			return {"success": false, "error": "source_repeat_exceeded", "applied": applied}
		applied.append(effect)
		if apply_effect.is_valid():
			var generated_value: Variant = apply_effect.call(effect)
			if generated_value is Array:
				for generated: Variant in generated_value:
					if generated is BattleEffect:
						enqueue(generated as BattleEffect)
	return {"success": true, "error": "", "applied": applied}

func _comes_before(left: BattleEffect, right: BattleEffect, current_side: int) -> bool:
	var left_side_rank: int = 0 if left.owner_color == current_side else 1
	var right_side_rank: int = 0 if right.owner_color == current_side else 1
	if left_side_rank != right_side_rank:
		return left_side_rank < right_side_rank
	if left.priority != right.priority:
		return left.priority < right.priority
	if left.board_position.y != right.board_position.y:
		return left.board_position.y < right.board_position.y
	if left.board_position.x != right.board_position.x:
		return left.board_position.x < right.board_position.x
	if left.source_instance_id != right.source_instance_id:
		return left.source_instance_id < right.source_instance_id
	return left.enqueue_order < right.enqueue_order
