class_name AppRunManager
extends Node

signal active_run_changed(run_state: RunState)
signal active_run_invalidated(reason: String)
signal opening_draft_completed(run_state: RunState)
signal map_generated(run_state: RunState)
signal map_node_selected(run_state: RunState, node_id: StringName)
signal map_node_resolved(run_state: RunState, node_id: StringName)
signal roster_changed(run_state: RunState)
signal deployment_changed(run_state: RunState)
signal run_phase_changed(previous_phase: StringName, current_phase: StringName)
signal run_saved

const DEFAULT_SAVE_PATH := "user://active_run.save"

var current_run: RunState = null
var rng_service: RunRngService = null
var save_service: ActiveRunSaveService = null
var opening_draft_service: OpeningDraftService = null
var map_progress_service: MapProgressService = null
var roster_service: RosterService = null
var deployment_service: DeploymentService = null
var content_service: RunContentService = null
var fusion_service: FusionService = null
var flow_state_machine: RunFlowStateMachine = null
var meta_progress_service: MetaProgressService = null
var save_path: String = DEFAULT_SAVE_PATH
var _initialized: bool = false

func _ready() -> void:
	_initialize_services()
	load_active_run()

func configure_save_path(path: String) -> void:
	save_path = path
	if _initialized:
		_initialize_services()
		load_active_run()

func can_continue() -> bool:
	return current_run != null

func create_run(seed_value: int, mode: String = RunState.MODE_STANDARD, allow_overwrite: bool = false) -> bool:
	_ensure_services()
	if (current_run != null or save_service.exists()) and not allow_overwrite:
		return false
	var new_run: RunState = RunState.new()
	new_run.initialize_new(seed_value, mode)
	var king: PieceInstanceState = new_run.allocate_piece("king", true)
	if king == null:
		return false
	var new_rng: RunRngService = RunRngService.new()
	new_rng.initialize(seed_value)
	new_run.rng_stream_states = new_rng.snapshot_states()
	if opening_draft_service.ensure_pending_choice(new_run, new_rng) != OK:
		return false
	return _commit_transaction(new_run, new_rng) == OK

func ensure_opening_draft_pending() -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if opening_draft_service.is_complete(current_run):
		return OK
	if not _phase_is([RunPhase.OPENING_DRAFT]):
		return ERR_UNAVAILABLE
	if opening_draft_service.validate_pending_choice(current_run):
		return OK
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var draft_run: RunState = transaction["run"] as RunState
	var draft_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = opening_draft_service.ensure_pending_choice(draft_run, draft_rng)
	if error != OK:
		return error
	return _commit_transaction(draft_run, draft_rng)

func submit_opening_draft_choice(piece_def_id: String) -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.OPENING_DRAFT]):
		return ERR_UNAVAILABLE
	var was_complete: bool = opening_draft_service.is_complete(current_run)
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var draft_run: RunState = transaction["run"] as RunState
	var draft_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = opening_draft_service.apply_choice(draft_run, draft_rng, piece_def_id)
	if error != OK:
		return error
	if opening_draft_service.is_complete(draft_run):
		error = flow_state_machine.transition(draft_run, RunPhase.MAP)
		if error != OK:
			return error
	var commit_error: Error = _commit_transaction(draft_run, draft_rng)
	if commit_error == OK and not was_complete and opening_draft_service.is_complete(current_run):
		opening_draft_completed.emit(current_run)
	return commit_error

func opening_draft_complete() -> bool:
	return current_run != null and opening_draft_service.is_complete(current_run)

func ensure_run_map() -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.MAP]):
		return ERR_UNAVAILABLE
	var had_map: bool = current_run.map_state != null
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var map_run: RunState = transaction["run"] as RunState
	var map_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = map_progress_service.ensure_map(map_run, map_rng)
	if error != OK:
		return error
	if had_map:
		return OK
	var commit_error: Error = _commit_transaction(map_run, map_rng)
	if commit_error == OK:
		map_generated.emit(current_run)
	return commit_error

func available_map_node_ids() -> Array[StringName]:
	_ensure_services()
	if not _phase_is([RunPhase.MAP, RunPhase.NODE_SELECTED]):
		return []
	return map_progress_service.available_node_ids(current_run)

func select_map_node(node_id: StringName) -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.MAP]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var map_run: RunState = transaction["run"] as RunState
	var map_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = map_progress_service.select_node(map_run, map_rng, node_id)
	if error != OK:
		return error
	error = flow_state_machine.transition(map_run, RunPhase.NODE_SELECTED)
	if error != OK:
		return error
	var commit_error: Error = _commit_transaction(map_run, map_rng)
	if commit_error == OK:
		map_node_selected.emit(current_run, node_id)
	return commit_error

func resolve_current_map_node(payload: Dictionary = {}) -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.NODE_SELECTED]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var map_run: RunState = transaction["run"] as RunState
	var map_rng: RunRngService = transaction["rng"] as RunRngService
	var node_id: StringName = map_run.current_node_id
	var error: Error = map_progress_service.resolve_current_node(map_run, payload)
	if error != OK:
		return error
	error = flow_state_machine.transition(map_run, RunPhase.MAP)
	if error != OK:
		return error
	var commit_error: Error = _commit_transaction(map_run, map_rng)
	if commit_error == OK:
		map_node_resolved.emit(current_run, node_id)
	return commit_error

func current_map_node() -> MapNodeState:
	if current_run == null or current_run.map_state == null:
		return null
	return current_run.map_state.get_node(current_run.current_node_id)

func move_roster_piece(instance_id: int, to_active: bool) -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.MAP, RunPhase.NODE_SELECTED, RunPhase.DEPLOYMENT, RunPhase.BATTLE_READY]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var roster_run: RunState = transaction["run"] as RunState
	var roster_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = roster_service.move_to_active(roster_run, instance_id) if to_active else roster_service.move_to_reserve(roster_run, instance_id)
	if error != OK:
		return error
	if roster_run.deployment_state != null:
		error = deployment_service.synchronize_with_roster(roster_run)
		if error != OK:
			return error
		error = flow_state_machine.transition(roster_run, RunPhase.DEPLOYMENT)
		if error != OK:
			return error
	var commit_error: Error = _commit_transaction(roster_run, roster_rng)
	if commit_error == OK:
		roster_changed.emit(current_run)
	return commit_error

func begin_deployment() -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.NODE_SELECTED, RunPhase.DEPLOYMENT, RunPhase.BATTLE_READY]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var deployment_run: RunState = transaction["run"] as RunState
	var deployment_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = deployment_service.ensure_deployment(deployment_run)
	if error != OK:
		return error
	var target_phase: StringName = RunPhase.BATTLE_READY if deployment_run.deployment_state.confirmed else RunPhase.DEPLOYMENT
	error = flow_state_machine.transition(deployment_run, target_phase)
	if error != OK:
		return error
	var commit_error: Error = _commit_transaction(deployment_run, deployment_rng)
	if commit_error == OK:
		deployment_changed.emit(current_run)
	return commit_error

func move_deployed_piece(instance_id: int, target: Vector2i) -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.DEPLOYMENT, RunPhase.BATTLE_READY]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var deployment_run: RunState = transaction["run"] as RunState
	var deployment_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = deployment_service.move_piece(deployment_run, instance_id, target)
	if error != OK:
		return error
	error = flow_state_machine.transition(deployment_run, RunPhase.DEPLOYMENT)
	if error != OK:
		return error
	var commit_error: Error = _commit_transaction(deployment_run, deployment_rng)
	if commit_error == OK:
		deployment_changed.emit(current_run)
	return commit_error

func confirm_deployment() -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.DEPLOYMENT, RunPhase.BATTLE_READY]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var deployment_run: RunState = transaction["run"] as RunState
	var deployment_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = deployment_service.confirm(deployment_run)
	if error != OK:
		return error
	error = flow_state_machine.transition(deployment_run, RunPhase.BATTLE_READY)
	if error != OK:
		return error
	var commit_error: Error = _commit_transaction(deployment_run, deployment_rng)
	if commit_error == OK:
		deployment_changed.emit(current_run)
	return commit_error

func start_current_battle() -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.BATTLE_READY]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var battle_run: RunState = transaction["run"] as RunState
	var battle_rng: RunRngService = transaction["rng"] as RunRngService
	var transition_error: Error = flow_state_machine.transition(battle_run, RunPhase.BATTLE_ACTIVE)
	if transition_error != OK:
		return transition_error
	var commit_error: Error = _commit_transaction(battle_run, battle_rng)
	if commit_error != OK:
		return commit_error
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state != null and bool(game_state.call("start_run_battle", current_run)):
		return OK
	return_to_deployment()
	return ERR_CANT_CREATE

func return_to_deployment() -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.BATTLE_ACTIVE, RunPhase.BATTLE_READY]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var deployment_run: RunState = transaction["run"] as RunState
	var deployment_rng: RunRngService = transaction["rng"] as RunRngService
	if deployment_run.deployment_state == null:
		return ERR_INVALID_DATA
	deployment_run.deployment_state.confirmed = false
	var transition_error: Error = flow_state_machine.transition(deployment_run, RunPhase.DEPLOYMENT)
	if transition_error != OK:
		return transition_error
	var commit_error: Error = _commit_transaction(deployment_run, deployment_rng)
	if commit_error == OK:
		var game_state: Node = get_node_or_null("/root/GameState")
		if game_state != null:
			game_state.call("start_new_game")
		deployment_changed.emit(current_run)
	return commit_error

func resolve_current_battle_node(payload: Dictionary = {}) -> Error:
	_ensure_services()
	if current_run == null or current_run.deployment_state == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.BATTLE_ACTIVE]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var battle_run: RunState = transaction["run"] as RunState
	var battle_rng: RunRngService = transaction["rng"] as RunRngService
	var node_id: StringName = battle_run.current_node_id
	var error: Error = map_progress_service.resolve_current_node(battle_run, payload)
	if error != OK:
		return error
	deployment_service.clear(battle_run)
	error = flow_state_machine.transition(battle_run, RunPhase.MAP)
	if error != OK:
		return error
	var commit_error: Error = _commit_transaction(battle_run, battle_rng)
	if commit_error == OK:
		map_node_resolved.emit(current_run, node_id)
		deployment_changed.emit(current_run)
	return commit_error

func begin_current_run_interaction() -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.NODE_SELECTED]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var interaction_run: RunState = transaction["run"] as RunState
	var interaction_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = content_service.begin_current_node(interaction_run, interaction_rng)
	if error != OK:
		return error
	error = flow_state_machine.transition(interaction_run, RunPhase.NODE_INTERACTION)
	if error != OK:
		return error
	return _commit_transaction(interaction_run, interaction_rng)

func submit_run_interaction(choice_id: String) -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.NODE_INTERACTION, RunPhase.POST_BATTLE_CHOICE, RunPhase.ROSTER_OVERFLOW, RunPhase.FUSION_CONFIRMATION]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var interaction_run: RunState = transaction["run"] as RunState
	var interaction_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = content_service.submit(interaction_run, interaction_rng, map_progress_service, deployment_service, choice_id)
	if error != OK:
		return error
	error = flow_state_machine.transition_to_derived_phase(interaction_run)
	if error != OK:
		return error
	return _commit_transaction(interaction_run, interaction_rng)

func leave_run_interaction() -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.NODE_INTERACTION]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var interaction_run: RunState = transaction["run"] as RunState
	var interaction_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = content_service.leave(interaction_run, map_progress_service)
	if error != OK:
		return error
	error = flow_state_machine.transition(interaction_run, RunPhase.MAP)
	if error != OK:
		return error
	return _commit_transaction(interaction_run, interaction_rng)

func consume_challenger_item(slot_index: int, expected_item_id: StringName, before_publish: Callable = Callable()) -> Error:
	_ensure_services()
	if current_run == null or slot_index < 0 or slot_index >= current_run.challenger_slots.size():
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.BATTLE_ACTIVE]):
		return ERR_UNAVAILABLE
	var item_definition: ChallengerItemDef = ChallengerItemDatabase.get_def(expected_item_id)
	if item_definition == null or not item_definition.is_consumable():
		return ERR_INVALID_DATA
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var item_run: RunState = transaction["run"] as RunState
	var item_rng: RunRngService = transaction["rng"] as RunRngService
	if item_run.challenger_slots[slot_index] != expected_item_id:
		return ERR_INVALID_DATA
	item_run.challenger_slots.remove_at(slot_index)
	return _commit_transaction(item_run, item_rng, before_publish)

func apply_battle_outcome(player_won: bool) -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	if not _phase_is([RunPhase.BATTLE_ACTIVE]):
		return ERR_UNAVAILABLE
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var battle_run: RunState = transaction["run"] as RunState
	var battle_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = content_service.apply_battle_victory(battle_run, battle_rng, map_progress_service, deployment_service) if player_won else content_service.apply_battle_defeat(battle_run, battle_rng, deployment_service)
	if error != OK:
		return error
	error = flow_state_machine.transition_to_derived_phase(battle_run)
	if error != OK:
		return error
	return _commit_transaction(battle_run, battle_rng)

func endless_unlocked() -> bool:
	_ensure_services()
	return meta_progress_service.endless_unlocked()

func discovered_piece_ids() -> Array[String]:
	_ensure_services()
	return meta_progress_service.discovered_piece_ids()

func is_piece_discovered(piece_id: String) -> bool:
	_ensure_services()
	return meta_progress_service.is_piece_discovered(piece_id)

func finish_run_summary() -> Error:
	_ensure_services()
	if current_run == null or not _phase_is([RunPhase.RUN_SUMMARY]) or str(current_run.pending_choice.get("type", "")) != "run_summary":
		return ERR_UNAVAILABLE
	if bool(current_run.run_statistics.get("run_won", false)):
		var unlock_error: Error = meta_progress_service.unlock_endless()
		if unlock_error != OK:
			return unlock_error
	return abandon_run()

func resume_scene_path() -> String:
	if current_run == null:
		return AppSceneRoutes.MAIN_MENU
	if current_run.phase in RunPhase.INTERACTION_PHASES:
		return AppSceneRoutes.RUN_INTERACTION
	if current_run.phase in [RunPhase.DEPLOYMENT, RunPhase.BATTLE_READY, RunPhase.BATTLE_ACTIVE]:
		return AppSceneRoutes.DEPLOYMENT
	if current_run.phase in [RunPhase.MAP, RunPhase.NODE_SELECTED]:
		return AppSceneRoutes.PATH_MAP
	return AppSceneRoutes.OPENING_DRAFT

func save_active_run() -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	current_run.rng_stream_states = rng_service.snapshot_states()
	var error: Error = save_service.save(current_run)
	if error == OK:
		run_saved.emit()
	return error

func load_active_run() -> bool:
	_ensure_services()
	if not save_service.exists():
		current_run = null
		return false
	var loaded_run: RunState = save_service.load_run()
	if loaded_run == null:
		current_run = null
		var invalid_reason: String = save_service.last_error_message
		save_service.delete()
		active_run_invalidated.emit(invalid_reason)
		return false
	var loaded_rng: RunRngService = RunRngService.new()
	loaded_rng.initialize(loaded_run.run_seed)
	if not loaded_rng.restore_states(loaded_run.rng_stream_states):
		current_run = null
		active_run_invalidated.emit("Active Run RNG state is invalid")
		return false
	var needed_draft_bootstrap: bool = (
		loaded_run.phase == RunPhase.OPENING_DRAFT
		and loaded_run.pending_choice.is_empty()
		and not opening_draft_service.is_complete(loaded_run)
	)
	if loaded_run.phase == RunPhase.OPENING_DRAFT and opening_draft_service.ensure_pending_choice(loaded_run, loaded_rng) != OK:
		current_run = null
		active_run_invalidated.emit("Active Run opening draft state is invalid")
		return false
	loaded_run.rng_stream_states = loaded_rng.snapshot_states()
	var needs_migration_save: bool = loaded_run.was_migrated_from_legacy or needed_draft_bootstrap
	if needs_migration_save and save_service.save(loaded_run) != OK:
		current_run = null
		active_run_invalidated.emit(save_service.last_error_message)
		return false
	loaded_run.was_migrated_from_legacy = false
	current_run = loaded_run
	rng_service = loaded_rng
	var codex_error: Error = meta_progress_service.record_discovered_piece_ids(_visible_piece_ids(current_run))
	if codex_error != OK:
		push_warning("Unable to save codex progress: %s" % error_string(codex_error))
	active_run_changed.emit(current_run)
	return true

func abandon_run() -> Error:
	_ensure_services()
	var error: Error = save_service.delete()
	if error == OK:
		current_run = null
		rng_service = RunRngService.new()
		active_run_changed.emit(null)
	return error

func _clone_transaction() -> Dictionary:
	var cloned_run: RunState = RunState.new()
	if current_run == null or not cloned_run.load_from_dictionary(current_run.to_dictionary(), false):
		return {}
	var cloned_rng: RunRngService = RunRngService.new()
	cloned_rng.initialize(cloned_run.run_seed)
	if not cloned_rng.restore_states(cloned_run.rng_stream_states):
		return {}
	return {"run": cloned_run, "rng": cloned_rng}

func _commit_transaction(new_run: RunState, new_rng: RunRngService, before_publish: Callable = Callable()) -> Error:
	var previous_phase: StringName = current_run.phase if current_run != null else &""
	new_run.rng_stream_states = new_rng.snapshot_states()
	if not new_run.is_valid():
		return ERR_INVALID_DATA
	var error: Error = save_service.save(new_run)
	if error != OK:
		return error
	if before_publish.is_valid():
		before_publish.call()
	current_run = new_run
	rng_service = new_rng
	var codex_error: Error = meta_progress_service.record_discovered_piece_ids(_visible_piece_ids(current_run))
	if codex_error != OK:
		push_warning("Unable to save codex progress: %s" % error_string(codex_error))
	run_saved.emit()
	active_run_changed.emit(current_run)
	if previous_phase != current_run.phase:
		run_phase_changed.emit(previous_phase, current_run.phase)
	return OK

func _visible_piece_ids(run_state: RunState) -> Array[String]:
	var visible: Array[String] = []
	if run_state == null:
		return visible
	for piece: PieceInstanceState in run_state.player_roster:
		_append_visible_piece_id(visible, String(piece.piece_def_id))
	if run_state.deployment_state != null:
		for placement: Dictionary in run_state.deployment_state.enemy_placements:
			_append_visible_piece_id(visible, str(placement.get("piece_def_id", "")))
	_append_pending_visible_piece_ids(visible, run_state.pending_choice)
	return visible

func _append_pending_visible_piece_ids(target: Array[String], pending: Dictionary) -> void:
	var candidate_values: Array = pending.get("candidate_piece_def_ids", []) as Array
	for candidate: Variant in candidate_values:
		_append_visible_piece_id(target, str(candidate))
	var option_values: Array = pending.get("options", []) as Array
	for option_value: Variant in option_values:
		if not option_value is Dictionary:
			continue
		var payload: Dictionary = (option_value as Dictionary).get("payload", {}) as Dictionary
		_append_visible_piece_id(target, str(payload.get("piece_def_id", "")))
		var recipe_id: StringName = StringName(str(payload.get("recipe_id", "")))
		if not recipe_id.is_empty():
			var recipe: FusionRecipeDef = FusionRecipeDatabase.get_def(recipe_id)
			if recipe != null:
				_append_visible_piece_id(target, String(recipe.result_piece_def_id))
	var plan_value: Variant = pending.get("plan", {})
	if plan_value is Dictionary and not (plan_value as Dictionary).is_empty():
		var plan_data: Dictionary = plan_value as Dictionary
		_append_visible_piece_id(target, str(plan_data.get("result_piece_def_id", "")))
		var original_value: Variant = plan_data.get("original_pending_choice", {})
		if original_value is Dictionary and not (original_value as Dictionary).is_empty():
			_append_pending_visible_piece_ids(target, original_value as Dictionary)

func _append_visible_piece_id(target: Array[String], piece_id: String) -> void:
	if not piece_id.is_empty() and PieceDefDatabase.has_def(piece_id) and piece_id not in target:
		target.append(piece_id)

func _initialize_services() -> void:
	save_service = ActiveRunSaveService.new(save_path)
	rng_service = RunRngService.new()
	opening_draft_service = OpeningDraftService.new()
	map_progress_service = MapProgressService.new()
	roster_service = RosterService.new()
	deployment_service = DeploymentService.new()
	fusion_service = FusionService.new()
	flow_state_machine = RunFlowStateMachine.new()
	content_service = RunContentService.new(fusion_service)
	meta_progress_service = MetaProgressService.new()
	_initialized = true

func _phase_is(allowed_phases: Array[StringName]) -> bool:
	return current_run != null and current_run.phase in allowed_phases

func _ensure_services() -> void:
	if not _initialized:
		_initialize_services()
