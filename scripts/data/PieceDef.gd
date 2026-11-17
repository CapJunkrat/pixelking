class_name PieceDef
extends Resource

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

## How this piece's attack lands. Presentation-only: it selects the victim's hit reaction.
## NONE means the piece has no bespoke strike animation and uses the simple move tween.
enum StrikeType {
	NONE,
	SLASH,
	BLUNT,
	PIERCE,
	CRUSH,
	## Special pieces with their own victim reactions (see StrikeDirector.reaction_for).
	VOID,
	GRAB,
	VENOM,
	ARCANE,
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
@export var base_value: int = 0
@export var rarity: Rarity = Rarity.COMMON
@export var available_in_opening_draft: bool = false
@export_range(0, 100, 1) var opening_draft_weight: int = 0

func is_rare_or_higher() -> bool:
	return rarity >= Rarity.RARE

func is_valid_opening_draft_piece() -> bool:
	return (
		available_in_opening_draft
		and opening_draft_weight > 0
		and not is_king
		and rarity in [Rarity.COMMON, Rarity.RARE]
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
