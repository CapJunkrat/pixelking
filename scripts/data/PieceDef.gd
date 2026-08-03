class_name PieceDef
extends Resource

## Immutable definition shared by every runtime instance of this piece type.
@export var id: String = ""
@export var display_name_key: StringName

## Ordinary movement may inherit from another profile. Special move rules stay
## directly on the piece definition so inheriting king movement does not grant castling.
@export var movement_profile: MovementProfile
@export var special_move_rules: Array[MovementRule] = []

## Royal is a content/category tag. Only is_king participates in check,
## checkmate, king-position tracking, and the loss condition.
@export var is_royal: bool = false
@export var is_king: bool = false
@export var is_pawn: bool = false
@export var base_value: int = 0

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
