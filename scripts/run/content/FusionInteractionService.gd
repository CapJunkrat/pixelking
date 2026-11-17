class_name FusionInteractionService
extends RefCounted

var fusion_service: FusionService

func _init(p_fusion_service: FusionService = null) -> void:
	fusion_service = p_fusion_service if p_fusion_service != null else FusionService.new()

func stage(run_state: RunState, original_pending: Dictionary, source_choice_id: String, payload: Dictionary) -> Error:
	var recipe_id: StringName = StringName(str(payload.get("recipe_id", "")))
	var price: int = int(payload.get("price", 0))
	var plan: FusionPlan = fusion_service.create_plan(run_state, recipe_id, original_pending, source_choice_id, price)
	if plan == null:
		return ERR_UNAVAILABLE
	var recipe: FusionRecipeDef = FusionRecipeDatabase.get_def(recipe_id)
	if recipe == null:
		return ERR_DOES_NOT_EXIST
	var options: Array[Dictionary] = [
		RunChoiceBuilder.option("confirm_fusion", "Confirm Fusion", "confirm_fusion", {}),
		RunChoiceBuilder.option("cancel_fusion", "Back to Offers", "cancel_fusion", {}),
	]
	options[0]["label_key"] = "FUSION_CONFIRM"
	options[1]["label_key"] = "FUSION_CANCEL"
	var preview: Dictionary = RunChoiceBuilder.pending("fusion_confirmation", recipe.display_name, fusion_service.preview_description(run_state, plan), options, false)
	preview["title_key"] = String(recipe.display_name_key)
	preview["description_key"] = String(recipe.description_key)
	preview["plan"] = plan.to_dictionary()
	run_state.pending_choice = preview
	return OK

func submit(run_state: RunState, progress: MapProgressService, deployment: DeploymentService, choice_id: String) -> Error:
	var plan_value: Variant = run_state.pending_choice.get("plan", {})
	if not plan_value is Dictionary:
		return ERR_INVALID_DATA
	var plan: FusionPlan = FusionPlan.new()
	if not plan.load_from_dictionary(plan_value as Dictionary):
		return ERR_INVALID_DATA
	if choice_id == "cancel_fusion":
		run_state.pending_choice = plan.original_pending_choice.duplicate(true)
		return OK
	if choice_id != "confirm_fusion":
		return ERR_INVALID_PARAMETER
	if plan.source_type == &"shop" and run_state.gold < plan.price:
		return ERR_UNAVAILABLE
	var snapshot: Dictionary = run_state.to_dictionary()
	run_state.pending_choice.clear()
	var fusion_error: Error = fusion_service.confirm(run_state, plan, deployment)
	if fusion_error != OK:
		run_state.load_from_dictionary(snapshot, false)
		return fusion_error
	if plan.source_type == &"shop":
		run_state.gold -= plan.price
		var resolve_error: Error = progress.resolve_current_node(run_state, {
			"outcome": "purchase",
			"choice": plan.source_choice_id,
			"recipe_id": String(plan.recipe_id),
		})
		if resolve_error != OK:
			run_state.load_from_dictionary(snapshot, false)
			return resolve_error
	return OK
