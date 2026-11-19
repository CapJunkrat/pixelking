class_name RangedAttackRule
extends MovementRule

## A shot from a distance: the shooter stays on its square. Shared rules of every
## ranged piece (Bowman, Catapult, Ranger, Falconer, Sky Archer, Blast Catapult):
## - only targets at least `min_distance` squares away;
## - an enemy standing next to the shooter (diagonals too) stops it from shooting;
## - a King with one of its own pieces next to it cannot be targeted (bodyguard);
## - pieces that are immune to ranged attacks (Gargoyle) cannot be targeted;
## - rocks stop every shot (unless `over_rocks`); heavy shots (`breaks_rocks`) can
##   target a rock and break it.

const ACTION := &"ranged"

@export var directions: Array[Vector2i] = []
@export var min_distance: int = 2
@export var max_distance: int = 8
## Lobbed shots fly over pieces in the way (rocks still stop them).
@export var over_pieces: bool = false
## Heavy shots can target a rock in their path and break it.
@export var breaks_rocks: bool = false
## Boomerang: one throw along a line hits every enemy on it up to `max_distance`,
## passing over every piece, turning back at the first rock.
@export var pierce: bool = false
## Arcing shots that also fly over rocks (Sky Archer).
@export var over_rocks: bool = false
## A beam that may also hit the squares next to the shooter (Archmage). Such a
## shooter keeps firing with an enemy beside it.
@export var hits_adjacent: bool = false

func rule_id() -> StringName:
	return &"ranged_attack"

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	return _collect(board, pos, piece, false)

func get_attack_squares(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	return _collect(board, pos, piece, true)

func action_kind(board: BoardState, from: Vector2i, to: Vector2i, piece: ChessPiece) -> StringName:
	return ACTION if to in get_moves(board, from, piece) else &""

## Whether an enemy stands next to `pos` (then a ranged piece cannot shoot).
static func is_engaged(board: BoardState, pos: Vector2i, color: int) -> bool:
	for offset: Vector2i in BoardState.NEIGHBORS:
		var neighbour: ChessPiece = board.get_piece(pos + offset)
		if neighbour != null and neighbour.color != color:
			return true
	return false

## Whether a ranged shot may hit `occupant` standing on `square`.
static func can_target(board: BoardState, square: Vector2i, occupant: ChessPiece) -> bool:
	if occupant == null:
		return false
	if occupant.def.immune_to_ranged:
		return false
	if occupant.def.is_king and board.is_king_guarded(square):
		return false
	return true

func _collect(board: BoardState, pos: Vector2i, piece: ChessPiece, attacks_only: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not hits_adjacent and is_engaged(board, pos, piece.color):
		return result
	var minimum: int = _minimum()
	for direction: Vector2i in directions:
		for distance: int in range(1, max_distance + 1):
			var target: Vector2i = pos + direction * distance
			if not board.on_board(target):
				break
			if board.is_rock(target):
				if breaks_rocks and not attacks_only and distance >= minimum:
					result.append(target)
				if over_rocks:
					continue
				break
			var occupant: ChessPiece = board.get_piece(target)
			if distance >= minimum:
				if occupant == null:
					if attacks_only:
						result.append(target)
				elif occupant.color == piece.color:
					if attacks_only:
						result.append(target)
				elif can_target(board, target, occupant) and target not in result:
					result.append(target)
			if occupant != null and not (over_pieces or pierce):
				break
	return result

## Squares hit when shooting at `to`: just `to`, or for a boomerang every enemy it
## can hit along that line.
func victims(board: BoardState, from: Vector2i, to: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not pierce:
		result.append(to)
		return result
	var delta: Vector2i = to - from
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	if steps == 0:
		return result
	var direction: Vector2i = delta / steps
	for distance: int in range(1, max_distance + 1):
		var square: Vector2i = from + direction * distance
		if not board.on_board(square) or board.is_rock(square):
			break
		var occupant: ChessPiece = board.get_piece(square)
		if distance >= _minimum() and occupant != null and occupant.color != piece.color and can_target(board, square, occupant):
			result.append(square)
	return result

func _minimum() -> int:
	return maxi(1, min_distance) if hits_adjacent else maxi(2, min_distance)
