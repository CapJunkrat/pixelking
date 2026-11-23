class_name BattleFinalePresenter
extends RefCounted

## The end of a battle on the board. When the last move leaves a lone King, it is
## executed: it trembles, the winning King dissolves into light, drops out of a pillar
## beside it and strikes it down in slow motion. Then "Victory" or "Defeat" slams down
## over the board. Both wait for the move that decided the battle to play out first
## (BoardEventPresenter.end_presentation calls play_next), and the winning King keeps
## its final place until the battle screen closes.

const NO_SQUARE := Vector2i(-1, -1)
## The execution blow plays a little faster than a normal King strike.
const EXECUTION_STRIKE_SPEED := 1.35
const MOTE_GOLD := Color(1.0, 0.85, 0.45)

var view: BattleBoardView = null
## The lone King's fall, played after the move that left it alone (EVENT_KING_EXECUTION).
var _pending_execution: Dictionary = {}
## The banner to show once the deciding move has played out: {"won": bool}.
var _pending_banner: Dictionary = {}
var _running: bool = false
## After the execution the winning King stays where it struck (the battle is over).
var _hidden: Dictionary = {}
var _nodes: Array[Node] = []
var _pillar_square: Vector2i = NO_SQUARE
var _pillar_strength: float = 0.0
var _banner: Control = null
var _strike: StrikeDirector = null
var _piece_layer: Node2D = null
var _air_canvas: Node2D = null

func _init(owner_view: BattleBoardView, strike: StrikeDirector, piece_layer: Node2D, air_canvas: Node2D) -> void:
	view = owner_view
	_strike = strike
	_piece_layer = piece_layer
	_air_canvas = air_canvas

# --- queue ----------------------------------------------------------------------

func queue_execution(execution: Dictionary) -> void:
	_pending_execution = execution

func queue_banner(won: bool) -> void:
	_pending_banner = {"won": won}

func forget_execution() -> void:
	_pending_execution = {}

func has_pending() -> bool:
	return not _pending_execution.is_empty() or not _pending_banner.is_empty()

## Starts what comes next once a move has played out: the execution, else the banner.
## Returns false when nothing is left and the presentation is complete.
func play_next() -> bool:
	if not _pending_execution.is_empty():
		var execution: Dictionary = _pending_execution
		_pending_execution = {}
		_start_execution(execution)
		return true
	if not _pending_banner.is_empty():
		var banner: Dictionary = _pending_banner
		_pending_banner = {}
		_show_banner(bool(banner.get("won", true)))
		return true
	return false

## A new action is about to be presented: drop anything queued, and the last finale
## (a move after the end only happens in tests and replays).
func reset() -> void:
	_pending_execution = {}
	_pending_banner = {}
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_nodes.clear()
	_hidden.clear()
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	_banner = null

# --- state ----------------------------------------------------------------------

func is_running() -> bool:
	return _running

func stop_running() -> void:
	_running = false

## Squares kept hidden after the finale (where the winning King struck from).
func hidden_squares() -> Dictionary:
	return _hidden.duplicate()

## Shows the winning King in its final place.
func reveal() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			(node as CanvasItem).visible = true

## A tap during the execution jumps straight to the banner.
func skip() -> void:
	_running = false
	if _nodes.is_empty():
		_hidden.clear()
	_pillar_square = NO_SQUARE
	_air_canvas.queue_redraw()
	view.presenter.stop_all()
	view.presenter.end_presentation()

## The board has already lost the lone King; keep it standing until its execution.
func hold_doomed_king() -> void:
	if _pending_execution.is_empty():
		return
	var execution: Dictionary = _pending_execution
	var square: Vector2i = execution.get("to", NO_SQUARE)
	if not view.board.in_bounds(square):
		return
	var color: int = int(execution.get("victim_color", GameRules.opposite(int(execution.get("color", view.player_color)))))
	var sprite: Sprite2D = view.pieces.make_sprite(view.pieces.texture_for(color, str(execution.get("victim_def_id", "king"))))
	if sprite == null:
		return
	view.pieces.place_sprite(sprite, view.projection.square_world(square))
	_piece_layer.add_child(sprite)
	view.presenter.nodes.append(sprite)

# --- execution ------------------------------------------------------------------

## The lone King's fall: it trembles, the winning King dissolves into light and
## reappears beside it, then strikes it down (slow motion on the blow).
func _start_execution(execution: Dictionary) -> void:
	var presenter: BoardEventPresenter = view.presenter
	var board: BoardState = view.board
	var projection: BoardProjection = view.projection
	var winner_square: Vector2i = execution.get("from", NO_SQUARE)
	var loser_square: Vector2i = execution.get("to", NO_SQUARE)
	if not board.in_bounds(winner_square) or not board.in_bounds(loser_square):
		presenter.end_presentation()
		return
	_running = true
	var short: bool = presenter.short_animations()
	var speed: float = maxf(presenter.last_speed, 0.1) * (2.2 if short else 1.0)
	var winner_color: int = int(execution.get("color", view.player_color))
	var loser_color: int = int(execution.get("victim_color", GameRules.opposite(winner_color)))
	var killer_id: String = str(execution.get("piece_def_id", "king"))
	var victim_id: String = str(execution.get("victim_def_id", "king"))
	var approach: Vector2i = execution_approach(board, loser_square, winner_square)
	view.pieces.hidden[winner_square] = true
	_hidden[winner_square] = true
	view.refresh()
	var king: Sprite2D = view.pieces.make_sprite(view.pieces.texture_for(winner_color, killer_id))
	var doomed_king: Sprite2D = view.pieces.make_sprite(view.pieces.texture_for(loser_color, victim_id))
	if king == null or doomed_king == null:
		presenter.end_presentation()
		return
	var home: Vector3 = projection.square_world(winner_square)
	var beside: Vector3 = projection.square_world(approach)
	view.pieces.place_sprite(king, home)
	view.pieces.place_sprite(doomed_king, projection.square_world(loser_square))
	for sprite: Sprite2D in [king, doomed_king]:
		_piece_layer.add_child(sprite)
		presenter.nodes.append(sprite)
	view.pieces.hidden[loser_square] = true
	var tween: Tween = view.create_tween().bind_node(view)
	presenter.tweens.append(tween)
	# 1. A beat of silence; the doomed King trembles.
	var doomed_rest: Vector2 = doomed_king.position
	tween.tween_method(_tremble.bind(doomed_king, doomed_rest), 0.0, 1.0, 0.4 / speed)
	# 2. The winner crouches and dissolves into golden motes...
	tween.tween_method(presenter.stretch.bind(king), Vector2.ONE, Vector2(1.16, 0.8), 0.15 / speed)
	tween.parallel().tween_method(_tremble.bind(doomed_king, doomed_rest), 0.0, 1.0, 0.15 / speed)
	tween.tween_callback(_motes.bind(winner_square))
	tween.tween_property(king, "modulate", Color(2.4, 2.0, 0.9, 0.0), 0.2 / speed)
	tween.parallel().tween_method(presenter.stretch.bind(king), Vector2(1.16, 0.8), Vector2(0.4, 1.5), 0.2 / speed)
	tween.parallel().tween_method(_tremble.bind(doomed_king, doomed_rest), 0.0, 1.0, 0.2 / speed)
	# ...and drops out of a pillar of light beside the doomed King.
	tween.tween_callback(_begin_pillar.bind(approach))
	tween.tween_callback(presenter.stretch.bind(Vector2.ONE, king))
	tween.tween_method(_set_pillar, 0.0, 1.0, 0.08 / speed)
	tween.tween_method(presenter.travel.bind(king, beside + Vector3(0.0, projection.cell * 1.2, 0.0), beside, 0.0), 0.0, 1.0, 0.16 / speed)
	tween.parallel().tween_property(king, "modulate", Color(1.6, 1.4, 0.9, 1.0), 0.16 / speed)
	tween.parallel().tween_method(_tremble.bind(doomed_king, doomed_rest), 0.0, 1.0, 0.16 / speed)
	tween.tween_callback(presenter.land.bind(beside, PieceDef.WeightClass.HEAVY))
	tween.tween_property(king, "modulate", Color.WHITE, 0.12 / speed)
	tween.parallel().tween_method(_set_pillar, 1.0, 0.0, 0.25 / speed)
	# 3. The blow: the King's own strike from beside the victim.
	tween.tween_callback(_execution_strike.bind(execution, approach, loser_square, winner_color, loser_color, speed, king, doomed_king))
	tween.tween_callback(presenter.finish_tween.bind(tween))

func _execution_strike(execution: Dictionary, approach: Vector2i, loser_square: Vector2i, winner_color: int, loser_color: int, speed: float, king: Sprite2D, doomed_king: Sprite2D) -> void:
	var move_data: Dictionary = {"from": approach, "to": loser_square, "target": loser_square, "piece_def_id": str(execution.get("piece_def_id", "king")), "color": winner_color}
	var capture_data: Dictionary = {"position": loser_square, "piece_def_id": str(execution.get("victim_def_id", "king")), "color": loser_color}
	_finale_king(str(execution.get("piece_def_id", "king")), winner_color, loser_square)
	if view.strikes.present(move_data, capture_data, speed * EXECUTION_STRIKE_SPEED):
		for sprite: Sprite2D in [king, doomed_king]:
			if is_instance_valid(sprite):
				sprite.visible = false
		return
	# No strike animation for this King: a plain blow and burst.
	view.blasts.hit(loser_square, false)
	if is_instance_valid(doomed_king):
		doomed_king.visible = false

## Where the winning King appears: the empty square next to the doomed King that is
## closest to where it stood (any neighbour if all are taken).
static func execution_approach(state: BoardState, loser_square: Vector2i, winner_square: Vector2i) -> Vector2i:
	var best: Vector2i = NO_SQUARE
	var best_distance: float = INF
	var fallback: Vector2i = NO_SQUARE
	var fallback_distance: float = INF
	for offset: Vector2i in BoardState.NEIGHBORS:
		var square: Vector2i = loser_square + offset
		if not state.on_board(square):
			continue
		var distance: float = Vector2(square - winner_square).length()
		if distance < fallback_distance and not state.is_rock(square):
			fallback = square
			fallback_distance = distance
		if state.get_piece(square) == null and not state.is_rock(square) and distance < best_distance:
			best = square
			best_distance = distance
	if best != NO_SQUARE:
		return best
	return fallback if fallback != NO_SQUARE else winner_square

## The winning King keeps its final place until the battle screen closes.
func _finale_king(piece_id: String, color: int, square: Vector2i) -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	var sprite: Sprite2D = view.pieces.make_sprite(view.pieces.texture_for(color, piece_id))
	if sprite == null:
		return
	sprite.name = "FinaleKing"
	view.pieces.place_sprite(sprite, view.projection.square_world(square))
	sprite.visible = false
	_piece_layer.add_child(sprite)
	_nodes.append(sprite)
	_hidden[square] = true

func _tremble(progress: float, sprite: Sprite2D, rest: Vector2) -> void:
	if not is_instance_valid(sprite):
		return
	var reach: float = view.projection.cell * 0.05 * (0.6 + 0.4 * progress)
	sprite.position = rest + Vector2(sin(Time.get_ticks_msec() * 0.07) * reach, 0.0)

func _motes(square: Vector2i) -> void:
	if _strike == null:
		return
	var at: Vector3 = view.projection.square_world(square)
	_strike.fx.spark_burst(at + Vector3(0.0, view.projection.cell * 0.4, 0.0), 22, Vector2.ZERO, 0.0, 0.8, MOTE_GOLD)
	_strike.fx.ring(at.x, at.z, view.projection.cell * 0.7, 0.35, MOTE_GOLD)

func _begin_pillar(square: Vector2i) -> void:
	_pillar_square = square
	_pillar_strength = 0.0
	if _strike != null:
		var at: Vector3 = view.projection.square_world(square)
		_strike.fx.ring(at.x, at.z, view.projection.cell * 0.9, 0.4, Color(1.0, 0.9, 0.6))

func _set_pillar(value: float) -> void:
	_pillar_strength = value
	if value <= 0.0:
		_pillar_square = NO_SQUARE
	_air_canvas.queue_redraw()

func draw_pillar() -> void:
	if _pillar_square == NO_SQUARE or _pillar_strength <= 0.0:
		return
	var projection: BoardProjection = view.projection
	var at: Vector3 = projection.square_world(_pillar_square)
	var foot: Vector2 = projection.project(at + Vector3(0.0, 0.0, view.standing_offset()))
	var width: float = projection.cell * 0.55 * projection.square_scale(_pillar_square) * _pillar_strength
	var height: float = projection.cell * 5.0
	var bands: int = 8
	for band: int in range(bands):
		var q: float = float(band) / bands
		var rect: Rect2 = Rect2(foot.x - width * 0.5, foot.y - height * (1.0 - q), width, height / bands + 1.0)
		_air_canvas.draw_rect(rect, Color(1.0, 0.92, 0.65, 0.75 * _pillar_strength * q))
	_air_canvas.draw_rect(Rect2(foot.x - width * 0.15, foot.y - height, width * 0.3, height), Color(1.0, 1.0, 0.9, 0.6 * _pillar_strength))

## The killing blow plays in slow motion for a moment.
func slow_motion() -> void:
	_strike.time_scale = 0.3
	var timer: SceneTreeTimer = view.get_tree().create_timer(0.6)
	var strike: StrikeDirector = _strike
	timer.timeout.connect(func() -> void:
		if strike != null:
			strike.time_scale = 1.0)

# --- banner ---------------------------------------------------------------------

## "Victory" (gold) or "Defeat" (dim) slams down over the board, then the battle ends.
func _show_banner(won: bool) -> void:
	var presenter: BoardEventPresenter = view.presenter
	var short: bool = presenter.short_animations()
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	_banner = Control.new()
	_banner.name = "EndBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_child(_banner)
	var band: ColorRect = ColorRect.new()
	band.color = Color(0.08, 0.05, 0.02, 0.72) if won else Color(0.06, 0.03, 0.06, 0.78)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(view.size.x, 92.0)
	band.position = Vector2(0.0, view.size.y * 0.42 - 46.0)
	_banner.add_child(band)
	for edge_y: float in [0.0, 90.0]:
		var edge: ColorRect = ColorRect.new()
		edge.color = Color("#f5c860") if won else Color("#8a6a74")
		edge.size = Vector2(view.size.x, 2.0)
		edge.position = Vector2(0.0, edge_y)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(edge)
	var label: Label = Label.new()
	label.text = _banner_text("BATTLE_BANNER_VICTORY" if won else "BATTLE_BANNER_DEFEAT")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = band.size
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", Color("#ffd876") if won else Color("#c9a0a8"))
	label.add_theme_color_override("font_outline_color", Color("#3a2304") if won else Color("#1a0d12"))
	label.add_theme_constant_override("outline_size", 10)
	label.pivot_offset = band.size * 0.5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(label)
	band.pivot_offset = band.size * 0.5
	var rest_y: float = band.position.y
	band.position.y = -band.size.y
	var speed: float = 2.0 if short else 1.0
	var tween: Tween = view.create_tween().bind_node(view)
	presenter.tweens.append(tween)
	tween.tween_property(band, "position:y", rest_y, 0.28 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_banner_landed.bind(won))
	tween.tween_property(label, "scale", Vector2(1.14, 1.14), 0.08 / speed)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14 / speed)
	tween.tween_interval(0.7 / speed)
	tween.tween_callback(presenter.finish_tween.bind(tween))

func _banner_landed(won: bool) -> void:
	view.presenter.sfx(&"victory" if won else &"defeat")
	if _strike == null:
		return
	var board: BoardState = view.board
	var centre: Vector3 = view.projection.square_world(Vector2i(board.board_size / 2, board.board_size / 2))
	if won:
		for color: Color in [Color("#f5c860"), Color("#fff2c4"), Color("#4fd1c5")]:
			_strike.fx.spark_burst(centre + Vector3(0.0, view.projection.cell * 2.0, 0.0), 18, Vector2.ZERO, 0.0, 1.4, color)
	else:
		_strike.fx.puff(centre + Vector3(0.0, view.projection.cell, 0.0), 10, 1.2)

func _banner_text(key: String) -> String:
	var localization: Node = view.get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
