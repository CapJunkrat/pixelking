class_name EndTurnAction
extends BattleAction

## Ends the turn without using the bonus action a piece earned (assassin, courier).
func _init(p_actor_color: int = GameRules.PieceColor.WHITE) -> void:
	super(BattleAction.ActionType.END_TURN, p_actor_color)
