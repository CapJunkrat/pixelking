class_name FusionService
extends RefCounted

var last_error_message: String = ""

func can_fuse(run_state: RunState, recipe_id: StringName) -> bool:
	return create_plan(run_state, recipe_id) != null

func eligible_recipes(run_state: RunState) -> Array[FusionRecipeDef]:
	var result: Array[FusionRecipeDef] = []
	for recipe: FusionRecipeDef in FusionRecipeDatabase.all_defs():
		if create_plan_for_recipe(run_state, recipe) != null:
			result.append(recipe)
	return result

func create_plan(
	run_state: RunState,
	recipe_id: StringName,
	original_pending_choice: Dictionary = {},
	source_choice_id: String = "",
	price: int = 0
) -> FusionPlan:
	var recipe: FusionRecipeDef = FusionRecipeDatabase.get_def(recipe_id)
	return create_plan_for_recipe(run_state, recipe, original_pending_choice, source_choice_id, price)

func create_plan_for_recipe(
	run_state: RunState,
	recipe: FusionRecipeDef,
	original_pending_choice: Dictionary = {},
	source_choice_id: String = "",
	price: int = 0
) -> FusionPlan:
	last_error_message = ""
	if run_state == null or recipe == null or price < 0:
		return _fail_plan("Missing Run, recipe, or valid price")
	var result_definition: PieceDef = PieceDefDatabase.get_def(String(recipe.result_piece_def_id))
	if result_definition == null:
		return _fail_plan("Fusion result definition is missing")
	var ingredient_ids: Array[int] = _select_ingredient_instances(run_state, recipe)
	if ingredient_ids.size() != recipe.ingredient_piece_def_ids.size():
		return _fail_plan("Required fusion ingredients are not owned")
	var king_ingredient_ids: Array[int] = []
	for instance_id: int in ingredient_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		if piece != null and piece.is_king:
			king_ingredient_ids.append(instance_id)
	if result_definition.is_king:
		if king_ingredient_ids.size() != 1:
			return _fail_plan("King fusion requires exactly one King ingredient")
	elif not king_ingredient_ids.is_empty():
		return _fail_plan("A non-King fusion cannot consume the King")
	if not result_definition.is_king:
		var reserve_removed: int = 0
		for instance_id: int in ingredient_ids:
			if instance_id in run_state.reserve_piece_ids:
				reserve_removed += 1
		if run_state.reserve_piece_ids.size() - reserve_removed + 1 > RunState.MAX_RESERVE_PIECES:
			return _fail_plan("The fusion result has no reserve slot")
	var plan: FusionPlan = FusionPlan.new()
	plan.recipe_id = recipe.id
	plan.ingredient_instance_ids = ingredient_ids
	plan.result_piece_def_id = recipe.result_piece_def_id
	plan.result_is_king = result_definition.is_king
	plan.preserved_king_instance_id = king_ingredient_ids[0] if result_definition.is_king else 0
	plan.destination = &"active" if result_definition.is_king else &"reserve"
	plan.price = price
	if not original_pending_choice.is_empty():
		plan.source_type = StringName(str(original_pending_choice.get("type", "")))
		plan.source_choice_id = source_choice_id
		plan.original_pending_choice = original_pending_choice.duplicate(true)
	if not plan.is_structurally_valid() or not validate_plan(run_state, plan, recipe):
		return _fail_plan("Fusion plan failed validation")
	return plan

func validate_plan(run_state: RunState, plan: FusionPlan, recipe_override: FusionRecipeDef = null) -> bool:
	last_error_message = ""
	if run_state == null or plan == null or not plan.is_structurally_valid():
		return _fail_validation("Fusion plan structure is invalid")
	var recipe: FusionRecipeDef = recipe_override if recipe_override != null else FusionRecipeDatabase.get_def(plan.recipe_id)
	if recipe == null or recipe.id != plan.recipe_id or recipe.result_piece_def_id != plan.result_piece_def_id:
		return _fail_validation("Fusion recipe no longer matches the plan")
	if plan.ingredient_instance_ids.size() != recipe.ingredient_piece_def_ids.size():
		return _fail_validation("Fusion ingredient count changed")
	var required: Dictionary = _piece_id_counts(recipe.ingredient_piece_def_ids)
	var actual: Dictionary = {}
	var reserve_removed: int = 0
	var king_count: int = 0
	for instance_id: int in plan.ingredient_instance_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		if piece == null:
			return _fail_validation("A planned ingredient no longer exists")
		actual[piece.piece_def_id] = int(actual.get(piece.piece_def_id, 0)) + 1
		reserve_removed += 1 if instance_id in run_state.reserve_piece_ids else 0
		king_count += 1 if piece.is_king else 0
	if actual != required:
		return _fail_validation("Planned ingredients no longer match the recipe")
	var result_definition: PieceDef = PieceDefDatabase.get_def(String(plan.result_piece_def_id))
	if result_definition == null or result_definition.is_king != plan.result_is_king:
		return _fail_validation("Fusion result King identity changed")
	if plan.result_is_king:
		if king_count != 1 or plan.preserved_king_instance_id not in plan.ingredient_instance_ids:
			return _fail_validation("King fusion identity is invalid")
		var king_piece: PieceInstanceState = run_state.get_piece_state(plan.preserved_king_instance_id)
		if king_piece == null or not king_piece.is_king or plan.preserved_king_instance_id not in run_state.active_piece_ids:
			return _fail_validation("The tracked King ingredient is invalid")
	elif king_count != 0 or run_state.reserve_piece_ids.size() - reserve_removed + 1 > RunState.MAX_RESERVE_PIECES:
		return _fail_validation("Fusion result has no valid reserve destination")
	if not plan.source_type.is_empty() and not _source_choice_matches(plan):
		return _fail_validation("Original fusion offer no longer matches the plan")
	return true

func confirm(
	run_state: RunState,
	plan: FusionPlan,
	deployment_service: DeploymentService = null,
	recipe_override: FusionRecipeDef = null
) -> Error:
	if not validate_plan(run_state, plan, recipe_override):
		return ERR_INVALID_DATA
	if plan.source_type.is_empty() and not run_state.is_valid():
		return ERR_INVALID_DATA
	var snapshot: Dictionary = run_state.to_dictionary()
	if plan.result_is_king:
		var king_piece: PieceInstanceState = run_state.get_piece_state(plan.preserved_king_instance_id)
		king_piece.piece_def_id = plan.result_piece_def_id
		king_piece.is_king = true
		for instance_id: int in plan.ingredient_instance_ids:
			if instance_id != plan.preserved_king_instance_id:
				_remove_piece(run_state, instance_id)
	else:
		# A learning piece fused into another learning piece hands over what it knows.
		var inherited: Array[String] = []
		for instance_id: int in plan.ingredient_instance_ids:
			var ingredient: PieceInstanceState = run_state.get_piece_state(instance_id)
			if ingredient != null:
				for learned_id: String in ingredient.learned_def_ids:
					if learned_id not in inherited:
						inherited.append(learned_id)
			_remove_piece(run_state, instance_id)
		var fused: PieceInstanceState = run_state.allocate_piece(String(plan.result_piece_def_id), false)
		if fused == null:
			_restore(run_state, snapshot)
			return ERR_OUT_OF_MEMORY
		var fused_definition: PieceDef = PieceDefDatabase.get_def(String(plan.result_piece_def_id))
		if fused_definition != null and fused_definition.learn_capacity > 0:
			while inherited.size() > fused_definition.learn_capacity:
				inherited.remove_at(0)
			fused.learned_def_ids = inherited
	if plan.recipe_id not in run_state.owned_recipe_history:
		run_state.owned_recipe_history.append(plan.recipe_id)
	if deployment_service != null and run_state.deployment_state != null:
		var deployment_error: Error = deployment_service.synchronize_with_roster(run_state)
		if deployment_error != OK:
			_restore(run_state, snapshot)
			return deployment_error
	# RunContentService clears a sourced confirmation before applying the fusion,
	# then resolves the source and derives the next phase. That transient state is
	# intentionally not persistable, so validate the bounded roster/deployment mutation here.
	if plan.source_type.is_empty() and not run_state.is_valid():
		_restore(run_state, snapshot)
		return ERR_INVALID_DATA
	if run_state.deployment_state != null and not run_state.deployment_state.is_valid(run_state):
		_restore(run_state, snapshot)
		return ERR_INVALID_DATA
	return OK

## What the fusion uses and creates, in the current language.
func preview_description(run_state: RunState, plan: FusionPlan) -> String:
	if run_state == null or plan == null:
		return _t("FUSION_PREVIEW_UNAVAILABLE")
	var ingredient_labels: Array[String] = []
	var active_removed: int = 0
	var reserve_removed: int = 0
	for instance_id: int in plan.ingredient_instance_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		if piece == null:
			continue
		var location: String = _t("ROSTER_ON_LINE") if instance_id in run_state.active_piece_ids else _t("ROSTER_IN_RESERVE")
		ingredient_labels.append("%s (%s)" % [_piece_name(String(piece.piece_def_id)), location])
		if instance_id != plan.preserved_king_instance_id:
			active_removed += 1 if instance_id in run_state.active_piece_ids else 0
			reserve_removed += 1 if instance_id in run_state.reserve_piece_ids else 0
	var result_definition: PieceDef = PieceDefDatabase.get_def(String(plan.result_piece_def_id))
	var rarity_keys: Array[String] = ["RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY", "RARITY_MYTHIC"]
	var rarity_label: String = _t(rarity_keys[result_definition.rarity]) if result_definition != null and result_definition.rarity >= 0 and result_definition.rarity < rarity_keys.size() else "?"
	var lines: Array[String] = [
		_t("FUSION_PREVIEW_USES") % ", ".join(ingredient_labels),
		_t("FUSION_PREVIEW_CREATES") % [_piece_name(String(plan.result_piece_def_id)), rarity_label, result_definition.base_value if result_definition != null else 0],
	]
	if result_definition != null:
		lines.append(_t(PieceRulePreview.move_key(result_definition)))
		lines.append(_t(PieceRulePreview.attack_key(result_definition)))
	var active_after: int = run_state.active_piece_ids.size() - active_removed
	var reserve_after: int = run_state.reserve_piece_ids.size() - reserve_removed + (0 if plan.result_is_king else 1)
	lines.append(_t("FUSION_PREVIEW_DESTINATION") % _t("FUSION_PREVIEW_AS_KING" if plan.result_is_king else "ROSTER_RESERVE"))
	lines.append(_t("FUSION_PREVIEW_CAPACITY") % [run_state.active_piece_ids.size(), active_after, run_state.reserve_piece_ids.size(), reserve_after])
	if plan.price > 0:
		lines.append(_t("FUSION_PREVIEW_PRICE") % plan.price)
	return "\n".join(lines)

func _piece_name(piece_def_id: String) -> String:
	var definition: PieceDef = PieceDefDatabase.get_def(piece_def_id)
	return _t(String(definition.display_name_key)) if definition != null else piece_def_id

func _t(key: String) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var localization: Node = tree.root.get_node_or_null("Localization") if tree != null else null
	return str(localization.call("text", key)) if localization != null else key

func _select_ingredient_instances(run_state: RunState, recipe: FusionRecipeDef) -> Array[int]:
	var result: Array[int] = []
	var candidate_ids: Array[int] = run_state.reserve_piece_ids.duplicate()
	candidate_ids.append_array(run_state.active_piece_ids)
	for ingredient_id: StringName in recipe.ingredient_piece_def_ids:
		var selected_id: int = 0
		for instance_id: int in candidate_ids:
			if instance_id in result:
				continue
			var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
			if piece != null and piece.piece_def_id == ingredient_id:
				selected_id = instance_id
				break
		if selected_id <= 0:
			return []
		result.append(selected_id)
	return result

func _piece_id_counts(ids: Array[StringName]) -> Dictionary:
	var result: Dictionary = {}
	for id: StringName in ids:
		result[id] = int(result.get(id, 0)) + 1
	return result

func _source_choice_matches(plan: FusionPlan) -> bool:
	if str(plan.original_pending_choice.get("type", "")) != String(plan.source_type):
		return false
	var options: Array = plan.original_pending_choice.get("options", []) as Array
	for value: Variant in options:
		if not value is Dictionary:
			continue
		var option: Dictionary = value as Dictionary
		if str(option.get("id", "")) != plan.source_choice_id:
			continue
		var payload: Dictionary = option.get("payload", {}) as Dictionary
		return (
			bool(option.get("enabled", true))
			and str(payload.get("kind", "")) == "fusion"
			and StringName(str(payload.get("recipe_id", ""))) == plan.recipe_id
			and int(payload.get("price", 0)) == plan.price
		)
	return false

func _remove_piece(run_state: RunState, instance_id: int) -> void:
	var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
	if piece == null:
		return
	run_state.active_piece_ids.erase(instance_id)
	run_state.reserve_piece_ids.erase(instance_id)
	run_state.player_roster.erase(piece)

func _restore(run_state: RunState, snapshot: Dictionary) -> void:
	if not run_state.load_from_dictionary(snapshot, false):
		push_error("Fusion rollback failed to restore RunState")

func _fail_plan(message: String) -> FusionPlan:
	last_error_message = message
	return null

func _fail_validation(message: String) -> bool:
	last_error_message = message
	return false
