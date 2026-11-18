class_name EncounterGenerator
extends RefCounted

## Builds the enemy army for normal and elite battles from a strength budget that
## grows with the map layer, instead of one fixed full army. Early battles field a few
## basic pieces; later ones bring special and rare pieces. The enemy King always has
## pieces in front of it. The same seed always gives the same army. Everything stands in
## the enemy's corner (DeploymentState.is_enemy_zone): the top three ranks, right columns.

const BOARD_SIZE := 8
const KING_FILES: Array[int] = [5]
const BACK_RANK := 7
const FRONT_RANK := 6
const THIRD_RANK := 5
## Strength (sum of piece values, King excluded) at the first and last battle layer.
const NORMAL_BUDGET := Vector2(7.0, 20.0)
const ELITE_BUDGET := Vector2(14.0, 26.0)
## Early battles never field more than this multiple of the player's own strength.
const EARLY_CAP_MULTIPLIER := 1.0
const EARLY_LAYERS := 2
const MAX_PIECES := 12

## Pieces unlock by how far into the map the battle is (0 = first layer, 1 = last).
const POOLS := [
	{"from": 0.0, "ids": ["pawn", "knight", "bishop", "rook", "vanguard", "sentry", "powder_keg"]},
	{"from": 0.3, "ids": ["assassin", "bowman", "catapult", "royal_guard", "martyr", "lantern_bearer", "squire", "tide_knight", "antelope", "echo", "ranger", "sun_moon_monk"]},
	{"from": 0.6, "ids": ["queen", "falconer", "unicorn_cavalry", "centaur", "gryphon", "manticore", "gorgon", "portal_mage", "gargoyle", "chameleon", "crystal_mage", "ember_bird"]},
]
## An elite battle is led by one of these, whatever the layer.
const ELITE_CAPTAINS: Array[String] = ["gorgon", "manticore", "gryphon", "centaur", "unicorn_cavalry", "portal_mage", "gargoyle"]

## How far through the battle layers `layer` is, from 0 to 1 (the Boss layer excluded).
static func progress(layer: int, total_layers: int) -> float:
	return clampf(float(layer) / float(maxi(1, total_layers - 2)), 0.0, 1.0)

static func budget(tier: StringName, layer: int, total_layers: int, player_strength: int) -> int:
	var curve: Vector2 = ELITE_BUDGET if tier == &"elite" else NORMAL_BUDGET
	var value: float = lerpf(curve.x, curve.y, progress(layer, total_layers))
	if layer < EARLY_LAYERS and player_strength > 0:
		value = minf(value, maxf(6.0, player_strength * EARLY_CAP_MULTIPLIER))
	return roundi(value)

## Placements in EncounterDef format: [{"placement_id", "piece_def_id", "position"}].
static func generate(tier: StringName, layer: int, total_layers: int, seed_value: int, player_strength: int) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var remaining: int = budget(tier, layer, total_layers, player_strength)
	var stage: float = progress(layer, total_layers)
	var pool: Array[String] = []
	for band: Dictionary in POOLS:
		if stage >= float(band["from"]):
			for id: String in band["ids"]:
				pool.append(id)
	var king_file: int = KING_FILES[rng.randi_range(0, KING_FILES.size() - 1)]
	var army: Array[String] = []
	if tier == &"elite":
		var captain: String = ELITE_CAPTAINS[rng.randi_range(0, ELITE_CAPTAINS.size() - 1)]
		army.append(captain)
		remaining -= _value(captain)
	# The King's guard: pawns directly in front of it, more as the army grows.
	var guards: int = 1 if remaining < 10 else (2 if remaining < 18 else 3)
	for _i: int in range(guards):
		if remaining >= 1:
			army.append("pawn")
			remaining -= 1
	while remaining > 0 and army.size() < MAX_PIECES:
		var affordable: Array[String] = []
		for id: String in pool:
			if _value(id) <= remaining:
				affordable.append(id)
		if affordable.is_empty():
			break
		var pick: String = affordable[rng.randi_range(0, affordable.size() - 1)]
		army.append(pick)
		remaining -= _value(pick)
	return _place(army, king_file, guards)

static func _place(army: Array[String], king_file: int, guards: int) -> Array[Dictionary]:
	var taken: Dictionary = {Vector2i(king_file, BACK_RANK): true}
	var result: Array[Dictionary] = [_placement("king", Vector2i(king_file, BACK_RANK), 0)]
	var guard_squares: Array[Vector2i] = [Vector2i(king_file, FRONT_RANK), Vector2i(king_file - 1, FRONT_RANK), Vector2i(king_file + 1, FRONT_RANK)]
	var middle_out: Array[int] = [king_file, king_file - 1, king_file + 1, king_file - 2, king_file + 2, king_file - 3, king_file + 3, king_file - 4, king_file + 4]
	var corners: Array[int] = [7, BOARD_SIZE - DeploymentState.zone_columns(BOARD_SIZE)]
	var guard_index: int = 0
	for index: int in range(army.size()):
		var id: String = army[index]
		var square: Vector2i = Vector2i(-1, -1)
		if id == "pawn" and guard_index < guards:
			square = guard_squares[guard_index]
			guard_index += 1
		elif DeploymentFormation.moves_forward_only(PieceDefDatabase.get_def(id)):
			square = _free(taken, middle_out, FRONT_RANK)
		elif PieceDefDatabase.get_def(id).weight_class == PieceDef.WeightClass.HEAVY:
			square = _free(taken, corners, BACK_RANK)
		else:
			square = _free(taken, middle_out, BACK_RANK)
		if square.x < 0:
			square = _free(taken, middle_out, FRONT_RANK)
		if square.x < 0:
			square = _free(taken, middle_out, THIRD_RANK)
		if square.x < 0:
			continue
		taken[square] = true
		result.append(_placement(id, square, index + 1))
	return result

static func _free(taken: Dictionary, files: Array[int], rank: int) -> Vector2i:
	for x: int in files:
		var square: Vector2i = Vector2i(x, rank)
		if DeploymentState.is_enemy_zone(square, BOARD_SIZE) and not taken.has(square):
			return square
	return Vector2i(-1, -1)

static func _placement(id: String, square: Vector2i, index: int) -> Dictionary:
	return {"placement_id": "gen_%d" % index, "piece_def_id": id, "position": {"x": square.x, "y": square.y}}

static func _value(id: String) -> int:
	var definition: PieceDef = PieceDefDatabase.get_def(id)
	return definition.base_value if definition != null else 99

## The player's strength: the value of every active piece besides the King.
static func player_strength(run_state: RunState) -> int:
	var total: int = 0
	for instance_id: int in run_state.active_piece_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		if piece != null and not piece.is_king:
			total += PieceDefDatabase.get_def(String(piece.piece_def_id)).base_value
	return total
