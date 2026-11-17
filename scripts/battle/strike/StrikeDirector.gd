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

enum Phase { IDLE, PLAYING, AFTERGLOW }

const PIECE_SHADER: Shader = preload("res://assets/shaders/strike_piece.gdshader")
const GHOST_SHADER: Shader = preload("res://assets/shaders/strike_ghost.gdshader")
const ROWS := PieceChunks.ROWS
const GOLD := Color(1.0, 0.886, 0.588)
const AMBER := Color(0.878, 0.706, 0.361)
const MAX_GHOSTS := 12

## impact: when the hit lands. done: when the attacker has settled on its square.
## end: hard cap. All in seconds at 1x speed.
const ATTACKS := {
	&"knight": {"impact": 0.84, "done": 1.1, "end": 2.6, "hitstop": 0.1, "shake": 1.35},
	&"bishop": {"impact": 0.36, "done": 1.14, "end": 2.2, "hitstop": 0.12, "shake": 0.8},
	&"rook": {"impact": 0.56, "done": 0.96, "end": 2.3, "hitstop": 0.1, "shake": 1.5},
	&"pawn": {"impact": 0.38, "done": 0.74, "end": 2.1, "hitstop": 0.07, "shake": 0.55},
	&"queen": {"impact": 0.62, "done": 1.49, "end": 2.4, "hitstop": 0.12, "shake": 0.9},
	&"king": {"impact": 0.72, "done": 2.0, "end": 2.7, "hitstop": 0.13, "shake": 1.4},
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

var fx: StrikeFx = StrikeFx.new()

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
var _speed: float = 1.0
var _to_square: Vector2i = Vector2i(-1, -1)

var _cell: float = 36.0
var _unit: float = 2.0
var _stand: float = 0.0
var _a: Vector3 = Vector3.ZERO
var _b: Vector3 = Vector3.ZERO
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

func setup(view: BattleBoardView) -> void:
	_view = view
	view.ground_canvas().draw.connect(_draw_ground)
	view.air_canvas().draw.connect(_draw_air)

static func can_play(attacker_id: StringName, strike_type: int) -> bool:
	return strike_type != PieceDef.StrikeType.NONE and ATTACKS.has(attacker_id)

func is_playing() -> bool:
	return _phase == Phase.PLAYING

## Starts a strike. The board is expected to already hold the post-capture position.
func play(attacker_id: StringName, attacker_texture: Texture2D, victim_texture: Texture2D, from: Vector2i, to: Vector2i, strike_type: int, attacker_weight: int, victim_weight: int, speed: float) -> void:
	_clear_actors()
	_reset_camera()
	_proj = _view.projection
	_cell = _proj.cell
	_unit = _cell / 18.0
	_stand = _view.standing_offset()
	fx.projection = _proj
	fx.unit = _unit
	_attack_id = attacker_id
	_attack = ATTACKS[attacker_id]
	_strike_type = strike_type
	_speed = maxf(speed, 0.1)
	_to_square = to
	_attacker_texture = attacker_texture
	_victim_texture = victim_texture
	_power = 1.0 if attacker_weight >= victim_weight else 0.45
	_reaction = reaction_for(strike_type, attacker_weight, victim_weight)
	_underdog = _reaction == &"underdog"

	_a = _proj.square_world(from)
	_b = _proj.square_world(to)
	_dir = Vector2(_b.x - _a.x, _b.z - _a.z).normalized()
	var screen_a: Vector2 = _proj.project(_a)
	var screen_b: Vector2 = _proj.project(_b)
	_face = 1.0 if absf(screen_b.x - screen_a.x) < 2.0 * _unit else signf(screen_b.x - screen_a.x)
	var delta: Vector2i = to - from
	_corner = _proj.square_world(Vector2i(from.x, to.y) if absi(delta.y) >= absi(delta.x) else Vector2i(to.x, from.y))
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
	_events = _build_events()
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
	_holder.add_child(_attacker)

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
	var scaled: float = dt * _speed
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
		_on_impact()
	if _impacted:
		_rt += scaled
		_reaction_tick()
		if not _split and _rt >= _split_time():
			_split = true
			_victim.visible = false
			_on_split()
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
	return []

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
	return o

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
	o.at(recoil.lerp(_b, _smooth(q)))
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
	var crush: bool = _strike_type == PieceDef.StrikeType.CRUSH
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
		fx.add_part(position, speed, _victim_chunks.colors[index], chunk * (1.7 if randf() < 0.25 else 1.0), randf_range(life_min, life_max), gravity)

# --- rendering ----------------------------------------------------------------

func _render() -> void:
	_pose = _compute_pose(_t)
	_place_pose(_attacker, _pose, true)
	_attacker_material.set_shader_parameter(&"flash", _pose.white)
	var trail_limit: int = MAX_GHOSTS if _attack_id == &"bishop" else 7
	if _pose.trail and _hs <= 0.0:
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
	_victim.position = position + Vector2(jitter * _unit, 0.0)
	_victim.scale = Vector2(scale_value, scale_value) * stretch

func _place_body(body: Body) -> void:
	var ground: Vector3 = Vector3(body.x, 0.0, body.z + _stand)
	var scale_value: float = float(body.sprite.get_meta("base_scale", 1.0)) * _proj.scale_at(ground)
	var jitter: float = float(randi_range(-1, 1)) * _unit if body.jitter and _rt < body.shatter_at else 0.0
	body.sprite.position = _proj.project(Vector3(ground.x, body.y, ground.z)) + Vector2(body.ox + jitter, body.oy)
	body.sprite.scale = Vector2(scale_value, scale_value)
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
	if _proj == null:
		return
	var canvas: Node2D = _view.ground_canvas()
	fx.draw_ground(canvas)
	if _phase != Phase.PLAYING:
		return
	_draw_shadow(canvas, _pose.x, _pose.z, _pose.y, 1.0)
	if not _split:
		_draw_shadow(canvas, _b.x, _b.z, 0.0, 1.0)
	for body: Body in _bodies:
		if body.y > _proj.height_for_pixels(2.0 * _unit):
			_draw_shadow(canvas, body.x + body.ox, body.z, body.y, 0.75)

func _draw_shadow(canvas: CanvasItem, x: float, z: float, height: float, size: float) -> void:
	var shrink: float = maxf(0.35, 1.0 - height / (45.0 * _unit))
	var radius: float = _cell * 0.33 * size * shrink
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(16):
		var angle: float = TAU * index / 16.0
		points.append(_proj.project(Vector3(x + cos(angle) * radius, 0.0, z + sin(angle) * radius)))
	canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.36 * shrink))

func _draw_air() -> void:
	if _proj == null:
		return
	var canvas: Node2D = _view.air_canvas()
	fx.draw_air(canvas)
	if _phase == Phase.PLAYING:
		match _attack_id:
			&"queen": _draw_lance(canvas)
			&"king": _draw_judgment(canvas)
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
