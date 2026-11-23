class_name SlotReplaceService
extends RefCounted

## Taking a relic or an item with every slot full: the player picks a relic or item
## to give up, or steps back. Used by the shop, battle rewards and events alike.
##
## The pending choice keeps its type ("shop", "battle_reward", "event"), so the screen
## keeps its header; the original choice rides along in "slot_return" (cancel goes
## back to it, nothing paid or rolled) and the option taken in "slot_source". Nothing is
## given up until the new relic or item is actually gained: RunContentService applies
## the pick together with the purchase, the reward or the event's outcome.

const PICK := "slot_replace_pick"
const CANCEL := "slot_replace_cancel"
const WAR_BANNER: StringName = &"war_banner"

## Whether taking `payload` (an option's payload) needs a slot the party lacks.
static func needs_room(run_state: RunState, payload: Dictionary) -> bool:
	return str(payload.get("kind", "")) in ["relic", "item"] and not run_state.has_challenger_room()

## Whether `slot_id` can be given up. The War Banner holds a place on the battle line:
## without it, a piece standing there moves to the reserve, so the reserve needs room.
static func can_give_up(run_state: RunState, slot_id: StringName) -> bool:
	if slot_id not in run_state.challenger_slots:
		return false
	if slot_id != WAR_BANNER:
		return true
	var over: int = _active_count(run_state) - RunState.MAX_ACTIVE_NON_KING_PIECES
	return over <= 0 or run_state.reserve_piece_ids.size() + over <= RunState.MAX_RESERVE_PIECES

## Shows every relic and item the party holds, plus a way back.
func stage(run_state: RunState, pending: Dictionary, choice_id: String, payload: Dictionary) -> void:
	var new_id: StringName = StringName(str(payload.get("relic_id", payload.get("item_id", ""))))
	var options: Array[Dictionary] = []
	for index: int in range(run_state.challenger_slots.size()):
		var slot_id: StringName = run_state.challenger_slots[index]
		var definition: ChallengerItemDef = ChallengerItemDatabase.get_def(slot_id)
		var allowed: bool = can_give_up(run_state, slot_id)
		var data: Dictionary = {"kind": PICK, "slot_id": String(slot_id)}
		if not allowed:
			data["detail_key"] = "SLOT_FULL_BANNER_BLOCKED"
		var option: Dictionary = RunChoiceBuilder.option("slot_drop_%d" % index, RunContentDatabase.item_label(slot_id), PICK, data, allowed)
		if definition != null:
			option["label_key"] = String(definition.display_name_key)
		options.append(option)
	var pending_type: String = str(pending.get("type", ""))
	var cancel: Dictionary = RunChoiceBuilder.option("slot_cancel", "Back", CANCEL, {})
	cancel["label_key"] = {"shop": "SHOP_FULL_CANCEL", "event": "SLOT_FULL_BACK_EVENT"}.get(pending_type, "SLOT_FULL_GIVE_UP")
	options.append(cancel)
	var staged: Dictionary = RunChoiceBuilder.pending(pending_type, "Your Slots Are Full", "", options, false)
	staged["title_key"] = "SLOT_FULL_TITLE"
	staged["description_key"] = "SLOT_FULL_DESC"
	staged["description_args"] = [RunContentDatabase.item_label(new_id)]
	for key: String in ["event_id", "gold_awarded"]:
		if pending.has(key):
			staged[key] = pending[key]
	staged["slot_return"] = pending.duplicate(true)
	staged["slot_source"] = {"choice_id": choice_id, "payload": payload.duplicate(true)}
	run_state.pending_choice = staged

## Gives up `slot_id` (the first one, when two are alike). Losing the War Banner sends
## the battle line's extra piece to the reserve.
static func give_up(run_state: RunState, slot_id: StringName) -> Error:
	if not can_give_up(run_state, slot_id):
		return ERR_UNAVAILABLE
	run_state.challenger_slots.erase(slot_id)
	while _active_count(run_state) > run_state.max_active_pieces():
		var moved: int = _last_active_non_king(run_state)
		if moved == 0:
			break
		run_state.active_piece_ids.erase(moved)
		run_state.reserve_piece_ids.append(moved)
	return OK

static func _active_count(run_state: RunState) -> int:
	var count: int = 0
	for instance_id: int in run_state.active_piece_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		if piece != null and not piece.is_king:
			count += 1
	return count

static func _last_active_non_king(run_state: RunState) -> int:
	for index: int in range(run_state.active_piece_ids.size() - 1, -1, -1):
		var piece: PieceInstanceState = run_state.get_piece_state(run_state.active_piece_ids[index])
		if piece != null and not piece.is_king:
			return piece.instance_id
	return 0
