extends SceneTree

## Renders the strike animations of the new pieces and saves one frame strip per
## attacker, for checking each animation against its description by eye.
##
## Needs a real renderer (not --headless):
##   Godot --path . --fixed-fps 30 --resolution 360x640 \
##       --script res://scripts/visual_review/capture_new_strikes.gd -- <output folder> [attacker ...]

const FROM := Vector2i(2, 2)
## attacker -> [destination, capture square]; ranged attackers stay on FROM.
const MOVES: Dictionary = {
	"swift_courier": [Vector2i(4, 4), Vector2i(4, 4)], "tide_knight": [Vector2i(3, 4), Vector2i(3, 4)],
	"echo": [Vector2i(3, 3), Vector2i(3, 3)], "chameleon": [Vector2i(3, 3), Vector2i(3, 3)],
	"sentry": [Vector2i(2, 4), Vector2i(2, 4)], "falconer": [Vector2i(2, 2), Vector2i(2, 5)],
	"vanguard": [Vector2i(3, 3), Vector2i(3, 3)], "squire": [Vector2i(3, 3), Vector2i(3, 3)],
	"stand_in": [Vector2i(4, 4), Vector2i(4, 4)], "powder_keg": [Vector2i(3, 3), Vector2i(3, 3)],
	"ember_bird": [Vector2i(4, 4), Vector2i(4, 4)], "gargoyle": [Vector2i(2, 2), Vector2i(2, 4)],
	"crystal_mage": [Vector2i(4, 4), Vector2i(4, 4)], "ranger": [Vector2i(2, 2), Vector2i(4, 4)],
	"sun_moon_monk": [Vector2i(3, 3), Vector2i(3, 3)], "antelope": [Vector2i(5, 3), Vector2i(5, 3)],
	"war_king": [Vector2i(2, 4), Vector2i(2, 4)], "shadow_king": [Vector2i(3, 3), Vector2i(3, 3)],
	"shield_king": [Vector2i(3, 3), Vector2i(3, 3)], "lantern_bearer": [Vector2i(3, 3), Vector2i(3, 3)],
	"martyr": [Vector2i(2, 4), Vector2i(2, 4)], "stone_giant": [Vector2i(2, 5), Vector2i(2, 5)],
	"blast_catapult": [Vector2i(2, 2), Vector2i(2, 5)], "sky_archer": [Vector2i(2, 2), Vector2i(5, 5)],
	"flame_phoenix": [Vector2i(3, 5), Vector2i(3, 5)], "thousand_faces": [Vector2i(3, 3), Vector2i(3, 3)],
}
## Special victims shown with a plain Rook as the attacker.
const VICTIM_SHOWS: Array[String] = ["powder_keg", "ember_bird", "gargoyle", "crystal_mage", "martyr", "stone_giant", "flame_phoenix"]
const EVERY := 4
const COLUMNS := 8
const CROP := Vector2i(130, 110)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://strikes"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var only: Array[String] = []
	for index: int in range(1, args.size()):
		only.append(args[index])
	root.get_node("GameState").call("start_new_game")
	var battle: Node = (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	for _i: int in range(10):
		await process_frame
	var view: BattleBoardView = battle.get_node("Margin/Layout/BoardFrame") as BattleBoardView
	for attacker: String in MOVES:
		if not only.is_empty() and attacker not in only:
			continue
		var landing: Vector2i = MOVES[attacker][0]
		var target: Vector2i = MOVES[attacker][1]
		await _capture(view, attacker, "knight", landing, target, false, "%s/%s.png" % [out_dir, attacker])
	for victim: String in VICTIM_SHOWS:
		if not only.is_empty() and ("victim_" + victim) not in only:
			continue
		var shell: bool = victim in ["gargoyle", "stone_giant"]
		await _capture(view, "rook", victim, FROM if shell else Vector2i(2, 5), Vector2i(2, 5), shell, "%s/victim_%s.png" % [out_dir, victim])
	quit()

func _capture(view: BattleBoardView, attacker: String, victim: String, landing: Vector2i, target: Vector2i, shell: bool, path: String) -> void:
	var board: BoardState = BoardState.new()
	board.clear_for_setup()
	board.place_piece_for_setup(Vector2i(4, 0), ChessPiece.new(Content.piece("king"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(4, 7), ChessPiece.new(Content.piece("king"), GameRules.PieceColor.BLACK))
	if shell:
		board.place_piece_for_setup(FROM, ChessPiece.new(Content.piece(attacker), GameRules.PieceColor.WHITE))
		board.place_piece_for_setup(target, ChessPiece.new(Content.piece(victim), GameRules.PieceColor.BLACK))
	else:
		board.place_piece_for_setup(landing, ChessPiece.new(Content.piece(attacker), GameRules.PieceColor.WHITE))
	(view.get_node("StrikeDirector") as StrikeDirector).stop()
	view.refresh(board)
	await process_frame
	var events: Array[BattleEvent] = [
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": FROM, "to": landing, "target": target, "piece_def_id": attacker, "color": GameRules.PieceColor.WHITE}),
	]
	if shell:
		events.append(BattleEvent.new(BattleCommandProcessor.EVENT_SHELL_BROKEN, 2, 1, {"position": target, "left": 0}))
	else:
		events.append(BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_CAPTURED, 2, 1, {"position": target, "piece_def_id": victim, "color": GameRules.PieceColor.BLACK}))
	var centre: Vector2 = view.get_global_transform() * view.projection.project(view.projection.square_world(FROM).lerp(view.projection.square_world(target), 0.5))
	var crop: Vector2i = CROP
	var origin: Vector2i = Vector2i(centre) - crop / 2 - Vector2i(0, 25)
	view.present_events(events, 1.0)
	var frames: Array[Image] = []
	var count: int = 0
	while view.is_presenting() and count < 400:
		await process_frame
		count += 1
		if count % EVERY == 0:
			var shot: Image = root.get_texture().get_image()
			var rect: Rect2i = Rect2i(origin, crop).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
			var frame: Image = shot.get_region(rect)
			frame.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
			frames.append(frame)
	if frames.is_empty():
		push_error("%s: nothing was presented" % attacker)
		return
	var rows: int = ceili(float(frames.size()) / COLUMNS)
	var sheet: Image = Image.create(CROP.x * 2 * COLUMNS, CROP.y * 2 * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	for index: int in range(frames.size()):
		var frame: Image = frames[index]
		frame.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i((index % COLUMNS) * CROP.x * 2, (index / COLUMNS) * CROP.y * 2))
	sheet.save_png(path)
	print("saved %s (%d frames)" % [path, frames.size()])
	for _i: int in range(5):
		await process_frame
