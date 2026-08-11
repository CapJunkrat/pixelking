extends Node

## 全局游戏状态单例。
## 当前持有对局棋盘和挑战者物品；后续 Roguelike 阶段将在此扩展金币、遗物、招募棋子与波次等状态。
var board: BoardState = null
var command_processor: BattleCommandProcessor = null
var last_command_result: BattleCommandResult = null

## Persistent and consumable objects share the same challenger inventory.
var challenger_items: Array[ChallengerItemDef] = []

## 玩家在 Roguelike 对局中控制的一方。
var player_color: int = GameRules.PieceColor.WHITE

func _ready() -> void:
	start_new_game()

func start_new_game() -> void:
	board = BoardState.new()
	board.remove_all_pawns()
	challenger_items.clear()
	command_processor = BattleCommandProcessor.new(board)
	last_command_result = null

func start_run_battle(run_state: RunState) -> bool:
	if run_state == null or run_state.deployment_state == null:
		return false
	var deployment: DeploymentState = run_state.deployment_state
	if not deployment.confirmed or not deployment.is_valid(run_state):
		return false
	var run_board: BoardState = BoardState.new(deployment.board_size, false)
	run_board.clear_for_setup()
	for instance_id: int in run_state.active_piece_ids:
		var piece_state: PieceInstanceState = run_state.get_piece_state(instance_id)
		var definition: PieceDef = PieceDefDatabase.get_def(String(piece_state.piece_def_id)) if piece_state != null else null
		if definition == null:
			return false
		var runtime_piece: ChessPiece = ChessPiece.create_with_instance_id(definition, player_color, instance_id)
		if not run_board.place_piece_for_setup(deployment.player_position(instance_id), runtime_piece):
			return false
	for enemy_placement: Dictionary in deployment.enemy_placements:
		var enemy_definition: PieceDef = PieceDefDatabase.get_def(str(enemy_placement.get("piece_def_id", "")))
		var enemy_position: Vector2i = DeploymentState.position_from_value(enemy_placement.get("position", {}))
		if enemy_definition == null or not run_board.place_piece_for_setup(enemy_position, ChessPiece.new(enemy_definition, GameRules.PieceColor.BLACK)):
			return false
	if not run_board.finalize_setup(player_color):
		return false
	board = run_board
	challenger_items.clear()
	command_processor = BattleCommandProcessor.new(board)
	last_command_result = null
	return true

## 尝试走一步棋，返回 true 表示成功。
## UI 与 AI 都通过此入口执行合法性校验、更新状态并广播事件。
func execute_battle_action(action: BattleAction) -> BattleCommandResult:
	if board == null:
		last_command_result = BattleCommandResult.rejected(&"missing_board")
		return last_command_result
	if command_processor == null or command_processor.board != board:
		command_processor = BattleCommandProcessor.new(board)
	last_command_result = command_processor.execute(action)
	return last_command_result

func try_move(from: Vector2i, to: Vector2i, promotion_id: String = "queen") -> bool:
	if board == null:
		return false
	var moving_piece: ChessPiece = board.get_piece(from)
	var actor_color: int = moving_piece.color if moving_piece != null else board.turn
	var action: MoveAction = MoveAction.new(from, to, actor_color, promotion_id)
	var command_result: BattleCommandResult = execute_battle_action(action)
	if not command_result.success:
		return false
	var result: Dictionary = command_result.legacy_result

	# Compatibility bridge for presentation code while battle-local domain events
	# become the authoritative Phase F stream.
	EventBus.move_made.emit(from, to, result)
	EventBus.turn_changed.emit(board.turn)
	if bool(result.get("checkmate", false)):
		EventBus.checkmate.emit(board.turn)
	elif bool(result.get("stalemate", false)):
		EventBus.stalemate.emit(board.turn)
	elif bool(result.get("check", false)):
		EventBus.check_declared.emit(board.turn)
	return true
