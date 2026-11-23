extends SceneTree

## Locks the strike animations frame by frame, so they can be restructured without
## changing what the player sees. Every attacker and victim pairing of
## StrikePresentationSuite plays with a fixed random seed and a fixed time step; each
## frame records every sprite on the piece layer (transform, colour, visibility and
## shader parameters), the board camera, every live effect particle, and the frames on
## which the strike lands, splits its victim and finishes. Each pairing's record is
## hashed and compared with strike_golden_trace.json.
##
## Known limit: lines and shapes the strike draws straight onto the ground and air
## canvases (slashes, projectiles, beams) are not recorded, because a headless run has
## no way to read canvas draw commands back. Check those by eye with
## scripts/visual_review/capture_new_strikes.gd when changing strike code.
##
## After an intended animation change, regenerate the record:
##   Godot --headless --path . --script res://scripts/tests/scenes/test_strike_golden_trace.gd -- --update

const GOLDEN_PATH := "res://scripts/tests/support/strike_golden_trace.json"
const FRAME_SECONDS := 1.0 / 30.0
const SPEED := 1.0
const MAX_FRAMES := 400
const W := GameRules.PieceColor.WHITE
const B := GameRules.PieceColor.BLACK

var failed: bool = false
var _frame: int = 0
var _moments: PackedFloat64Array = PackedFloat64Array()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var update: bool = "--update" in OS.get_cmdline_user_args()
	root.get_node("GameState").call("start_new_game")
	var battle: Node = (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	await process_frame
	var view: BattleBoardView = battle.get_node("Margin/Layout/BoardFrame") as BattleBoardView
	var director: StrikeDirector = view.get_node("StrikeDirector") as StrikeDirector
	director.impacted.connect(func() -> void: _moments.append_array([1.0, _frame]))
	director.victim_split.connect(func() -> void: _moments.append_array([2.0, _frame]))
	director.finished.connect(func() -> void: _moments.append_array([3.0, _frame]))
	var start_board: BoardState = (root.get_node("GameState").get("board") as BoardState).clone_runtime()
	var traces: Dictionary = {}
	for scenario: Dictionary in _scenarios():
		var board: BoardState = scenario.get("board", start_board) as BoardState
		view.refresh(board.clone_runtime())
		traces[scenario["key"]] = _trace(view, director, scenario["key"], scenario["events"])
	if update:
		var file: FileAccess = FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(traces, "\t", true) + "\n")
		file.close()
		print("[PASS] Wrote %d strike traces to %s" % [traces.size(), GOLDEN_PATH])
		quit(0)
		return
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH)) as Dictionary
	_expect(golden != null and not golden.is_empty(), "the golden strike traces load")
	if golden == null:
		quit(1)
		return
	var changed: Array[String] = []
	for key: String in traces:
		if str(golden.get(key, "")) != str(traces[key]):
			changed.append(key)
	var missing: Array[String] = []
	for key: String in golden:
		if not traces.has(key):
			missing.append(key)
	_expect(changed.is_empty(), "every strike plays exactly as recorded (%d of %d changed: %s)" % [changed.size(), traces.size(), ", ".join(changed.slice(0, 12))])
	_expect(missing.is_empty(), "every recorded strike is still played: %s" % [missing])
	print("[PASS] Strike golden trace" if not failed else "[FAIL] Strike golden trace")
	quit(1 if failed else 0)

## Plays one strike to the end with a fixed step and returns the hash of its record.
func _trace(view: BattleBoardView, director: StrikeDirector, key: String, events: Array[BattleEvent]) -> String:
	seed(hash(key))
	_moments = PackedFloat64Array()
	_frame = 0
	view.present_events(events, SPEED)
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	while _frame < MAX_FRAMES:
		_frame += 1
		# The main strike and any echo strikes (extra boomerang victims), in tree order.
		var directors: Array[StrikeDirector] = _directors(view)
		for each: StrikeDirector in directors:
			each.set_process(false)
			each._process(FRAME_SECONDS)
		hashing.update(_frame_record(view, directors).to_byte_array())
		if not view.is_presenting() and not director.is_playing() and director.fx.is_empty():
			break
	hashing.update(_moments.to_byte_array())
	hashing.update(PackedFloat64Array([_frame]).to_byte_array())
	view.skip_presentations()
	for each: StrikeDirector in _directors(view):
		each.set_process(true)
	return hashing.finish().hex_encode()

func _directors(view: BattleBoardView) -> Array[StrikeDirector]:
	var directors: Array[StrikeDirector] = []
	for child: Node in view.get_children():
		if child is StrikeDirector and not child.is_queued_for_deletion():
			directors.append(child as StrikeDirector)
	return directors

func _frame_record(view: BattleBoardView, directors: Array[StrikeDirector]) -> PackedFloat64Array:
	var record: PackedFloat64Array = PackedFloat64Array()
	for each: StrikeDirector in directors:
		record.append(1.0 if each.is_playing() else 0.0)
	var layer: Node2D = view.piece_layer()
	_append_transform(record, layer.transform)
	_append_transform(record, view.ground_canvas().transform)
	for child: Node in layer.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null:
			continue
		if sprite.is_queued_for_deletion():
			continue
		record.append_array([sprite.position.x, sprite.position.y, sprite.scale.x, sprite.scale.y, sprite.rotation])
		record.append_array([sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, sprite.modulate.a, sprite.self_modulate.a])
		record.append_array([1.0 if sprite.visible else 0.0, sprite.z_index, sprite.offset.x, sprite.offset.y, 1.0 if sprite.flip_h else 0.0])
		_append_material(record, sprite.material as ShaderMaterial)
	for each: StrikeDirector in directors:
		_append_fx(record, each.fx)
	return record

func _append_fx(record: PackedFloat64Array, fx: StrikeFx) -> void:
	record.append_array([fx.parts.size(), fx.sparks.size(), fx.rings.size(), fx.smoke.size(), fx.decals.size()])
	for part: StrikeFx.Part in fx.parts:
		record.append_array([part.pos.x, part.pos.y, part.pos.z, part.age, part.size])
	for spark: StrikeFx.Spark in fx.sparks:
		record.append_array([spark.pos.x, spark.pos.y, spark.pos.z, spark.age])
	for ring: StrikeFx.Ring in fx.rings:
		record.append_array([ring.x, ring.z, ring.max_radius, ring.age])
	for puff: StrikeFx.Smoke in fx.smoke:
		record.append_array([puff.pos.x, puff.pos.y, puff.pos.z, puff.radius, puff.age])
	for crack: StrikeFx.Crack in fx.decals:
		record.append_array([crack.points.size(), crack.age])

func _append_transform(record: PackedFloat64Array, transform: Transform2D) -> void:
	record.append_array([transform.x.x, transform.x.y, transform.y.x, transform.y.y, transform.origin.x, transform.origin.y])

func _append_material(record: PackedFloat64Array, material: ShaderMaterial) -> void:
	if material == null or material.shader == null:
		record.append(-1.0)
		return
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		var value: Variant = material.get_shader_parameter(StringName(uniform["name"]))
		match typeof(value):
			TYPE_FLOAT, TYPE_INT:
				record.append(float(value))
			TYPE_BOOL:
				record.append(1.0 if value else 0.0)
			TYPE_VECTOR2:
				record.append_array([value.x, value.y])
			TYPE_VECTOR3:
				record.append_array([value.x, value.y, value.z])
			TYPE_VECTOR4, TYPE_COLOR, TYPE_RECT2:
				var packed: PackedFloat64Array = PackedFloat64Array()
				if value is Color:
					packed = PackedFloat64Array([value.r, value.g, value.b, value.a])
				elif value is Rect2:
					packed = PackedFloat64Array([value.position.x, value.position.y, value.size.x, value.size.y])
				else:
					packed = PackedFloat64Array([value.x, value.y, value.z, value.w])
				record.append_array(packed)
			TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
				for item: Variant in value:
					record.append(float(item))

# --- scenarios ------------------------------------------------------------------

func _scenarios() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for attacker: String in StrikePresentationSuite.PIECES:
		for victim: String in StrikePresentationSuite.PIECES:
			var to: Vector2i = Vector2i(3, 4) if attacker == "knight" else Vector2i(3, 3)
			result.append(_capture("core/%s>%s" % [attacker, victim], attacker, to, to, victim))
	for attacker: String in StrikePresentationSuite.SPECIAL_MOVES:
		for to: Vector2i in StrikePresentationSuite.SPECIAL_MOVES[attacker]:
			for victim: String in StrikePresentationSuite.SPECIAL_VICTIMS:
				result.append(_capture("special/%s@%d%d>%s" % [attacker, to.x, to.y, victim], attacker, to, to, victim))
	for attacker: String in StrikePresentationSuite.NEW_MOVES:
		var landing: Vector2i = StrikePresentationSuite.NEW_MOVES[attacker][0]
		var target: Vector2i = StrikePresentationSuite.NEW_MOVES[attacker][1]
		for victim: String in StrikePresentationSuite.NEW_VICTIMS:
			result.append(_capture("new/%s>%s" % [attacker, victim], attacker, landing, target, victim))
	for shelled: String in StrikePresentationSuite.SHELL_VICTIMS:
		var board: BoardState = BoardState.new()
		board.clear_for_setup()
		board.place_piece_for_setup(Vector2i(4, 0), ChessPiece.new(Content.piece("king"), W))
		board.place_piece_for_setup(Vector2i(4, 7), ChessPiece.new(Content.piece("king"), B))
		board.place_piece_for_setup(Vector2i(2, 2), ChessPiece.new(Content.piece("rook"), W))
		board.place_piece_for_setup(Vector2i(2, 5), ChessPiece.new(Content.piece(shelled), B))
		result.append({"key": "shell/rook>%s" % shelled, "board": board, "events": [
			BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": Vector2i(2, 2), "to": Vector2i(2, 2), "target": Vector2i(2, 5), "piece_def_id": "rook", "color": W}),
			BattleEvent.new(BattleCommandProcessor.EVENT_SHELL_BROKEN, 2, 1, {"position": Vector2i(2, 5), "left": 0}),
		] as Array[BattleEvent]})
	# A boomerang through three enemies: the main strike and two echo strikes.
	result.append({"key": "echo/ranger", "events": [
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": Vector2i(2, 1), "to": Vector2i(2, 1), "target": Vector2i(2, 3), "piece_def_id": "ranger", "color": W, "ranged": true}),
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_CAPTURED, 2, 1, {"position": Vector2i(2, 3), "piece_def_id": "pawn", "color": B}),
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_DESTROYED, 3, 1, {"position": Vector2i(2, 4), "piece_def_id": "knight", "color": B, "cause": "pierce"}),
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_DESTROYED, 4, 1, {"position": Vector2i(2, 5), "piece_def_id": "rook", "color": B, "cause": "pierce"}),
	] as Array[BattleEvent]})
	return result

func _capture(key: String, attacker: String, landing: Vector2i, target: Vector2i, victim: String) -> Dictionary:
	return {"key": key, "events": [
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": Vector2i(2, 2), "to": landing, "target": target, "piece_def_id": attacker, "color": W}),
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_CAPTURED, 2, 1, {"position": target, "piece_def_id": victim, "color": B}),
	] as Array[BattleEvent]}

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)
