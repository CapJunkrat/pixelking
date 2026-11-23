class_name QuickTipReaction
extends StrikeReaction

## A lighter blunt attacker topples a medium piece quickly.

func split_time() -> float:
	return 0.03

func on_split() -> void:
	s.make_tip_body({}, 6.0, 30.0, 26.0, 0.35, false)
