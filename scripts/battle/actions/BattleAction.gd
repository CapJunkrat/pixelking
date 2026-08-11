class_name BattleAction
extends RefCounted

enum ActionType {
	MOVE,
	USE_ITEM,
}

var action_type: ActionType:
	get:
		return _action_type
var actor_color: int:
	get:
		return _actor_color

var _action_type: ActionType = ActionType.MOVE
var _actor_color: int = GameRules.PieceColor.WHITE

func _init(p_action_type: ActionType = ActionType.MOVE, p_actor_color: int = GameRules.PieceColor.WHITE) -> void:
	_action_type = p_action_type
	_actor_color = p_actor_color
