class_name StrikeDirector
extends Node

## Plays a capture as a short strike animation on the 2.5D board. Presentation only.
##
## The attack belongs to the attacking piece, the reaction belongs to the victim, and
## the two meet at the moment of impact. Which reaction plays is decided by the
## attacker's strike type and the two pieces' weight classes (see _pick_reaction).
## Timings follow docs/prototypes/strike_lab.html; lengths there are in "design units"
## (1/18 of a cell) and are scaled here by `_unit`.

signal finished
## The blow lands (after the wind-up, before the hit-stop).
signal impacted
## The victim breaks apart (for the Powder Keg: the moment it explodes).
signal victim_split

enum Phase { IDLE, PLAYING, AFTERGLOW }

const PIECE_SHADER: Shader = preload("res://assets/shaders/strike_piece.gdshader")
const GHOST_SHADER: Shader = preload("res://assets/shaders/strike_ghost.gdshader")
const ROWS := PieceChunks.ROWS
const GOLD := Color(1.0, 0.886, 0.588)
const AMBER := Color(0.878, 0.706, 0.361)
const MAX_GHOSTS := 12
const VOID_COLOR := Color(0.79, 0.63, 1.0)
const VOID_DEEP := Color(0.54, 0.35, 0.84)
const VENOM_COLOR := Color(0.53, 0.83, 0.42)
const VENOM_DARK := Color(0.31, 0.56, 0.24)
const ARCANE_COLOR := Color(0.65, 0.925, 1.0)
const ARCANE_DEEP := Color(0.43, 0.75, 1.0)
const ROCK_COLORS := [Color("#7d7b84"), Color("#a9a7b0"), Color("#5d5c63")]
## Hybrid pieces that strike like a knight when they make a knight-shaped move.
const KNIGHT_HYBRIDS := [&"lancer", &"centaur", &"unicorn_cavalry"]

## impact: when the hit lands. done: when the attacker has settled on its square.
## end: hard cap. All in seconds at 1x speed.
const ATTACKS := {
	&"knight": {"impact": 0.84, "done": 1.1, "end": 2.6, "hitstop": 0.1, "shake": 1.35},
	&"bishop": {"impact": 0.36, "done": 1.14, "end": 2.2, "hitstop": 0.12, "shake": 0.8},
	&"rook": {"impact": 0.56, "done": 0.96, "end": 2.3, "hitstop": 0.1, "shake": 1.5},
	&"pawn": {"impact": 0.38, "done": 0.74, "end": 2.1, "hitstop": 0.07, "shake": 0.55},
	&"queen": {"impact": 0.62, "done": 1.49, "end": 2.4, "hitstop": 0.12, "shake": 0.9},
	&"king": {"impact": 0.72, "done": 2.0, "end": 2.7, "hitstop": 0.13, "shake": 1.4},
	# Special pieces (docs/prototypes/special_strikes.html). Entries marked dynamic have
	# their timings recomputed in play() from the victim's weight or the move length.
	&"assassin": {"impact": 0.62, "done": 1.43, "end": 2.0, "hitstop": 0.12, "shake": 0.7},
	&"bowman": {"impact": 0.74, "done": 1.65, "end": 2.2, "hitstop": 0.08, "shake": 0.5},
	&"catapult": {"impact": 0.94, "done": 1.85, "end": 2.7, "hitstop": 0.13, "shake": 1.5},
	&"lancer": {"impact": 0.58, "done": 1.25, "end": 2.2, "hitstop": 0.1, "shake": 0.9},
	&"portal_mage": {"impact": 0.7, "done": 2.6, "end": 3.4, "hitstop": 0.06, "shake": 0.4},
	&"royal_guard": {"impact": 0.52, "done": 0.94, "end": 2.3, "hitstop": 0.1, "shake": 1.3},
	&"centaur": {"impact": 0.47, "done": 1.38, "end": 2.2, "hitstop": 0.11, "shake": 0.7},
	&"unicorn_cavalry": {"impact": 0.56, "done": 1.25, "end": 2.3, "hitstop": 0.12, "shake": 1.0},
	&"gryphon": {"impact": 0.72, "done": 1.85, "end": 2.6, "hitstop": 0.1, "shake": 0.8},
	&"manticore": {"impact": 0.64, "done": 2.6, "end": 3.4, "hitstop": 0.1, "shake": 0.6},
	&"archmage": {"impact": 0.76, "done": 2.6, "end": 3.4, "hitstop": 0.12, "shake": 0.9},
}

class Pose:
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var sx: float = 1.0
	var sy: float = 1.0
	var rot: float = 0.0
	var white: float = 0.0
	var trail: bool = false
	var dizzy: bool = false
	var alpha: float = 1.0

	func at(point: Vector3) -> void:
		x = point.x
		z = point.z

class Body:
	var sprite: Sprite2D = null
	var material: ShaderMaterial = null
	var indices: PackedInt32Array = PackedInt32Array()
	var pivot: Vector2 = Vector2.ZERO
	var kind: StringName = &"free"
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var vz: float = 0.0
	var rot: float = 0.0
	var vr: float = 0.0
	var gravity: float = 0.0
	var age: float = 0.0
	var ox: float = 0.0
	var oy: float = 0.0
	var shatter_ground: bool = false
	var shatter_at: float = INF
	var jitter: bool = false
	var poof: bool = false
	var crumble: bool = false
	var glow: bool = false
	var dead: bool = false
	var heavy: bool = false
	var phase: int = 0
	var bounce: int = 0
	var lie: float = 0.0
	var angle: float = 0.0
	var tip_speed: float = 0.0
	var tip_accel: float = 0.0
	var landed: float = -1.0
	var slide: float = 0.0
	var land_shake: float = 0.5
	var land_big: bool = false
	var normal: Vector2 = Vector2.ZERO
	var tangent: Vector2 = Vector2.ZERO
	var base_y: float = 0.0
	var scale_mul: float = 1.0
	var released: bool = false

var fx: StrikeFx = StrikeFx.new()
## Attacks and reactions of the pieces from plan §27.
var _extra: NewPieceStrikes = NewPieceStrikes.new()
## The captured piece drawn in the attacker's colours (Thousand Faces wears it briefly).
var mimic_texture: Texture2D = null

var _view: BattleBoardView = null
var _proj: BoardProjection = null
var _phase: Phase = Phase.IDLE
var _canvas_clean: bool = true

var _attack_id: StringName = &""
var _attack: Dictionary = {}
var _reaction: StringName = &""
var _strike_type: int = PieceDef.StrikeType.NONE
var _underdog: bool = false
var _power: float = 1.0
var _victim_weight: int = PieceDef.WeightClass.MEDIUM
var _attacker_height: float = 0.0
var _speed: float = 1.0
## Extra slow motion on top of the playback speed (1 = normal).
var time_scale: float = 1.0
var _to_square: Vector2i = Vector2i(-1, -1)

var _cell: float = 36.0
var _unit: float = 2.0
var _stand: float = 0.0
var _a: Vector3 = Vector3.ZERO
var _b: Vector3 = Vector3.ZERO
var _dest: Vector3 = Vector3.ZERO
var _corner: Vector3 = Vector3.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _face: float = 1.0
var _slash_angle: float = 0.0

var _t: float = 0.0
var _hs: float = 0.0
var _rt: float = -1.0
var _impacted: bool = false
var _split: bool = false
var _impact_time: float = 0.0
var _done_time: float = 0.0
var _end_time: float = 0.0
var _settle_time: float = 0.0
var _shake: float = 0.0
var _punch: float = 0.0
var _flash: float = 0.0
var _slash_age: float = -1.0
var _wobble_time: float = -9.0
var _rows_broken: int = 0
var _brick_out: bool = false
var _events: Array = []
var _events_fired: int = 0

var _attacker_texture: Texture2D = null
var _victim_texture: Texture2D = null
var _victim_chunks: PieceChunks = null
var _victim_height: float = 0.0
var _jag_seed: float = 0.0
var _jag_base: float = 0.42
var _plane_origin: Vector2 = Vector2(0.5, 0.55)
var _brick: Rect2 = Rect2()

var _holder: Node2D = null
var _attacker: Sprite2D = null
var _attacker_material: ShaderMaterial = null
var _victim: Sprite2D = null
var _victim_material: ShaderMaterial = null
var _ghosts: Array[Sprite2D] = []
var _trail: Array[Pose] = []
var _bodies: Array[Body] = []
var _pose: Pose = Pose.new()
## The victim survives (a shell absorbed the blow): the attacker springs back to its
## own square right after the hit instead of standing on the victim.
var _bounce: bool = false
var _contact: Vector3 = Vector3.ZERO
const BOUNCE_SECONDS := 0.38

func setup(view: BattleBoardView) -> void:
	_view = view
	_extra.d = self
	view.ground_canvas().draw.connect(_draw_ground)
	view.air_canvas().draw.connect(_draw_air)

static func can_play(attacker_id: StringName, strike_type: int) -> bool:
	return strike_type != PieceDef.StrikeType.NONE and (ATTACKS.has(attacker_id) or NewPieceStrikes.has_attack(attacker_id))

## Which attack plays for this move: [attack id, strike type]. Hybrid pieces that make a
## knight-shaped move borrow the knight's stomp; everything else keeps its own attack.
static func resolve_attack(attacker_id: StringName, strike_type: int, from: Vector2i, to: Vector2i) -> Array:
	var delta: Vector2i = (to - from).abs()
	var knight_shaped: bool = (delta.x == 1 and delta.y == 2) or (delta.x == 2 and delta.y == 1)
	if attacker_id in KNIGHT_HYBRIDS and knight_shaped:
		return [&"knight", PieceDef.StrikeType.CRUSH]
	return [attacker_id, strike_type]

func is_playing() -> bool:
	return _phase == Phase.PLAYING

## Starts a strike. `victim_square` differs from `to` only for en passant.
## The board is expected to already hold the post-capture position.
## `corner_square` is the turning square of a bent move (gryphon, manticore), if known.
## `victim_id` lets pieces with their own capture reaction (Powder Keg, Gargoyle...) play it.
func play(attacker_id: StringName, attacker_texture: Texture2D, victim_texture: Texture2D, from: Vector2i, to: Vector2i, strike_type: int, attacker_weight: int, victim_weight: int, speed: float, victim_square: Vector2i = Vector2i(-1, -1), corner_square: Vector2i = Vector2i(-1, -1), victim_id: StringName = &"") -> void:
	_clear_actors()
	_reset_camera()
	_proj = _view.projection
	_cell = _proj.cell
	_unit = _cell / 18.0
	_stand = _view.standing_offset()
	fx.projection = _proj
	fx.unit = _unit
	_attack_id = attacker_id
	_attack = ATTACKS[attacker_id] if ATTACKS.has(attacker_id) else NewPieceStrikes.ATTACKS[attacker_id]
	_extra.reset()
	_strike_type = strike_type
	_speed = maxf(speed, 0.1)
	_to_square = to
	_attacker_texture = attacker_texture
	_victim_texture = victim_texture
	_power = 1.0 if attacker_weight >= victim_weight else 0.45
	_victim_weight = clampi(victim_weight, 0, 2)
	_reaction = reaction_for(strike_type, attacker_weight, victim_weight)
	var own_reaction: StringName = NewPieceStrikes.victim_reaction(victim_id)
	if not own_reaction.is_empty():
		_reaction = own_reaction
	_underdog = _reaction == &"underdog"

	_a = _proj.square_world(from)
	# The strike aims at the victim; the attacker then settles on its destination.
	_dest = _proj.square_world(to)
	_b = _proj.square_world(victim_square if victim_square.x >= 0 else to)
	_dir = Vector2(_b.x - _a.x, _b.z - _a.z).normalized()
	var screen_a: Vector2 = _proj.project(_a)
	var screen_b: Vector2 = _proj.project(_b)
	_face = 1.0 if absf(screen_b.x - screen_a.x) < 2.0 * _unit else signf(screen_b.x - screen_a.x)
	var delta: Vector2i = to - from
	_corner = _proj.square_world(Vector2i(from.x, to.y) if absi(delta.y) >= absi(delta.x) else Vector2i(to.x, from.y))
	if corner_square.x >= 0:
		_corner = _proj.square_world(corner_square)
	elif attacker_id == &"gryphon":
		_corner = _proj.square_world(from + Vector2i(signi(delta.x), signi(delta.y)))
	elif attacker_id == &"manticore":
		_corner = _proj.square_world(from + (Vector2i(signi(delta.x), 0) if absi(delta.x) > absi(delta.y) else Vector2i(0, signi(delta.y))))
	var line: Vector2 = (screen_b - screen_a).normalized()
	if absf(line.y) < 0.42:
		line.y = (-1.0 if line.y <= 0.0 else 1.0) * 0.42
	if absf(line.x) < 0.42:
		line.x = (-1.0 if line.x < 0.0 else 1.0) * 0.42
	_slash_angle = atan2(line.y, line.x)

	_impact_time = 1.2 if _underdog else float(_attack["impact"])
	_settle_time = _impact_time + (0.75 if _underdog else 0.14)
	_done_time = _settle_time + 0.22 if attacker_id == &"pawn" else float(_attack["done"])
	_end_time = _impact_time + 2.0 if _underdog else float(_attack["end"])
	_apply_dynamic_timing()
	_bounce = NewPieceStrikes.victim_survives(_reaction)
	if _bounce:
		_end_time = minf(_end_time, _impact_time + BOUNCE_SECONDS + 0.45)
	_t = 0.0
	_hs = 0.0
	_rt = -1.0
	_impacted = false
	_split = false
	_shake = 0.0
	_punch = 0.0
	_flash = 0.0
	_slash_age = -1.0
	_wobble_time = -9.0
	_rows_broken = 0
	_brick_out = false
	_events_fired = 0

	_victim_chunks = PieceChunks.of(victim_texture)
	_jag_seed = randf() * 20.0
	_plane_origin = Vector2(_victim_chunks.aspect * 0.5, 0.55)
	var brick_width: float = 5.0 / ROWS
	_brick = Rect2(_victim_chunks.aspect - brick_width if _face > 0.0 else 0.0, 0.625, brick_width, 0.25)

	var layer: Node2D = _view.piece_layer()
	_victim = _view.make_piece_sprite(victim_texture)
	_victim_material = _piece_material(_victim_chunks)
	_victim.material = _victim_material
	_victim_height = _victim_chunks.used.size.y * float(_victim.get_meta("base_scale", 1.0))
	layer.add_child(_victim)
	_set_tint(_victim_material, Color.WHITE, 0.0)

	_holder = Node2D.new()
	layer.add_child(_holder)
	for _index: int in range(MAX_GHOSTS):
		var ghost: Sprite2D = _view.make_piece_sprite(attacker_texture)
		var ghost_material: ShaderMaterial = ShaderMaterial.new()
		ghost_material.shader = GHOST_SHADER
		ghost.material = ghost_material
		ghost.visible = false
		_holder.add_child(ghost)
		_ghosts.append(ghost)
	_attacker = _view.make_piece_sprite(attacker_texture)
	_attacker_material = _piece_material(PieceChunks.of(attacker_texture))
	_attacker.material = _attacker_material
	_attacker_height = PieceChunks.of(attacker_texture).used.size.y * float(_attacker.get_meta("base_scale", 1.0))
	_holder.add_child(_attacker)
	# Built last: some events aim at heights that need both sprites measured.
	_events = _build_events()

	_phase = Phase.PLAYING
	_render()

## Stops immediately and removes every trace, including lingering debris.
func stop() -> void:
	_clear_actors()
	fx.clear()
	_reset_camera()
	_phase = Phase.IDLE
	_redraw()

static func reaction_for(strike_type: int, attacker_weight: int, victim_weight: int) -> StringName:
	var weight: int = clampi(victim_weight, 0, 2)
	match strike_type:
		PieceDef.StrikeType.SLASH:
			return [&"slash_shatter", &"slash_split", &"slash_split_heavy"][weight]
		PieceDef.StrikeType.CRUSH:
			return [&"crush_flat", &"crush_collapse", &"crush_sink"][weight]
		PieceDef.StrikeType.PIERCE:
			return [&"pierce_knock", &"hole", &"hole_heavy"][weight]
		PieceDef.StrikeType.VOID:
			return &"vortex"
		PieceDef.StrikeType.GRAB:
			# Too heavy to carry off: the talons rake it in two instead.
			return &"rake" if weight == 2 else &"grab"
		PieceDef.StrikeType.VENOM:
			return &"venom"
		PieceDef.StrikeType.ARCANE:
			return &"arcane"
	var extra: StringName = NewPieceStrikes.reaction_for_type(strike_type)
	if not extra.is_empty():
		return extra
	if weight == 0:
		return &"blunt_fly"
	if weight == 1:
		return &"low_fly" if attacker_weight > weight else &"quick_tip"
	return &"blunt_crack" if attacker_weight >= weight else &"underdog"

## Seconds after impact at which the standing victim is replaced by its pieces.
func _split_time() -> float:
	match _reaction:
		&"slash_shatter": return 0.2
		&"slash_split", &"slash_split_heavy": return 0.1
		&"blunt_fly": return 0.06
		&"low_fly": return 0.05
		&"quick_tip": return 0.03
		&"underdog": return 0.04
		&"blunt_crack": return 0.22
		&"crush_flat": return 0.26
		&"crush_collapse": return 0.36
		&"crush_sink": return _sink_duration() + 0.02
		&"pierce_knock": return 0.05
		&"hole": return 0.48
		&"hole_heavy": return 0.75
		&"vortex", &"grab": return 0.0
		&"rake": return 0.1
		&"venom": return 0.25 + _melt_duration()
		&"arcane": return _arcane_duration()
	if _extra.handles(_reaction):
		return _extra.split_time()
	return 0.1

# --- frame loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	if _view == null:
		return
	var dt: float = minf(delta, 0.05)
	match _phase:
		Phase.PLAYING:
			_step(dt)
			if _phase == Phase.PLAYING:
				_render()
		Phase.AFTERGLOW:
			var scaled: float = dt * _speed
			_rt += scaled
			fx.step(scaled)
			_decay(dt)
			_apply_camera()
			if _rt > 1.2 and _shake <= 0.0 and _punch <= 0.0:
				_reset_camera()
				_phase = Phase.IDLE
		Phase.IDLE:
			if fx.is_empty():
				if not _canvas_clean:
					_redraw()
					_canvas_clean = true
				return
			fx.step(dt * _speed)
	_redraw()

func _redraw() -> void:
	_canvas_clean = false
	_view.ground_canvas().queue_redraw()
	_view.air_canvas().queue_redraw()

func _step(dt: float) -> void:
	var scaled: float = dt * _speed * time_scale
	if _hs > 0.0:
		_hs -= scaled
	else:
		_t += scaled
	while _events_fired < _events.size() and _t >= float(_events[_events_fired][0]):
		var event: Callable = _events[_events_fired][1]
		_events_fired += 1
		event.call()
	if not _impacted and _t >= _impact_time:
		_impacted = true
		_t = _impact_time
		_rt = 0.0
		_hs = float(_attack["hitstop"])
		_shake = float(_attack["shake"])
		_punch = 1.0
		_flash = 1.0
		_contact = Vector3(_pose.x, _pose.y, _pose.z)
		# A shooter never left its square: nothing to spring back from.
		if _bounce and Vector2(_contact.x - _a.x, _contact.z - _a.z).length() < _cell * 0.3:
			_bounce = false
		_on_impact()
		impacted.emit()
	if _impacted:
		_rt += scaled
		_reaction_tick()
		if not _split and _rt >= _split_time():
			_split = true
			_victim.visible = false
			_on_split()
			victim_split.emit()
	if _hs <= 0.0:
		_physics(scaled)
	_decay(dt)
	if (_t >= _done_time and _split and _bodies.is_empty()) or _t >= _end_time:
		_complete()

func _decay(dt: float) -> void:
	var rate: float = maxf(_speed, 0.3)
	_shake = maxf(0.0, _shake - dt * 3.0 * rate)
	_punch = maxf(0.0, _punch - dt * 3.5 * rate)
	_flash = maxf(0.0, _flash - dt * 9.0 * rate)

func _complete() -> void:
	_clear_actors()
	_phase = Phase.AFTERGLOW
	if _rt < 0.0:
		_rt = 2.0
	finished.emit()

func _clear_actors() -> void:
	for body: Body in _bodies:
		if is_instance_valid(body.sprite):
			body.sprite.queue_free()
	_bodies.clear()
	_trail.clear()
	_ghosts.clear()
	if is_instance_valid(_holder):
		_holder.queue_free()
	if is_instance_valid(_victim):
		_victim.queue_free()
	_holder = null
	_attacker = null
	_victim = null
	_extra.clear()
	_slash_age = -1.0

func _physics(dt: float) -> void:
	for body: Body in _bodies:
		if body.dead:
			continue
		body.age += dt
		match body.kind:
			&"tip":
				_step_tip(body, dt)
			&"low_fly":
				_step_low_fly(body, dt)
			&"slash_upper":
				_step_slash_upper(body)
			&"slash_lower":
				_step_slash_lower(body)
			&"vortex":
				_step_vortex(body, dt)
			&"grab":
				_step_grab(body, dt)
			_:
				_step_free(body, dt)
	_bodies = _bodies.filter(func(body: Body) -> bool: return not body.dead)
	fx.step(dt)
	if _slash_age >= 0.0:
		_slash_age += dt
		if _slash_age > 0.5:
			_slash_age = -1.0

# --- attacker -----------------------------------------------------------------

func _build_events() -> Array:
	match _attack_id:
		&"knight":
			return [[0.24, _event_knight_crouch], [0.5, _event_knight_turn]]
		&"rook":
			return [[0.1, _event_rook_rumble.bind(0.0, 4, 0.6)], [0.25, _event_rook_rumble.bind(-4.0, 5, 0.7)]]
		&"pawn":
			if _underdog:
				return [[0.38, _knock_brick_out]]
		&"king":
			return [[1.52, _event_king_step.bind(0.5, 4, 0.6, 0.3)], [1.86, _event_king_step.bind(1.0, 5, 0.7, 0.35)]]
	return _special_events()

func _event_knight_crouch() -> void:
	fx.puff(_up(_a, 2.0), 6, 0.8)

func _event_knight_turn() -> void:
	fx.spark_burst(Vector3(_corner.x, _cell * 1.9, _corner.z), 5, Vector2.ZERO, 0.0, 0.35)
	fx.ring(_corner.x, _corner.z, _cell * 0.4, 0.25, AMBER)

func _event_rook_rumble(back: float, count: int, big: float) -> void:
	fx.puff(_up(_along(_a, back * _unit), 2.0), count, big)

func _event_king_step(progress: float, count: int, big: float, shake: float) -> void:
	fx.puff(_up(_a.lerp(_b, progress), 1.0), count, big)
	_shake = maxf(_shake, shake)

func _compute_pose(u: float) -> Pose:
	var o: Pose = Pose.new()
	o.at(_a)
	if u < 0.0:
		return o
	match _attack_id:
		&"knight": _pose_knight(u, o)
		&"bishop": _pose_bishop(u, o)
		&"rook": _pose_rook(u, o)
		&"pawn": _pose_pawn(u, o)
		&"queen": _pose_queen(u, o)
		&"king": _pose_king(u, o)
		_: _special_pose(u, o)
	if _bounce and _impacted and u >= _impact_time:
		_bounce_pose(u, o)
	return o

## Knocked back off a shell: from the point of contact back home with a small hop.
func _bounce_pose(u: float, o: Pose) -> void:
	var q: float = clampf((u - _impact_time) / BOUNCE_SECONDS, 0.0, 1.0)
	var s: float = q * q * (3.0 - 2.0 * q)
	o.x = lerpf(_contact.x, _a.x, s)
	o.z = lerpf(_contact.z, _a.z, s)
	o.y = lerpf(_contact.y, 0.0, s) + sin(q * PI) * _cell * 0.45
	o.rot = -0.3 * _face * sin(q * PI)
	o.sx = 1.0
	o.sy = 1.0
	o.trail = false
	o.white = 0.0

func _pose_knight(u: float, o: Pose) -> void:
	var high: float = _cell * 1.9
	var peak: float = _cell * 2.2
	if u < 0.24:
		var s: float = sin(u / 0.24 * PI * 0.5)
		o.rot = -0.32 * s * _face
		o.sx = 1.0 + 0.14 * s
		o.sy = 1.0 - 0.18 * s
		return
	if u < 0.5:
		var q: float = (u - 0.24) / 0.26
		var stretch: float = sin(q * PI)
		o.at(_a.lerp(_corner, q))
		o.y = high * _ease_out(q)
		o.rot = lerpf(-0.32, -0.1, q) * _face
		o.sy = 1.0 + 0.12 * stretch
		o.sx = 1.0 - 0.08 * stretch
		o.trail = true
		return
	if u < 0.66:
		var q: float = (u - 0.5) / 0.16
		var e: float = _smooth(q)
		o.at(_corner.lerp(_b, e))
		o.y = lerpf(high, peak, q)
		o.rot = lerpf(-0.1, 0.38, e) * _face
		o.trail = true
		return
	o.at(_b)
	if u < 0.74:
		var q: float = (u - 0.66) / 0.08
		o.y = peak + 2.0 * _unit * sin(q * PI)
		o.rot = 0.42 * _face
		o.sx = 1.08
		o.sy = 0.94
		return
	if u < 0.84:
		var q: float = (u - 0.74) / 0.1
		o.y = lerpf(peak, _victim_top(), _ease_in(q))
		o.rot = 0.42 * _face
		o.sx = 0.86
		o.sy = 1.22
		o.trail = true
		return
	var settle: float = clampf((u - 0.84) / 0.2, 0.0, 1.0)
	var squash: float = sin(clampf((u - 0.84) / 0.16, 0.0, 1.0) * PI) * (1.0 - settle * 0.3)
	o.y = _victim_top()
	o.rot = lerpf(0.42, 0.0, _ease_out(settle)) * _face
	o.sx = 1.0 + 0.25 * squash
	o.sy = 1.0 - 0.22 * squash

func _pose_bishop(u: float, o: Pose) -> void:
	var past: Vector3 = _along(_b, _cell * 0.7)
	if not _on_board(past):
		past = _along(_b, _cell * 0.3)
	var wound: Vector3 = _along(_a, -2.0 * _unit)
	if u < 0.28:
		var s: float = sin(u / 0.28 * PI * 0.5)
		o.rot = -0.22 * s * _face
		o.sx = 1.0 + 0.1 * s
		o.sy = 1.0 - 0.12 * s
		o.at(_along(_a, -2.0 * _unit * s))
		o.white = 0.55 * s * (0.7 + 0.3 * sin(u * 60.0))
		return
	if u < 0.36:
		var q: float = (u - 0.28) / 0.08
		o.at(wound.lerp(past, q))
		o.sx = 1.25
		o.sy = 0.82
		o.white = 0.8
		o.trail = true
		o.rot = 0.1 * _face
		return
	if u < 0.9:
		var q: float = (u - 0.36) / 0.54
		o.at(past)
		o.rot = lerpf(0.18, 0.0, _smooth(q)) * _face
		o.white = 0.8 * (1.0 - clampf(q * 2.0, 0.0, 1.0))
		return
	var back: float = clampf((u - 0.9) / 0.22, 0.0, 1.0)
	o.at(past.lerp(_b, _smooth(back)))
	o.y = 4.0 * back * (1.0 - back) * 4.0 * _unit

func _pose_rook(u: float, o: Pose) -> void:
	var back: Vector3 = _along(_a, -_cell * 0.28)
	var contact: Vector3 = _along(_b, -_cell * 0.55)
	if u < 0.38:
		var q: float = u / 0.38
		o.at(_a.lerp(back, _ease_out(q)))
		o.x += (randf() - 0.5) * 2.0 * _unit * q
		o.sy = 1.0 - 0.1 * q
		o.sx = 1.0 + 0.06 * q
		return
	if u < 0.56:
		var q: float = (u - 0.38) / 0.18
		o.at(back.lerp(contact, _ease_in(q)))
		o.sx = 0.9
		o.sy = 1.12
		o.trail = true
		return
	if u < 0.64:
		var q: float = (u - 0.56) / 0.08
		o.at(contact)
		o.sx = 1.0 + 0.22 * sin(q * PI)
		o.sy = 1.0 - 0.2 * sin(q * PI)
		return
	var q: float = clampf((u - 0.64) / 0.3, 0.0, 1.0)
	o.at(contact.lerp(_b, _smooth(q)))

func _pose_pawn(u: float, o: Pose) -> void:
	var contact: Vector3 = _along(_b, -_cell * 0.38)
	var low_contact: Vector3 = _along(_b, -_cell * 0.42)
	if u < 0.14:
		var s: float = sin(u / 0.14 * PI * 0.5)
		o.sx = 1.0 + 0.2 * s
		o.sy = 1.0 - 0.22 * s
		return
	if u < 0.38:
		var q: float = (u - 0.14) / 0.24
		if _underdog:
			o.at(_a.lerp(low_contact, q))
			o.y = _cell * 0.35 * 4.0 * q * (1.0 - q)
			o.rot = 0.6 * _smooth(q) * _face
			o.sy = 0.85
			o.sx = 1.1
			o.trail = true
		else:
			o.at(_a.lerp(contact, q))
			o.y = _cell * 0.75 * 4.0 * q * (1.0 - q) + _cell * 0.25 * q
			o.rot = 0.4 * _smooth(q) * _face
			o.sy = 1.0 + 0.1 * sin(q * PI)
		return
	if _underdog and u < 1.2:
		# First hit bounced off: stagger back dizzy, then take a run-up for the second.
		var rest: Vector3 = low_contact.lerp(_a, 0.7)
		var runup: Vector3 = _along(rest, -_cell * 0.3)
		if u < 0.6:
			var q: float = (u - 0.38) / 0.22
			o.at(low_contact.lerp(rest, _ease_out(q)))
			o.y = _cell * 0.6 * 4.0 * q * (1.0 - q)
			o.rot = lerpf(0.6, -0.5, q) * _face
			return
		o.at(rest)
		if u < 0.84:
			var q: float = (u - 0.6) / 0.24
			var w: float = sin(clampf(q * 3.0, 0.0, 1.0) * PI)
			o.rot = sin(q * PI * 3.0) * 0.18 * (1.0 - q)
			o.sy = 1.0 - 0.15 * w
			o.sx = 1.0 + 0.12 * w
			o.dizzy = true
			return
		if u < 0.96:
			var q: float = (u - 0.84) / 0.12
			o.at(rest.lerp(runup, _smooth(q)))
			o.sy = 1.0 - 0.15 * q
			o.sx = 1.0 + 0.1 * q
			o.rot = -0.15 * q * _face
			return
		var q: float = (u - 0.96) / 0.24
		o.at(runup.lerp(contact, _ease_in(q)))
		if q < 0.55:
			o.y = absf(sin(q / 0.55 * PI * 2.0)) * 3.0 * _unit
		else:
			o.y = _cell * 0.55 * sin((q - 0.55) / 0.45 * PI * 0.75)
		o.rot = 0.45 * _face
		o.trail = q > 0.35
		return
	var recoil: Vector3 = _along(contact, -3.0 * _unit)
	if u < _impact_time + 0.14:
		var q: float = (u - _impact_time) / 0.14
		o.at(contact.lerp(recoil, _ease_out(q)))
		o.y = _cell * 0.25 * (1.0 - q)
		o.rot = lerpf(0.4, -0.1, q) * _face
		return
	if u < _settle_time:
		o.at(recoil)
		o.rot = -0.1 * _face
		return
	var q: float = clampf((u - _settle_time) / 0.2, 0.0, 1.0)
	o.at(recoil.lerp(_dest, _smooth(q)))
	o.y = 4.0 * q * (1.0 - q) * 3.0 * _unit
	o.rot = lerpf(-0.1, 0.0, q) * _face

func _pose_queen(u: float, o: Pose) -> void:
	var hover: float = _cell * 0.45
	if u < 0.3:
		var q: float = u / 0.3
		o.y = hover * _ease_out(q)
		o.white = 0.35 * q
		o.sy = 1.0 + 0.06 * q
		return
	if u < 0.62:
		o.y = hover + sin(u * 18.0) * 0.8 * _unit
		o.white = 0.35 + 0.15 * sin(u * 50.0)
		if u > 0.5:
			o.at(_along(_a, -2.0 * _unit * (u - 0.5) / 0.12))
		return
	if u < 1.05:
		var q: float = (u - 0.62) / 0.43
		o.at(_along(_a, -2.0 * _unit * (1.0 - q)))
		o.y = hover + sin(u * 18.0) * 0.8 * _unit
		o.white = 0.4 * (1.0 - q)
		return
	var q: float = clampf((u - 1.05) / 0.42, 0.0, 1.0)
	o.at(_a.lerp(_b, _smooth(q)))
	o.y = hover * (1.0 - _ease_in(q))
	o.trail = q > 0.05 and q < 0.9

func _pose_king(u: float, o: Pose) -> void:
	var middle: Vector3 = _a.lerp(_b, 0.5)
	if u < 0.72:
		var q: float = clampf(u / 0.35, 0.0, 1.0)
		o.sy = 1.0 + 0.08 * q
		o.sx = 1.0 - 0.03 * q
		o.white = 0.45 * q * (0.75 + 0.25 * sin(u * 40.0))
		return
	if u < 1.3:
		var q: float = (u - 0.72) / 0.58
		o.sy = 1.0 + 0.08 * (1.0 - q)
		o.white = 0.45 * (1.0 - q)
		return
	if u < 1.52:
		_hop(o, _a, middle, (u - 1.3) / 0.22)
		return
	if u < 1.64:
		var w: float = sin((u - 1.52) / 0.12 * PI)
		o.at(middle)
		o.sx = 1.0 + 0.12 * w
		o.sy = 1.0 - 0.12 * w
		return
	if u < 1.86:
		_hop(o, middle, _b, (u - 1.64) / 0.22)
		return
	var w: float = sin(clampf((u - 1.86) / 0.12, 0.0, 1.0) * PI)
	o.at(_b)
	o.sx = 1.0 + 0.12 * w
	o.sy = 1.0 - 0.12 * w

func _hop(o: Pose, start: Vector3, finish: Vector3, q: float) -> void:
	o.at(start.lerp(finish, _smooth(q)))
	o.y = _cell * 0.35 * 4.0 * q * (1.0 - q)

func _on_impact() -> void:
	# Bring the two actors in front of the dimmed bystanders. A crush lands on top of
	# the victim; every other strike reads better with the victim in front.
	var crush: bool = _strike_type == PieceDef.StrikeType.CRUSH or _strike_type == PieceDef.StrikeType.GRAB
	_holder.z_index = 2 if crush else 1
	_victim.z_index = 1 if crush else 2
	match _attack_id:
		&"knight":
			fx.ring(_b.x, _b.z, _cell * 1.3, 0.5)
			fx.ring(_b.x, _b.z, _cell * 0.7, 0.3)
			fx.puff(_up(_b, 2.0), 12, 1.3)
			fx.crack_decal(_b.x, _b.z, 7, _cell * 0.95)
			fx.spark_burst(_up(_b, 4.0), 6, Vector2.ZERO, 0.0, 0.6)
		&"bishop":
			_slash_age = 0.0
			fx.spark_burst(_up(_b, 9.0), 10, _dir, 60.0, 0.8)
		&"rook":
			fx.ring(_b.x, _b.z, _cell * 1.4, 0.5)
			fx.ring(_b.x, _b.z, _cell * 0.8, 0.32)
			fx.puff(_up(_b, 2.0), 10, 1.4)
			fx.spark_burst(_up(_b, 6.0), 8, _dir, 40.0, 0.7)
		&"pawn":
			fx.spark_burst(_up(_b, 10.0), 10 if _underdog else 7, _dir, 30.0, 0.6)
			fx.ring(_b.x, _b.z, _cell * 0.55, 0.28)
		&"queen":
			fx.spark_burst(_up(_b, 9.0), 14, _dir, 120.0, 0.8)
			fx.ring(_b.x, _b.z, _cell * 0.7, 0.3, GOLD)
		&"king":
			fx.ring(_b.x, _b.z, _cell * 1.4, 0.5, GOLD)
			fx.ring(_b.x, _b.z, _cell * 0.8, 0.32, GOLD)
			fx.puff(_up(_b, 2.0), 12, 1.3)
			fx.crack_decal(_b.x, _b.z, 8, _cell * 1.05)
			fx.spark_burst(_up(_b, 4.0), 12, Vector2.ZERO, 0.0, 0.8)
		_:
			_special_impact()

## Pawn against a heavy piece, first hit: a brick flies out of the far side of the base.
func _knock_brick_out() -> void:
	_brick_out = true
	_victim_material.set_shader_parameter(&"brick_mode", 1.0)
	var brick: Body = _make_body({"brick_mode": 2.0})
	brick.vx = (_dir.x * 50.0 + _face * 50.0) * _unit
	brick.vz = _dir.y * 50.0 * _unit
	brick.vy = 55.0 * _unit
	brick.vr = 10.0 * _face
	brick.gravity = 300.0 * _unit
	brick.shatter_ground = true
	fx.spark_burst(_up(_b, 3.0), 8, _dir, 40.0, 0.6)
	fx.puff(Vector3(_b.x + _face * 6.0 * _unit, 2.0 * _unit, _b.z), 5, 0.7)
	fx.ring(_b.x, _b.z, _cell * 0.45, 0.25)
	_wobble_time = _t
	_hs = 0.06
	_shake = 0.45

# --- victim -------------------------------------------------------------------

func _sink_duration() -> float:
	return 0.68 if _power < 1.0 else 0.48

func _sink_pixels() -> float:
	return _victim_height * 0.65 * _ease_out(clampf(_rt / _sink_duration(), 0.0, 1.0))

func _collapsed_rows() -> int:
	return mini(ROWS, floori(clampf(_rt / 0.32, 0.0, 1.0) * ROWS))

func _flatten_progress() -> float:
	return _ease_out(clampf(_rt / 0.22, 0.0, 1.0))

## World height of whatever is left of the victim, so a stomping piece can ride it down.
func _victim_top() -> float:
	if not _impacted:
		return _proj.height_for_pixels(_victim_height)
	if _split:
		return 0.0
	var pixels: float = 0.0
	match _reaction:
		&"crush_flat":
			pixels = _victim_height * (1.0 - 0.82 * _flatten_progress())
		&"crush_collapse":
			pixels = _victim_height * (1.0 - float(_collapsed_rows()) / ROWS)
		&"crush_sink":
			pixels = _victim_height - _sink_pixels()
	return _proj.height_for_pixels(maxf(pixels, 0.0))

func _reaction_tick() -> void:
	if _split:
		return
	match _reaction:
		&"venom", &"arcane":
			_special_reaction_tick()
		_ when _extra.handles(_reaction):
			_extra.reaction_tick()
		&"crush_collapse":
			var rows: int = _collapsed_rows()
			while _rows_broken < rows:
				var row: int = _rows_broken
				_rows_broken += 1
				var indices: PackedInt32Array = _select(func(p: Vector2) -> bool: return int(p.y * ROWS) == row)
				_debris(indices, _foot_pivot(), _foot(_b), {"vel": Vector3(0.0, 25.0 * _unit, 0.0), "spread": 40.0, "radial": 4.0})
		&"crush_sink":
			if _hs <= 0.0 and randf() < 0.5 and _victim_chunks.points.size() > 0:
				var index: int = randi() % _victim_chunks.points.size()
				var origin: Vector3 = _foot(_b) + Vector3(randf_range(-6.0, 6.0) * _unit, 0.0, 0.0)
				_debris(PackedInt32Array([index]), _victim_chunks.points[index], origin, {"vel": Vector3(0.0, 30.0 * _unit, 0.0), "spread": 30.0})

func _on_split() -> void:
	var whole: PackedInt32Array = _victim_chunks.all_indices()
	match _reaction:
		&"slash_shatter":
			_debris(whole, _foot_pivot(), _foot(_b), {"vel": Vector3(-sin(_slash_angle) * 10.0 * _unit, 15.0 * _unit, 0.0), "spread": 22.0, "gravity": 70.0, "life_min": 1.1, "life_max": 1.8, "radial": 1.2})
			fx.spark_burst(_up(_b, 8.0), 6, Vector2.ZERO, 0.0, 0.4)
		&"slash_split", &"slash_split_heavy":
			_split_along_slash(_reaction == &"slash_split_heavy")
		&"blunt_fly":
			var body: Body = _make_body({})
			body.vx = (_dir.x * 70.0 + _face * 25.0) * _power * _unit
			body.vz = _dir.y * 70.0 * _power * _unit
			body.vy = 130.0 * _power * _unit
			body.vr = 15.0 * _face
			body.gravity = 300.0 * _unit
			body.shatter_ground = true
			body.poof = true
		&"low_fly":
			var body: Body = _make_body({})
			body.kind = &"low_fly"
			body.vx = (_dir.x * 115.0 + _face * 20.0) * _unit
			body.vz = _dir.y * 115.0 * _unit
			body.vy = 38.0 * _unit
			body.vr = 10.0 * _face
		&"quick_tip":
			_make_tip_body({}, 6.0, 30.0, 26.0, 0.35, false)
		&"underdog":
			_make_tip_body({"brick_mode": 1.0} if _brick_out else {}, 1.3, 13.0, 0.0, 1.15, true)
		&"blunt_crack":
			var top: Body = _make_body({"jag_keep": 1.0})
			top.vx = _dir.x * 50.0 * _unit
			top.vz = _dir.y * 50.0 * _unit
			top.vy = 70.0 * _unit
			top.vr = 7.0 * _face
			top.gravity = 260.0 * _unit
			top.shatter_ground = true
			var bottom: Body = _make_body({"jag_keep": -1.0})
			bottom.jitter = true
			bottom.shatter_at = _rt + 0.3
			bottom.crumble = true
			var seam: PackedInt32Array = _select(func(p: Vector2) -> bool: return absf(p.y - _jag(p.x)) < 1.25 / ROWS)
			_debris(seam, _foot_pivot(), _foot(_b), {"vel": Vector3(_dir.x * 30.0, 40.0, _dir.y * 30.0) * _unit, "spread": 25.0, "every": 2})
			fx.puff(Vector3(_b.x, _proj.height_for_pixels(6.0 * _unit), _b.z), 4, 0.6)
		&"crush_flat":
			_debris(whole, _foot_pivot(), _foot(_b), {"vel": Vector3(0.0, 15.0 * _unit, 0.0), "spread": 45.0, "every": 2, "radial": 3.0})
			fx.puff(_up(_b, 1.0), 12, 1.1)
		&"crush_collapse":
			fx.puff(_up(_b, 1.0), 8, 1.0)
		&"crush_sink":
			var visible_part: float = 1.0 - _sink_pixels() / _victim_height
			var above: PackedInt32Array = _select(func(p: Vector2) -> bool: return p.y < visible_part)
			_debris(above, Vector2(_victim_chunks.aspect * 0.5, visible_part), _foot(_b), {"vel": Vector3(0.0, 50.0 * _unit, 0.0), "spread": 40.0, "radial": 3.0})
			fx.puff(_up(_b, 2.0), 12, 1.3)
			fx.ring(_b.x, _b.z, _cell * 1.1, 0.45)
			fx.crack_decal(_b.x, _b.z, 5, _cell * 1.3)
			_shake = maxf(_shake, 0.8)
		&"pierce_knock":
			var body: Body = _make_body({})
			body.vx = _dir.x * 150.0 * _unit
			body.vz = _dir.y * 150.0 * _unit
			body.vy = 28.0 * _unit
			body.vr = 1.5 * _face
			body.gravity = 240.0 * _unit
			body.shatter_ground = true
			body.poof = true
		&"hole", &"hole_heavy":
			var heavy: bool = _reaction == &"hole_heavy"
			_debris(whole, _foot_pivot(), _foot(_b), {"vel": Vector3(_dir.x * 55.0, 30.0, _dir.y * 55.0) * _unit, "spread": 35.0, "radial": 2.5})
			fx.puff(_up(_b, 4.0), 10, 1.1)
			fx.ring(_b.x, _b.z, _cell * (1.0 if heavy else 0.7), 0.4, GOLD)
			_shake = maxf(_shake, 0.9 if heavy else 0.6)
		_:
			_special_split()

func _split_along_slash(heavy: bool) -> void:
	var first: Body = _make_body({"plane_keep": -1.0})
	var second: Body = _make_body({"plane_keep": 1.0})
	var upper: Body = first if first.pivot.y <= second.pivot.y else second
	var lower: Body = second if upper == first else first
	var normal: Vector2 = Vector2(-sin(_slash_angle), cos(_slash_angle))
	if normal.dot(upper.pivot - lower.pivot) < 0.0:
		normal = -normal
	var tangent: Vector2 = Vector2(cos(_slash_angle), sin(_slash_angle))
	if tangent.y < 0.0:
		tangent = -tangent
	for body: Body in [upper, lower]:
		body.glow = true
		body.heavy = heavy
		body.normal = normal
		body.tangent = tangent
	upper.kind = &"slash_upper"
	lower.kind = &"slash_lower"

# --- bodies -------------------------------------------------------------------

func _piece_material(chunks: PieceChunks) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PIECE_SHADER
	material.set_shader_parameter(&"used", chunks.used_uv())
	material.set_shader_parameter(&"aspect", chunks.aspect)
	material.set_shader_parameter(&"grid", float(ROWS))
	material.set_shader_parameter(&"plane_origin", _plane_origin)
	material.set_shader_parameter(&"plane_dir", Vector2(cos(_slash_angle), sin(_slash_angle)))
	material.set_shader_parameter(&"jag_base", _jag_base)
	material.set_shader_parameter(&"jag_seed", _jag_seed)
	material.set_shader_parameter(&"crack_from_right", 1.0 if _face < 0.0 else 0.0)
	material.set_shader_parameter(&"hole_center", Vector2(chunks.aspect * 0.5, 0.5))
	material.set_shader_parameter(&"brick", Vector4(_brick.position.x, _brick.position.y, _brick.end.x, _brick.end.y))
	return material

func _jag(x: float) -> float:
	var q: float = (floorf(x * ROWS) + 0.5) / ROWS
	var row: float = floorf(_jag_base * ROWS) + floorf(sin(q * 19.0 + _jag_seed) * 1.6 + 0.5) + floorf(sin(q * 47.0 + _jag_seed * 1.7) * 0.9 + 0.5)
	return (row + 0.5) / ROWS

## Script-side mirror of the cuts the strike shader makes for the same `mask`.
func _mask_keeps(mask: Dictionary, p: Vector2) -> bool:
	var plane_keep: float = float(mask.get("plane_keep", 0.0))
	if plane_keep != 0.0:
		var side: float = (p.x - _plane_origin.x) * sin(_slash_angle) - (p.y - _plane_origin.y) * cos(_slash_angle)
		if side * plane_keep < 0.6 / ROWS:
			return false
	var jag_keep: float = float(mask.get("jag_keep", 0.0))
	if jag_keep > 0.0 and p.y > _jag(p.x) - 0.25 / ROWS:
		return false
	if jag_keep < 0.0 and p.y < _jag(p.x) + 0.25 / ROWS:
		return false
	var brick_mode: float = float(mask.get("brick_mode", 0.0))
	if brick_mode > 0.5:
		var inside: bool = p.x >= _brick.position.x and p.x <= _brick.end.x and p.y >= _brick.position.y and p.y <= _brick.end.y
		if (brick_mode < 1.5 and inside) or (brick_mode > 1.5 and not inside):
			return false
	return true

func _select(keep: Callable) -> PackedInt32Array:
	var indices: PackedInt32Array = PackedInt32Array()
	for index: int in range(_victim_chunks.points.size()):
		if keep.call(_victim_chunks.points[index]):
			indices.append(index)
	return indices

func _foot_pivot() -> Vector2:
	return Vector2(_victim_chunks.aspect * 0.5, 1.0)

## A part of the victim that moves on its own. `pivot` defaults to the part's centroid.
func _make_body(mask: Dictionary, pivot: Variant = null) -> Body:
	var body: Body = Body.new()
	body.indices = _select(func(p: Vector2) -> bool: return _mask_keeps(mask, p))
	if pivot == null:
		var sum: Vector2 = Vector2.ZERO
		for index: int in body.indices:
			sum += _victim_chunks.points[index]
		body.pivot = sum / maxf(body.indices.size(), 1.0) if not body.indices.is_empty() else _foot_pivot()
	else:
		body.pivot = pivot
	body.material = _piece_material(_victim_chunks)
	for key: String in mask:
		body.material.set_shader_parameter(StringName(key), mask[key])
	body.sprite = _view.make_piece_sprite(_victim_texture)
	body.sprite.material = body.material
	body.sprite.offset = -(Vector2(_victim_chunks.used.position) + body.pivot * float(_victim_chunks.used.size.y))
	body.sprite.z_index = _victim.z_index
	body.x = _b.x + (body.pivot.x - _victim_chunks.aspect * 0.5) * _victim_height
	body.y = _proj.height_for_pixels((1.0 - body.pivot.y) * _victim_height)
	body.z = _b.z
	_view.piece_layer().add_child(body.sprite)
	_bodies.append(body)
	_place_body(body)
	return body

## A body that topples over the base corner facing away from the attacker.
func _make_tip_body(mask: Dictionary, start_speed: float, accel: float, slide: float, land_shake: float, big: bool) -> void:
	var corner: Vector2 = Vector2(_victim_chunks.aspect if _face > 0.0 else 0.0, 1.0)
	var body: Body = _make_body(mask, corner)
	body.kind = &"tip"
	body.tip_speed = start_speed
	body.tip_accel = accel
	body.slide = slide * _unit
	body.land_shake = land_shake
	body.land_big = big

func _shatter(body: Body, force: float = 1.0) -> void:
	var origin: Vector3 = Vector3(body.x + body.ox, maxf(0.0, body.y - _proj.height_for_pixels(body.oy)), body.z + _stand)
	_debris(body.indices, body.pivot, origin, {
		"vel": Vector3(body.vx * 0.4, maxf(20.0 * _unit, body.vy * 0.2) * force, body.vz * 0.4),
		"rot": body.rot,
		"spread": 30.0 * force,
	})
	body.dead = true
	if is_instance_valid(body.sprite):
		body.sprite.queue_free()

func _step_free(body: Body, dt: float) -> void:
	body.vy -= body.gravity * dt
	body.x += body.vx * dt
	body.y += body.vy * dt
	body.z += body.vz * dt
	body.rot += body.vr * dt
	if body.shatter_ground and body.vy < 0.0 and body.y < _proj.height_for_pixels(3.0 * _unit):
		_shatter(body, 0.9)
		fx.ring(body.x, body.z, _cell * 0.5, 0.3)
		if body.poof:
			fx.puff(Vector3(body.x, 3.0 * _unit, body.z), 10, 1.0)
	elif _rt >= body.shatter_at:
		_shatter(body, 0.35 if body.crumble else 0.7)
		if body.crumble:
			fx.puff(Vector3(body.x, 2.0 * _unit, body.z), 7, 0.8)

func _step_tip(body: Body, dt: float) -> void:
	if body.slide > 0.0 and body.age < 0.15:
		var k: float = 1.0 - body.age / 0.15
		body.x += _dir.x * body.slide * dt * k
		body.z += _dir.y * body.slide * dt * k
	if body.landed < 0.0:
		body.tip_speed += body.tip_accel * dt
		body.angle += body.tip_speed * dt
		if body.angle >= 1.5:
			body.angle = 1.5
			body.landed = body.age
			_shake = maxf(_shake, body.land_shake)
			var reach: float = body.x + _face * _cell * 0.55
			fx.ring(reach, body.z, _cell * (1.2 if body.land_big else 0.6), 0.45 if body.land_big else 0.3)
			fx.puff(Vector3(reach, 2.0 * _unit, body.z), 14 if body.land_big else 6, 1.3 if body.land_big else 0.8)
			if body.land_big:
				fx.crack_decal(reach, body.z, 4, _cell * 0.8)
	body.rot = _face * body.angle
	if body.landed >= 0.0 and body.age - body.landed > 0.08:
		_shatter(body, 0.8)

func _step_low_fly(body: Body, dt: float) -> void:
	var rest_height: float = _proj.height_for_pixels(4.0 * _unit)
	if body.phase == 0:
		body.vy -= 320.0 * _unit * dt
		body.x += body.vx * dt
		body.y += body.vy * dt
		body.z += body.vz * dt
		body.rot += body.vr * dt
		if body.vy < 0.0 and body.y < rest_height:
			body.bounce += 1
			fx.puff(Vector3(body.x, _unit, body.z), 3, 0.6)
			if body.bounce < 2:
				body.vy = 42.0 * _unit
				body.vx *= 0.72
				body.vz *= 0.72
				body.vr *= 0.6
			else:
				body.phase = 1
				body.y = rest_height
				body.lie = roundf(body.rot / (PI * 0.5)) * PI * 0.5
				if is_zero_approx(body.lie):
					body.lie = _face * PI * 0.5
		return
	var friction: float = pow(0.03, dt)
	body.vx *= friction
	body.vz *= friction
	body.x += body.vx * dt
	body.z += body.vz * dt
	body.rot += (body.lie - body.rot) * minf(1.0, dt * 14.0)
	if randf() < 0.5:
		fx.puff(Vector3(body.x, _unit, body.z), 1, 0.45)
	if Vector2(body.vx, body.vz).length() < 14.0 * _unit:
		_shatter(body, 0.8)
		fx.ring(body.x, body.z, _cell * 0.45, 0.3)

func _step_slash_upper(body: Body) -> void:
	var hold: float = 0.32 if body.heavy else 0.24
	var accel: float = (110.0 if body.heavy else 190.0) * _unit
	var fall: float = 0.5 if body.heavy else 0.38
	var apart: float = _ease_out(clampf(body.age / 0.08, 0.0, 1.0)) * 3.0 * _unit
	var offset: Vector2 = body.normal * apart
	if body.age > hold:
		var since: float = body.age - hold
		offset += body.tangent * 0.5 * accel * since * since
		body.rot = (-1.0 if body.tangent.x < 0.0 else 1.0) * 1.3 * since
		if since > fall:
			body.ox = offset.x
			body.oy = offset.y
			_shatter(body, 1.0 if body.heavy else 0.8)
			fx.ring(body.x + offset.x, body.z, _cell * (0.7 if body.heavy else 0.45), 0.3)
			if body.heavy:
				_shake = maxf(_shake, 0.7)
			return
	body.ox = offset.x
	body.oy = offset.y

func _step_slash_lower(body: Body) -> void:
	var hold: float = 0.32 if body.heavy else 0.24
	var fall: float = 0.5 if body.heavy else 0.38
	var apart: float = _ease_out(clampf(body.age / 0.08, 0.0, 1.0)) * 1.5 * _unit
	body.ox = -body.normal.x * apart
	body.oy = -body.normal.y * apart
	if body.age > hold:
		body.rot = (-1.0 if -body.normal.x < 0.0 else 1.0) * 0.35 * _smooth(clampf((body.age - hold) / 0.4, 0.0, 1.0))
	if body.age > hold + fall + 0.1:
		_shatter(body, 0.6)

## Breaks the given chunks of the victim into loose particles. `pivot` is the chunk
## point that sits at `origin`; `vel` is in world units, `spread`/`gravity` in design units.
func _debris(indices: PackedInt32Array, pivot: Vector2, origin: Vector3, options: Dictionary = {}) -> void:
	var velocity: Vector3 = options.get("vel", Vector3.ZERO)
	var rotation: float = float(options.get("rot", 0.0))
	var spread: float = float(options.get("spread", 30.0)) * _unit
	var every: int = int(options.get("every", 1))
	var gravity: float = float(options.get("gravity", 260.0)) * _unit
	var life_min: float = float(options.get("life_min", 1.0))
	var life_max: float = float(options.get("life_max", 1.6))
	var color_override: Variant = options.get("color", null)
	var radial: float = float(options.get("radial", 2.0))
	var chunk: float = _victim_height / ROWS
	for order: int in range(indices.size()):
		if order % every != 0:
			continue
		var index: int = indices[order]
		var local: Vector2 = ((_victim_chunks.points[index] - pivot) * _victim_height).rotated(rotation)
		var position: Vector3 = Vector3(origin.x + local.x, maxf(0.0, origin.y - _proj.height_for_pixels(local.y)), origin.z)
		var speed: Vector3 = Vector3(
			velocity.x + randf_range(-spread, spread) + local.x * radial,
			velocity.y + randf_range(0.0, spread * 1.2),
			velocity.z + randf_range(-spread, spread) * 0.6)
		fx.add_part(position, speed, _victim_chunks.colors[index] if color_override == null else color_override as Color, chunk * (1.7 if randf() < 0.25 else 1.0), randf_range(life_min, life_max), gravity)

# --- rendering ----------------------------------------------------------------

func _render() -> void:
	_pose = _compute_pose(_t)
	_place_pose(_attacker, _pose, true)
	_attacker_material.set_shader_parameter(&"flash", _pose.white)
	_attacker_material.set_shader_parameter(&"alpha", 0.0 if _extra.attacker_gone else _pose.alpha)
	var trail_limit: int = MAX_GHOSTS if _attack_id == &"bishop" else 7
	if _pose.trail and _hs <= 0.0 and not _extra.attacker_gone:
		_trail.append(_pose)
		if _trail.size() > trail_limit:
			_trail.pop_front()
	elif not _pose.trail and not _trail.is_empty():
		_trail.pop_front()
	for index: int in range(_ghosts.size()):
		var ghost: Sprite2D = _ghosts[index]
		ghost.visible = index < _trail.size()
		if ghost.visible:
			_place_pose(ghost, _trail[index], false)
			(ghost.material as ShaderMaterial).set_shader_parameter(&"alpha", 0.06 + index * (0.03 if _attack_id == &"bishop" else 0.05))
	if not _split:
		_update_victim()
	for body: Body in _bodies:
		_place_body(body)
	_apply_camera()

func _place_pose(sprite: Sprite2D, pose: Pose, move_holder: bool) -> void:
	var ground: Vector3 = Vector3(pose.x, 0.0, pose.z + _stand)
	var scale_value: float = float(sprite.get_meta("base_scale", 1.0)) * _proj.scale_at(ground)
	if move_holder:
		_holder.position = _proj.project(ground)
	sprite.position = _proj.project(Vector3(ground.x, pose.y, ground.z)) - _holder.position
	sprite.scale = Vector2(scale_value * pose.sx, scale_value * pose.sy)
	sprite.rotation = pose.rot

func _update_victim() -> void:
	var ground: Vector3 = _foot(_b)
	var scale_value: float = float(_victim.get_meta("base_scale", 1.0)) * _proj.scale_at(ground)
	var position: Vector2 = _proj.project(ground)
	var stretch: Vector2 = Vector2.ONE
	var jitter: float = 0.0
	var material: ShaderMaterial = _victim_material
	material.set_shader_parameter(&"flash", 1.0 if _impacted and _rt < 0.07 else 0.0)
	if not _impacted:
		if _t - _wobble_time < 0.28:
			jitter = roundf(sin((_t - _wobble_time) * 70.0) * 1.5)
	else:
		jitter = float(randi_range(-1, 1))
		match _reaction:
			&"slash_shatter":
				material.set_shader_parameter(&"sparkle", (_rt - 0.06) * 4.0 if _rt > 0.06 else 0.0)
				material.set_shader_parameter(&"sparkle_time", _rt)
			&"blunt_crack":
				material.set_shader_parameter(&"crack_progress", clampf((_rt - 0.04) / 0.16, 0.0, 1.0))
			&"crush_flat":
				var p: float = _flatten_progress()
				stretch = Vector2(1.0 + 0.7 * p, 1.0 - 0.82 * p)
				jitter = 0.0
			&"crush_collapse":
				material.set_shader_parameter(&"clip_y", Vector2(float(_collapsed_rows()) / ROWS, 1.0))
				jitter = 0.0
			&"crush_sink":
				var sunk: float = _sink_pixels()
				material.set_shader_parameter(&"clip_y", Vector2(0.0, 1.0 - sunk / _victim_height))
				position.y += sunk * _proj.scale_at(ground)
			&"hole", &"hole_heavy":
				var total: float = _split_time()
				material.set_shader_parameter(&"hole_radius", 1.7 / ROWS)
				material.set_shader_parameter(&"hole_glow", 0.9 * (1.0 - clampf(_rt / total, 0.0, 1.0) * 0.6))
				material.set_shader_parameter(&"web_progress", clampf((_rt - 0.12) / (total - 0.2), 0.0, 1.0))
				jitter = roundf(randf_range(-1.0, 1.0) * (0.4 + clampf(_rt / total, 0.0, 1.0))) if _rt > 0.1 else 0.0
			&"venom":
				if _rt < 0.25:
					var q: float = _rt / 0.25
					_set_tint(material, VENOM_COLOR, 0.55 * q * (0.7 + 0.3 * sin(_rt * 50.0)))
					jitter = roundf(randf_range(-1.0, 1.0) * q)
				else:
					var melt: float = clampf((_rt - 0.25) / _melt_duration(), 0.0, 1.0)
					material.set_shader_parameter(&"clip_y", Vector2(floorf(melt * ROWS) / ROWS, 1.0))
					_set_tint(material, VENOM_COLOR, 0.55)
					stretch = Vector2(1.0 + 0.3 * melt, 1.0)
					jitter = 0.0
			&"arcane":
				var q: float = clampf(_rt / _arcane_duration(), 0.0, 1.0)
				position = _proj.project(ground + Vector3(0.0, _arcane_lift(), 0.0))
				_set_tint(material, ARCANE_COLOR, (0.25 + 0.5 * q) * (0.7 + 0.3 * sin(_rt * 60.0)))
				jitter = roundf(randf_range(-1.0, 1.0) * (0.3 + q * 1.6))
			_ when _extra.handles(_reaction):
				var state: Dictionary = _extra.victim_state(material)
				if state.has("world"):
					var world: Vector3 = state["world"]
					position = _proj.project(world)
				stretch = state.get("stretch", stretch)
				jitter = float(state.get("jitter", jitter))
				_victim.rotation = float(state.get("rot", 0.0))
	_victim.position = position + Vector2(jitter * _unit, 0.0)
	_victim.scale = Vector2(scale_value, scale_value) * stretch

func _place_body(body: Body) -> void:
	var ground: Vector3 = Vector3(body.x, 0.0, body.z + _stand)
	var scale_value: float = float(body.sprite.get_meta("base_scale", 1.0)) * _proj.scale_at(ground)
	var jitter: float = float(randi_range(-1, 1)) * _unit if body.jitter and _rt < body.shatter_at else 0.0
	body.sprite.position = _proj.project(Vector3(ground.x, body.y, ground.z)) + Vector2(body.ox + jitter, body.oy)
	body.sprite.scale = Vector2(scale_value, scale_value) * body.scale_mul
	body.sprite.rotation = body.rot
	if body.glow:
		body.material.set_shader_parameter(&"edge_glow", clampf(1.0 - body.age / 0.55, 0.0, 1.0))

func _focus() -> float:
	if not _impacted:
		return 0.0
	var rise: float = minf(1.0, _rt / 0.08)
	return rise * (1.0 if _rt < 0.8 else maxf(0.0, 1.0 - (_rt - 0.8) / 0.35))

## Zoom punch and shake around the impact point, and dimming of the bystanders.
func _apply_camera() -> void:
	var focus: float = _focus()
	var strength: float = _shake * _shake * 3.4 * _unit
	var offset: Vector2 = Vector2(roundf(randf_range(-1.0, 1.0) * strength), roundf(randf_range(-1.0, 1.0) * strength))
	var zoom: float = 1.0 + 0.1 * _smooth(focus) + 0.07 * _punch
	var impact_point: Vector2 = _proj.project(Vector3(_b.x, 8.0 * _unit, _b.z))
	_view.set_camera(Transform2D(0.0, Vector2(zoom, zoom), 0.0, impact_point * (1.0 - zoom) + offset))
	_dim_bystanders(1.0 - 0.62 * focus)

func _reset_camera() -> void:
	if _view == null:
		return
	_view.set_camera(Transform2D.IDENTITY)
	_dim_bystanders(1.0)

func _dim_bystanders(alpha: float) -> void:
	var sprites: Dictionary = _view.standing_sprites()
	for square: Variant in sprites:
		var sprite: Sprite2D = sprites[square] as Sprite2D
		if is_instance_valid(sprite):
			sprite.self_modulate.a = 1.0 if square == _to_square else alpha

func _draw_ground() -> void:
	if fx.projection == null:
		return
	var canvas: Node2D = _view.ground_canvas()
	fx.draw_ground(canvas)
	if _phase != Phase.PLAYING:
		return
	_draw_special_ground(canvas)
	_extra.draw_ground(canvas)
	if _pose.alpha > 0.05:
		_draw_shadow(canvas, _pose.x, _pose.z, _pose.y, 1.0, _pose.alpha)
	if not _split:
		_draw_shadow(canvas, _b.x, _b.z, 0.0, 1.0)
	for body: Body in _bodies:
		if body.y > _proj.height_for_pixels(2.0 * _unit):
			_draw_shadow(canvas, body.x + body.ox, body.z, body.y, 0.75)

func _draw_shadow(canvas: CanvasItem, x: float, z: float, height: float, size: float, alpha: float = 1.0) -> void:
	var shrink: float = maxf(0.35, 1.0 - height / (45.0 * _unit))
	var radius: float = _cell * 0.33 * size * shrink
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(16):
		var angle: float = TAU * index / 16.0
		points.append(_proj.project(Vector3(x + cos(angle) * radius, 0.0, z + sin(angle) * radius)))
	canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.36 * shrink * alpha))

func _draw_air() -> void:
	if fx.projection == null:
		return
	var canvas: Node2D = _view.air_canvas()
	fx.draw_air(canvas)
	if _phase == Phase.PLAYING:
		match _attack_id:
			&"queen": _draw_lance(canvas)
			&"king": _draw_judgment(canvas)
			_: _draw_special_air(canvas)
		_extra.draw_air(canvas)
		if _slash_age >= 0.0:
			_draw_slash(canvas)
		if _pose.dizzy:
			_draw_dizzy(canvas)
	if _flash > 0.0 and _phase != Phase.IDLE:
		var impact_point: Vector2 = _proj.project(Vector3(_b.x, 8.0 * _unit, _b.z))
		canvas.draw_circle(impact_point, ((1.0 - _flash) * 18.0 + 4.0) * _unit, Color(1.0, 0.98, 0.9, _flash * 0.9))
		canvas.draw_rect(Rect2(Vector2(-2000.0, -2000.0), Vector2(5000.0, 5000.0)), Color(1.0, 1.0, 1.0, _flash * 0.16))

func _draw_slash(canvas: CanvasItem) -> void:
	var progress: float = _slash_age / 0.5
	var centre: Vector2 = _proj.project(Vector3(_b.x, _proj.height_for_pixels(_victim_height * 0.45), _b.z + _stand))
	var reach: Vector2 = Vector2(cos(_slash_angle), sin(_slash_angle)) * 28.0 * _unit * minf(1.0, _slash_age / 0.06)
	canvas.draw_line(centre - reach, centre + reach, Color(1.0, 1.0, 1.0, (1.0 - progress) * 0.35), (5.0 * (1.0 - progress) + 1.0) * _unit)
	canvas.draw_line(centre - reach, centre + reach, Color(1.0, 1.0, 1.0, 1.0 - progress), maxf(_unit, 1.0))

func _draw_dizzy(canvas: CanvasItem) -> void:
	var head: Vector2 = _proj.project(Vector3(_pose.x, _proj.height_for_pixels(14.0 * _unit), _pose.z + _stand))
	for index: int in range(3):
		var angle: float = _t * 7.0 + index * 2.1
		var star: Vector2 = head + Vector2(cos(angle) * 6.0, sin(angle) * 2.0) * _unit
		var color: Color = Color("#fff3b0") if index % 2 == 1 else Color("#e0b45c")
		canvas.draw_rect(Rect2(star - Vector2(0.5, 1.5) * _unit, Vector2(1.0, 3.0) * _unit), color)
		canvas.draw_rect(Rect2(star - Vector2(1.5, 0.5) * _unit, Vector2(3.0, 1.0) * _unit), color)

## Queen: a lance of light forms in front of her, draws back, then flies through the target.
func _draw_lance(canvas: CanvasItem) -> void:
	var u: float = _t
	if u < 0.08 or (_impacted and _rt > 0.4):
		return
	var start: Vector2 = _proj.project(Vector3(_pose.x, _pose.y + _proj.height_for_pixels(8.0 * _unit), _pose.z + _stand))
	var target: Vector2 = _proj.project(Vector3(_b.x, _proj.height_for_pixels(7.0 * _unit), _b.z + _stand))
	var distance: float = start.distance_to(target)
	if distance < 0.001:
		return
	var along: Vector2 = (target - start) / distance
	var across: Vector2 = Vector2(-along.y, along.x) * _unit
	var full: float = 18.0 * _unit
	var length: float = full
	var tail: float = 7.0 * _unit
	var alpha: float = 1.0
	if u < 0.3:
		length = full * _ease_out((u - 0.08) / 0.22)
		alpha = (u - 0.08) / 0.22
	elif u < 0.5:
		tail = (7.0 - 4.0 * _smooth((u - 0.3) / 0.2)) * _unit
	elif not _impacted:
		tail = lerpf(3.0 * _unit, distance - full + 9.0 * _unit, _ease_in(clampf((u - 0.5) / 0.12, 0.0, 1.0)))
	else:
		tail = distance - full + 9.0 * _unit
		alpha = 1.0 - _rt / 0.4
	var back: Vector2 = start + along * tail
	var tip: Vector2 = back + along * length
	canvas.draw_line(back, tip, Color(1.0, 0.86, 0.51, 0.3 * alpha), 5.0 * _unit)
	if u > 0.5 and not _impacted:
		canvas.draw_line(start, back, Color(1.0, 0.94, 0.75, 0.35), 2.0 * _unit)
	var shoulder: Vector2 = tip - along * 3.0 * _unit
	canvas.draw_line(back - across, shoulder - across, Color(AMBER, alpha), maxf(_unit, 1.0))
	canvas.draw_line(back + across, shoulder + across, Color(AMBER, alpha), maxf(_unit, 1.0))
	canvas.draw_line(back, tip, Color(1.0, 1.0, 1.0, alpha), maxf(_unit, 1.0))

## King: an aiming line over the target, then a pillar of light drops on it.
func _draw_judgment(canvas: CanvasItem) -> void:
	var u: float = _t
	var foot: Vector2 = _proj.project(_b)
	var top: float = foot.y - _cell * 14.0
	if u > 0.15 and u < 0.6:
		canvas.draw_rect(Rect2(foot.x - _unit * 0.5, top, _unit, foot.y - top), Color(AMBER, 0.35 + 0.3 * sin(u * 60.0)))
		var radius: float = _cell * 0.5 * (1.4 - 0.4 * clampf((u - 0.15) / 0.4, 0.0, 1.0))
		for index: int in range(20):
			var angle: float = TAU * index / 20.0 + u * 4.0
			var dot: Vector2 = _proj.project(Vector3(_b.x + cos(angle) * radius, 0.0, _b.z + sin(angle) * radius))
			canvas.draw_rect(Rect2(dot - Vector2(0.5, 0.5) * _unit, Vector2(_unit, _unit)), AMBER)
	if u >= 0.6 and not _impacted:
		var bottom: float = lerpf(top, foot.y, _ease_in(clampf((u - 0.6) / 0.12, 0.0, 1.0)))
		canvas.draw_rect(Rect2(foot.x - 4.5 * _unit, top, 9.0 * _unit, bottom - top), Color(AMBER, 0.85))
		canvas.draw_rect(Rect2(foot.x - 2.5 * _unit, top, 5.0 * _unit, bottom - top), Color("#fffbe8"))
	if _impacted and _rt < 0.45:
		var k: float = 1.0 - _rt / 0.45
		var half: float = maxf(1.0, roundf(6.0 * k)) * _unit
		canvas.draw_rect(Rect2(foot.x - half - 2.5 * _unit, top, half * 2.0 + 5.0 * _unit, foot.y - top), Color(AMBER, 0.75 * k))
		canvas.draw_rect(Rect2(foot.x - half, top, half * 2.0, foot.y - top), Color(1.0, 0.98, 0.91, k))

# --- special pieces -----------------------------------------------------------
# Ported from docs/prototypes/special_strikes.html. Same conventions as above: `u` is
# seconds since the strike started, plain numbers are design units scaled by `_unit`.

func _absorb_duration() -> float:
	return [0.55, 0.75, 1.0][_victim_weight]

func _melt_duration() -> float:
	return [0.7, 0.9, 1.15][_victim_weight]

func _arcane_duration() -> float:
	return [0.4, 0.55, 0.75][_victim_weight]

func _manticore_walk() -> float:
	return 0.64 + 0.25 + _melt_duration() + 0.3

func _portal_vanish() -> float:
	return 0.7 + _absorb_duration() + 0.45

func _archmage_glide() -> float:
	return 0.76 + _arcane_duration() + 0.55

## Height of a fraction of the attacker / victim sprite, in world units.
func _attacker_at(fraction: float) -> float:
	return _proj.height_for_pixels(_attacker_height * fraction)

func _victim_at(fraction: float) -> float:
	return _proj.height_for_pixels(_victim_height * fraction)

func _assassin_behind() -> Vector3:
	var behind: Vector3 = _along(_b, _cell * 0.62)
	return behind if _on_board(behind) else _along(_b, _cell * 0.35)

func _centaur_past() -> Vector3:
	var past: Vector3 = _along(_b, _cell * 0.75)
	return past if _on_board(past) else _along(_b, _cell * 0.35)

## Timings that depend on the victim's weight or on how far the attacker travels.
func _apply_dynamic_timing() -> void:
	match _attack_id:
		&"portal_mage":
			_done_time = _portal_vanish() + 0.45
		&"manticore":
			_done_time = _manticore_walk() + 0.4
		&"archmage":
			_done_time = _archmage_glide() + 0.45
		&"centaur":
			# The cut lands as the gallop passes the target, wherever that is on the line.
			var past: Vector3 = _centaur_past()
			var reach: float = Vector2(past.x - _a.x, past.z - _a.z).length()
			var hit: float = Vector2(_b.x - _a.x, _b.z - _a.z).length() / maxf(reach, 0.001)
			_impact_time = 0.2 + 0.32 * clampf(hit, 0.2, 1.0)
			_done_time = maxf(_done_time, _impact_time + 0.9)
		_:
			if not _extra.dynamic_timing():
				return
	_end_time = maxf(_end_time, _done_time + 0.8)

func _special_events() -> Array:
	match _attack_id:
		&"assassin":
			return [[0.16, _event_puff.bind(_up(_a, 2.0), 9, 0.8)], [0.34, _event_puff.bind(_up(_assassin_behind(), 2.0), 7, 0.7)]]
		&"bowman":
			return [[0.46, _event_sparks.bind(Vector3(_a.x, _attacker_at(0.6), _a.z), 3, 40.0, 0.25)]]
		&"catapult":
			return [[0.1, _event_puff.bind(_up(_a, 1.0), 3, 0.5)], [0.4, _event_catapult_release]]
		&"royal_guard":
			return [[0.22, _event_sparks.bind(Vector3(_along(_a, 4.0 * _unit).x, 8.0 * _unit, _along(_a, 4.0 * _unit).z), 4, 0.0, 0.25)]]
		&"centaur":
			return [[0.2, _event_puff.bind(_up(_a, 2.0), 6, 0.8)]]
		&"gryphon":
			return [[0.2, _event_gryphon_takeoff]]
		&"manticore":
			return [[0.45, _event_puff.bind(_up(_along(_b, -_cell * 0.5), 1.0), 6, 0.8)]]
		&"portal_mage":
			var vanish: float = _portal_vanish()
			return [[vanish, _event_puff.bind(_up(_a, 3.0), 8, 0.7)], [vanish + 0.25, _event_portal_arrive]]
	return _extra.events()

func _event_puff(at: Vector3, count: int, big: float) -> void:
	fx.puff(at, count, big)

func _event_sparks(at: Vector3, count: int, bias: float, speed: float) -> void:
	fx.spark_burst(at, count, _dir, bias, speed)

func _event_catapult_release() -> void:
	fx.puff(_up(_a, 2.0), 6, 0.8)
	_shake = maxf(_shake, 0.35)

func _event_gryphon_takeoff() -> void:
	fx.puff(_up(_a, 1.0), 8, 1.0)
	fx.ring(_a.x, _a.z, _cell * 0.6, 0.3)

func _event_portal_arrive() -> void:
	fx.puff(_up(_dest, 3.0), 8, 0.7)
	fx.ring(_dest.x, _dest.z, _cell * 0.55, 0.3, VOID_COLOR)

func _settle_into(o: Pose, start: Vector3, u: float, at: float, duration: float, hop: float) -> void:
	var q: float = clampf((u - at) / duration, 0.0, 1.0)
	o.at(start.lerp(_dest, _smooth(q)))
	o.y = hop * _unit * sin(q * PI)

func _special_pose(u: float, o: Pose) -> void:
	match _attack_id:
		&"assassin": _pose_assassin(u, o)
		&"bowman": _pose_bowman(u, o)
		&"catapult": _pose_catapult(u, o)
		&"lancer": _pose_lancer(u, o)
		&"portal_mage": _pose_portal_mage(u, o)
		&"royal_guard": _pose_royal_guard(u, o)
		&"centaur": _pose_centaur(u, o)
		&"unicorn_cavalry": _pose_unicorn(u, o)
		&"gryphon": _pose_gryphon(u, o)
		&"manticore": _pose_manticore(u, o)
		&"archmage": _pose_archmage(u, o)
		_: _extra.pose(u, o)

## Vanishes in smoke, reappears behind the target and cuts backhanded.
func _pose_assassin(u: float, o: Pose) -> void:
	var behind: Vector3 = _assassin_behind()
	if u < 0.16:
		var s: float = u / 0.16
		o.sx = 1.0 + 0.15 * s
		o.sy = 1.0 - 0.3 * s
		o.alpha = 1.0 - 0.4 * s
		return
	if u < 0.34:
		o.alpha = 0.0
		return
	o.at(behind)
	if u < 0.46:
		var q: float = (u - 0.34) / 0.12
		o.alpha = q
		o.sy = 0.75 + 0.25 * q
		return
	if u < 0.62:
		var q: float = (u - 0.46) / 0.16
		o.rot = lerpf(0.3, -0.4, _ease_in(q)) * -_face
		o.at(_along(behind, -2.5 * _unit * q))
		o.white = 0.45 * q
		o.trail = q > 0.6
		return
	if u < 1.15:
		var q: float = clampf((u - 0.62) / 0.25, 0.0, 1.0)
		o.at(_along(behind, -2.5 * _unit * (1.0 - q)))
		o.rot = 0.4 * _face * (1.0 - _smooth(q))
		return
	_settle_into(o, behind, u, 1.15, 0.28, 3.0)

## Draws, looses an arrow on an arching flight, then trots in.
func _pose_bowman(u: float, o: Pose) -> void:
	if u < 0.44:
		var s: float = sin(clampf(u / 0.38, 0.0, 1.0) * PI * 0.5)
		o.rot = -0.14 * s * _face
		o.sx = 1.0 - 0.06 * s
		o.sy = 1.0 + 0.04 * s
		return
	if u < 0.6:
		var q: float = (u - 0.44) / 0.16
		o.at(_along(_a, -2.5 * _unit * sin(q * PI)))
		o.rot = lerpf(0.12, 0.0, q) * _face
		return
	if u < 1.2:
		return
	var q: float = clampf((u - 1.2) / 0.45, 0.0, 1.0)
	o.at(_a.lerp(_dest, _smooth(q)))
	o.y = absf(sin(q * PI * 3.0)) * 2.5 * _unit

## Winds the arm back, flings a boulder, later rolls onto the square.
func _pose_catapult(u: float, o: Pose) -> void:
	if u < 0.38:
		var s: float = clampf(u / 0.34, 0.0, 1.0)
		o.rot = -0.1 * s * _face
		o.sy = 1.0 - 0.1 * s
		o.sx = 1.0 + 0.05 * s
		o.x += (randf() - 0.5) * 1.4 * _unit * s
		return
	if u < 0.62:
		var q: float = (u - 0.38) / 0.24
		o.rot = lerpf(0.16, 0.0, _ease_out(q)) * _face
		o.sx = 1.0 + 0.06 * (1.0 - q)
		return
	if u < 1.3:
		return
	var q: float = clampf((u - 1.3) / 0.55, 0.0, 1.0)
	o.at(_a.lerp(_dest, _smooth(q)))
	o.y = absf(sin(q * PI * 5.0)) * _unit

## World position of the boulder in flight, and how far along it is.
func _boulder(u: float) -> Array:
	var q: float = clampf((u - 0.4) / (float(_attack["impact"]) - 0.4), 0.0, 1.0)
	var height: float = lerpf(_attacker_at(0.8), _victim_at(1.0), q) + _cell * 3.4 * 4.0 * q * (1.0 - q)
	return [Vector3(lerpf(_a.x, _b.x, q), height, lerpf(_a.z, _b.z, q)), q]

func _pose_lancer(u: float, o: Pose) -> void:
	var contact: Vector3 = _along(_b, -_cell * 0.55)
	if u < 0.24:
		var s: float = sin(u / 0.24 * PI * 0.5)
		o.rot = -0.25 * s * _face
		o.sy = 1.0 - 0.08 * s
		return
	if u < 0.58:
		var q: float = (u - 0.24) / 0.34
		o.at(_a.lerp(contact, _ease_in(q)))
		o.y = absf(sin(q * PI * 3.0)) * 3.0 * _unit
		o.rot = 0.1 * _face
		o.trail = q > 0.4
		return
	if u < 0.95:
		var q: float = clampf((u - 0.58) / 0.15, 0.0, 1.0)
		o.at(_along(contact, 3.0 * _unit * sin(q * PI)))
		return
	_settle_into(o, contact, u, 0.95, 0.3, 2.0)

## Floats while the void gate opens, then blinks out and reappears on the square.
func _pose_portal_mage(u: float, o: Pose) -> void:
	var vanish: float = _portal_vanish()
	o.y = _cell * 0.22 * _ease_out(clampf(u / 0.3, 0.0, 1.0)) + sin(u * 9.0) * 0.8 * _unit
	o.white = 0.3 * clampf(u / 0.3, 0.0, 1.0) * (0.7 + 0.3 * sin(u * 40.0)) if u < 0.75 else 0.0
	if u < vanish:
		return
	if u < vanish + 0.1:
		var k: float = (u - vanish) / 0.1
		o.alpha = 1.0 - k
		o.sy = 1.0 + 0.3 * k
		o.sx = 1.0 - 0.4 * k
		return
	o.at(_dest)
	o.y = 0.0
	if u < vanish + 0.25:
		o.alpha = 0.0
		return
	var q: float = clampf((u - vanish - 0.25) / 0.2, 0.0, 1.0)
	o.alpha = q
	o.y = _cell * 0.25 * (1.0 - q)
	o.sy = 1.2 - 0.2 * q
	o.sx = 0.7 + 0.3 * q

func _pose_royal_guard(u: float, o: Pose) -> void:
	var back: Vector3 = _along(_a, -_cell * 0.22)
	var contact: Vector3 = _along(_b, -_cell * 0.55)
	if u < 0.3:
		var q: float = _ease_out(u / 0.3)
		o.at(_a.lerp(back, q))
		o.sx = 1.0 + 0.08 * q
		o.sy = 1.0 - 0.1 * q
		o.white = 0.5 if u > 0.18 and u < 0.28 else 0.0
		return
	if u < 0.52:
		var q: float = (u - 0.3) / 0.22
		o.at(back.lerp(contact, _ease_in(q)))
		o.sx = 0.92
		o.sy = 1.08
		o.trail = true
		return
	if u < 0.62:
		var q: float = (u - 0.52) / 0.1
		o.at(contact)
		o.sx = 1.0 + 0.2 * sin(q * PI)
		o.sy = 1.0 - 0.18 * sin(q * PI)
		return
	_settle_into(o, contact, u, 0.62, 0.32, 1.5)

## Gallops along the line, cuts while passing, wheels round and trots back.
func _pose_centaur(u: float, o: Pose) -> void:
	var past: Vector3 = _centaur_past()
	if u < 0.2:
		var s: float = sin(u / 0.2 * PI * 0.5)
		o.rot = -0.28 * s * _face
		o.y = _cell * 0.1 * s
		return
	if u < 0.52:
		var q: float = (u - 0.2) / 0.32
		o.at(_a.lerp(past, q))
		o.y = absf(sin(q * PI * 4.0)) * 2.5 * _unit
		o.rot = 0.08 * _face
		o.trail = true
		o.white = 0.6 if absf(u - _impact_time) < 0.04 else 0.0
		return
	o.at(past)
	if u < 0.8:
		o.rot = lerpf(0.08, -0.12, _ease_out((u - 0.52) / 0.28)) * _face
		return
	if u < 1.0:
		o.sx = lerpf(1.0, -1.0, _smooth((u - 0.8) / 0.2))
		return
	var q: float = clampf((u - 1.0) / 0.38, 0.0, 1.0)
	o.sx = -1.0 if q < 1.0 else 1.0
	o.at(past.lerp(_dest, _smooth(q)))
	o.y = absf(sin(q * PI * 2.0)) * 2.0 * _unit

func _pose_unicorn(u: float, o: Pose) -> void:
	var contact: Vector3 = _along(_b, -_cell * 0.5)
	if u < 0.3:
		var s: float = sin(u / 0.3 * PI)
		o.rot = -0.35 * s * _face
		o.y = _cell * 0.18 * s
		o.white = 0.35 * clampf(u / 0.2, 0.0, 1.0) * (0.6 + 0.4 * sin(u * 60.0))
		return
	if u < 0.56:
		var q: float = (u - 0.3) / 0.26
		o.at(_a.lerp(contact, _ease_in(q)))
		o.rot = 0.14 * _face
		o.trail = true
		o.white = 0.25
		o.y = absf(sin(q * PI * 2.0)) * 2.0 * _unit
		return
	if u < 0.95:
		var q: float = clampf((u - 0.56) / 0.14, 0.0, 1.0)
		o.at(_along(contact, 3.0 * _unit * sin(q * PI)))
		o.rot = 0.14 * _face * (1.0 - q)
		return
	_settle_into(o, contact, u, 0.95, 0.3, 2.0)

## Climbs diagonally, glides over the target, dives. Light and medium prey is carried
## up and dropped; heavy prey is raked and the gryphon bounces back up.
func _pose_gryphon(u: float, o: Pose) -> void:
	var high: float = _cell * 2.8
	var top: float = _victim_at(1.0)
	if u < 0.2:
		var s: float = sin(u / 0.2 * PI * 0.5)
		o.sy = 1.0 - 0.18 * s
		o.sx = 1.0 + 0.1 * s
		return
	if u < 0.42:
		var q: float = (u - 0.2) / 0.22
		o.at(_a.lerp(_corner, q))
		o.y = high * _ease_out(q)
		_flap(o, u, 40.0)
		o.trail = true
		return
	if u < 0.55:
		o.at(_corner.lerp(_b, _smooth((u - 0.42) / 0.13)))
		o.y = high
		o.rot = -0.08 * _face
		return
	o.at(_b)
	if u < 0.62:
		o.y = high + 2.0 * _unit * sin(u * 30.0)
		_flap(o, u, 50.0)
		return
	if u < 0.72:
		o.y = lerpf(high, top, _ease_in((u - 0.62) / 0.1))
		o.rot = 0.2 * _face
		o.sx = 0.9
		o.sy = 1.15
		o.trail = true
		return
	if _victim_weight == PieceDef.WeightClass.HEAVY:
		var hover: float = _cell * 1.3
		if u < 0.95:
			o.y = lerpf(top, hover, _ease_out((u - 0.72) / 0.23))
			_flap(o, u, 45.0)
		elif u < 1.5:
			o.y = hover + sin(u * 10.0) * 1.5 * _unit
			_flap(o, u, 45.0)
		else:
			var q: float = clampf((u - 1.5) / 0.35, 0.0, 1.0)
			o.y = hover * (1.0 - _smooth(q))
			_flap(o, u, 30.0 * (1.0 - q))
		return
	if u < 0.8:
		o.y = top
		o.sx = 1.1
		o.sy = 0.9
		return
	if u < 1.15:
		o.y = lerpf(top, high * 0.95, _ease_out((u - 0.8) / 0.35))
		_flap(o, u, 48.0)
		return
	if u < 1.45:
		o.y = high * 0.95 + sin(u * 12.0) * 1.5 * _unit
		_flap(o, u, 45.0)
		return
	var q: float = clampf((u - 1.45) / 0.4, 0.0, 1.0)
	o.y = high * 0.95 * (1.0 - _smooth(q))
	_flap(o, u, 30.0 * (1.0 - q))

func _flap(o: Pose, u: float, rate: float) -> void:
	o.sy = 1.0 + 0.1 * sin(u * rate)
	o.sx = 1.0 - 0.06 * sin(u * rate)

## Pounces along its bent path, coils the tail and stings; walks in once the victim melts.
func _pose_manticore(u: float, o: Pose) -> void:
	var contact: Vector3 = _along(_b, -_cell * 0.5)
	if u < 0.22:
		var s: float = sin(u / 0.22 * PI * 0.5)
		o.sy = 1.0 - 0.18 * s
		o.sx = 1.0 + 0.12 * s
		o.rot = -0.1 * s * _face
		return
	if u < 0.45:
		var q: float = (u - 0.22) / 0.23
		if q < 0.4:
			o.at(_a.lerp(_corner, q / 0.4))
		else:
			o.at(_corner.lerp(contact, (q - 0.4) / 0.6))
		o.y = _cell * 0.9 * sin(q * PI)
		o.rot = 0.12 * _face
		o.trail = true
		return
	o.at(contact)
	if u < 0.52:
		var w: float = sin((u - 0.45) / 0.07 * PI)
		o.sx = 1.0 + 0.18 * w
		o.sy = 1.0 - 0.16 * w
		return
	if u < 0.6:
		o.rot = -0.2 * (u - 0.52) / 0.08 * _face
		return
	if u < 0.66:
		o.rot = lerpf(-0.2, 0.25, (u - 0.6) / 0.06) * _face
		return
	var walk: float = _manticore_walk()
	if u < walk:
		o.rot = 0.25 * _face * (1.0 - clampf((u - 0.66) / 0.2, 0.0, 1.0))
		return
	_settle_into(o, contact, u, walk, 0.4, 1.5)

func _pose_archmage(u: float, o: Pose) -> void:
	var hover: float = _cell * 0.32
	var glide: float = _archmage_glide()
	if u < glide:
		o.y = hover * _ease_out(clampf(u / 0.3, 0.0, 1.0)) + sin(u * 8.0) * 0.8 * _unit
		o.white = 0.35 * clampf(u / 0.3, 0.0, 1.0) * (0.7 + 0.3 * sin(u * 45.0)) if u < 0.8 else 0.0
		if u > 0.56 and u < 0.7:
			o.rot = 0.12 * _face * sin((u - 0.56) / 0.14 * PI)
		return
	var q: float = clampf((u - glide) / 0.45, 0.0, 1.0)
	o.at(_a.lerp(_dest, _smooth(q)))
	o.y = hover * (1.0 - _ease_in(q))
	o.trail = q > 0.05 and q < 0.9

func _special_impact() -> void:
	match _attack_id:
		&"assassin":
			_slash_age = 0.0
			fx.spark_burst(_up(_b, 9.0), 8, -_dir, 50.0, 0.7)
		&"bowman":
			fx.spark_burst(_up(_b, 9.0), 9, _dir, 90.0, 0.6)
			fx.ring(_b.x, _b.z, _cell * 0.5, 0.26)
		&"catapult":
			fx.ring(_b.x, _b.z, _cell * 1.4, 0.5)
			fx.ring(_b.x, _b.z, _cell * 0.8, 0.32)
			fx.puff(_up(_b, 2.0), 14, 1.4)
			fx.crack_decal(_b.x, _b.z, 8, _cell * 1.05)
			fx.spark_burst(_up(_b, 4.0), 8, Vector2.ZERO, 0.0, 0.7)
			var chunk: float = _victim_height / ROWS
			for index: int in range(16):
				var angle: float = randf() * TAU
				var speed: float = randf_range(20.0, 70.0) * _unit
				fx.add_part(Vector3(_b.x, _victim_at(0.6), _b.z + _stand), Vector3(cos(angle) * speed, randf_range(40.0, 110.0) * _unit, sin(angle) * speed * 0.6), ROCK_COLORS[index % ROCK_COLORS.size()], chunk * (1.7 if index % 4 == 0 else 1.0), randf_range(1.0, 1.6), 260.0 * _unit)
		&"lancer":
			fx.spark_burst(_up(_b, 8.0), 10, _dir, 90.0, 0.7)
			fx.ring(_b.x, _b.z, _cell * 0.7, 0.3)
		&"portal_mage":
			fx.ring(_b.x, _b.z, _cell * 0.9, 0.45, VOID_COLOR)
			fx.spark_burst(_up(_b, 4.0), 6, Vector2.ZERO, 0.0, 0.4, VOID_COLOR)
		&"royal_guard":
			fx.ring(_b.x, _b.z, _cell * 1.3, 0.5, GOLD)
			fx.ring(_b.x, _b.z, _cell * 0.7, 0.3)
			fx.puff(_up(_b, 2.0), 9, 1.2)
			fx.spark_burst(_up(_b, 7.0), 8, _dir, 40.0, 0.7)
		&"centaur":
			_slash_age = 0.0
			fx.spark_burst(_up(_b, 9.0), 10, _dir, 70.0, 0.8)
		&"unicorn_cavalry":
			fx.spark_burst(_up(_b, 9.0), 14, _dir, 110.0, 0.8)
			fx.ring(_b.x, _b.z, _cell * 0.75, 0.3, GOLD)
		&"gryphon":
			fx.spark_burst(Vector3(_b.x, _victim_at(1.0), _b.z), 8, Vector2.ZERO, 0.0, 0.6)
			fx.ring(_b.x, _b.z, _cell * 0.7, 0.3)
			fx.puff(_up(_b, 2.0), 6, 0.8)
		&"manticore":
			fx.spark_burst(_up(_b, 8.0), 6, _dir, 40.0, 0.5, VENOM_COLOR)
		&"archmage":
			fx.ring(_b.x, _b.z, _cell * 0.9, 0.4, ARCANE_COLOR)
			fx.spark_burst(_up(_b, 8.0), 8, Vector2.ZERO, 0.0, 0.5, ARCANE_COLOR)
		_:
			_extra.impact()

func _arcane_lift() -> float:
	var q: float = clampf(_rt / _arcane_duration(), 0.0, 1.0)
	return _cell * 0.38 * _ease_out(q) * (0.45 if _victim_weight == PieceDef.WeightClass.HEAVY else 1.0)

func _random_chunk() -> int:
	return randi() % _victim_chunks.points.size() if _victim_chunks.points.size() > 0 else -1

func _special_reaction_tick() -> void:
	if _hs > 0.0:
		return
	match _reaction:
		&"venom":
			if _rt < 0.25:
				var index: int = _random_chunk()
				if index >= 0 and randf() < 0.5:
					_debris(PackedInt32Array([index]), _foot_pivot(), _foot(_b), {"vel": Vector3(0.0, 8.0 * _unit, 0.0), "spread": 6.0, "gravity": -50.0, "life_min": 0.3, "life_max": 0.5, "radial": 0.0, "color": VENOM_COLOR})
			elif randf() < 0.7:
				var row: int = floori(clampf((_rt - 0.25) / _melt_duration(), 0.0, 1.0) * ROWS)
				var front: PackedInt32Array = _select(func(p: Vector2) -> bool: return int(p.y * ROWS) == row)
				if not front.is_empty():
					var pick: int = front[randi() % front.size()]
					_debris(PackedInt32Array([pick]), _foot_pivot(), _foot(_b), {"vel": Vector3.ZERO, "spread": 5.0, "gravity": 160.0, "life_min": 0.4, "life_max": 0.7, "radial": 0.3, "color": VENOM_COLOR if randf() < 0.5 else VENOM_DARK})
		&"arcane":
			var index: int = _random_chunk()
			if index >= 0 and randf() < 0.6:
				_debris(PackedInt32Array([index]), _foot_pivot(), _foot(_b) + Vector3(0.0, _arcane_lift(), 0.0), {"vel": Vector3(0.0, 15.0 * _unit, 0.0), "spread": 10.0, "gravity": -40.0, "life_min": 0.2, "life_max": 0.35, "radial": 0.0, "color": Color("#d6f6ff")})

func _special_split() -> void:
	match _reaction:
		&"vortex":
			var body: Body = _make_body({})
			body.kind = &"vortex"
			body.base_y = body.y
		&"grab":
			var body: Body = _make_body({})
			body.kind = &"grab"
			body.base_y = body.y
		&"rake":
			_slash_age = 0.0
			_split_along_slash(true)
		&"venom":
			fx.ring(_b.x, _b.z, _cell * 0.6, 0.4, VENOM_COLOR)
			fx.puff(_up(_b, 1.0), 4, 0.5)
		&"arcane":
			var lift: float = _arcane_lift()
			var centre: Vector2 = Vector2(_victim_chunks.aspect * 0.5, 0.5)
			_debris(_victim_chunks.all_indices(), centre, _foot(_b) + Vector3(0.0, lift + _victim_at(0.5), 0.0), {"vel": Vector3(0.0, 45.0 * _unit, 0.0), "spread": 60.0, "radial": 7.0, "gravity": 220.0})
			fx.spark_burst(Vector3(_b.x, lift + 8.0 * _unit, _b.z), 16, Vector2.ZERO, 0.0, 1.0, ARCANE_COLOR)
			fx.ring(_b.x, _b.z, _cell * 1.5, 0.5, ARCANE_COLOR)
			fx.ring(_b.x, _b.z, _cell * 0.8, 0.32, Color(0.9, 0.98, 1.0))
			fx.puff(Vector3(_b.x, lift + 4.0 * _unit, _b.z), 8, 1.1)
			_flash = maxf(_flash, 0.7)
			_shake = maxf(_shake, 0.9)
		_:
			_extra.on_split()

## Dragged into the void gate: struggles (heavy only), then spins, shrinks and vanishes.
func _step_vortex(body: Body, dt: float) -> void:
	var total: float = _absorb_duration()
	var heavy: bool = _victim_weight == PieceDef.WeightClass.HEAVY
	var fight: float = clampf(1.0 - body.age / (total * 0.4), 0.0, 1.0) if heavy else 0.0
	var pull: float = clampf((body.age - total * (0.35 if heavy else 0.1)) / (total * (0.65 if heavy else 0.9)), 0.0, 1.0)
	body.scale_mul = maxf(0.02, 1.0 - _ease_in(pull) * 0.92)
	body.rot = _ease_in(pull) * PI * 4.0 * _face + (sin(body.age * 40.0) * 0.12 if fight > 0.0 else 0.0)
	body.y = body.base_y * body.scale_mul
	body.ox = roundf(randf_range(-1.5, 1.5)) * _unit if fight > 0.0 else 0.0
	_set_tint(body.material, VOID_COLOR, 0.7 * clampf(body.age / total, 0.0, 1.0))
	if randf() < 0.5:
		var angle: float = randf() * TAU
		var radius: float = _cell * 0.55
		fx.add_part(Vector3(_b.x + cos(angle) * radius, _unit, _b.z + _stand + sin(angle) * radius), Vector3(-cos(angle) * 20.0, 15.0, -sin(angle) * 20.0) * _unit, VOID_COLOR if randf() < 0.5 else VOID_DEEP, _victim_height / ROWS, randf_range(0.25, 0.4), -20.0 * _unit)
	if body.age >= total:
		body.dead = true
		if is_instance_valid(body.sprite):
			body.sprite.queue_free()
		fx.ring(_b.x, _b.z, _cell * 0.5, 0.3, VOID_COLOR)
		fx.spark_burst(_up(_b, 2.0), 8, Vector2.ZERO, 0.0, 0.35, VOID_COLOR)
		_shake = maxf(_shake, 0.35)

## Hangs from the gryphon's talons, then is dropped from the top of the climb.
func _step_grab(body: Body, dt: float) -> void:
	if _rt < 0.5:
		var carrier: Pose = _compute_pose(_t)
		body.x = carrier.x + (body.pivot.x - _victim_chunks.aspect * 0.5) * _victim_height
		body.z = carrier.z
		body.y = maxf(body.base_y, carrier.y - _victim_at(0.55))
		body.rot = sin(body.age * 14.0) * 0.15 * clampf(body.age / 0.2, 0.0, 1.0)
		return
	if not body.released:
		body.released = true
		body.vy = 10.0 * _unit
		body.vr = 6.0 * _face
	body.vy -= 330.0 * _unit * dt
	body.y += body.vy * dt
	body.rot += body.vr * dt
	if body.y < _proj.height_for_pixels(3.0 * _unit):
		_shatter(body, 1.1)
		fx.ring(body.x, body.z, _cell * 0.9, 0.42)
		fx.puff(Vector3(body.x, 2.0 * _unit, body.z), 12, 1.2)
		fx.crack_decal(body.x, body.z, 5, _cell * 0.7)
		_shake = maxf(_shake, 0.9)

func _set_tint(material: ShaderMaterial, color: Color, amount: float) -> void:
	material.set_shader_parameter(&"tint", color)
	material.set_shader_parameter(&"tint_amount", amount)

# --- special drawing ---

func _ground_disc(canvas: CanvasItem, centre: Vector3, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * index / 24.0
		points.append(_proj.project(Vector3(centre.x + cos(angle) * radius, 0.0, centre.z + sin(angle) * radius)))
	canvas.draw_colored_polygon(points, color)

func _ground_dots(canvas: CanvasItem, centre: Vector3, radius: float, count: int, turn: float, color: Color) -> void:
	for index: int in range(count):
		var angle: float = TAU * index / count + turn
		var dot: Vector2 = _proj.project(Vector3(centre.x + cos(angle) * radius, 0.0, centre.z + sin(angle) * radius))
		canvas.draw_rect(Rect2(dot - Vector2(0.5, 0.5) * _unit, Vector2(_unit, _unit)), color)

func _draw_special_ground(canvas: CanvasItem) -> void:
	var u: float = _t
	var foot: Vector3 = _foot(_b)
	match _attack_id:
		&"catapult":
			if u >= 0.4 and not _impacted:
				var flight: Array = _boulder(u)
				var at: Vector3 = flight[0]
				var q: float = flight[1]
				_ground_disc(canvas, Vector3(at.x, 0.0, at.z + _stand), (2.0 + 4.0 * q) * _unit, Color(0.0, 0.0, 0.0, 0.15 + 0.3 * q))
		&"portal_mage":
			if u < 0.2:
				return
			var radius: float = _cell * 0.58 * _ease_out(clampf((u - 0.2) / 0.5, 0.0, 1.0))
			var total: float = _absorb_duration()
			if _impacted and _rt > total + 0.1:
				radius *= 1.0 - clampf((_rt - total - 0.1) / 0.25, 0.0, 1.0)
			if radius < 0.5 * _unit:
				return
			_ground_disc(canvas, foot, radius + _unit, Color(VOID_DEEP, 0.55))
			_ground_disc(canvas, foot, radius, Color(0.086, 0.024, 0.14, 0.96))
			_ground_dots(canvas, foot, radius, 28, u * 5.0, Color("#d9b8ff"))
			_ground_dots(canvas, foot, radius * 0.6, 18, -u * 7.0, VOID_DEEP)
		&"archmage":
			if u < 0.12:
				return
			var strength: float = clampf((u - 0.12) / 0.25, 0.0, 1.0)
			if _impacted:
				strength *= 1.0 - clampf((_rt - _arcane_duration()) / 0.3, 0.0, 1.0)
			if strength <= 0.0:
				return
			var radius: float = _cell * 0.62 * _ease_out(strength)
			_ground_dots(canvas, foot, radius, 40, u * 2.0, Color(ARCANE_COLOR, strength))
			_ground_dots(canvas, foot, radius * 0.72, 28, -u * 3.0, Color(ARCANE_DEEP, 0.8 * strength))
			for index: int in range(6):
				var angle: float = TAU * index / 6.0 + u * 2.0
				var inner: Vector2 = _proj.project(Vector3(foot.x + cos(angle) * radius * 0.72, 0.0, foot.z + sin(angle) * radius * 0.72))
				var outer: Vector2 = _proj.project(Vector3(foot.x + cos(angle) * radius, 0.0, foot.z + sin(angle) * radius))
				canvas.draw_line(inner, outer, Color(ARCANE_COLOR, strength), maxf(_unit, 1.0))
		&"manticore":
			if not _impacted or _rt < 0.25:
				return
			var melt: float = _melt_duration()
			var radius: float = _cell * 0.52 * _ease_out(clampf((_rt - 0.25) / melt, 0.0, 1.0))
			var fade: float = 1.0 - clampf((_rt - 0.25 - melt - 0.6) / 0.6, 0.0, 1.0)
			if radius > 0.5 * _unit and fade > 0.0:
				_ground_disc(canvas, foot, radius, Color(0.27, 0.55, 0.22, 0.6 * fade))
				_ground_disc(canvas, foot, radius * 0.55, Color(0.55, 0.86, 0.39, 0.35 * fade))

func _screen_dir() -> Vector2:
	var line: Vector2 = _proj.project(_b) - _proj.project(_a)
	return line.normalized() if line.length() > 0.001 else Vector2.RIGHT

func _victim_centre(fraction: float = 0.5) -> Vector2:
	return _proj.project(Vector3(_b.x, _victim_at(fraction), _b.z + _stand))

func _draw_special_air(canvas: CanvasItem) -> void:
	var u: float = _t
	var thin: float = maxf(_unit, 1.0)
	match _attack_id:
		&"bowman":
			if u < 0.08:
				return
			if u < 0.44:
				var hand: Vector2 = _proj.project(Vector3(_a.x, _attacker_at(0.6), _a.z + _stand))
				var pull: float = clampf(u / 0.38, 0.0, 1.0) * 3.0 * _unit
				var along: Vector2 = _screen_dir()
				canvas.draw_line(hand - along * pull, hand + along * (6.0 * _unit - pull), Color("#e8d9b0"), thin)
				return
			if _impacted:
				return
			var q: float = clampf((u - 0.46) / (float(_attack["impact"]) - 0.46), 0.0, 1.0)
			var head: Vector2 = _arrow_at(q)
			var tail: Vector2 = _arrow_at(maxf(0.0, q - 0.1))
			canvas.draw_line(tail, head, Color(1.0, 0.94, 0.78, 0.25), 3.0 * _unit)
			canvas.draw_line(tail, head, Color("#e8d9b0"), thin)
			canvas.draw_rect(Rect2(head - Vector2(0.5, 0.5) * _unit, Vector2(_unit, _unit)), Color.WHITE)
			var across: Vector2 = Vector2(-(head - tail).normalized().y, (head - tail).normalized().x) * _unit
			canvas.draw_rect(Rect2(tail + across - Vector2(0.5, 0.5) * _unit, Vector2(_unit, _unit)), Color("#d0564f"))
			canvas.draw_rect(Rect2(tail - across - Vector2(0.5, 0.5) * _unit, Vector2(_unit, _unit)), Color("#d0564f"))
		&"catapult":
			if u < 0.4 or _impacted:
				return
			var at: Vector3 = _boulder(u)[0]
			var centre: Vector2 = _proj.project(Vector3(at.x, at.y, at.z + _stand))
			canvas.draw_rect(Rect2(centre - Vector2(2.5, 2.5) * _unit, Vector2(5.0, 5.0) * _unit), Color("#3b3a40"))
			canvas.draw_rect(Rect2(centre - Vector2(2.5, 2.5) * _unit, Vector2(4.0, 4.0) * _unit), Color("#7d7b84"))
			canvas.draw_rect(Rect2(centre - Vector2(1.5, 1.5) * _unit, Vector2(2.0, 1.0) * _unit), Color("#a9a7b0"))
		&"lancer":
			if _impacted and _rt > 0.3:
				return
			var along: Vector2 = _screen_dir()
			var lower: float = _smooth(clampf((u - 0.06) / 0.2, 0.0, 1.0))
			var aim: Vector2 = Vector2(lerpf(along.x * 0.35, along.x, lower), lerpf(-0.95, along.y, lower)).normalized()
			var grip: Vector2 = _proj.project(Vector3(_pose.x, _pose.y + _attacker_at(0.5), _pose.z + _stand))
			var tip: Vector2 = grip + aim * 12.0 * _unit
			canvas.draw_line(grip, tip, Color("#d9c79e"), thin)
			canvas.draw_rect(Rect2(tip - Vector2(0.5, 0.5) * _unit, Vector2(_unit, _unit)), Color.WHITE)
		&"unicorn_cavalry":
			if u < 0.3 or _impacted:
				return
			var colors: Array[Color] = [Color("#ffe6f5"), Color("#d8f2ff"), Color("#fff3c4")]
			for index: int in range(3):
				var back: float = randf_range(4.0, 16.0) * _unit
				var spark: Vector2 = _proj.project(Vector3(_pose.x - _dir.x * back, _pose.y + randf_range(4.0, 18.0) * _unit, _pose.z - _dir.y * back + _stand))
				canvas.draw_rect(Rect2(spark - Vector2(0.5, 0.5) * _unit, Vector2(_unit, _unit)), colors[index])
		&"manticore":
			if u < 0.58 or (_impacted and _rt > 0.1):
				return
			var start: Vector2 = _proj.project(Vector3(_pose.x - _dir.x * 4.0 * _unit, _pose.y + _attacker_at(0.95), _pose.z - _dir.y * 4.0 * _unit + _stand))
			var finish: Vector2 = _victim_centre(0.55)
			var bend: Vector2 = Vector2((start.x + finish.x) * 0.5, minf(start.y, finish.y) - 10.0 * _unit)
			var reach: float = clampf((u - 0.6) / 0.04, 0.0, 1.0)
			var points: PackedVector2Array = PackedVector2Array([start])
			for index: int in range(1, int(16.0 * reach) + 1):
				var s: float = index / 16.0
				points.append(start * (1.0 - s) * (1.0 - s) + bend * 2.0 * (1.0 - s) * s + finish * s * s)
			if points.size() >= 2:
				canvas.draw_polyline(points, Color("#9be36a"), thin)
		&"archmage":
			# A beam from the staff: it shoots out, holds while the victim lifts, then fades.
			if u < 0.58:
				return
			var fade: float = 1.0 - clampf((_rt - 0.25) / 0.3, 0.0, 1.0) if _impacted else 1.0
			if fade <= 0.0:
				return
			var q: float = _ease_in(clampf((u - 0.6) / 0.16, 0.0, 1.0))
			var staff: Vector2 = _proj.project(Vector3(_pose.x + _face * 5.0 * _unit, _pose.y + _attacker_at(1.0), _pose.z + _stand))
			var tip: Vector2 = staff.lerp(_victim_centre(), q)
			var flicker: float = 0.85 + 0.15 * sin(u * 70.0)
			canvas.draw_line(staff, tip, Color(0.47, 0.78, 1.0, 0.28 * fade), 9.0 * _unit)
			canvas.draw_line(staff, tip, Color(ARCANE_COLOR, 0.75 * fade * flicker), 4.0 * _unit)
			canvas.draw_line(staff, tip, Color(0.92, 0.99, 1.0, fade), 1.6 * _unit)
			canvas.draw_circle(staff, 3.5 * _unit, Color(0.92, 0.99, 1.0, 0.8 * fade))
			canvas.draw_circle(tip, 5.0 * _unit * (0.6 + 0.4 * flicker), Color(0.47, 0.78, 1.0, 0.45 * fade))
		&"portal_mage":
			if u > 0.1 and u < 0.75:
				var hand: Vector2 = _proj.project(Vector3(_pose.x, _pose.y + _attacker_at(0.85), _pose.z + _stand))
				canvas.draw_rect(Rect2(hand + Vector2(4.0, -2.0) * _unit, Vector2(2.0, 2.0) * _unit), Color(0.85, 0.72, 1.0, 0.6 + 0.4 * sin(u * 50.0)))

func _arrow_at(q: float) -> Vector2:
	var height: float = lerpf(_attacker_at(0.6), _victim_at(0.5), q) + _cell * 0.7 * 4.0 * q * (1.0 - q)
	return _proj.project(Vector3(lerpf(_a.x, _b.x, q), height, lerpf(_a.z, _b.z, q) + _stand))

# --- helpers ------------------------------------------------------------------

## `point` lifted by `height` design units.
func _up(point: Vector3, height: float) -> Vector3:
	return Vector3(point.x, height * _unit, point.z)

## `point` moved `distance` world units along the attack direction.
func _along(point: Vector3, distance: float) -> Vector3:
	return Vector3(point.x + _dir.x * distance, point.y, point.z + _dir.y * distance)

## Where a sprite standing on `point` puts its feet.
func _foot(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z + _stand)

func _on_board(point: Vector3) -> bool:
	var half: float = _proj.board_size * _cell * 0.5
	return absf(point.x) < half and absf(point.z) < half

static func _smooth(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)

static func _ease_out(u: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u)

static func _ease_in(u: float) -> float:
	return u * u
