class_name BattleBoardView
extends Control

## 2.5D battle board. The board is drawn in code on a tilted plane and pieces are
## standing sprites sorted by depth. This node is presentation and input only: it reads
## BoardState and BattleEvents and never changes authoritative battle state.
##
## The view owns the layers, the projection and the selection state the battle scene
## reads; the work is done by its components (scripts/battle/board/):
##   input     BoardInputHandler     taps, long presses, selection and item targeting
##   markers   BoardMarkerLayer      everything drawn on and over the squares
##   pieces    BoardPieceSprites     piece and rock sprites, stone and gorgon gazes
##   presenter BoardEventPresenter   one action's events: travel, follow-ups, lifecycle
##   strikes   BoardStrikePresenter  captures played as full strike animations
##   blasts    BoardBlastPresenter   pieces thrown clear by an explosion or splash
##   finale    BattleFinalePresenter the lone King's execution and the end banner

signal move_requested(from: Vector2i, to: Vector2i)
signal item_target_requested(position: Vector2i)
signal presentations_completed
## A piece was held down long enough to ask what it does (works on either side's turn).
signal piece_info_requested(square: Vector2i)
## The piece the player is looking at changed: their selected piece, an inspected
## enemy, or NO_SQUARE when none.
signal focus_changed(square: Vector2i)
## The player tried to attack a piece that a shield protects (the opening King shield...).
signal shielded_target_tapped(square: Vector2i)

const NO_SQUARE := Vector2i(-1, -1)

@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var selected_square: Vector2i = NO_SQUARE
var legal_targets: Array[Vector2i] = []
## Marks on the selected piece's destinations (see BoardState.evaluate_landing):
## Squares where an enemy reply kills the piece and nothing answers it: red "!".
var dangerous_targets: Array[Vector2i] = []
## Squares where the piece can be killed but every such attacker can be taken back
## (an exchange, not a loss): amber shield with a red "!".
var protected_targets: Array[Vector2i] = []
## Squares where an enemy can only break the piece's shell: cracked ice shield with "!".
var shell_risk_targets: Array[Vector2i] = []
## Safe squares another of your pieces covers: a small faint amber shield.
var guarded_targets: Array[Vector2i] = []
## Enemies your blow would only crack (a shell or a hard egg takes it): cracked shield.
var shell_strike_targets: Array[Vector2i] = []
## An enemy piece tapped to see its reach (NO_SQUARE when none), with the empty squares
## it can move to and the squares of your pieces it can capture.
var inspected_square: Vector2i = NO_SQUARE
var inspect_moves: Array[Vector2i] = []
var inspect_threats: Array[Vector2i] = []
var board: BoardState = null
var player_color: int = GameRules.PieceColor.WHITE
var presentation_speed: float = 1.0
var item_targeting: bool = false
var input_enabled: bool = true
## True while the opening transition plays; taps are ignored.
var intro_locked: bool = false
## Size of the shield domes (0 hides them); the opening transition pops them in.
var dome_scale: float = 1.0
var projection: BoardProjection = BoardProjection.new()

var input: BoardInputHandler = null
var markers: BoardMarkerLayer = null
var pieces: BoardPieceSprites = null
var presenter: BoardEventPresenter = null
var strikes: BoardStrikePresenter = null
var blasts: BoardBlastPresenter = null
var finale: BattleFinalePresenter = null

var _board_canvas: Node2D = null
var _ground_canvas: Node2D = null
var _air_canvas: Node2D = null
var _piece_layer: Node2D = null
var _overlay: Control = null
var _strike: StrikeDirector = null

func _init() -> void:
	# Components exist from the start so the view can be set up before it enters the
	# tree; their layers arrive in _ready.
	input = BoardInputHandler.new(self)

func _ready() -> void:
	piece_skin_manager.connect("skin_changed", _on_skin_changed)
	_board_canvas = _add_layer("BoardCanvas")
	_ground_canvas = _add_layer("GroundFx")
	_piece_layer = _add_layer("PieceLayer")
	_piece_layer.y_sort_enabled = true
	_air_canvas = _add_layer("AirFx")
	_air_canvas.z_index = 10
	_overlay = Control.new()
	_overlay.name = "MarkerOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_strike = StrikeDirector.new()
	_strike.name = "StrikeDirector"
	add_child(_strike)
	markers = BoardMarkerLayer.new(self, _board_canvas, _overlay)
	pieces = BoardPieceSprites.new(self, _piece_layer, _air_canvas)
	presenter = BoardEventPresenter.new(self, _strike, _piece_layer, _ground_canvas)
	strikes = BoardStrikePresenter.new(self, _strike)
	blasts = BoardBlastPresenter.new(self, _strike, _piece_layer)
	finale = BattleFinalePresenter.new(self, _strike, _piece_layer, _air_canvas)
	_board_canvas.draw.connect(markers.draw_board)
	_ground_canvas.draw.connect(presenter.draw_proxy_shadows)
	_air_canvas.draw.connect(pieces.draw_gazes)
	_air_canvas.draw.connect(finale.draw_pillar)
	_overlay.draw.connect(markers.draw_overlay)
	_strike.setup(self)
	_strike.finished.connect(strikes.on_strike_finished)
	_strike.impacted.connect(strikes.on_strike_moment.bind(&"impact"))
	_strike.victim_split.connect(strikes.on_strike_moment.bind(&"split"))
	resized.connect(_on_resized)
	_update_projection()

func _add_layer(layer_name: String) -> Node2D:
	var layer: Node2D = Node2D.new()
	layer.name = layer_name
	add_child(layer)
	return layer

func _exit_tree() -> void:
	if piece_skin_manager.is_connected("skin_changed", _on_skin_changed):
		piece_skin_manager.disconnect("skin_changed", _on_skin_changed)

func setup(board_value: BoardState, player_color_value: int) -> void:
	board = board_value
	player_color = player_color_value
	selected_square = NO_SQUARE
	legal_targets.clear()
	input.clear_marks()
	_update_projection()
	refresh(board)

func refresh(board_value: BoardState = null) -> void:
	if board_value != null:
		board = board_value
	if board == null:
		return
	if projection.board_size != board.board_size:
		_update_projection()
	if pieces != null:
		pieces.rebuild()
	redraw()

func redraw() -> void:
	if _board_canvas != null:
		_board_canvas.queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()

func _process(delta: float) -> void:
	input.advance_hold(delta)
	if pieces != null:
		pieces.advance(delta)

func _on_skin_changed(_skin_id: StringName) -> void:
	refresh()

# --- geometry -------------------------------------------------------------------

func square_count() -> int:
	return 0 if board == null else board.board_size * board.board_size

## Centre of a square in this control's local coordinates.
func square_center(square: Vector2i) -> Vector2:
	return projection.square_center(square)

func square_at(point: Vector2) -> Vector2i:
	return input.square_at(point)

func pieces_at(point: Vector2) -> Array[Vector2i]:
	return input.pieces_at(point)

func tap_at(point: Vector2) -> Vector2i:
	return input.tap_at(point)

func piece_square_at(point: Vector2) -> Vector2i:
	return input.piece_square_at(point)

func _update_projection() -> void:
	var board_size: int = 8 if board == null else board.board_size
	var view_size: Vector2 = size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	projection = BoardPainter.fit(board_size, view_size)
	if _strike != null:
		_strike.fx.projection = projection
		_strike.fx.unit = projection.cell / 18.0

func _on_resized() -> void:
	_update_projection()
	refresh()

# --- input and selection --------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	input.gui_input(event)

## Same entry point as a tap on that square. Used by input handling and scene tests.
func press_square(square: Vector2i) -> void:
	input.press(square)

## Counts a held piece towards a long press. Split out so tests can drive time.
func advance_hold(delta: float) -> void:
	input.advance_hold(delta)

## Shows where the enemy piece on `square` can move and what it can capture.
func inspect(square: Vector2i) -> void:
	input.inspect(square)

func clear_inspection(redraw_now: bool = true) -> void:
	input.clear_inspection(redraw_now)

func set_input_enabled(enabled: bool) -> void:
	input.set_enabled(enabled)

func begin_item_targeting() -> void:
	input.begin_item_targeting()

func cancel_item_targeting() -> void:
	item_targeting = false

func clear_selection() -> void:
	input.clear_selection()

func set_selection_state(square: Vector2i, targets: Array[Vector2i], dangers: Array[Vector2i] = []) -> void:
	input.set_selection_state(square, targets, dangers)

# --- hooks for strike animations --------------------------------------------------

func piece_layer() -> Node2D:
	return _piece_layer

func ground_canvas() -> Node2D:
	return _ground_canvas

func air_canvas() -> Node2D:
	return _air_canvas

## Square -> Sprite2D for every piece currently standing on the board.
func standing_sprites() -> Dictionary:
	return pieces.sprites

## How far in front of a square's centre a piece plants its feet, in world units.
func standing_offset() -> float:
	return projection.cell * BoardPainter.STAND_FORWARD_CELLS

func make_piece_sprite(texture: Texture2D) -> Sprite2D:
	return BoardPainter.make_sprite(texture, projection)

## The board's effects layer, or null before the view is ready.
func strike_fx() -> StrikeFx:
	return _strike.fx if _strike != null else null

# --- opening transition -----------------------------------------------------------

## Opening transition: the board starts exactly where the pre-battle board stood
## (`source` in global coordinates) and glides into place over `seconds`.
func glide_in_from(source: Rect2, seconds: float) -> Tween:
	var size_now: int = 8 if board == null else board.board_size
	var from_projection: BoardProjection = BoardPainter.fit(size_now, source.size)
	var k: float = from_projection.cell / maxf(projection.cell, 1.0)
	var target_centre: Vector2 = source.position + from_projection.center - get_global_rect().position
	var start: Transform2D = Transform2D(0.0, Vector2(k, k), 0.0, target_centre - projection.center * k)
	set_camera(start)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float) -> void: set_camera(start.interpolate_with(Transform2D.IDENTITY, t)), 0.0, 1.0, seconds)
	return tween

## One side's pieces hop in place, one after another, as if waking up.
func hop_pieces(color: int, stagger: float = 0.035) -> void:
	var index: int = 0
	for square_value: Variant in pieces.sprites:
		var piece: ChessPiece = board.get_piece(square_value)
		var sprite: Sprite2D = pieces.sprites[square_value] as Sprite2D
		if piece == null or piece.color != color or sprite == null:
			continue
		var rest: float = sprite.position.y
		var hop: Tween = create_tween()
		hop.tween_interval(index * stagger)
		hop.tween_property(sprite, "position:y", rest - projection.cell * 0.32, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(sprite, "position:y", rest, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		index += 1

## Pops the shield domes in (they are hidden during the opening glide).
func pop_domes(seconds: float = 0.3) -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_dome_scale, 0.0, 1.0, seconds)

func _set_dome_scale(value: float) -> void:
	dome_scale = value
	if _overlay != null:
		_overlay.queue_redraw()

## Moves the whole board picture (zoom punch, shake). Identity restores it.
func set_camera(camera: Transform2D) -> void:
	for layer: Node2D in [_board_canvas, _ground_canvas, _piece_layer, _air_canvas]:
		if layer != null:
			layer.transform = camera

# --- presentation -----------------------------------------------------------------

func present_events(events: Array[BattleEvent], speed: float = 1.0) -> void:
	presenter.present(events, speed)

func is_presenting() -> bool:
	return presenter != null and presenter.is_presenting()

func skip_presentations() -> void:
	presenter.skip()

## Where the screen and the rules disagree, for battle codes (see
## BoardPieceSprites.report). While a move is still animating some squares are hidden
## on purpose; that is reported as "presenting".
func view_report() -> Array[String]:
	var issues: Array[String] = []
	if board == null:
		return issues
	if is_presenting():
		issues.append("presenting")
	pieces.report(issues)
	return issues
