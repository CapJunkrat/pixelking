class_name TossReaction
extends EruptReaction

## Thrown up and back over the attacker's shoulder.

func split_time() -> float:
	return 0.03

## Nothing is drawn around a tossed piece (an erupting one gets its rock spikes).
func draw_air(_canvas: CanvasItem) -> void:
	pass
