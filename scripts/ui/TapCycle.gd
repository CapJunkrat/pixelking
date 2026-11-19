class_name TapCycle
extends RefCounted

## Repeated taps on one spot step through the pieces stacked under it. The first tap
## picks the first candidate (the piece on the tapped board square); each further tap
## at about the same point picks the next one, wrapping round.

const NO_SQUARE := Vector2i(-1, -1)

## Whether the last pick() stepped on to another piece instead of starting fresh.
var cycled: bool = false
var _point: Vector2 = Vector2(INF, INF)
var _last: Vector2i = NO_SQUARE

## Picks among `candidates` for a tap at `point`; `radius` is how close a tap must be
## to the previous one to count as tapping the same spot again.
func pick(point: Vector2, candidates: Array[Vector2i], radius: float) -> Vector2i:
	cycled = false
	if candidates.is_empty():
		reset()
		return NO_SQUARE
	var choice: Vector2i = candidates[0]
	if candidates.size() > 1 and _last in candidates and point.distance_to(_point) <= radius:
		choice = candidates[(candidates.find(_last) + 1) % candidates.size()]
		cycled = true
	_point = point
	_last = choice
	return choice

func reset() -> void:
	cycled = false
	_point = Vector2(INF, INF)
	_last = NO_SQUARE
