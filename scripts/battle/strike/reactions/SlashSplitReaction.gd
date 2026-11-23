class_name SlashSplitReaction
extends StrikeReaction

## A slash cuts a medium piece in two along the blade.

func split_time() -> float:
	return 0.1

func on_split() -> void:
	s.split_along_slash(s.reaction == &"slash_split_heavy")
