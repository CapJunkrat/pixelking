class_name BoardEventPresenter
extends RefCounted

## Plays one action's BattleEvents on the battle board. The authoritative board has
## already changed; this shows how it got there: the mover travels as a stand-in (or
## BoardStrikePresenter plays a full strike), then follow-up effects (promotion,
## check, rings and bursts) play on the settled board. Blasts are BoardBlastPresenter's
## and the end of a battle is BattleFinalePresenter's. All of them run their tweens
## through `tweens` here, so a presentation ends only when every part is done.

const NO_SQUARE := Vector2i(-1, -1)
const CHECK_GLOW := Color(1.0, 0.32, 0.28)
const PROMOTION_GLOW := Color(1.0, 0.886, 0.588)
## Speed multipliers applied when the player turns on short battle animations.
const SHORT_STRIKE_SPEED := 2.2
const SHORT_MOVE_SPEED := 1.5

var view: BattleBoardView = null
## Running presentation tweens; the presentation ends when the last one finishes.
var tweens: Array[Tween] = []
## Stand-in sprites shown only while presenting; freed when it ends.
var nodes: Array[Node] = []
## Playback speed of the action being presented (before short-animation scaling).
var last_speed: float = 1.0
## Squares where a rock or a doomed piece bursts once the move lands.
var pending_bursts: Array[Vector2i] = []
var _pending_promotion: Vector2i = NO_SQUARE
var _pending_check: Dictionary = {}
var _pending_rings: Array[Vector2i] = []
var _strike: StrikeDirector = null
var _piece_layer: Node2D = null
var _ground_canvas: Node2D = null

func _init(owner_view: BattleBoardView, strike: StrikeDirector, piece_layer: Node2D, ground_canvas: Node2D) -> void:
	view = owner_view
	_strike = strike
	_piece_layer = piece_layer
	_ground_canvas = ground_canvas

# --- entry --------------------------------------------------------------------

func present(events: Array[BattleEvent], speed: float) -> void:
	view.input.clear_inspection(false)
	_pending_promotion = NO_SQUARE
	_pending_check = {}
	pending_bursts = []
	_pending_rings = []
	view.finale.reset()
	view.strikes.clear_echoes()
	view.strikes.eggs_by_victim = {}
	var digest: Dictionary = _read_events(events)
	var board: BoardState = view.board
	if board == null:
		return
	last_speed = speed
	var move_event: BattleEvent = digest["move"]
	var capture_event: BattleEvent = digest["capture"]
	var destroyed: Array[Dictionary] = digest["destroyed"]
	# Enemies a boomerang passes through react like the main target, at the same moment.
	var pierced: Array[Dictionary] = []
	if capture_event != null:
		for entry: Dictionary in destroyed.duplicate():
			if str(entry.get("cause", "")) == "pierce":
				pierced.append(entry)
				destroyed.erase(entry)
	view.blasts.spawn(destroyed, move_event, capture_event)
	_hold_broken_rocks(digest["broken_rocks"])
	view.finale.hold_doomed_king()
	if move_event == null:
		_finish_without_move()
		return
	var data: Dictionary = move_event.payload
	var from: Vector2i = data.get("from", NO_SQUARE)
	var to: Vector2i = data.get("to", NO_SQUARE)
	if not board.in_bounds(from) or not board.in_bounds(to):
		_finish_without_move()
		return
	var short: bool = short_animations()
	var strike_speed: float = speed * (SHORT_STRIKE_SPEED if short else 1.0)
	if capture_event != null and view.strikes.present(data, capture_event.payload, strike_speed):
		for entry: Dictionary in pierced:
			view.strikes.play_echo(data, entry, strike_speed)
		# A Powder Keg goes off when it bursts; any other blast when the blow lands.
		view.blasts.trigger = &"split" if StrikeLibrary.victim_reaction(StringName(str(capture_event.payload.get("piece_def_id", "")))) == &"keg" else &"impact"
		return
	if not pierced.is_empty():
		var fallback: Array[Dictionary] = []
		fallback.assign(pierced)
		view.blasts.spawn(fallback, move_event, capture_event)
	# A shell that absorbed the blow: the strike plays, the victim stays, the attacker bounces back.
	var shell_event: BattleEvent = digest["shell"]
	if capture_event == null and shell_event != null:
		var shelled_square: Vector2i = shell_event.payload.get("position", NO_SQUARE)
		var shelled: ChessPiece = board.get_piece(shelled_square)
		if shelled != null and shelled_square == data.get("target", NO_SQUARE):
			var shell_data: Dictionary = {"position": shelled_square, "piece_def_id": shelled.def.id, "color": shelled.color}
			if view.strikes.present(data, shell_data, strike_speed):
				view.pieces.hidden[shelled_square] = true
				view.blasts.trigger = &"impact"
				return
		_pending_rings.append(shelled_square)
	_present_travel(data, capture_event, bool(digest["castled"]), speed * (SHORT_MOVE_SPEED if short else 1.0))

## Sorts the events into what the presentation needs and records the follow-ups.
func _read_events(events: Array[BattleEvent]) -> Dictionary:
	var digest: Dictionary = {"move": null, "capture": null, "shell": null, "castled": false, "destroyed": [] as Array[Dictionary], "broken_rocks": [] as Array[Vector2i]}
	for event: BattleEvent in events:
		var position: Variant = event.payload.get("position", NO_SQUARE)
		match event.event_type:
			BattleCommandProcessor.EVENT_PIECE_MOVED:
				digest["move"] = event
			BattleCommandProcessor.EVENT_PIECE_CAPTURED:
				digest["capture"] = event
			BattleCommandProcessor.EVENT_CASTLED, BattleCommandProcessor.EVENT_KING_SWAPPED:
				digest["castled"] = true
			BattleCommandProcessor.EVENT_KING_EXECUTION:
				# Played after the move: the winning King blinks over and strikes it down.
				view.finale.queue_execution(event.payload)
			BattleCommandProcessor.EVENT_BATTLE_ENDED:
				if not bool(event.payload.get("draw", false)) and int(event.payload.get("winner", -1)) >= 0:
					view.finale.queue_banner(int(event.payload.get("winner", -1)) == view.player_color)
			BattleCommandProcessor.EVENT_PIECE_DESTROYED:
				(digest["destroyed"] as Array[Dictionary]).append(event.payload)
			BattleCommandProcessor.EVENT_ROCK_BROKEN:
				pending_bursts.append(position)
				(digest["broken_rocks"] as Array[Vector2i]).append(position)
			BattleCommandProcessor.EVENT_SHELL_BROKEN:
				if digest["shell"] == null:
					digest["shell"] = event
				else:
					_pending_rings.append(position)
			BattleCommandProcessor.EVENT_LAST_STAND, BattleCommandProcessor.EVENT_PIECE_REVIVED, BattleCommandProcessor.EVENT_PIECE_EVOLVED, BattleCommandProcessor.EVENT_FORM_CHANGED, BattleCommandProcessor.EVENT_MOVE_LEARNED:
				_pending_rings.append(position)
			BattleCommandProcessor.EVENT_EGG_LAID:
				# The egg appears once the bird has fallen.
				view.pieces.hidden[position] = true
				view.strikes.eggs_by_victim[int(event.payload.get("victim_instance_id", -1))] = position
				_pending_rings.append(position)
			BattleCommandProcessor.EVENT_PROMOTED:
				_pending_promotion = position
			BattleCommandProcessor.EVENT_CHECK_DECLARED:
				_pending_check = event.payload
	return digest

## A broken rock stays until the move lands (it bursts with the follow-up effects).
func _hold_broken_rocks(squares: Array[Vector2i]) -> void:
	for square: Vector2i in squares:
		if view.board.on_board(square):
			var rock: Sprite2D = view.pieces.make_sprite(RockArt.texture())
			if rock != null:
				view.pieces.place_sprite(rock, view.projection.square_world(square))
				_piece_layer.add_child(rock)
				nodes.append(rock)

# --- a plain move ---------------------------------------------------------------

## The mover travels to its square as a stand-in sprite; a captured piece fades.
func _present_travel(data: Dictionary, capture_event: BattleEvent, castled: bool, speed: float) -> void:
	var projection: BoardProjection = view.projection
	var from: Vector2i = data.get("from", NO_SQUARE)
	var to: Vector2i = data.get("to", NO_SQUARE)
	var captured: bool = capture_event != null
	var piece_id: String = str(data.get("piece_def_id", "queen"))
	var proxy: Sprite2D = view.pieces.make_sprite(view.pieces.texture_for(int(data.get("color", view.player_color)), piece_id))
	if proxy == null:
		_finish_without_move()
		return
	var definition: PieceDef = Content.piece(piece_id)
	var profile: PieceMotionProfile = definition.motion_profile if definition != null and definition.motion_profile != null else Content.motion_profile(&"queen")
	var duration: float = (profile.capture_duration if captured else profile.move_duration) / maxf(speed, 0.1)
	var presentation_kind: StringName = presentation_kind_for(definition, captured)
	var weight: int = definition.weight_class if definition != null else PieceDef.WeightClass.MEDIUM
	var start: Vector3 = projection.square_world(from)
	var finish: Vector3 = projection.square_world(to)
	view.pieces.place_sprite(proxy, start)
	_piece_layer.add_child(proxy)
	nodes.append(proxy)
	# The authoritative board already shows the mover on its destination; keep that
	# sprite hidden until the travelling proxy arrives.
	view.pieces.hidden[to] = true
	var victim: Sprite2D = null
	if captured:
		var capture_data: Dictionary = capture_event.payload
		victim = view.pieces.make_sprite(view.pieces.texture_for(int(capture_data.get("color", view.player_color)), str(capture_data.get("piece_def_id", ""))))
		if victim != null:
			view.pieces.place_sprite(victim, projection.square_world(capture_data.get("position", to)))
			_piece_layer.add_child(victim)
			nodes.append(victim)

	var tween: Tween = view.create_tween().bind_node(view).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tweens.append(tween)
	# Anticipation: every piece crouches briefly before it leaves its square.
	tween.tween_method(stretch.bind(proxy), Vector2.ONE, Vector2(1.12, 0.86), 0.06 / maxf(speed, 0.1))
	match presentation_kind:
		&"teleport":
			tween.tween_property(proxy, "modulate:a", 0.0, duration * 0.35)
			tween.tween_callback(view.pieces.place_sprite.bind(proxy, finish))
			tween.tween_property(proxy, "modulate:a", 1.0, duration * 0.35)
		&"bent_ray":
			var corner: Vector3 = projection.square_world(bent_corner_square(definition, from, to))
			tween.tween_method(travel.bind(proxy, start, corner, 0.0), 0.0, 1.0, duration * 0.35)
			tween.tween_method(travel.bind(proxy, corner, finish, 0.0), 0.0, 1.0, duration * 0.65)
		&"lob":
			tween.tween_method(travel.bind(proxy, start, finish, projection.cell * 1.6), 0.0, 1.0, duration)
		_:
			# Light pieces hop, heavy pieces slide; the castling king vaults over its partner.
			var arc: float = 0.0
			if castled:
				arc = projection.cell * 0.7
			elif profile.path_type == PieceMotionProfile.PathType.ARC:
				arc = projection.cell * profile.arc_height_cells
			elif weight == PieceDef.WeightClass.LIGHT:
				arc = projection.cell * 0.3
			var travel_time: float = maxf(duration, (0.13 + 0.03 * Vector2(to - from).length()) / maxf(speed, 0.1))
			tween.tween_method(travel.bind(proxy, start, finish, arc), 0.0, 1.0, travel_time)
			tween.parallel().tween_method(stretch.bind(proxy), Vector2(0.94, 1.08), Vector2(0.94, 1.08), travel_time)
	if presentation_kind == &"petrify":
		tween.parallel().tween_property(proxy, "modulate", Color(0.4, 1.25, 1.35, 1.0), duration * 0.6)
	elif presentation_kind == &"chained_capture":
		tween.tween_property(proxy, "modulate", Color(1.4, 1.2, 0.8, 1.0), duration * 0.18)
		tween.tween_property(proxy, "modulate", Color.WHITE, duration * 0.12)
	elif captured:
		tween.parallel().tween_property(proxy, "modulate", Color(1.35, 0.85, 0.65, 1.0), duration * 0.45)
	if victim != null:
		var fade: Tween = view.create_tween().bind_node(view)
		tweens.append(fade)
		fade.tween_interval(duration * 0.8)
		fade.tween_callback(view.blasts.detonate)
		fade.tween_property(victim, "modulate:a", 0.0, maxf(duration * 0.2, 0.01))
		fade.tween_callback(finish_tween.bind(fade))
	elif view.blasts.has_doomed():
		tween.tween_callback(view.blasts.detonate)
	if castled:
		_present_castling_partner(from, to, duration, speed)
	# Landing: a squash and a little dust, heavier pieces kick up more.
	tween.tween_callback(land.bind(finish, weight))
	tween.tween_method(stretch.bind(proxy), Vector2(1.16, 0.82), Vector2.ONE, 0.1 / maxf(speed, 0.1))
	tween.tween_callback(finish_tween.bind(tween))

## Castling swaps the king with its partner: the partner slides back to the king's square.
func _present_castling_partner(king_from: Vector2i, king_to: Vector2i, duration: float, speed: float) -> void:
	var partner_piece: ChessPiece = view.board.get_piece(king_from)
	var partner: Sprite2D = view.pieces.make_sprite(view.pieces.piece_texture(partner_piece))
	if partner == null:
		return
	var start: Vector3 = view.projection.square_world(king_to)
	var finish: Vector3 = view.projection.square_world(king_from)
	view.pieces.place_sprite(partner, start)
	_piece_layer.add_child(partner)
	nodes.append(partner)
	view.pieces.hidden[king_from] = true
	var travel_time: float = maxf(duration, (0.13 + 0.03 * Vector2(king_to - king_from).length()) / maxf(speed, 0.1))
	var slide: Tween = view.create_tween().bind_node(view).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tweens.append(slide)
	slide.tween_interval(0.06 / maxf(speed, 0.1))
	slide.tween_method(travel.bind(partner, start, finish, 0.0), 0.0, 1.0, travel_time)
	slide.tween_callback(land.bind(finish, PieceDef.WeightClass.HEAVY))
	slide.tween_method(stretch.bind(partner), Vector2(1.12, 0.86), Vector2.ONE, 0.1 / maxf(speed, 0.1))
	slide.tween_callback(finish_tween.bind(slide))

func stretch(value: Vector2, sprite: Sprite2D) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.set_meta("stretch", value)
	sprite.scale = Vector2.ONE * float(sprite.get_meta("placed_scale", sprite.scale.x)) * value

func land(world: Vector3, weight: int) -> void:
	if _strike == null:
		return
	_strike.fx.puff(world + Vector3(0.0, _strike.fx.unit, 0.0), 3 + weight * 2, 0.5 + 0.2 * weight)
	if weight == PieceDef.WeightClass.HEAVY:
		_strike.fx.ring(world.x, world.z, view.projection.cell * 0.5, 0.25)

## Tween step: moves `sprite` from `start` to `finish`, lifting it along a parabola.
func travel(progress: float, sprite: Sprite2D, start: Vector3, finish: Vector3, arc_height: float) -> void:
	if not is_instance_valid(sprite):
		return
	var world: Vector3 = start.lerp(finish, progress)
	world.y = lerpf(start.y, finish.y, progress) + arc_height * 4.0 * progress * (1.0 - progress)
	view.pieces.place_sprite(sprite, world)
	_ground_canvas.queue_redraw()

## Shadows under the stand-ins, shrinking as they rise.
func draw_proxy_shadows() -> void:
	var projection: BoardProjection = view.projection
	for node: Node in nodes:
		if not is_instance_valid(node) or not node.has_meta("world"):
			continue
		var world: Vector3 = node.get_meta("world")
		var shrink: float = maxf(0.4, 1.0 - world.y / (projection.cell * 2.5))
		var radius: float = projection.cell * 0.33 * shrink
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in range(16):
			var angle: float = TAU * step / 16.0
			points.append(projection.project(Vector3(world.x + cos(angle) * radius, 0.0, world.z + sin(angle) * radius)))
		_ground_canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.34 * shrink * (node as CanvasItem).modulate.a))

func short_animations() -> bool:
	var settings: AppSettingsManager = view.get_node_or_null("/root/SettingsManager") as AppSettingsManager
	return settings != null and settings.short_battle_animations

static func presentation_kind_for(definition: PieceDef, captured: bool = false) -> StringName:
	if definition == null:
		return &"standard"
	for rule: MovementRule in definition.resolved_movement_rules():
		if rule.rule_id() == &"shadow_step":
			return &"teleport"
		if rule is TeleportMovementRule:
			return &"teleport"
		if rule is RangeTeleportMovementRule and (rule as RangeTeleportMovementRule).once_ability.is_empty():
			return &"teleport"
		if rule is BentRayMovementRule:
			return &"bent_ray"
		if rule is SlideMovementRule and (rule as SlideMovementRule).jump_over_occupied:
			return &"lob"
	if definition.immobilizes_adjacent:
		return &"petrify"
	if captured and definition.extra_move_on_capture:
		return &"chained_capture"
	return &"standard"

## The square where a bent-ray mover (Manticore) turns on its way from `from` to `to`.
func bent_corner_square(definition: PieceDef, from: Vector2i, to: Vector2i) -> Vector2i:
	for rule: MovementRule in definition.resolved_movement_rules():
		var bent_rule: BentRayMovementRule = rule as BentRayMovementRule
		if bent_rule == null:
			continue
		for initial_direction: Vector2i in bent_rule.initial_directions:
			var corner: Vector2i = from + initial_direction
			var delta: Vector2i = to - corner
			for ray_direction: Vector2i in bent_rule.ray_directions:
				if delta.x * ray_direction.x + delta.y * ray_direction.y > 0 and delta.x * ray_direction.y == delta.y * ray_direction.x and view.board.in_bounds(corner):
					return corner
	return Vector2i(to.x, from.y)

# --- lifecycle ------------------------------------------------------------------

func is_presenting() -> bool:
	return not tweens.is_empty() or view.strikes.is_playing()

## Stops every tween and strike at once.
func stop_all() -> void:
	for tween: Tween in tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	tweens.clear()
	view.strikes.stop()

func skip() -> void:
	view.finale.forget_execution()
	stop_all()
	end_presentation()

func finish_tween(tween: Tween) -> void:
	tweens.erase(tween)
	if tweens.is_empty() and not view.strikes.is_playing():
		end_presentation()

func end_presentation() -> void:
	view.blasts.detonate()
	if not tweens.is_empty():
		return
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	nodes.clear()
	view.pieces.hidden = view.finale.hidden_squares()
	view.finale.stop_running()
	_strike.time_scale = 1.0
	view.refresh()
	view.finale.reveal()
	_ground_canvas.queue_redraw()
	_play_followups()
	# The battle's last word: the execution, then the banner, then the result screen.
	if view.finale.play_next():
		return
	view.presentations_completed.emit()

## A move-less action (an item) or a move that could not be animated.
func _finish_without_move() -> void:
	if view.blasts.has_doomed():
		view.blasts.detonate_from_first()
		return
	if view.finale.has_pending():
		end_presentation()
		return
	_play_followups()

## Effects that play on the settled board after a move: promotion flash, check alarm.
func _play_followups() -> void:
	var board: BoardState = view.board
	if board == null or _strike == null:
		return
	var projection: BoardProjection = view.projection
	var fx: StrikeFx = _strike.fx
	if _pending_promotion != NO_SQUARE and board.in_bounds(_pending_promotion):
		var world: Vector3 = projection.square_world(_pending_promotion)
		fx.ring(world.x, world.z, projection.cell * 0.9, 0.45, PROMOTION_GLOW)
		fx.ring(world.x, world.z, projection.cell * 0.5, 0.3, PROMOTION_GLOW)
		fx.spark_burst(world + Vector3(0.0, projection.cell * 0.5, 0.0), 14, Vector2.ZERO, 0.0, 0.7)
		var promoted: Sprite2D = view.pieces.sprites.get(_pending_promotion) as Sprite2D
		if promoted != null:
			var rest: Vector2 = promoted.scale
			promoted.scale = rest * Vector2(0.55, 1.6)
			promoted.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(promoted, "scale", rest, 0.28)
	if not _pending_check.is_empty():
		var color: int = int(_pending_check.get("color", -1))
		if board.has_king(color):
			var king_square: Vector2i = board.king_pos[color]
			var world: Vector3 = projection.square_world(king_square)
			var mate: bool = bool(_pending_check.get("checkmate", false))
			fx.ring(world.x, world.z, projection.cell * (1.3 if mate else 0.9), 0.5, CHECK_GLOW)
			if mate:
				fx.ring(world.x, world.z, projection.cell * 0.7, 0.35, CHECK_GLOW)
			var king: Sprite2D = view.pieces.sprites.get(king_square) as Sprite2D
			if king != null:
				var home: Vector2 = king.position
				var shake: Tween = king.create_tween()
				for step: int in range(6):
					var reach: float = projection.cell * 0.09 * (1.0 - step / 6.0) * (1.0 if step % 2 == 0 else -1.0)
					shake.tween_property(king, "position", home + Vector2(reach, 0.0), 0.04)
				shake.tween_property(king, "position", home, 0.04)
	for square: Vector2i in pending_bursts:
		if board.on_board(square):
			var burst_at: Vector3 = projection.square_world(square)
			fx.puff(burst_at + Vector3(0.0, fx.unit * 4.0, 0.0), 10, 1.0)
			fx.spark_burst(burst_at + Vector3(0.0, projection.cell * 0.3, 0.0), 12, Vector2.ZERO, 0.0, 0.9)
	for square: Vector2i in _pending_rings:
		if board.in_bounds(square):
			var ring_at: Vector3 = projection.square_world(square)
			fx.ring(ring_at.x, ring_at.z, projection.cell * 0.8, 0.4, PROMOTION_GLOW)
	pending_bursts = []
	_pending_rings = []
	_pending_promotion = NO_SQUARE
	_pending_check = {}

func sfx(sound: StringName, volume_db: float = 0.0) -> void:
	var audio: Node = view.get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", sound, volume_db)
