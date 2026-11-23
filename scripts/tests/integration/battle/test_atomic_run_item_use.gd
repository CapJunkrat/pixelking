extends SceneTree

const TEST_PATH := "user://pixelking_atomic_item_test.save"
const FAILING_PATH := "user://pixelking_missing_atomic_item_dir/active.save"

var failed: bool = false
var emitted_events: Array[BattleEvent] = []
var observed_target: Vector2i = Vector2i(-1, -1)
var atomic_signal_consistent: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	var game_state: Node = root.get_node("GameState")
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_expect(RunTestFixture.create_drafted_run(manager) == OK, "atomic item test creates a drafted Run")
	manager.current_run.challenger_slots.append(&"royal_bomb")
	_expect(manager.save_active_run() == OK, "test consumable is persisted before battle")
	var battle_node_id: StringName = RunTestFixture.first_battle_node_id(manager)
	_expect(not battle_node_id.is_empty(), "test route exposes a battle")
	manager.select_map_node(battle_node_id)
	manager.begin_deployment()
	manager.confirm_deployment()
	_expect(manager.start_current_battle() == OK, "test starts an active Run battle")

	var target_position: Vector2i = _first_enemy_non_king_position(manager.current_run.deployment_state)
	_expect(target_position != Vector2i(-1, -1), "battle exposes a valid bomb target")
	var battle_board: BoardState = game_state.get("board") as BoardState
	var before_target: ChessPiece = battle_board.get_piece(target_position)
	var before_run: Dictionary = manager.current_run.to_dictionary()
	var before_runtime_count: int = (game_state.get("challenger_items") as Array).size()
	game_state.connect("battle_events_emitted", _capture_events)

	var wrong_id_before: Dictionary = manager.current_run.to_dictionary()
	_expect(manager.consume_challenger_item(0, &"iron_crown") == ERR_INVALID_DATA, "mismatched item ID is rejected")
	_expect(manager.current_run.to_dictionary() == wrong_id_before, "mismatched item ID leaves Run unchanged")
	var player_king_id: int = manager.current_run.active_piece_ids[0]
	var invalid_target: Vector2i = manager.current_run.deployment_state.player_position(player_king_id)
	var invalid_use: bool = bool(game_state.call("try_use_item", 0, invalid_target))
	_expect(not invalid_use, "invalid battle target is rejected before persistence")
	_expect(manager.current_run.to_dictionary() == wrong_id_before, "invalid target leaves Run unchanged")
	_expect((game_state.get("challenger_items") as Array).size() == before_runtime_count, "invalid target leaves runtime inventory unchanged")
	emitted_events.clear()

	manager.save_service = ActiveRunSaveService.new(FAILING_PATH)
	var failed_use: bool = bool(game_state.call("try_use_item", 0, target_position))
	var failed_result: BattleCommandResult = game_state.get("last_command_result") as BattleCommandResult
	_expect(not failed_use and failed_result.error == &"run_item_persistence_failed", "save failure rejects item use")
	_expect(manager.current_run.to_dictionary() == before_run, "save failure leaves Run unchanged")
	_expect((game_state.get("challenger_items") as Array).size() == before_runtime_count, "save failure leaves runtime inventory unchanged")
	var unchanged_board: BoardState = game_state.get("board") as BoardState
	_expect(unchanged_board.get_piece(target_position) == before_target, "save failure leaves battle board unchanged")
	_expect(_has_event(BattleCommandProcessor.EVENT_ACTION_REJECTED), "save failure emits a structured rejection")
	_expect(not _has_event(BattleCommandProcessor.EVENT_ITEM_USED), "save failure emits no item-used event")
	_expect(not _has_event(BattleCommandProcessor.EVENT_EFFECT_APPLIED), "save failure applies no battle effect")

	emitted_events.clear()
	observed_target = target_position
	manager.active_run_changed.connect(_observe_atomic_publish)
	manager.save_service = ActiveRunSaveService.new(TEST_PATH)
	var successful_use: bool = bool(game_state.call("try_use_item", 0, target_position))
	_expect(successful_use, "item use succeeds after persistence is restored")
	_expect(manager.current_run.challenger_slots.is_empty(), "successful use commits Run inventory")
	_expect((game_state.get("challenger_items") as Array).is_empty(), "successful use commits runtime inventory")
	var committed_board: BoardState = game_state.get("board") as BoardState
	_expect(committed_board.get_piece(target_position) == null, "successful use publishes the staged battle effect")
	var saved_run: RunState = ActiveRunSaveService.new(TEST_PATH).load_run()
	_expect(saved_run != null and saved_run.challenger_slots.is_empty(), "successful use persists the consumed item")
	_expect(_has_event(BattleCommandProcessor.EVENT_ITEM_USED), "successful use publishes item event after persistence")
	_expect(atomic_signal_consistent, "Run observers see battle and Run inventory committed together")

	if manager.active_run_changed.is_connected(_observe_atomic_publish):
		manager.active_run_changed.disconnect(_observe_atomic_publish)
	if game_state.is_connected("battle_events_emitted", _capture_events):
		game_state.disconnect("battle_events_emitted", _capture_events)
	manager.abandon_run()
	_cleanup()
	_finish()

func _first_enemy_non_king_position(deployment: DeploymentState) -> Vector2i:
	for placement: Dictionary in deployment.enemy_placements:
		var definition: PieceDef = Content.piece(str(placement.get("piece_def_id", "")))
		if definition != null and not definition.is_king:
			return DeploymentState.position_from_value(placement.get("position", {}))
	return Vector2i(-1, -1)

func _observe_atomic_publish(run_state: RunState) -> void:
	if run_state == null or not run_state.challenger_slots.is_empty():
		return
	var game_state: Node = root.get_node("GameState")
	var runtime_items: Array = game_state.get("challenger_items") as Array
	var runtime_board: BoardState = game_state.get("board") as BoardState
	atomic_signal_consistent = runtime_items.is_empty() and runtime_board.get_piece(observed_target) == null

func _capture_events(events: Array[BattleEvent]) -> void:
	emitted_events.append_array(events)

func _has_event(event_type: StringName) -> bool:
	for event: BattleEvent in emitted_events:
		if event.event_type == event_type:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak", FAILING_PATH, FAILING_PATH + ".tmp", FAILING_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var failing_directory: String = FAILING_PATH.get_base_dir()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(failing_directory)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(failing_directory))

func _finish() -> void:
	print("[PASS] Atomic Run item use test" if not failed else "[FAIL] Atomic Run item use test")
	quit(1 if failed else 0)
