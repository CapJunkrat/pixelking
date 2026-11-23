class_name RarityOdds
extends RefCounted

## How likely each rarity is when a piece is offered (battle rewards, shops, events).
## A rarity is rolled first, then a piece of that rarity, so a long list of commons
## cannot drown out the few rare pieces. The odds move towards rarer pieces as the Run
## goes deeper, and elite rewards roll as if further along.

const COMMON := 0
const RARE := 1
const EPIC := 2
const LEGENDARY := 3
## Percent per rarity [common, rare, epic, legendary] at the start and at the end of the map.
const EARLY: Array[int] = [30, 40, 22, 8]
const LATE: Array[int] = [10, 35, 35, 20]
const ELITE_BONUS := 0.35
## Legendary pieces that may be offered directly (they can also be fused).
const LEGENDARY_OFFERS: Array[String] = ["archmage", "stone_giant"]
## A shop asks more for rarer pieces.
const SHOP_PRICE_MULTIPLIER: Array[float] = [1.0, 1.3, 1.7, 2.2]

## Percent chance of each rarity at `progress` (0 = first layer, 1 = last).
static func weights(progress: float) -> Array[int]:
	var result: Array[int] = []
	var t: float = clampf(progress, 0.0, 1.0)
	for index: int in range(EARLY.size()):
		result.append(roundi(lerpf(float(EARLY[index]), float(LATE[index]), t)))
	return result

## Rolls a rarity, then a piece of it from `ids` (plus the offerable legendaries).
## A rarity with no piece in the list passes its roll down to the next rarer one, then up.
static func pick(ids: Array, rng: RunRngService, stream: StringName, progress: float) -> String:
	var by_tier: Array = [[], [], [], []]
	for value: Variant in ids + LEGENDARY_OFFERS:
		var id: String = str(value)
		var definition: PieceDef = Content.piece(id)
		if definition == null or definition.is_king or definition.rarity > PieceDef.Rarity.LEGENDARY:
			continue
		if id not in by_tier[definition.rarity]:
			(by_tier[definition.rarity] as Array).append(id)
	var odds: Array[int] = weights(progress)
	var roll: int = rng.randi_range(stream, 1, 100)
	var tier: int = 0
	var cursor: int = 0
	for index: int in range(odds.size()):
		cursor += odds[index]
		if roll <= cursor:
			tier = index
			break
		tier = index
	for step: int in [0, 1, 2, 3, -1, -2, -3]:
		var candidate: int = tier + step
		if candidate >= 0 and candidate < by_tier.size() and not (by_tier[candidate] as Array).is_empty():
			var bucket: Array = by_tier[candidate]
			return str(bucket[rng.pick_index(stream, bucket.size())])
	return "pawn"

## How far through the whole Run (all three acts) the player is, from 0 to 1.
static func run_progress(run_state: RunState) -> float:
	if run_state == null:
		return 0.0
	return clampf(run_state.run_stage(), 0.0, 1.0)

static func rarity_of(id: String) -> int:
	var definition: PieceDef = Content.piece(id)
	return clampi(definition.rarity, 0, LEGENDARY) if definition != null else COMMON
