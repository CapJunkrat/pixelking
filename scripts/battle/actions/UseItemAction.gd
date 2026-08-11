class_name UseItemAction
extends BattleAction

var slot_index: int:
	get:
		return _slot_index
var target_position: Vector2i:
	get:
		return _target_position

var _slot_index: int = -1
var _target_position: Vector2i = Vector2i(-1, -1)

func _init(
	p_slot_index: int = -1,
	p_actor_color: int = GameRules.PieceColor.WHITE,
	p_target_position: Vector2i = Vector2i(-1, -1)
) -> void:
	super(BattleAction.ActionType.USE_ITEM, p_actor_color)
	_slot_index = p_slot_index
	_target_position = p_target_position
