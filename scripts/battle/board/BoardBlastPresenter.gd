class_name BoardBlastPresenter
extends RefCounted

## Pieces caught by an explosion or a splash. The board has already lost them, so
## stand-ins keep them on screen until the blast reaches them; then each one flashes,
## is thrown clear and fades in smoke, nearest to the blast first.

const NO_SQUARE := Vector2i(-1, -1)
const BLAST_ORANGE := Color(1.0, 0.59, 0.24)

var view: BattleBoardView = null
## &"impact" or &"split": which moment of the running strike sets off the blast.
var trigger: StringName = &""
## Stand-ins waiting for the blast: [{square, sprite, def_id}].
var _doomed: Array[Dictionary] = []
var _origin: Vector2i = NO_SQUARE
var _strike: StrikeDirector = null
var _piece_layer: Node2D = null

func _init(owner_view: BattleBoardView, strike: StrikeDirector, piece_layer: Node2D) -> void:
	view = owner_view
	_strike = strike
	_piece_layer = piece_layer

func has_doomed() -> bool:
	return not _doomed.is_empty()

## Stand-ins for the pieces a blast will remove. The attacker blown up with a Powder
## Keg is left to the strike; a piece with no art just bursts with the follow-ups.
func spawn(destroyed: Array[Dictionary], move_event: BattleEvent, capture_event: BattleEvent) -> void:
	var presenter: BoardEventPresenter = view.presenter
	_doomed = []
	trigger = &""
	_origin = NO_SQUARE
	if capture_event != null:
		_origin = capture_event.payload.get("position", NO_SQUARE)
	var landing: Vector2i = move_event.payload.get("to", NO_SQUARE) if move_event != null else NO_SQUARE
	for entry: Dictionary in destroyed:
		var square: Vector2i = entry.get("position", NO_SQUARE)
		if not view.board.in_bounds(square):
			continue
		if square == landing and capture_event != null:
			presenter.pending_bursts.append(square)
			continue
		var sprite: Sprite2D = view.pieces.make_sprite(view.pieces.texture_for(int(entry.get("color", view.player_color)), str(entry.get("piece_def_id", ""))))
		if sprite == null:
			presenter.pending_bursts.append(square)
			continue
		view.pieces.place_sprite(sprite, view.projection.square_world(square))
		_piece_layer.add_child(sprite)
		presenter.nodes.append(sprite)
		_doomed.append({"square": square, "sprite": sprite, "def_id": str(entry.get("piece_def_id", ""))})
	if _origin == NO_SQUARE and not _doomed.is_empty():
		_origin = _doomed[0]["square"]

func on_strike_moment(moment: StringName) -> void:
	if not _doomed.is_empty() and moment == trigger:
		detonate()

## Sets off the blast from the first doomed piece (no strike to time it by).
func detonate_from_first() -> void:
	if _doomed.is_empty():
		return
	_origin = _doomed[0]["square"]
	detonate()

## The blast reaches the doomed pieces one after another, nearest first: each one
## flashes, is thrown clear of the blast and fades in a puff of smoke.
func detonate() -> void:
	if _doomed.is_empty():
		return
	var presenter: BoardEventPresenter = view.presenter
	var projection: BoardProjection = view.projection
	var doomed: Array[Dictionary] = _doomed
	_doomed = []
	var origin: Vector2i = _origin
	doomed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a["square"] - origin).length() < Vector2(b["square"] - origin).length())
	var speed: float = maxf(presenter.last_speed * (BoardEventPresenter.SHORT_STRIKE_SPEED if presenter.short_animations() else 1.0), 0.1)
	for index: int in range(doomed.size()):
		var entry: Dictionary = doomed[index]
		var sprite: Sprite2D = entry["sprite"]
		var square: Vector2i = entry["square"]
		if not is_instance_valid(sprite):
			continue
		var away: Vector2 = Vector2(square - origin)
		if away.length() < 0.1:
			away = Vector2(randf_range(-1.0, 1.0), -1.0)
		away = away.normalized()
		var start: Vector3 = projection.square_world(square)
		var finish: Vector3 = start + Vector3(away.x, 0.0, -away.y) * projection.cell * 1.3
		var flight: float = 0.5 / speed
		var tween: Tween = view.create_tween().bind_node(view)
		presenter.tweens.append(tween)
		tween.tween_interval((0.04 + 0.09 * index) / speed)
		tween.tween_callback(hit.bind(square, entry["def_id"] == "powder_keg"))
		tween.tween_property(sprite, "modulate", Color(2.2, 1.5, 0.9, 1.0), 0.05 / speed)
		tween.tween_method(presenter.travel.bind(sprite, start, finish, projection.cell * 0.9), 0.0, 1.0, flight)
		tween.parallel().tween_property(sprite, "rotation", (1.0 if away.x >= 0.0 else -1.0) * 2.4, flight)
		tween.parallel().tween_property(sprite, "modulate", Color(0.35, 0.3, 0.3, 0.0), flight).set_ease(Tween.EASE_IN)
		tween.tween_callback(presenter.finish_tween.bind(tween))

## One blast going off on `square` (a Powder Keg's is bigger).
func hit(square: Vector2i, keg: bool) -> void:
	if _strike == null:
		return
	view.presenter.sfx(&"explode", -3.0 if not keg else 0.0)
	var fx: StrikeFx = _strike.fx
	var at: Vector3 = view.projection.square_world(square)
	fx.puff(at + Vector3(0.0, fx.unit * 4.0, 0.0), 14 if keg else 8, 1.4 if keg else 1.0)
	fx.spark_burst(at + Vector3(0.0, view.projection.cell * 0.3, 0.0), 16 if keg else 10, Vector2.ZERO, 0.0, 1.0, BLAST_ORANGE)
	if keg:
		fx.ring(at.x, at.z, view.projection.cell * 1.6, 0.5, BLAST_ORANGE)
