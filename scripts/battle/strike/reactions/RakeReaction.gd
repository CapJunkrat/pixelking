class_name RakeReaction
extends StrikeReaction

## Too heavy to lift: the gryphon's talons rake it in two.

func split_time() -> float:
	return 0.1

func on_split() -> void:
	s.slash_age = 0.0
	s.split_along_slash(true)
