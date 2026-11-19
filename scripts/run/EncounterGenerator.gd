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
## Strength (sum of piece values, King excluded) at the start of Act 1 and the end of
## Act 3. Acts past that add LATE_ACT_STEP per act.
const NORMAL_BUDGET := Vector2(7.0, 24.0)
const ELITE_BUDGET := Vector2(14.0, 30.0)
const LATE_ACT_STEP := 5.0
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
## Legendary pieces that join enemy armies from Act 3 on.
const LEGENDARY_ENEMIES: Array[String] = ["archmage", "stone_giant"]
## Percent per rarity [common, rare, epic, legendary] of each enemy pick, by act
## (Act 1, 2, 3; later acts use the last row). Later acts field rarer pieces rather
## than more pawns.
const ACT_RARITY_ODDS: Array = [
	[60, 30, 10, 0],
	[25, 45, 25, 5],
	[10, 35, 40, 15],
	[5, 25, 45, 25],
]
## From Act 2 on, pawns only guard the King, and only one of them.
const PAWN_FREE_FROM_ACT := 1
## An elite battle is led by one of these, whatever the layer.
const ELITE_CAPTAINS: Array[String] = ["gorgon", "manticore", "gryphon", "centaur", "unicorn_cavalry", "portal_mage", "gargoyle"]

## How far through the battle layers `layer` is, from 0 to 1 (the Boss layer excluded).
static func progress(layer: int, total_layers: int) -> float:
	return clampf(float(layer) / float(maxi(1, total_layers - 2)), 0.0, 1.0)

static func budget(tier: StringName, layer: int, total_layers: int, player_strength: int) -> int:
	return budget_at(tier, progress(layer, total_layers), layer < EARLY_LAYERS, player_strength)

## The budget `stage` of the way through the run (RunState.run_stage: 0 to 1 over the
## three acts, more after that). `early` caps it by the player's own strength.
static func budget_at(tier: StringName, stage: float, early: bool, player_strength: int) -> int:
	var curve: Vector2 = ELITE_BUDGET if tier == &"elite" else NORMAL_BUDGET
	var value: float = lerpf(curve.x, curve.y, clampf(stage, 0.0, 1.0))
	if stage > 1.0:
		value += (stage - 1.0) * float(RunState.ACT_COUNT) * LATE_ACT_STEP
	if early and player_strength > 0:
		value = minf(value, maxf(6.0, player_strength * EARLY_CAP_MULTIPLIER))
	return roundi(value)

## Placements in EncounterDef format: [{"placement_id", "piece_def_id", "position"}].
static func generate(tier: StringName, layer: int, total_layers: int, seed_value: int, player_strength: int) -> Array[Dictionary]:
	return generate_at(tier, progress(layer, total_layers), layer < EARLY_LAYERS, seed_value, player_strength)

## The act (0 = Act 1) a run stage falls in, for callers that do not pass one.
static func act_of_stage(stage: float) -> int:
	return maxi(0, floori(stage * float(RunState.ACT_COUNT) - 0.0001))

static func generate_at(tier: StringName, stage: float, early: bool, seed_value: int, player_strength: int, act: int = -1) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	if act < 0:
		act = act_of_stage(stage)
	var remaining: int = budget_at(tier, stage, early, player_strength)
	var pool: Array[String] = []
	for band: Dictionary in POOLS:
		if stage >= float(band["from"]):
			for id: String in band["ids"]:
				pool.append(id)
	if act >= 2:
		pool.append_array(LEGENDARY_ENEMIES)
	if act >= PAWN_FREE_FROM_ACT:
		pool.erase("pawn")
	var king_file: int = KING_FILES[rng.randi_range(0, KING_FILES.size() - 1)]
	var army: Array[String] = []
	if tier == &"elite":
		var captain: String = ELITE_CAPTAINS[rng.randi_range(0, ELITE_CAPTAINS.size() - 1)]
		army.append(captain)
		remaining -= _value(captain)
	# The King's guard: pawns directly in front of it, more as the army grows.
	var guards: int = 1 if remaining < 10 else (2 if remaining < 18 else 3)
	if act >= PAWN_FREE_FROM_ACT:
		guards = 1
	for _i: int in range(guards):
		if remaining >= 1:
			army.append("pawn")
			remaining -= 1
	while remaining > 0 and army.size() < MAX_PIECES:
		var pick: String = _pick_by_rarity(pool, act, remaining, rng)
		if pick.is_empty():
			break
		army.append(pick)
		remaining -= _value(pick)
	return _place(army, king_file, guards)

static func rarity_odds(act: int) -> Array:
	return ACT_RARITY_ODDS[clampi(act, 0, ACT_RARITY_ODDS.size() - 1)]

## Rolls a rarity by the act's odds, then an affordable piece of it from `pool`
## (`budget` < 0: any price). A rarity with nothing affordable passes the roll to the
## next cheaper one, then the next rarer one. Empty when nothing fits at all.
static func _pick_by_rarity(pool: Array[String], act: int, budget: int, rng: RandomNumberGenerator) -> String:
	var by_tier: Array = [[], [], [], []]
	for id: String in pool:
		if budget >= 0 and _value(id) > budget:
			continue
		var definition: PieceDef = PieceDefDatabase.get_def(id)
		if definition == null:
			continue
		var tier_index: int = clampi(definition.rarity, 0, 3)
		if id not in by_tier[tier_index]:
			(by_tier[tier_index] as Array).append(id)
	var odds: Array = rarity_odds(act)
	var roll: int = rng.randi_range(1, 100)
	var tier: int = 0
	var cursor: int = 0
	for index: int in range(odds.size()):
		cursor += int(odds[index])
		tier = index
		if roll <= cursor:
			break
	for step: int in [0, -1, -2, -3, 1, 2, 3]:
		var candidate: int = tier + step
		if candidate >= 0 and candidate < by_tier.size() and not (by_tier[candidate] as Array).is_empty():
			var bucket: Array = by_tier[candidate]
			return str(bucket[rng.randi_range(0, bucket.size() - 1)])
	return ""

## Boss armies are fixed, but from Act 2 on all their pawns but the first are swapped
## for pieces rolled by the act's rarity odds, on the same squares.
static func upgrade_boss_pawns(placements: Array[Dictionary], act: int, seed_value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array[String] = []
	for band: Dictionary in POOLS:
		for id: String in band["ids"]:
			if id != "pawn":
				pool.append(id)
	if act >= 2:
		pool.append_array(LEGENDARY_ENEMIES)
	var pawns_kept: int = 0
	for placement: Dictionary in placements:
		var copy: Dictionary = placement.duplicate(true)
		if act >= PAWN_FREE_FROM_ACT and str(copy.get("piece_def_id", "")) == "pawn":
			if pawns_kept == 0:
				pawns_kept += 1
			else:
				var pick: String = _pick_by_rarity(pool, act, -1, rng)
				if not pick.is_empty():
					copy["piece_def_id"] = pick
		result.append(copy)
	return result

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

## Bosses past Act 3: add pieces worth about `extra` to a fixed Boss army, on free squares
## of the enemy corner (the most valuable first, while room lasts).
static func reinforce(placements: Array[Dictionary], extra: int, seed_value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var taken: Dictionary = {}
	for placement: Dictionary in placements:
		result.append(placement.duplicate(true))
		taken[DeploymentState.position_from_value(placement.get("position", {}))] = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array[String] = []
	for band: int in [1, 2]:
		for id: String in POOLS[band]["ids"]:
			pool.append(id)
	var remaining: int = extra
	var index: int = 0
	while remaining > 0:
		var affordable: Array[String] = []
		for id: String in pool:
			if _value(id) <= remaining:
				affordable.append(id)
		if affordable.is_empty():
			break
		var square: Vector2i = _free(taken, [3, 4, 5, 6, 7], THIRD_RANK)
		if square.x < 0:
			square = _free(taken, [3, 4, 5, 6, 7], FRONT_RANK)
		if square.x < 0:
			square = _free(taken, [3, 4, 5, 6, 7], BACK_RANK)
		if square.x < 0:
			break
		var pick: String = affordable[rng.randi_range(0, affordable.size() - 1)]
		taken[square] = true
		result.append({"placement_id": "late_%d" % index, "piece_def_id": pick, "position": {"x": square.x, "y": square.y}})
		remaining -= _value(pick)
		index += 1
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
