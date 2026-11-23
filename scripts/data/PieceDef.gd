class_name PieceDef
extends Resource

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
	## Fusion only: never offered in shops, rewards or the opening draft.
	MYTHIC,
}

## How this piece's attack lands. Presentation-only: it selects the victim's hit reaction.
## NONE means the piece has no bespoke strike animation and uses the simple move tween.
enum StrikeType {
	NONE,
	SLASH,
	BLUNT,
	PIERCE,
	CRUSH,
	## Special pieces with their own victim reactions (see StrikeLibrary.reaction_for).
	VOID,
	GRAB,
	VENOM,
	ARCANE,
	## Hit types of the pieces from plan §27 (see StrikeLibrary.reaction_for).
	DEVOUR,
	HOLY,
	RESONANCE,
	BURN,
	ERUPT,
	TOSS,
	FLATTEN,
	BLAST,
	SKEWER,
	INFERNO,
	MIMIC,
}

## Visual mass. Presentation-only: together with the attacker's StrikeType it decides
## how a captured piece breaks, flies or topples.
enum WeightClass {
	LIGHT,
	MEDIUM,
	HEAVY,
}

## Immutable definition shared by every runtime instance of this piece type.
@export var id: String = ""
@export var display_name_key: StringName

## Ordinary movement may inherit from another profile. Special move rules stay
## directly on the piece definition so inheriting king movement does not grant castling.
@export var movement_profile: MovementProfile
## Presentation-only motion. It never participates in legal move generation.
@export var motion_profile: PieceMotionProfile
@export var special_move_rules: Array[MovementRule] = []
## Presentation-only strike data. Never read by move generation or battle resolution.
@export var strike_type: StrikeType = StrikeType.NONE
@export var weight_class: WeightClass = WeightClass.MEDIUM

## Royal is a content/category tag. Only is_king participates in check,
## checkmate, king-position tracking, and the loss condition.
@export var is_royal: bool = false
@export var is_king: bool = false
@export var is_pawn: bool = false
## Generic combat traits used by special pieces without hardcoded stable IDs.
@export var extra_move_on_capture: bool = false
@export var immobilizes_adjacent: bool = false
@export var immune_to_immobilization: bool = false
## Bonus action: after this piece acts it may act once more in the same turn
## (on capture only for extra_move_on_capture). A turn never holds more than two actions.
@export var extra_move_always: bool = false
## When captured, every non-King piece on the 3x3 around it is destroyed, either side.
@export var explodes_when_captured: bool = false
## When captured, adjacent allies cannot be captured during the opponent's next turn.
@export var shields_allies_when_captured: bool = false
## Adjacent allies cannot be immobilized.
@export var protects_adjacent_from_immobilization: bool = false
## Captures by ranged rules also destroy the non-King enemies around the target.
@export var splash_on_ranged_capture: bool = false
## Ranged shots (and their splash) cannot target this piece; only melee captures can.
@export var immune_to_ranged: bool = false
## Hits absorbed before this piece is really captured. Restored every battle.
@export var shell_hits: int = 0
## Revives this many of its owner's turns after being captured (0 = never).
@export var revive_after_turns: int = 0
## How many times per battle it may come back as an egg (-1 = every time).
@export var revive_limit: int = 1
## When captured (with a revive left) it leaves this egg piece on the owner's free
## square nearest its bottom-left corner; the egg hatches back into it.
@export var egg_def_id: String = ""
## An egg: it cannot move or fight and does not keep its side in the battle.
@export var is_egg: bool = false
## A hard egg is never broken: each blow only adds 2 turns to its hatching.
@export var egg_hardened: bool = false
## Learns the movement of the pieces it captures, keeping at most this many (0 = never).
@export var learn_capacity: int = 0
## Becomes `evolves_into` once its run-wide capture count reaches `evolve_at_captures`.
@export var evolve_at_captures: int = 0
@export var evolves_into: String = ""
## Swaps to this form after every move (and back again from that form).
@export var alternate_form_id: String = ""
## The form a run keeps between battles; empty means this definition itself.
@export var base_form_id: String = ""
## Turns into this piece on reaching the far rank (non-pawn promotion).
@export var promotes_to: String = ""
## Once per battle, when checkmated: the checking pieces are destroyed and play goes on.
@export var survives_checkmate_once: bool = false
## Texture used for this definition; empty means `id`. Lets forms share one picture.
@export var art_id: String = ""
@export var base_value: int = 0
@export var rarity: Rarity = Rarity.COMMON
@export var available_in_opening_draft: bool = false
@export_range(0, 100, 1) var opening_draft_weight: int = 0

func art_key() -> String:
	return art_id if not art_id.is_empty() else id

func run_form_id() -> String:
	return base_form_id if not base_form_id.is_empty() else id

func is_rare_or_higher() -> bool:
	return rarity >= Rarity.RARE

func is_valid_opening_draft_piece() -> bool:
	return (
		available_in_opening_draft
		and opening_draft_weight > 0
		and not is_king
		and rarity <= Rarity.LEGENDARY
	)

func resolved_movement_rules() -> Array[MovementRule]:
	var result: Array[MovementRule] = []
	if movement_profile != null:
		result.append_array(movement_profile.resolved_rules())
	for rule in special_move_rules:
		if rule != null and rule not in result:
			result.append(rule)
	return result

func movement_rule(rule: StringName) -> MovementRule:
	for candidate in resolved_movement_rules():
		if candidate.rule_id() == rule:
			return candidate
	return null

func has_movement_rule(rule: StringName) -> bool:
	return movement_rule(rule) != null

## Shoots from a distance (and so follows the shared ranged rules).
func is_ranged() -> bool:
	return has_movement_rule(&"ranged_attack")
