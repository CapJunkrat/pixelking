class_name MoveOutcome
extends RefCounted

## What one action did to the board (BoardState.apply_move / simulate_move).
##
## Only what the action itself changed is recorded here. Whose turn it is next, check,
## checkmate and the other ways a battle ends are decided afterwards by
## BattleCommandProcessor, which alone hands the turn over.
##
## The entries of `removed`, `shells` and `eggs_laid` become BattleEvent payloads as
## they are, so they stay Dictionaries instead of getting their own classes.

const NO_SQUARE := Vector2i(-1, -1)

var success: bool = false
## Why the action was refused (&"no_piece", &"wrong_turn", &"illegal_move",
## &"invalid_promotion"); empty on success.
var error: StringName = &""
## The movement rule's ability id (&"ranged", a shadow step...), empty for a plain move.
var action_kind: StringName = &""
## The acting piece's definition before the action (it may change form during it).
var moved_def_id: String = ""
## Where the acting piece ends up: a shooter, or an attacker bounced off a shell,
## stays on its own square.
var landing: Vector2i = NO_SQUARE
var captured: bool = false
var king_captured: bool = false
## The color of the King that was taken, or -1.
var captured_color: int = -1
var en_passant_capture: bool = false
var castled: bool = false
var promoted: bool = false
var ranged: bool = false
var swapped_with_king: bool = false
## A rock the action shattered, or NO_SQUARE.
var rock_broken: Vector2i = NO_SQUARE
var evolved_into: String = ""
var learned: String = ""
var form_changed: String = ""
## Every piece that left the board: {position, piece_def_id, instance_id, color, cause, was_king}.
var removed: Array[Dictionary] = []
## Blows a shell or a hard egg absorbed: {position, instance_id, left[, egg_delayed, turns_left]}.
var shells: Array[Dictionary] = []
## Squares of the allies a fallen Martyr shielded.
var shielded: Array[Vector2i] = []
## Eggs laid by fallen reviving pieces: {position, piece_def_id, instance_id, victim_instance_id, color, turns_left}.
var eggs_laid: Array[Dictionary] = []

static func refused(reason: StringName) -> MoveOutcome:
	var outcome: MoveOutcome = MoveOutcome.new()
	outcome.error = reason
	return outcome

## Whether the piece with `instance_id` left the board.
func removed_instance(instance_id: int) -> bool:
	return _lists_instance(removed, instance_id)

## Whether a shell of the piece with `instance_id` took a blow.
func shelled_instance(instance_id: int) -> bool:
	return _lists_instance(shells, instance_id)

static func _lists_instance(entries: Array[Dictionary], instance_id: int) -> bool:
	for entry: Dictionary in entries:
		if int(entry.get("instance_id", 0)) == instance_id:
			return true
	return false
