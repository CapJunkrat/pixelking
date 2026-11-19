class_name RunRosterChoiceService
extends RefCounted

var reward_service: RunRewardService

func _init(p_reward_service: RunRewardService = null) -> void:
	reward_service = p_reward_service if p_reward_service != null else RunRewardService.new()

func stage_overflow(run_state: RunState, new_piece_def_id: String) -> void:
	var options: Array[Dictionary] = []
	for instance_id: int in run_state.reserve_piece_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		options.append(RunChoiceBuilder.option("replace_%d" % instance_id, "Replace %s" % reward_service.piece_label(piece), "replace_piece", {"instance_id": instance_id, "piece_def_id": new_piece_def_id}))
	options.append(RunChoiceBuilder.option("discard_new", "Decline %s" % reward_service.definition_label(new_piece_def_id), "discard_new", {}))
	run_state.pending_choice = RunChoiceBuilder.pending("roster_overflow", "Reserve Full", "Replace one reserve piece or decline the new recruit.", options, false)

func submit_overflow(run_state: RunState, payload: Dictionary) -> Error:
	var overflow_kind: String = str(payload.get("kind", ""))
	if overflow_kind == "discard_new":
		run_state.pending_choice.clear()
		return OK
	if overflow_kind != "replace_piece":
		return ERR_INVALID_PARAMETER
	var replaced_id: int = int(payload.get("instance_id", 0))
	var replacement_id: String = str(payload.get("piece_def_id", ""))
	var remove_error: Error = reward_service.remove_piece(run_state, replaced_id)
	if remove_error != OK or run_state.allocate_piece(replacement_id, false) == null:
		return ERR_UNAVAILABLE
	run_state.pending_choice.clear()
	return OK

# --- Buying a recruit in the shop with no room left -------------------------------
# The shop stays a "shop" choice throughout; the original offers ride along in
# "shop_return" so either step can step back to them. Nothing is paid until a piece
# to let go has been picked.

## Step 1: tell the player a piece has to go, and ask whether to go on.
func stage_shop_replace_confirm(run_state: RunState, shop_pending: Dictionary, source_choice_id: String, payload: Dictionary) -> void:
	var new_id: String = str(payload.get("piece_def_id", ""))
	var data: Dictionary = {"piece_def_id": new_id, "price": int(payload.get("price", 0)), "source_choice": source_choice_id}
	var options: Array[Dictionary] = [
		RunChoiceBuilder.option("shop_replace_confirm", "Choose a piece to let go", "shop_replace_confirm", data),
		RunChoiceBuilder.option("shop_replace_cancel", "Back to the shop", "shop_replace_cancel", {}),
	]
	options[0]["label_key"] = "SHOP_FULL_CONFIRM"
	options[1]["label_key"] = "SHOP_FULL_CANCEL"
	var pending: Dictionary = RunChoiceBuilder.pending("shop", "Your Party Is Full", "", options, false)
	pending["title_key"] = "SHOP_FULL_TITLE"
	pending["description_key"] = "SHOP_FULL_DESC"
	pending["description_args"] = [reward_service.definition_label(new_id)]
	pending["shop_return"] = _shop_offers(shop_pending).duplicate(true)
	run_state.pending_choice = pending

## Step 2: every piece but the King, on the battle line or in reserve.
func stage_shop_replace_pick(run_state: RunState, confirm_pending: Dictionary, payload: Dictionary) -> void:
	var options: Array[Dictionary] = []
	for instance_id: int in run_state.active_piece_ids + run_state.reserve_piece_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		if piece == null or piece.is_king:
			continue
		var data: Dictionary = payload.duplicate(true)
		data.erase("kind")
		data["instance_id"] = instance_id
		data["replaced_def_id"] = String(piece.piece_def_id)
		data["detail_key"] = "SHOP_FULL_ON_LINE" if instance_id in run_state.active_piece_ids else "SHOP_FULL_IN_RESERVE"
		options.append(RunChoiceBuilder.option("shop_replace_%d" % instance_id, "Replace %s" % reward_service.piece_label(piece), "shop_replace_pick", data))
	var cancel: Dictionary = RunChoiceBuilder.option("shop_replace_cancel", "Back to the shop", "shop_replace_cancel", {})
	cancel["label_key"] = "SHOP_FULL_CANCEL"
	options.append(cancel)
	var pending: Dictionary = RunChoiceBuilder.pending("shop", "Let a Piece Go", "", options, false)
	pending["title_key"] = "SHOP_PICK_TITLE"
	pending["description_key"] = "SHOP_PICK_DESC"
	pending["description_args"] = [reward_service.definition_label(str(payload.get("piece_def_id", "")))]
	pending["shop_return"] = _shop_offers(confirm_pending).duplicate(true)
	run_state.pending_choice = pending

## Step 3: let the chosen piece go, take the recruit and pay. Undone on any failure.
func buy_replacing(run_state: RunState, payload: Dictionary) -> Error:
	var price: int = int(payload.get("price", 0))
	if run_state.gold < price:
		return ERR_UNAVAILABLE
	var snapshot: Dictionary = run_state.to_dictionary()
	if reward_service.remove_piece(run_state, int(payload.get("instance_id", 0))) != OK or run_state.allocate_piece(str(payload.get("piece_def_id", "")), false) == null:
		run_state.load_from_dictionary(snapshot, false)
		return ERR_UNAVAILABLE
	run_state.gold -= price
	return OK

## The shop's own offers behind a replace step (or the shop itself).
static func _shop_offers(pending: Dictionary) -> Dictionary:
	var stored: Variant = pending.get("shop_return", {})
	return stored as Dictionary if stored is Dictionary and not (stored as Dictionary).is_empty() else pending
