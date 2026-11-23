extends Node

signal battle_events_emitted(events: Array[BattleEvent])
signal debug_mode_changed(enabled: bool)

## 全局游戏状态单例。
## 当前持有对局棋盘和挑战者物品；后续 Roguelike 阶段将在此扩展金币、遗物、招募棋子与波次等状态。
var board: BoardState = null
## Hand-off from the pre-battle screen: where its board stood on screen and a picture
## of that last frame, so the battle board can grow out of it without a cut.
var entry_board_rect: Rect2 = Rect2()
var entry_snapshot: Texture2D = null
var command_processor: BattleCommandProcessor = null
var last_command_result: BattleCommandResult = null
## The current run battle written down move by move (null outside run battles); the
## battle menu copies it as a battle code so a bug can be replayed exactly.
var battle_record: BattleRecord = null
var _staged_target: Vector2i = Vector2i(-1, -1)

## Persistent and consumable objects share the same challenger inventory.
var challenger_items: Array[ChallengerItemDef] = []

## 玩家在 Roguelike 对局中控制的一方。
var player_color: int = GameRules.PieceColor.WHITE

## How hard the enemy plays in the current battle (EnemyMoveSelector.DIFFICULTY_*):
## the journey's choice for a run battle, Easy otherwise.
var ai_difficulty: String = EnemyMoveSelector.DIFFICULTY_EASY

## Developer access is intentionally session-only and resets on every launch.
var debug_mode: bool = false

func _ready() -> void:
	start_new_game()

func enable_debug_mode() -> void:
	if not OS.is_debug_build():
		return
	if debug_mode:
		return
	debug_mode = true
	debug_mode_changed.emit(true)

func reset_debug_mode() -> void:
	if not debug_mode:
		return
	debug_mode = false
	debug_mode_changed.emit(false)

func start_new_game() -> void:
	ai_difficulty = EnemyMoveSelector.DIFFICULTY_EASY
	board = BoardState.new()
	challenger_items.clear()
	command_processor = BattleCommandProcessor.new(board, challenger_items, player_color)
	last_command_result = null
	battle_record = null

func start_run_battle(run_state: RunState) -> bool:
	if run_state == null or run_state.phase != RunPhase.BATTLE_ACTIVE or run_state.deployment_state == null:
		return false
	var deployment: DeploymentState = run_state.deployment_state
	if not deployment.confirmed or not deployment.is_valid(run_state):
		return false
	var run_board: BoardState = BoardState.new(deployment.board_size, false)
	run_board.clear_for_setup()
	for instance_id: int in run_state.active_piece_ids:
		var piece_state: PieceInstanceState = run_state.get_piece_state(instance_id)
		var definition: PieceDef = Content.piece(String(piece_state.piece_def_id)) if piece_state != null else null
		if definition == null:
			return false
		var runtime_piece: ChessPiece = ChessPiece.create_with_instance_id(definition, player_color, instance_id)
		piece_state.apply_growth_to(runtime_piece)
		if not run_board.place_piece_for_setup(deployment.player_position(instance_id), runtime_piece):
			return false
	for enemy_placement: Dictionary in deployment.enemy_placements:
		var enemy_definition: PieceDef = Content.piece(str(enemy_placement.get("piece_def_id", "")))
		var enemy_position: Vector2i = DeploymentState.position_from_value(enemy_placement.get("position", {}))
		if enemy_definition == null or not run_board.place_piece_for_setup(enemy_position, ChessPiece.new(enemy_definition, GameRules.PieceColor.BLACK)):
			return false
	if not run_board.finalize_setup(player_color):
		return false
	run_board.set_rocks(deployment.rocks)
	challenger_items.clear()
	for item_id: StringName in run_state.challenger_slots:
		var item_definition: ChallengerItemDef = Content.challenger_item(item_id)
		if item_definition == null:
			return false
		challenger_items.append(item_definition)
	ai_difficulty = run_state.ai_difficulty
	var turn_limit: int = 0
	var encounter: EncounterDef = EncounterGenerator.encounter_for_current(run_state)
	if encounter != null:
		turn_limit = encounter.turn_limit
	var node: MapNodeState = run_state.map_state.get_node(run_state.current_node_id) if run_state.map_state != null else null
	var record: BattleRecord = BattleRecord.from_setup(run_board, challenger_items, player_color, turn_limit, {
		"seed": run_state.run_seed,
		"act": run_state.act_index + 1,
		"node": String(node.node_type_id) if node != null else "?",
		"enc": String(encounter.id) if encounter != null else "?",
	})
	return start_recorded_battle(record)

## Sets up a battle from a record (a run battle, or a pasted battle code in debug mode):
## the very same setup the replay tool uses.
func start_recorded_battle(record: BattleRecord) -> bool:
	var built: Dictionary = record.build() if record != null else {"error": "no record"}
	if built.has("error"):
		push_warning("Battle setup failed: %s" % built["error"])
		return false
	board = built["board"]
	command_processor = built["processor"]
	challenger_items = command_processor.challenger_items
	player_color = record.player_color
	battle_record = record
	last_command_result = null
	return true

## The battle so far as a code to paste: line-up, every move, and a snapshot of now.
## `view_issues` are squares the screen shows differently from the rules.
func battle_code(view_issues: Array[String] = []) -> String:
	if battle_record == null:
		return ""
	return battle_record.encode(board, view_issues)

## 尝试走一步棋，返回 true 表示成功。
## UI 与 AI 都通过此入口执行合法性校验、更新状态并广播事件。
func execute_battle_action(action: BattleAction) -> BattleCommandResult:
	if board == null:
		last_command_result = BattleCommandResult.rejected(&"missing_board")
		return last_command_result
	if command_processor == null or command_processor.board != board:
		command_processor = BattleCommandProcessor.new(board, challenger_items, player_color)
	var target_was_occupied: bool = action is MoveAction and board.get_piece((action as MoveAction).to) != null
	last_command_result = command_processor.execute(action)
	if last_command_result.success and battle_record != null:
		battle_record.add_action(action, board, target_was_occupied)
	_publish_command_result(last_command_result)
	return last_command_result

func can_use_challenger_item(slot_index: int) -> bool:
	return command_processor != null and command_processor.can_use_item(slot_index, player_color)

func try_use_item(slot_index: int, target_position: Vector2i = Vector2i(-1, -1)) -> bool:
	var action: UseItemAction = UseItemAction.new(slot_index, player_color, target_position)
	var manager: AppRunManager = get_node_or_null("/root/RunManager") as AppRunManager
	if manager == null or manager.current_run == null:
		return execute_battle_action(action).success
	if command_processor == null or command_processor.board != board:
		last_command_result = BattleCommandResult.rejected(&"missing_command_processor")
		_publish_command_result(last_command_result)
		return false
	_staged_target = target_position
	var plan: BattleItemUsePlan = command_processor.stage_item_use(action)
	if plan == null or not plan.is_valid():
		return execute_battle_action(action).success
	var consume_error: Error = manager.consume_challenger_item(
		plan.slot_index,
		plan.expected_item_id,
		_commit_staged_item_plan.bind(plan)
	)
	if consume_error != OK:
		push_warning("Saving the used item failed: %s" % error_string(consume_error))
		last_command_result = command_processor.reject_external(&"run_item_persistence_failed")
		_publish_command_result(last_command_result)
		return false
	_publish_command_result(last_command_result)
	return true

func _commit_staged_item_plan(plan: BattleItemUsePlan) -> void:
	board = plan.staged_board
	challenger_items = plan.staged_items
	command_processor = plan.staged_processor
	last_command_result = plan.result
	if battle_record != null:
		battle_record.add_action(UseItemAction.new(plan.slot_index, player_color, _staged_target), board)

func _publish_command_result(result: BattleCommandResult) -> void:
	if result != null:
		battle_events_emitted.emit(result.events)

func is_battle_finished() -> bool:
	return command_processor != null and command_processor.status.is_finished()

func evaluate_battle_terminal_state() -> bool:
	if command_processor == null:
		return false
	var result: BattleCommandResult = command_processor.evaluate_terminal_state()
	if result == null:
		return false
	last_command_result = result
	if battle_record != null:
		battle_record.add_line("=", board)
	_publish_command_result(result)
	return result.success

func force_debug_victory() -> bool:
	if not OS.is_debug_build() or not debug_mode or command_processor == null:
		return false
	var result: BattleCommandResult = command_processor.force_finish(player_color, false, &"debug_victory")
	last_command_result = result
	if result.success and battle_record != null:
		battle_record.add_line("win", board)
	_publish_command_result(result)
	return result.success

## Gives up the remaining bonus action (assassin, courier), or a turn in which no piece
## can move, and passes the turn.
func try_end_turn() -> bool:
	if board == null or command_processor == null or not command_processor.can_end_turn(player_color):
		return false
	return execute_battle_action(EndTurnAction.new(player_color)).success

func try_move(from: Vector2i, to: Vector2i, promotion_id: String = "queen") -> bool:
	if board == null:
		return false
	var moving_piece: ChessPiece = board.get_piece(from)
	var actor_color: int = moving_piece.color if moving_piece != null else board.turn
	var action: MoveAction = MoveAction.new(from, to, actor_color, promotion_id)
	return execute_battle_action(action).success
