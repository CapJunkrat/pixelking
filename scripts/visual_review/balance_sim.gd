extends SceneTree

## Plays the enemy AI against itself on generated encounters and prints how often the
## player's side wins at each map layer, to tune EncounterGenerator's budget curve.
##   Godot --headless --path . --script res://scripts/visual_review/balance_sim.gd -- [games per layer]
## The player's army is modelled as a typical Run: three drafted pieces, then one more
## piece (of the layer's tier) after each battle, up to a full battle line.

const TOTAL_LAYERS := 7
const MAX_PLIES := 160
const DRAFT: Array[String] = ["knight", "bishop", "vanguard", "sentry", "powder_keg", "rook", "squire", "tide_knight"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var games: int = int(args[0]) if args.size() > 0 else 20
	var selector: EnemyMoveSelector = EnemyMoveSelector.new()
	for tier: StringName in [&"normal", &"elite"]:
		for layer: int in range(TOTAL_LAYERS - 1):
			if tier == &"elite" and layer < 2:
				continue
			var wins: int = 0
			var losses: int = 0
			var plies_total: int = 0
			var player_strength_total: int = 0
			var enemy_strength_total: int = 0
			for game: int in range(games):
				var rng: RandomNumberGenerator = RandomNumberGenerator.new()
				rng.seed = layer * 1000 + game + (500000 if tier == &"elite" else 0)
				var run: RunState = _player_run(layer, rng)
				var strength: int = EncounterGenerator.player_strength(run)
				var enemies: Array[Dictionary] = EncounterGenerator.generate(tier, layer, TOTAL_LAYERS, rng.randi(), strength)
				player_strength_total += strength
				for placement: Dictionary in enemies:
					var id: String = str(placement["piece_def_id"])
					if id != "king":
						enemy_strength_total += PieceDefDatabase.get_def(id).base_value
				var started: int = Time.get_ticks_msec()
				var outcome: Array = _play(run, enemies, selector)
				if OS.get_environment("SIM_VERBOSE") == "1":
					print("  game %d: %d plies, %d ms, winner %d" % [game, int(outcome[1]), Time.get_ticks_msec() - started, int(outcome[0])])
				plies_total += int(outcome[1])
				if int(outcome[0]) == GameRules.PieceColor.WHITE:
					wins += 1
				elif int(outcome[0]) == GameRules.PieceColor.BLACK:
					losses += 1
			print("%s layer %d: player %4.1f vs enemy %4.1f strength | player wins %3d%%, loses %3d%%, draws %3d%% | %d plies" % [
				tier, layer + 1, float(player_strength_total) / games, float(enemy_strength_total) / games,
				roundi(100.0 * wins / games), roundi(100.0 * losses / games), roundi(100.0 * (games - wins - losses) / games), plies_total / games])
	quit()

func _player_run(layer: int, rng: RandomNumberGenerator) -> RunState:
	var run: RunState = RunState.new()
	run.initialize_new(rng.randi())
	run.allocate_piece("king", true)
	for _i: int in range(3):
		run.allocate_piece(DRAFT[rng.randi_range(0, DRAFT.size() - 1)], false)
	# One reward piece per earlier battle, drawn from what that layer offers.
	for earlier: int in range(layer):
		var pool: Array[String] = []
		for band: Dictionary in EncounterGenerator.POOLS:
			if EncounterGenerator.progress(earlier, TOTAL_LAYERS) >= float(band["from"]):
				for id: String in band["ids"]:
					pool.append(id)
		run.allocate_piece(pool[rng.randi_range(0, pool.size() - 1)], false)
	return run

## Returns [winner colour or -1, plies played].
func _play(run: RunState, enemies: Array[Dictionary], selector: EnemyMoveSelector) -> Array:
	var board: BoardState = BoardState.new(8, false)
	board.clear_for_setup()
	var formation: Dictionary = DeploymentFormation.arrange(run, 8)
	for instance_id: int in run.active_piece_ids:
		var piece: PieceInstanceState = run.get_piece_state(instance_id)
		board.place_piece_for_setup(formation[instance_id], piece.to_chess_piece(GameRules.PieceColor.WHITE))
	for placement: Dictionary in enemies:
		var square: Vector2i = DeploymentState.position_from_value(placement["position"])
		board.place_piece_for_setup(square, ChessPiece.new(PieceDefDatabase.get_def(str(placement["piece_def_id"])), GameRules.PieceColor.BLACK))
	board.finalize_setup(GameRules.PieceColor.WHITE)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	processor.shield_kings_for_opening()
	var plies: int = 0
	while not processor.status.is_finished() and plies < MAX_PLIES:
		var action: MoveAction = selector.choose_action(board, board.turn)
		if action == null:
			processor.evaluate_terminal_state()
			break
		processor.execute(action)
		plies += 1
	if processor.status.is_finished():
		return [processor.status.winner if not processor.status.draw else -1, plies]
	# Undecided after the move cap: whoever is clearly ahead on material wins.
	var lead: int = _material(board, GameRules.PieceColor.WHITE) - _material(board, GameRules.PieceColor.BLACK)
	return [GameRules.PieceColor.WHITE if lead > 3 else (GameRules.PieceColor.BLACK if lead < -3 else -1), plies]

func _material(board: BoardState, color: int) -> int:
	var total: int = 0
	for x: int in range(board.board_size):
		for y: int in range(board.board_size):
			var piece: ChessPiece = board.get_piece(Vector2i(x, y))
			if piece != null and piece.color == color and not piece.def.is_king:
				total += piece.def.base_value
	return total
