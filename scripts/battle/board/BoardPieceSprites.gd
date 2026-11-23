class_name BoardPieceSprites
extends RefCounted

## The standing figures on the battle board: one sprite per piece and per rock, rebuilt
## from the authoritative board on every refresh. Pieces held by a gorgon are shown as
## stone; a newly held piece petrifies under a gaze beam drawn on the air canvas.
##
## `hidden` lists squares whose sprite is kept out of sight on purpose while a move or
## the battle's finale is presented (the board already shows the result; a stand-in
## plays it out). Every presentation component reads and writes it here.

const NO_SQUARE := Vector2i(-1, -1)
const STONE_SHADER: Shader = preload("res://assets/shaders/stone_piece.gdshader")
const PETRIFY_SECONDS := 0.8
const CRACK_SECONDS := 0.4
const GAZE_COLOR := Color(0.9, 1.0, 0.55)

var view: BattleBoardView = null
## Square -> Sprite2D for every piece currently standing on the board.
var sprites: Dictionary = {}
## Squares whose piece is not drawn (see above): square -> true.
var hidden: Dictionary = {}
var _piece_layer: Node2D = null
var _air_canvas: Node2D = null
var _rock_sprites: Array[Sprite2D] = []
## Pieces currently shown as stone (held by a gorgon), keyed by square + piece, so a
## piece that stays held does not replay the petrify animation on every refresh.
var _stone_keys: Dictionary = {}
## Gorgon gaze beams in flight: [gorgon square, target square, seconds elapsed].
var _gazes: Array = []

func _init(owner_view: BattleBoardView, piece_layer: Node2D, air_canvas: Node2D) -> void:
	view = owner_view
	_piece_layer = piece_layer
	_air_canvas = air_canvas

# --- sprites --------------------------------------------------------------------

func make_sprite(texture: Texture2D) -> Sprite2D:
	return BoardPainter.make_sprite(texture, view.projection)

## Positions a piece sprite so its feet rest on `world` (Y lifts it off the board).
func place_sprite(sprite: Sprite2D, world: Vector3) -> void:
	BoardPainter.place_sprite(sprite, view.projection, world)

func piece_texture(piece: ChessPiece) -> Texture2D:
	if piece == null:
		return null
	return texture_for(piece.color, piece.def.id)

func texture_for(color: int, piece_id: String) -> Texture2D:
	var color_id: StringName = &"white" if color == GameRules.PieceColor.WHITE else &"black"
	return view.piece_skin_manager.call("piece_texture", color_id, StringName(piece_id)) as Texture2D

func rebuild() -> void:
	var board: BoardState = view.board
	var projection: BoardProjection = view.projection
	for rock: Sprite2D in _rock_sprites:
		if is_instance_valid(rock):
			_piece_layer.remove_child(rock)
			rock.queue_free()
	_rock_sprites.clear()
	for square_value: Variant in board.rocks:
		var square: Vector2i = square_value
		var rock: Sprite2D = make_sprite(RockArt.texture())
		rock.name = "Rock_%d_%d" % [square.x, square.y]
		place_sprite(rock, projection.square_world(square))
		_piece_layer.add_child(rock)
		_rock_sprites.append(rock)
	for sprite_value: Variant in sprites.values():
		var old: Sprite2D = sprite_value as Sprite2D
		if is_instance_valid(old):
			_piece_layer.remove_child(old)
			old.queue_free()
	sprites.clear()
	var previous_stone: Dictionary = _stone_keys
	_stone_keys = {}
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			var piece: ChessPiece = board.get_piece(square)
			if piece == null:
				continue
			var sprite: Sprite2D = make_sprite(piece_texture(piece))
			if sprite == null:
				continue
			sprite.name = "Piece_%d_%d" % [file, rank]
			place_sprite(sprite, projection.square_world(square))
			if board.is_piece_immobilized(square):
				_show_stone(sprite, square, piece, previous_stone)
			sprite.visible = not hidden.has(square)
			_piece_layer.add_child(sprite)
			sprites[square] = sprite

# --- stone --------------------------------------------------------------------

## Held pieces turn to stone. A newly held piece petrifies from the feet up under the
## gorgon's gaze; while a move is still animating it waits so the gorgon arrives first.
func _show_stone(sprite: Sprite2D, square: Vector2i, piece: ChessPiece, previous: Dictionary) -> void:
	var key: String = "%d_%d_%s_%d" % [square.x, square.y, piece.def.id, piece.color]
	var known: bool = previous.has(key)
	if not known and view.is_presenting():
		return
	_stone_keys[key] = true
	var chunks: PieceChunks = PieceChunks.of(sprite.texture)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = STONE_SHADER
	material.set_shader_parameter(&"used", chunks.used_uv())
	material.set_shader_parameter(&"aspect", chunks.aspect)
	material.set_shader_parameter(&"seed", float(square.x * 7 + square.y * 3))
	material.set_shader_parameter(&"progress", 1.0 if known else 0.0)
	material.set_shader_parameter(&"crack", 1.0 if known else 0.0)
	sprite.material = material
	if known:
		return
	var gorgon: Vector2i = _holding_gorgon(square, piece)
	if gorgon != NO_SQUARE:
		_gazes.append([gorgon, square, 0.0])
	var tween: Tween = view.create_tween()
	tween.tween_method(_set_stone.bind(material, &"progress"), 0.0, 1.0, PETRIFY_SECONDS / view.presentation_speed)
	tween.tween_method(_set_stone.bind(material, &"crack"), 0.0, 1.0, CRACK_SECONDS / view.presentation_speed)

func _set_stone(value: float, material: ShaderMaterial, parameter: StringName) -> void:
	material.set_shader_parameter(parameter, value)

func _holding_gorgon(square: Vector2i, piece: ChessPiece) -> Vector2i:
	var board: BoardState = view.board
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var neighbour: Vector2i = square + Vector2i(dx, dy)
			if neighbour == square or not board.in_bounds(neighbour):
				continue
			var other: ChessPiece = board.get_piece(neighbour)
			if other != null and other.color != piece.color and other.def.immobilizes_adjacent:
				return neighbour
	return NO_SQUARE

## Ages the gaze beams; called every frame by the view.
func advance(delta: float) -> void:
	if _gazes.is_empty():
		return
	for gaze: Array in _gazes:
		gaze[2] = float(gaze[2]) + delta * view.presentation_speed
	_gazes = _gazes.filter(func(gaze: Array) -> bool: return float(gaze[2]) < 0.6)
	_air_canvas.queue_redraw()

## The gorgon's eyes light up and a wavering beam reaches the piece it holds.
func draw_gazes() -> void:
	var projection: BoardProjection = view.projection
	var stand: float = view.standing_offset()
	for gaze: Array in _gazes:
		var age: float = float(gaze[2])
		var alpha: float = clampf(age / 0.12, 0.0, 1.0) * (1.0 - clampf((age - 0.4) / 0.2, 0.0, 1.0))
		var source: Vector3 = projection.square_world(gaze[0])
		var target: Vector3 = projection.square_world(gaze[1])
		var piece_pixels: float = projection.cell * BoardPainter.PIECE_HEIGHT_CELLS
		var eye_height: float = projection.height_for_pixels(piece_pixels * 0.62)
		var eye: Vector2 = projection.project(Vector3(source.x, eye_height, source.z + stand))
		var hit: Vector2 = projection.project(Vector3(target.x, projection.height_for_pixels(piece_pixels * 0.45), target.z + stand))
		var unit: float = projection.cell / 18.0
		var waver: Vector2 = Vector2(0.0, sin(age * 50.0) * unit)
		_air_canvas.draw_line(eye, hit + waver, Color(GAZE_COLOR, 0.25 * alpha), 4.0 * unit)
		_air_canvas.draw_line(eye - Vector2(unit, 0.0), hit + waver, Color(GAZE_COLOR, alpha), maxf(unit, 1.0))
		_air_canvas.draw_line(eye + Vector2(unit, 0.0), hit - waver, Color(GAZE_COLOR, alpha), maxf(unit, 1.0))
		_air_canvas.draw_rect(Rect2(eye - Vector2(2.0, 0.5) * unit, Vector2(unit, unit)), Color(GAZE_COLOR, alpha))
		_air_canvas.draw_rect(Rect2(eye + Vector2(1.0, -0.5) * unit, Vector2(unit, unit)), Color(GAZE_COLOR, alpha))

# --- diagnostics ----------------------------------------------------------------

## Where the screen and the rules disagree, for battle codes: "d5:hidden" (a piece the
## rules have but the screen hides), "d5:nosprite", "d5:faded", "d5:ghost" (a sprite
## with no piece behind it), "d5:wrongart". Empty when they agree.
func report(issues: Array[String]) -> void:
	var board: BoardState = view.board
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			var name: String = BattleRecord.square_name(square)
			var piece: ChessPiece = board.get_piece(square)
			var sprite: Sprite2D = sprites.get(square) as Sprite2D
			if piece == null:
				if sprite != null and is_instance_valid(sprite) and sprite.visible:
					issues.append("%s:ghost" % name)
				continue
			if hidden.has(square):
				issues.append("%s:hidden" % name)
			elif sprite == null or not is_instance_valid(sprite) or not sprite.is_inside_tree():
				issues.append("%s:nosprite" % name)
			elif not sprite.is_visible_in_tree():
				issues.append("%s:invisible" % name)
			elif sprite.modulate.a < 0.3 or sprite.self_modulate.a < 0.3 or sprite.scale.length() < 0.05:
				issues.append("%s:faded" % name)
			elif sprite.texture != piece_texture(piece):
				issues.append("%s:wrongart" % name)
