extends SceneTree

var failed: bool = false

func _init() -> void:
	var state_script: Script = load("res://scripts/run/RunState.gd") as Script
	var state: RefCounted = state_script.new() as RefCounted
	state.call("initialize_new", 922337203685477000, "standard")
	var king: RefCounted = state.call("allocate_piece", "king", true) as RefCounted
	var rook: RefCounted = state.call("allocate_piece", "rook", false) as RefCounted
	state.call("move_piece_to_active", int(rook.get("instance_id")))
	state.set("gold", 125)
	state.set("rng_stream_states", {"map_rng": 9876543210123456})

	_expect(int(king.get("instance_id")) == 1, "new Run owns deterministic piece IDs")
	_expect(bool(king.get("is_king")), "initial king identity is persistent")
	_expect(int(rook.get("instance_id")) == 2, "piece allocator is monotonic")
	_expect(state.call("is_valid"), "new populated RunState validates")

	var serialized: Dictionary = state.call("to_dictionary") as Dictionary
	var restored: RefCounted = state_script.new() as RefCounted
	_expect(restored.call("load_from_dictionary", serialized), "RunState loads its serialized dictionary")
	_expect(restored.call("to_dictionary") == serialized, "RunState round-trip is structurally identical")
	_expect(int(restored.get("run_seed")) == 922337203685477000, "64-bit Run seed survives round-trip")
	_expect(int((restored.get("rng_stream_states") as Dictionary)["map_rng"]) == 9876543210123456, "64-bit RNG state survives round-trip")

	var bishop: RefCounted = restored.call("allocate_piece", "bishop", false) as RefCounted
	_expect(int(bishop.get("instance_id")) == 3, "restored allocator never reuses piece IDs")

	var prior_piece: ChessPiece = ChessPiece.new(Content.piece("queen"), GameRules.PieceColor.WHITE)
	var second_state: RefCounted = state_script.new() as RefCounted
	second_state.call("initialize_new", 922337203685477000, "standard")
	var second_king: RefCounted = second_state.call("allocate_piece", "king", true) as RefCounted
	_expect(prior_piece.instance_id > 0 and int(second_king.get("instance_id")) == 1, "Run IDs ignore transient ChessPiece allocation")

	var clean_a: RefCounted = state_script.new() as RefCounted
	var clean_b: RefCounted = state_script.new() as RefCounted
	clean_a.call("initialize_new", 42424242, "standard")
	clean_b.call("initialize_new", 42424242, "standard")
	var clean_rng_a: RunRngService = RunRngService.new()
	var clean_rng_b: RunRngService = RunRngService.new()
	clean_rng_a.initialize(42424242)
	clean_rng_b.initialize(42424242)
	clean_a.set("rng_stream_states", clean_rng_a.snapshot_states())
	clean_b.set("rng_stream_states", clean_rng_b.snapshot_states())
	var clean_king_a: RefCounted = clean_a.call("allocate_piece", "king", true) as RefCounted
	clean_b.call("allocate_piece", "king", true)
	_expect(clean_a.call("to_dictionary") == clean_b.call("to_dictionary"), "same seed creates structurally equal blank Runs")
	_expect(clean_a.call("allocate_piece", "missing_piece", false) == null, "unknown piece definition IDs are rejected")
	var deployed_king: ChessPiece = clean_king_a.call("to_chess_piece", GameRules.PieceColor.WHITE) as ChessPiece
	_expect(deployed_king != null and deployed_king.instance_id == 1, "persistent piece identity bridges into battle ChessPiece")

	var invalid_data: Dictionary = serialized.duplicate(true)
	invalid_data["run_version"] = 999
	var invalid_state: RefCounted = state_script.new() as RefCounted
	_expect(not invalid_state.call("load_from_dictionary", invalid_data), "unsupported Run version is rejected")
	var unknown_item_data: Dictionary = serialized.duplicate(true)
	unknown_item_data["challenger_slots"] = ["removed_item"]
	var unknown_item_state: RefCounted = state_script.new() as RefCounted
	_expect(not unknown_item_state.call("load_from_dictionary", unknown_item_data), "unknown challenger item IDs are rejected")

	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _finish() -> void:
	print("[PASS] RunState test" if not failed else "[FAIL] RunState test")
	quit(1 if failed else 0)
