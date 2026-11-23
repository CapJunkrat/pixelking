class_name BoardInputHandler
extends RefCounted

## Taps and long presses on the battle board, and the selection they drive: the
## selected piece with its destinations and their safety marks, an inspected enemy
## piece, and item targeting.
##
## The selection itself stays in BattleBoardView's public fields, since the battle
## scene, BoardMarkerLayer and the scene tests read it there; this class only decides
## how input changes it.

const NO_SQUARE := Vector2i(-1, -1)
const LONG_PRESS_SECONDS := 0.45
## A finger that drifts further than this (pixels) is not holding still.
const LONG_PRESS_SLOP := 14.0
## How close (in cells) a tap must be to the previous one to step to the next stacked piece.
const TAP_CYCLE_RADIUS_CELLS := 0.3

var view: BattleBoardView = null
## The piece being held down for its info card: square, where and how long.
var _hold_square: Vector2i = NO_SQUARE
var _hold_point: Vector2 = Vector2.ZERO
var _hold_seconds: float = 0.0
var _tap_cycle: TapCycle = TapCycle.new()

func _init(owner_view: BattleBoardView) -> void:
	view = owner_view

# --- hit testing --------------------------------------------------------------

## Square a first tap at a local point selects. The board decides: a legal destination
## or a piece standing on the tapped square wins; on an empty square, the piece whose
## figure covers the point (front-most first); else the bare square.
func square_at(point: Vector2) -> Vector2i:
	var ground: Vector2i = view.projection.screen_to_square(point)
	if ground != NO_SQUARE and ground in view.legal_targets:
		return ground
	var under: Array[Vector2i] = pieces_at(point)
	return under[0] if not under.is_empty() else ground

## Pieces under a point, in the order repeated taps cycle through them.
func pieces_at(point: Vector2) -> Array[Vector2i]:
	if view.board == null:
		return []
	return BoardPainter.pieces_under(point, view.projection.screen_to_square(point), view.pieces.sprites)

## Square a tap selects, stepping to the next stacked piece when the same spot is
## tapped again (see TapCycle).
func tap_at(point: Vector2) -> Vector2i:
	var ground: Vector2i = view.projection.screen_to_square(point)
	if ground != NO_SQUARE and ground in view.legal_targets:
		_tap_cycle.reset()
		return ground
	var under: Array[Vector2i] = pieces_at(point)
	if under.is_empty():
		_tap_cycle.reset()
		return ground
	return _tap_cycle.pick(point, under, view.projection.cell * TAP_CYCLE_RADIUS_CELLS)

## The piece under a point, ignoring move targets (for long presses).
func piece_square_at(point: Vector2) -> Vector2i:
	var under: Array[Vector2i] = pieces_at(point)
	return under[0] if not under.is_empty() else NO_SQUARE

# --- events -------------------------------------------------------------------

func gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _hold_square != NO_SQUARE and motion.position.distance_to(_hold_point) > LONG_PRESS_SLOP:
			_hold_square = NO_SQUARE
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not click.pressed:
		_hold_square = NO_SQUARE
		return
	if view.finale.is_running():
		view.accept_event()
		view.finale.skip()
		return
	var square: Vector2i = tap_at(click.position)
	_hold_square = square if square != NO_SQUARE and view.board != null and view.board.get_piece(square) != null else NO_SQUARE
	_hold_point = click.position
	_hold_seconds = 0.0
	if square == NO_SQUARE:
		return
	view.accept_event()
	press(square, _tap_cycle.cycled)

## Counts a held piece towards a long press. Split out so tests can drive time.
func advance_hold(delta: float) -> void:
	if _hold_square == NO_SQUARE or view.item_targeting:
		return
	_hold_seconds += delta
	if _hold_seconds >= LONG_PRESS_SECONDS:
		var square: Vector2i = _hold_square
		_hold_square = NO_SQUARE
		if view.board != null and view.board.get_piece(square) != null:
			view.piece_info_requested.emit(square)

## A tap on `board_position`. `cycled`: the tap stepped to another piece stacked under
## the same spot, so it only picks that piece (never moves the selected one onto it).
func press(board_position: Vector2i, cycled: bool = false) -> void:
	var board: BoardState = view.board
	if board == null or not view.input_enabled or view.intro_locked or not board.on_board(board_position):
		return
	if view.item_targeting:
		view.item_targeting = false
		view.item_target_requested.emit(board_position)
		return
	if cycled:
		_deselect()
		clear_inspection(false)
	if board_position in view.legal_targets:
		view.move_requested.emit(view.selected_square, board_position)
		return
	var piece: ChessPiece = board.get_piece(board_position)
	if piece != null and piece.color != view.player_color and view.selected_square != NO_SQUARE and piece.is_shielded(board.turn_serial):
		view.markers.pulse_shield(board_position)
		view.shielded_target_tapped.emit(board_position)
	var was_inspected: bool = board_position == view.inspected_square
	clear_inspection(false)
	if piece != null and piece.color != view.player_color and not was_inspected:
		_deselect()
		inspect(board_position)
		view.focus_changed.emit(board_position)
		return
	if piece != null and piece.color == board.turn and piece.color == view.player_color:
		view.selected_square = board_position
		view.legal_targets = board.get_executable_moves(board_position)
		_mark_targets(board_position)
	else:
		_deselect()
	view.refresh()
	view.focus_changed.emit(view.selected_square)

# --- selection ----------------------------------------------------------------

func clear_marks() -> void:
	view.dangerous_targets.clear()
	view.protected_targets.clear()
	view.shell_risk_targets.clear()
	view.guarded_targets.clear()
	view.shell_strike_targets.clear()

func _deselect() -> void:
	view.selected_square = NO_SQUARE
	view.legal_targets.clear()
	clear_marks()

## Sorts the selected piece's destinations into the safety marks by playing the
## enemy replies with the real rules (BoardState.evaluate_landing).
func _mark_targets(from: Vector2i) -> void:
	clear_marks()
	var board: BoardState = view.board
	var mover: ChessPiece = board.get_piece(from)
	for target: Vector2i in view.legal_targets:
		var safety: Dictionary = board.evaluate_landing(from, target)
		if bool(safety.get("lethal", false)):
			if bool(safety.get("protected", false)):
				view.protected_targets.append(target)
			else:
				view.dangerous_targets.append(target)
		elif bool(safety.get("shell", false)):
			view.shell_risk_targets.append(target)
		elif bool(safety.get("protected", false)):
			view.guarded_targets.append(target)
		var occupant: ChessPiece = board.get_piece(target)
		if mover != null and occupant != null and occupant.color != mover.color and (occupant.shell_left > 0 or occupant.def.egg_hardened):
			view.shell_strike_targets.append(target)

## Shows where the enemy piece on `square` can move and what it can capture.
func inspect(square: Vector2i) -> void:
	view.inspected_square = square
	view.inspect_moves.clear()
	view.inspect_threats.clear()
	var board: BoardState = view.board
	var piece: ChessPiece = board.get_piece(square) if board != null else null
	if piece == null:
		view.inspected_square = NO_SQUARE
		view.refresh()
		return
	# Everything it could do on its own turn (shots and captures included).
	for target: Vector2i in MoveGenerator.generate_pseudo_legal(board, square):
		if board.is_rock(target) or target == square:
			continue
		var occupant: ChessPiece = board.get_piece(target)
		if occupant == null:
			if target not in view.inspect_moves:
				view.inspect_moves.append(target)
		elif occupant.color != piece.color and target not in view.inspect_threats:
			view.inspect_threats.append(target)
	view.refresh()

func clear_inspection(redraw: bool = true) -> void:
	if view.inspected_square == NO_SQUARE:
		return
	view.inspected_square = NO_SQUARE
	view.inspect_moves.clear()
	view.inspect_threats.clear()
	if redraw:
		view.refresh()

func set_enabled(enabled: bool) -> void:
	view.input_enabled = enabled
	if not enabled:
		view.item_targeting = false
		_deselect()
		view.redraw()

func begin_item_targeting() -> void:
	clear_inspection(false)
	view.item_targeting = true
	_deselect()
	view.refresh()

func clear_selection() -> void:
	clear_inspection(false)
	_deselect()
	view.refresh()

func set_selection_state(square: Vector2i, targets: Array[Vector2i], dangers: Array[Vector2i] = []) -> void:
	view.selected_square = square
	view.legal_targets = targets.duplicate()
	clear_marks()
	view.dangerous_targets = dangers.duplicate()
	view.refresh()
