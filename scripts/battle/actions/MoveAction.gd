class_name MoveAction
extends BattleAction

var from: Vector2i:
	get:
		return _from
var to: Vector2i:
	get:
		return _to
var promotion_id: String:
	get:
		return _promotion_id

var _from: Vector2i = Vector2i(-1, -1)
var _to: Vector2i = Vector2i(-1, -1)
var _promotion_id: String = "queen"

func _init(
	p_from: Vector2i = Vector2i(-1, -1),
	p_to: Vector2i = Vector2i(-1, -1),
	p_actor_color: int = GameRules.PieceColor.WHITE,
	p_promotion_id: String = "queen"
) -> void:
	super(BattleAction.ActionType.MOVE, p_actor_color)
	_from = p_from
	_to = p_to
	_promotion_id = p_promotion_id
