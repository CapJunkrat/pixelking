class_name BattleRunResultCoordinator
extends RefCounted

func integrate(manager: AppRunManager, player_won: bool) -> BattleRunResult:
	var result: BattleRunResult = BattleRunResult.new()
	result.exit_text_key = &"BATTLE_RESULT_MAIN_MENU"
	if manager == null or manager.current_run == null:
		return result
	result.has_active_run = true
	var current: MapNodeState = manager.current_map_node()
	var definition: MapNodeDef = MapNodeDefDatabase.get_def(current.node_type_id) if current != null else null
	if definition == null or not definition.is_battle:
		return result
	var error: Error = manager.apply_battle_outcome(player_won)
	if error != OK:
		result.success = false
		result.error = error
		return result
	result.retry_visible = false
	result.pending_type = StringName(str(manager.current_run.pending_choice.get("type", "")))
	match result.pending_type:
		&"battle_reward":
			result.exit_text = "Choose Reward"
		&"sacrifice":
			result.exit_text = "Choose Sacrifice"
		&"run_summary":
			result.exit_text = "Run Summary"
		_:
			result.exit_text = ""
			result.exit_text_key = &"BATTLE_RESULT_MAP"
	return result
