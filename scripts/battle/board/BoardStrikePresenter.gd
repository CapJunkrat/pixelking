class_name BoardStrikePresenter
extends RefCounted

## Captures played as full strike animations (StrikeDirector): the main blow, plus an
## echo strike for every extra victim of the same blow (each enemy a boomerang passes
## through), in step with the main one. BoardEventPresenter decides when a capture is
## shown this way; the presentation it belongs to ends once every strike is done.

const NO_SQUARE := Vector2i(-1, -1)

var view: BattleBoardView = null
## Egg squares laid this move, keyed by the instance id of the bird that fell (the
## strike shows the egg landing there).
var eggs_by_victim: Dictionary = {}
var _strike: StrikeDirector = null
var _echo_strikes: Array[StrikeDirector] = []

func _init(owner_view: BattleBoardView, strike: StrikeDirector) -> void:
	view = owner_view
	_strike = strike

## Plays the capture as a full strike animation when the attacker has one. Returns
## false when the simple move presentation should be used instead.
func present(move_data: Dictionary, capture_data: Dictionary, speed: float) -> bool:
	var board: BoardState = view.board
	var from: Vector2i = move_data.get("from", NO_SQUARE)
	var to: Vector2i = move_data.get("to", NO_SQUARE)
	# En passant hits a piece that does not stand on the destination square.
	var victim_square: Vector2i = capture_data.get("position", to)
	if not board.in_bounds(victim_square) or victim_square == from:
		return false
	var attacker_id: String = str(move_data.get("piece_def_id", ""))
	var attacker_def: PieceDef = Content.piece(attacker_id)
	if attacker_def == null:
		return false
	# Forms of one piece (Squire levels, tide states) share that piece's attack.
	# Hybrids moving like a knight borrow the knight's stomp (see StrikeDirector.resolve_attack).
	var aim: Vector2i = move_data.get("target", to)
	var attack: Array = StrikeDirector.resolve_attack(StringName(attacker_def.art_key()), attacker_def.strike_type, from, aim)
	var attack_id: StringName = attack[0]
	var strike_type: int = attack[1]
	if not StrikeDirector.can_play(attack_id, strike_type):
		return false
	var victim_def: PieceDef = Content.piece(str(capture_data.get("piece_def_id", "")))
	var attacker_color: int = int(move_data.get("color", view.player_color))
	var attacker_texture: Texture2D = view.pieces.texture_for(attacker_color, attacker_id)
	var victim_texture: Texture2D = view.pieces.texture_for(int(capture_data.get("color", view.player_color)), str(capture_data.get("piece_def_id", "")))
	if victim_def == null or attacker_texture == null or victim_texture == null:
		return false
	view.pieces.hidden[to] = true
	var corner: Vector2i = NO_SQUARE
	if BoardEventPresenter.presentation_kind_for(attacker_def) == &"bent_ray":
		corner = view.presenter.bent_corner_square(attacker_def, from, to)
	_strike.mimic_texture = view.pieces.texture_for(attacker_color, str(capture_data.get("piece_def_id", "")))
	_strike.egg_square = eggs_by_victim.get(int(capture_data.get("instance_id", -1)), NO_SQUARE)
	var settled_attacker: ChessPiece = board.get_piece(to)
	_strike.returning_attacker_alive = settled_attacker != null and settled_attacker.get_id() == attacker_id and settled_attacker.color == attacker_color
	_strike.play(attack_id, attacker_texture, victim_texture, from, to, strike_type, attacker_def.weight_class, victim_def.weight_class, speed, victim_square, corner, StringName(victim_def.id))
	return true

## The hit reaction of one extra victim of the current blow (same attack, same timing).
func play_echo(move_data: Dictionary, entry: Dictionary, speed: float) -> void:
	var from: Vector2i = move_data.get("from", NO_SQUARE)
	var to: Vector2i = move_data.get("to", NO_SQUARE)
	var victim_square: Vector2i = entry.get("position", NO_SQUARE)
	var attacker_id: String = str(move_data.get("piece_def_id", ""))
	var attacker_def: PieceDef = Content.piece(attacker_id)
	var victim_def: PieceDef = Content.piece(str(entry.get("piece_def_id", "")))
	if attacker_def == null or victim_def == null or not view.board.in_bounds(victim_square):
		return
	var attack: Array = StrikeDirector.resolve_attack(StringName(attacker_def.art_key()), attacker_def.strike_type, from, victim_square)
	var attacker_texture: Texture2D = view.pieces.texture_for(int(move_data.get("color", view.player_color)), attacker_id)
	var victim_texture: Texture2D = view.pieces.texture_for(int(entry.get("color", view.player_color)), victim_def.id)
	if attacker_texture == null or victim_texture == null or not StrikeDirector.can_play(attack[0], attack[1]):
		return
	var echo: StrikeDirector = StrikeDirector.new()
	echo.name = "EchoStrike"
	echo.victim_only = true
	view.add_child(echo)
	echo.setup(view)
	echo.finished.connect(_on_echo_finished)
	_echo_strikes.append(echo)
	echo.egg_square = eggs_by_victim.get(int(entry.get("instance_id", -1)), NO_SQUARE)
	echo.play(attack[0], attacker_texture, victim_texture, from, to, attack[1], attacker_def.weight_class, victim_def.weight_class, speed, victim_square, NO_SQUARE, StringName(victim_def.id))
	echo.align_impact(_strike)

## The echo strikes of the current blow (for tests).
func echo_strikes() -> Array[StrikeDirector]:
	return _echo_strikes

func is_playing() -> bool:
	return (_strike != null and _strike.is_playing()) or echoes_playing()

func echoes_playing() -> bool:
	for echo: StrikeDirector in _echo_strikes:
		if is_instance_valid(echo) and echo.is_playing():
			return true
	return false

## Stops the main strike and every echo at once.
func stop() -> void:
	if _strike != null:
		_strike.stop()
	clear_echoes(true)

## Echo strikes that have finished and faded are removed before the next blow.
func clear_echoes(force: bool = false) -> void:
	var kept: Array[StrikeDirector] = []
	for echo: StrikeDirector in _echo_strikes:
		if not is_instance_valid(echo):
			continue
		if force or not echo.is_playing():
			echo.stop()
			echo.queue_free()
		else:
			kept.append(echo)
	_echo_strikes = kept

func on_strike_finished() -> void:
	if view.presenter.tweens.is_empty() and not echoes_playing():
		view.presenter.end_presentation()

func _on_echo_finished() -> void:
	if view.presenter.tweens.is_empty() and not _strike.is_playing() and not echoes_playing():
		view.presenter.end_presentation()

## A strike reached its impact or split moment: a blast may go off, and the
## execution blow slows down.
func on_strike_moment(moment: StringName) -> void:
	view.blasts.on_strike_moment(moment)
	if moment == &"impact" and view.finale.is_running() and not view.presenter.short_animations():
		view.finale.slow_motion()
