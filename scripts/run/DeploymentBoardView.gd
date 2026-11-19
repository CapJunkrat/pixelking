class_name DeploymentBoardView
extends Control

## 2.5D board for the pre-battle deployment screen. It shares its look with the battle
## board (BoardPainter) and only reports taps; DeploymentScene owns every rule.

signal square_pressed(square: Vector2i)

const NO_SQUARE := Vector2i(-1, -1)
const ZONE_TINT := Color(0.96, 0.84, 0.44, 0.2)
const SELECTED_TINT := Color(0.88, 0.71, 0.36, 0.6)
const TARGET_DOT := Color(1.0, 0.94, 0.78, 0.6)
const ENEMY_MODULATE := Color(1.0, 1.0, 1.0, 0.92)

var projection: BoardProjection = BoardProjection.new()
var board_size: int = 8
var deploy_rows: int = 2
var selected_square: Vector2i = NO_SQUARE

var _piece_layer: Node2D = null
## square -> {"texture": Texture2D, "player": bool}
var _pieces: Dictionary = {}
var _sprites: Dictionary = {}
var _drop_square: Vector2i = NO_SQUARE
var _tap_cycle: TapCycle = TapCycle.new()
## True while a tap that stepped to another stacked piece is being handled.
var last_tap_cycled: bool = false
## Rock squares (Vector2i -> true), drawn as boulders; taps on them are ignored.
var rocks: Dictionary = {}
## Squares to mark for a previewed enemy piece: "move" (blue dot) or "attack" (red tile).
var hints: Dictionary = {}
const HINT_MOVE := Color(0.25, 0.71, 0.85, 0.75)
const HINT_ATTACK := Color(0.88, 0.40, 0.35, 0.5)

func _ready() -> void:
	_piece_layer = Node2D.new()
	_piece_layer.name = "PieceLayer"
	_piece_layer.y_sort_enabled = true
	add_child(_piece_layer)
	resized.connect(_rebuild)
	_rebuild()

## Shows a position. `pieces` maps squares to {"texture": Texture2D, "player": bool}.
## `dropped` names a square whose piece was just placed, so it lands with a bounce.
func show_position(size_value: int, pieces: Dictionary, selected: Vector2i = NO_SQUARE, dropped: Vector2i = NO_SQUARE) -> void:
	board_size = maxi(size_value, 1)
	_pieces = pieces
	selected_square = selected
	_drop_square = dropped
	_rebuild()

func square_count() -> int:
	return board_size * board_size

func piece_count(player: bool) -> int:
	var count: int = 0
	for square: Variant in _pieces:
		if bool((_pieces[square] as Dictionary).get("player", false)) == player:
			count += 1
	return count

func has_piece(square: Vector2i) -> bool:
	return _pieces.has(square)

func is_deploy_square(square: Vector2i) -> bool:
	return deploy_rows > 0 and DeploymentState.is_player_zone(square, board_size)

func square_center(square: Vector2i) -> Vector2:
	return projection.square_center(square)

## Square a first tap at a local point selects. The board decides: with a piece in
## hand an empty deployment square wins, then a piece standing on the tapped square; on
## an empty square, the piece whose figure covers the point (front-most first).
func square_at(point: Vector2) -> Vector2i:
	var ground: Vector2i = projection.screen_to_square(point)
	if _drops_on(ground):
		return ground
	var under: Array[Vector2i] = BoardPainter.pieces_under(point, ground, _sprites)
	return under[0] if not under.is_empty() else ground

## Square a tap selects, stepping to the next stacked piece when the same spot is
## tapped again. `last_tap_cycled` tells whether it stepped.
func tap_at(point: Vector2) -> Vector2i:
	var ground: Vector2i = projection.screen_to_square(point)
	var square: Vector2i = ground
	if _drops_on(ground):
		_tap_cycle.reset()
	else:
		var under: Array[Vector2i] = BoardPainter.pieces_under(point, ground, _sprites)
		if under.is_empty():
			_tap_cycle.reset()
		else:
			square = _tap_cycle.pick(point, under, projection.cell * 0.3)
	last_tap_cycled = _tap_cycle.cycled
	return square

func _drops_on(ground: Vector2i) -> bool:
	return selected_square != NO_SQUARE and ground != NO_SQUARE and is_deploy_square(ground) and not _pieces.has(ground)

## Same entry point as a tap on that square. Used by input handling and scene tests.
func press_square(square: Vector2i) -> void:
	if square.x < 0 or square.y < 0 or square.x >= board_size or square.y >= board_size:
		return
	if rocks.has(square):
		return
	square_pressed.emit(square)

func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var square: Vector2i = tap_at(click.position)
	if square == NO_SQUARE:
		return
	accept_event()
	press_square(square)
	last_tap_cycled = false

func _rebuild() -> void:
	if _piece_layer == null:
		return
	var view: Vector2 = size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	projection = BoardPainter.fit(board_size, view)
	for child: Node in _piece_layer.get_children():
		_piece_layer.remove_child(child)
		child.queue_free()
	_sprites.clear()
	for rock_value: Variant in rocks:
		var rock_square: Vector2i = rock_value
		var rock: Sprite2D = BoardPainter.make_sprite(RockArt.texture(), projection)
		rock.name = "Rock_%d_%d" % [rock_square.x, rock_square.y]
		BoardPainter.place_sprite(rock, projection, projection.square_world(rock_square))
		_piece_layer.add_child(rock)
	for square_value: Variant in _pieces:
		var square: Vector2i = square_value
		var entry: Dictionary = _pieces[square]
		var sprite: Sprite2D = BoardPainter.make_sprite(entry.get("texture") as Texture2D, projection)
		if sprite == null:
			continue
		sprite.name = "Piece_%d_%d" % [square.x, square.y]
		var world: Vector3 = projection.square_world(square)
		# The piece in hand floats slightly so it is obvious which one will move.
		if square == selected_square:
			world.y = projection.cell * 0.22
		BoardPainter.place_sprite(sprite, projection, world)
		if not bool(entry.get("player", false)):
			sprite.modulate = ENEMY_MODULATE
		_piece_layer.add_child(sprite)
		_sprites[square] = sprite
		if square == _drop_square:
			var rest: Vector2 = sprite.scale
			sprite.scale = rest * Vector2(1.2, 0.78)
			sprite.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(sprite, "scale", rest, 0.22)
	_drop_square = NO_SQUARE
	queue_redraw()

func _draw() -> void:
	BoardPainter.draw_frame(self, projection)
	for rank: int in range(board_size):
		for file: int in range(board_size):
			var square: Vector2i = Vector2i(file, rank)
			var fill: Color = BoardPainter.square_color(square)
			# Squares outside the deployment zone sit back so the zone stands out.
			BoardPainter.draw_square(self, projection, square, fill if is_deploy_square(square) else fill.darkened(0.22))
	for rank: int in range(deploy_rows):
		for file: int in range(board_size):
			var square: Vector2i = Vector2i(file, rank)
			if rocks.has(square) or not is_deploy_square(square):
				continue
			BoardPainter.draw_marker(self, projection, square, ZONE_TINT)
			if selected_square != NO_SQUARE and not _pieces.has(square):
				BoardPainter.draw_ground_ellipse(self, projection, square, projection.cell * 0.2, TARGET_DOT)
	for hint_value: Variant in hints:
		var hint_square: Vector2i = hint_value
		if str(hints[hint_square]) == "attack":
			BoardPainter.draw_marker(self, projection, hint_square, HINT_ATTACK)
		else:
			BoardPainter.draw_ground_ellipse(self, projection, hint_square, projection.cell * 0.18, HINT_MOVE)
	if selected_square != NO_SQUARE:
		BoardPainter.draw_marker(self, projection, selected_square, SELECTED_TINT)
	for rock_value: Variant in rocks:
		BoardPainter.draw_ground_ellipse(self, projection, rock_value, projection.cell * 0.4, BoardPainter.SHADOW)
	for square_value: Variant in _pieces:
		var square: Vector2i = square_value
		BoardPainter.draw_ground_ellipse(self, projection, square, projection.cell * (0.26 if square == selected_square else 0.33), BoardPainter.SHADOW)
