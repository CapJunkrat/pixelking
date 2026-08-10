class_name AppRunManager
extends Node

signal active_run_changed(run_state: RunState)
signal active_run_invalidated(reason: String)
signal opening_draft_completed(run_state: RunState)
signal map_generated(run_state: RunState)
signal map_node_selected(run_state: RunState, node_id: StringName)
signal map_node_resolved(run_state: RunState, node_id: StringName)
signal run_saved

const DEFAULT_SAVE_PATH := "user://active_run.save"

var current_run: RunState = null
var rng_service: RunRngService = null
var save_service: ActiveRunSaveService = null
var opening_draft_service: OpeningDraftService = null
var map_progress_service: MapProgressService = null
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
	var was_complete: bool = opening_draft_service.is_complete(current_run)
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var draft_run: RunState = transaction["run"] as RunState
	var draft_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = opening_draft_service.apply_choice(draft_run, draft_rng, piece_def_id)
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
	return map_progress_service.available_node_ids(current_run)

func select_map_node(node_id: StringName) -> Error:
	_ensure_services()
	if current_run == null:
		return ERR_DOES_NOT_EXIST
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var map_run: RunState = transaction["run"] as RunState
	var map_rng: RunRngService = transaction["rng"] as RunRngService
	var error: Error = map_progress_service.select_node(map_run, map_rng, node_id)
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
	var transaction: Dictionary = _clone_transaction()
	if transaction.is_empty():
		return ERR_INVALID_DATA
	var map_run: RunState = transaction["run"] as RunState
	var map_rng: RunRngService = transaction["rng"] as RunRngService
	var node_id: StringName = map_run.current_node_id
	var error: Error = map_progress_service.resolve_current_node(map_run, payload)
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

func resume_scene_path() -> String:
	if opening_draft_complete():
		return "res://scenes/run/PathMapScene.tscn"
	return "res://scenes/run/OpeningDraftScene.tscn"

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
	var needed_draft_bootstrap: bool = loaded_run.pending_choice.is_empty() and not opening_draft_service.is_complete(loaded_run)
	if opening_draft_service.ensure_pending_choice(loaded_run, loaded_rng) != OK:
		current_run = null
		active_run_invalidated.emit("Active Run opening draft state is invalid")
		return false
	loaded_run.rng_stream_states = loaded_rng.snapshot_states()
	if needed_draft_bootstrap and save_service.save(loaded_run) != OK:
		current_run = null
		active_run_invalidated.emit(save_service.last_error_message)
		return false
	current_run = loaded_run
	rng_service = loaded_rng
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
	if current_run == null or not cloned_run.load_from_dictionary(current_run.to_dictionary()):
		return {}
	var cloned_rng: RunRngService = RunRngService.new()
	cloned_rng.initialize(cloned_run.run_seed)
	if not cloned_rng.restore_states(cloned_run.rng_stream_states):
		return {}
	return {"run": cloned_run, "rng": cloned_rng}

func _commit_transaction(new_run: RunState, new_rng: RunRngService) -> Error:
	new_run.rng_stream_states = new_rng.snapshot_states()
	if not new_run.is_valid():
		return ERR_INVALID_DATA
	var error: Error = save_service.save(new_run)
	if error != OK:
		return error
	current_run = new_run
	rng_service = new_rng
	run_saved.emit()
	active_run_changed.emit(current_run)
	return OK

func _initialize_services() -> void:
	save_service = ActiveRunSaveService.new(save_path)
	rng_service = RunRngService.new()
	opening_draft_service = OpeningDraftService.new()
	map_progress_service = MapProgressService.new()
	_initialized = true

func _ensure_services() -> void:
	if not _initialized:
		_initialize_services()
