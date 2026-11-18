extends SceneTree

## Rocks: nothing stands on or targets them, sliders stop in front, leapers hop over.
## They only appear in the middle rows, mirrored, more of them deeper in the map.

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var board: BoardState = BoardState.new(8, false)
	board.clear_for_setup()
	board.place_piece_for_setup(Vector2i(0, 0), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(7, 7), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.BLACK))
	board.place_piece_for_setup(Vector2i(3, 0), ChessPiece.new(PieceDefDatabase.get_def("rook"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(4, 2), ChessPiece.new(PieceDefDatabase.get_def("knight"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(3, 6), ChessPiece.new(PieceDefDatabase.get_def("pawn"), GameRules.PieceColor.BLACK))
	board.finalize_setup(GameRules.PieceColor.WHITE)
	board.set_rocks([Vector2i(3, 3), Vector2i(5, 4), Vector2i(0, 0)])
	_expect(board.is_rock(Vector2i(3, 3)) and not board.is_rock(Vector2i(0, 0)), "rocks never bury a piece")
	var rook_moves: Array[Vector2i] = board.get_executable_moves(Vector2i(3, 0))
	_expect(Vector2i(3, 2) in rook_moves and Vector2i(3, 3) not in rook_moves and Vector2i(3, 4) not in rook_moves, "a rook stops in front of a rock")
	_expect(Vector2i(3, 6) not in MoveGenerator.get_attack_squares(board, Vector2i(3, 0)), "a rock blocks a slider's line of attack")
	var knight_moves: Array[Vector2i] = board.get_executable_moves(Vector2i(4, 2))
	_expect(Vector2i(5, 4) not in knight_moves and Vector2i(3, 4) in knight_moves, "a knight cannot land on a rock but hops past others")
	var copy: BoardState = board.clone()
	_expect(copy.is_rock(Vector2i(3, 3)), "AI copies of the board keep the rocks")
	var portal: BoardState = BoardState.new(8, false)
	portal.clear_for_setup()
	portal.place_piece_for_setup(Vector2i(0, 0), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.WHITE))
	portal.place_piece_for_setup(Vector2i(7, 7), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.BLACK))
	portal.place_piece_for_setup(Vector2i(2, 0), ChessPiece.new(PieceDefDatabase.get_def("portal_mage"), GameRules.PieceColor.WHITE))
	portal.finalize_setup(GameRules.PieceColor.WHITE)
	portal.set_rocks([Vector2i(4, 4)])
	_expect(Vector2i(4, 4) not in MoveGenerator.generate_pseudo_legal(portal, Vector2i(2, 0)), "teleporting pieces cannot land on a rock")
	portal.clear_for_setup()
	_expect(portal.rocks.is_empty(), "a fresh setup clears old rocks")

	# Layout.
	_expect(RockLayout.generate(1, 0, 7).is_empty(), "the first battle has no rocks")
	var seen_any: bool = false
	var most: int = 0
	for seed_value: int in range(200):
		for layer: int in range(1, 7):
			var rocks: Array[Vector2i] = RockLayout.generate(seed_value, layer, 7)
			most = maxi(most, rocks.size())
			seen_any = seen_any or not rocks.is_empty()
			for rock: Vector2i in rocks:
				if rock.y < DeploymentState.PLAYER_ROWS or rock.y >= 8 - DeploymentState.PLAYER_ROWS:
					_expect(false, "rock %s sits inside a deployment zone" % rock)
				if Vector2i(7 - rock.x, 7 - rock.y) not in rocks:
					_expect(false, "rock %s has no mirrored twin" % rock)
	_expect(seen_any and most <= 4, "rocks appear, at most two mirrored pairs")
	_expect(RockLayout.generate(42, 5, 7) == RockLayout.generate(42, 5, 7), "the same seed gives the same rocks")
	var late: int = 0
	var early: int = 0
	for seed_value: int in range(200):
		early += RockLayout.generate(seed_value, 1, 7).size()
		late += RockLayout.generate(seed_value, 6, 7).size()
	_expect(late > early, "deeper battles have more rocks")

	# Saved with the deployment.
	var deployment: DeploymentState = DeploymentState.new()
	deployment.rocks = [Vector2i(2, 3), Vector2i(5, 4)]
	var restored: DeploymentState = DeploymentState.new()
	restored.load_from_dictionary(deployment.to_dictionary(), null)
	_expect(restored.rocks == deployment.rocks, "rocks are saved and restored with the battle")
	print("[PASS] Rocks test" if not failed else "[FAIL] Rocks test")
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)
