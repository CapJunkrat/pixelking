class_name UnderdogReaction
extends StrikeReaction

## A light blunt attacker needs two hits to topple a heavy piece.

func split_time() -> float:
	return 0.04

func on_split() -> void:
	s.make_tip_body({"brick_mode": 1.0} if s.brick_out else {}, 1.3, 13.0, 0.0, 1.15, true)
