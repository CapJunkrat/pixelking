class_name StrikeDirector
extends Node

## Plays a capture as a short strike animation on the 2.5D board. Presentation only.
##
## The attack belongs to the attacking piece, the reaction belongs to the victim, and
## the two meet at the moment of impact. Which reaction plays is decided by the
## attacker's strike type and the two pieces' weight classes (StrikeLibrary.reaction_for)
## unless the victim always plays its own.
##
## The director runs the strike: the clock and hit-stop, the impact and split moments,
## the attacker and victim sprites, ghost trails, body physics, the camera and the
## drawing passes. What each attack and reaction does is in its own class under
## attacks/ and reactions/ (StrikeLibrary lists them); they share this strike's state
## through `stage`. Timings follow docs/prototypes/strike_lab.html; lengths there are in
## "design units" (1/18 of a cell) and are scaled by `stage.unit`.

signal finished
## The blow lands (after the wind-up, before the hit-stop).
signal impacted
## The victim breaks apart (for the Powder Keg: the moment it explodes).
signal victim_split

enum Phase { IDLE, PLAYING, AFTERGLOW }

const GHOST_SHADER: Shader = preload("res://assets/shaders/strike_ghost.gdshader")
const MAX_GHOSTS := 12
const BOUNCE_SECONDS := 0.38

## Everything this strike shares with its attack and reaction.
var stage: StrikeStage = StrikeStage.new()
## Extra slow motion on top of the playback speed (1 = normal).
var time_scale: float = 1.0

var fx: StrikeFx:
	get:
		return stage.fx
## Where the victim's egg is laid (Ember Bird / Flame Phoenix), set before play().
var egg_square: Vector2i:
	get:
		return stage.egg_square
	set(value):
		stage.egg_square = value
## The captured piece drawn in the attacker's colours (Thousand Faces wears it briefly).
var mimic_texture: Texture2D:
	get:
		return stage.mimic_texture
	set(value):
		stage.mimic_texture = value
## Plays only the victim's side of a strike (an extra victim of the same blow, such
## as every enemy a boomerang passes through): no attacker, no camera, no attack art.
var victim_only: bool:
	get:
		return stage.victim_only
	set(value):
		stage.victim_only = value
## A returning strike may lose its attacker to a death effect before it can return.
var returning_attacker_alive: bool:
	get:
		return stage.returning_attacker_alive
	set(value):
		stage.returning_attacker_alive = value

var _phase: Phase = Phase.IDLE
var _canvas_clean: bool = true
var _attack: StrikeAttack = null
var _reaction: StrikeReaction = null
var _events: Array = []
var _events_fired: int = 0
var _holder: Node2D = null
var _ghosts: Array[Sprite2D] = []
var _trail: Array[StrikePose] = []
## The victim survives (a shell absorbed the blow): the attacker springs back to its
## own square right after the hit instead of standing on the victim.
var _bounce: bool = false
var _contact: Vector3 = Vector3.ZERO

func setup(view: BattleBoardView) -> void:
	stage.view = view
	stage.pose_at = compute_pose
	view.ground_canvas().draw.connect(_draw_ground)
	view.air_canvas().draw.connect(_draw_air)

static func can_play(attacker_id: StringName, strike_type: int) -> bool:
	return strike_type != PieceDef.StrikeType.NONE and StrikeLibrary.has_attack(attacker_id)

## Which attack plays for this move: [attack id, strike type] (StrikeLibrary.resolve_attack).
static func resolve_attack(attacker_id: StringName, strike_type: int, from: Vector2i, to: Vector2i) -> Array:
	return StrikeLibrary.resolve_attack(attacker_id, strike_type, from, to)

static func reaction_for(strike_type: int, attacker_weight: int, victim_weight: int) -> StringName:
	return StrikeLibrary.reaction_for(strike_type, attacker_weight, victim_weight)

func is_playing() -> bool:
	return _phase == Phase.PLAYING

## Starts a strike. `victim_square` differs from `to` only for en passant.
## The board is expected to already hold the post-capture position.
## `corner_square` is the turning square of a bent move (gryphon, manticore), if known.
## `victim_id` lets pieces with their own capture reaction (Powder Keg, Gargoyle...) play it.
func play(attacker_id: StringName, attacker_texture: Texture2D, victim_texture: Texture2D, from: Vector2i, to: Vector2i, strike_type: int, attacker_weight: int, victim_weight: int, speed: float, victim_square: Vector2i = Vector2i(-1, -1), corner_square: Vector2i = Vector2i(-1, -1), victim_id: StringName = &"") -> void:
	_clear_actors()
	_reset_camera()
	var s: StrikeStage = stage
	s.proj = s.view.projection
	s.cell = s.proj.cell
	s.unit = s.cell / 18.0
	s.stand = s.view.standing_offset()
	s.fx.projection = s.proj
	s.fx.unit = s.unit
	s.attack_id = attacker_id
	_attack = StrikeLibrary.make_attack(attacker_id)
	_attack.s = s
	s.attack_obj = _attack
	s.attack = _attack.timing()
	s.reset_strike()
	s.strike_type = strike_type
	s.play_speed = maxf(speed, 0.1)
	s.to_square = to
	s.attacker_texture = attacker_texture
	s.victim_texture = victim_texture
	s.power = 1.0 if attacker_weight >= victim_weight else 0.45
	s.victim_weight = clampi(victim_weight, 0, 2)
	s.reaction = StrikeLibrary.reaction_for(strike_type, attacker_weight, victim_weight)
	var own_reaction: StringName = StrikeLibrary.victim_reaction(victim_id)
	if not own_reaction.is_empty():
		s.reaction = own_reaction
	if s.victim_only and s.reaction == &"underdog":
		# An extra victim reacts at the main blow's moment: no slow struggle.
		s.reaction = &"blunt_crack"
	_reaction = StrikeLibrary.make_reaction(s.reaction)
	_reaction.s = s
	s.reaction_obj = _reaction
	s.underdog = s.reaction == &"underdog"

	s.a = s.proj.square_world(from)
	# The strike aims at the victim; the attacker then settles on its destination.
	s.dest = s.proj.square_world(to)
	s.b = s.proj.square_world(victim_square if victim_square.x >= 0 else to)
	s.dir = Vector2(s.b.x - s.a.x, s.b.z - s.a.z).normalized()
	var screen_a: Vector2 = s.proj.project(s.a)
	var screen_b: Vector2 = s.proj.project(s.b)
	s.face = 1.0 if absf(screen_b.x - screen_a.x) < 2.0 * s.unit else signf(screen_b.x - screen_a.x)
	var delta: Vector2i = to - from
	s.corner = s.proj.square_world(Vector2i(from.x, to.y) if absi(delta.y) >= absi(delta.x) else Vector2i(to.x, from.y))
	var own_corner: Variant = _attack.corner(from, to)
	if corner_square.x >= 0:
		s.corner = s.proj.square_world(corner_square)
	elif own_corner != null:
		s.corner = own_corner
	var line: Vector2 = (screen_b - screen_a).normalized()
	if absf(line.y) < 0.42:
		line.y = (-1.0 if line.y <= 0.0 else 1.0) * 0.42
	if absf(line.x) < 0.42:
		line.x = (-1.0 if line.x < 0.0 else 1.0) * 0.42
	s.slash_angle = atan2(line.y, line.x)

	s.impact_time = 1.2 if s.underdog else float(s.attack["impact"])
	s.settle_time = s.impact_time + (0.75 if s.underdog else 0.14)
	s.done_time = _attack.done_time()
	s.end_time = s.impact_time + 2.0 if s.underdog else float(s.attack["end"])
	if _attack.adjust_timing():
		s.end_time = maxf(s.end_time, s.done_time + 0.8)
	_bounce = _reaction.survives() and _attack.keeps_bounce()
	if _bounce:
		s.end_time = minf(s.end_time, s.impact_time + BOUNCE_SECONDS + 0.45)
	s.t = 0.0
	s.hs = 0.0
	s.rt = -1.0
	s.impacted = false
	s.split = false
	s.shake = 0.0
	s.punch = 0.0
	s.flash = 0.0
	s.slash_age = -1.0
	s.wobble_time = -9.0
	s.rows_broken = 0
	s.brick_out = false
	_events_fired = 0

	s.victim_chunks = PieceChunks.of(victim_texture)
	s.jag_seed = randf() * 20.0
	s.plane_origin = Vector2(s.victim_chunks.aspect * 0.5, 0.55)
	var brick_width: float = 5.0 / PieceChunks.ROWS
	s.brick = Rect2(s.victim_chunks.aspect - brick_width if s.face > 0.0 else 0.0, 0.625, brick_width, 0.25)

	var layer: Node2D = s.view.piece_layer()
	s.victim = s.view.make_piece_sprite(victim_texture)
	s.victim_material = s.piece_material(s.victim_chunks)
	s.victim.material = s.victim_material
	s.victim_height = s.victim_chunks.used.size.y * float(s.victim.get_meta("base_scale", 1.0))
	layer.add_child(s.victim)
	s.set_tint(s.victim_material, Color.WHITE, 0.0)

	_holder = Node2D.new()
	layer.add_child(_holder)
	for _index: int in range(MAX_GHOSTS):
		var ghost: Sprite2D = s.view.make_piece_sprite(attacker_texture)
		var ghost_material: ShaderMaterial = ShaderMaterial.new()
		ghost_material.shader = GHOST_SHADER
		ghost.material = ghost_material
		ghost.visible = false
		_holder.add_child(ghost)
		_ghosts.append(ghost)
	s.attacker = s.view.make_piece_sprite(attacker_texture)
	s.attacker_material = s.piece_material(PieceChunks.of(attacker_texture))
	s.attacker.material = s.attacker_material
	s.attacker_height = PieceChunks.of(attacker_texture).used.size.y * float(s.attacker.get_meta("base_scale", 1.0))
	_holder.add_child(s.attacker)
	# Built last: some events aim at heights that need both sprites measured.
	_events = _attack.events()
	if s.victim_only:
		_holder.visible = false
		_events = []

	_phase = Phase.PLAYING
	_render()

## Lands this (victim-only) strike at the same moment as `main`.
func align_impact(main: StrikeDirector) -> void:
	stage.impact_time = main.stage.impact_time
	stage.settle_time = stage.impact_time + 0.14
	stage.done_time = maxf(stage.done_time, stage.impact_time + 0.5)
	stage.end_time = maxf(stage.end_time, stage.impact_time + 2.0)

## Stops immediately and removes every trace, including lingering debris.
func stop() -> void:
	_clear_actors()
	stage.fx.clear()
	_reset_camera()
	_phase = Phase.IDLE
	_redraw()

# --- frame loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	if stage.view == null:
		return
	var dt: float = minf(delta, 0.05)
	match _phase:
		Phase.PLAYING:
			_step(dt)
			if _phase == Phase.PLAYING:
				_render()
		Phase.AFTERGLOW:
			var scaled: float = dt * stage.play_speed
			stage.rt += scaled
			stage.fx.step(scaled)
			_decay(dt)
			_apply_camera()
			if stage.rt > 1.2 and stage.shake <= 0.0 and stage.punch <= 0.0:
				_reset_camera()
				_phase = Phase.IDLE
		Phase.IDLE:
			if stage.fx.is_empty():
				if not _canvas_clean:
					_redraw()
					_canvas_clean = true
				return
			stage.fx.step(dt * stage.play_speed)
	_redraw()

func _redraw() -> void:
	_canvas_clean = false
	stage.view.ground_canvas().queue_redraw()
	stage.view.air_canvas().queue_redraw()

func _step(dt: float) -> void:
	var s: StrikeStage = stage
	var scaled: float = dt * s.play_speed * time_scale
	if s.hs > 0.0:
		s.hs -= scaled
	else:
		s.t += scaled
	while _events_fired < _events.size() and s.t >= float(_events[_events_fired][0]):
		var event: Callable = _events[_events_fired][1]
		_events_fired += 1
		event.call()
	if not s.impacted and s.t >= s.impact_time:
		s.impacted = true
		s.t = s.impact_time
		s.rt = 0.0
		s.hs = float(s.attack["hitstop"])
		s.shake = float(s.attack["shake"])
		s.punch = 1.0
		s.flash = 1.0
		_contact = Vector3(s.pose.x, s.pose.y, s.pose.z)
		# A shooter never left its square: nothing to spring back from.
		if _bounce and Vector2(_contact.x - s.a.x, _contact.z - s.a.z).length() < s.cell * 0.3:
			_bounce = false
		_on_impact()
		impacted.emit()
	if s.impacted:
		s.rt += scaled
		if not s.split:
			_reaction.tick()
		if not s.split and s.rt >= _reaction.split_time():
			s.split = true
			s.victim.visible = false
			_reaction.on_split()
			victim_split.emit()
	if s.hs <= 0.0:
		_physics(scaled)
	_decay(dt)
	if (s.t >= s.done_time and s.split and s.bodies.is_empty()) or s.t >= s.end_time:
		_complete()

func _decay(dt: float) -> void:
	var rate: float = maxf(stage.play_speed, 0.3)
	stage.shake = maxf(0.0, stage.shake - dt * 3.0 * rate)
	stage.punch = maxf(0.0, stage.punch - dt * 3.5 * rate)
	stage.flash = maxf(0.0, stage.flash - dt * 9.0 * rate)

func _complete() -> void:
	_clear_actors()
	_phase = Phase.AFTERGLOW
	if stage.rt < 0.0:
		stage.rt = 2.0
	finished.emit()

func _clear_actors() -> void:
	for body: StrikeBody in stage.bodies:
		if is_instance_valid(body.sprite):
			body.sprite.queue_free()
	stage.bodies.clear()
	_trail.clear()
	_ghosts.clear()
	if is_instance_valid(_holder):
		_holder.queue_free()
	if is_instance_valid(stage.victim):
		stage.victim.queue_free()
	_holder = null
	stage.attacker = null
	stage.victim = null
	if _attack != null:
		_attack.clear()
	stage.slash_age = -1.0

func _physics(dt: float) -> void:
	var s: StrikeStage = stage
	for body: StrikeBody in s.bodies:
		if body.dead:
			continue
		body.age += dt
		match body.kind:
			&"tip":
				s.step_tip(body, dt)
			&"low_fly":
				s.step_low_fly(body, dt)
			&"slash_upper":
				s.step_slash_upper(body)
			&"slash_lower":
				s.step_slash_lower(body)
			_:
				if not _reaction.step_body(body, dt):
					s.step_free(body, dt)
	s.bodies = s.bodies.filter(func(body: StrikeBody) -> bool: return not body.dead)
	s.fx.step(dt)
	if s.slash_age >= 0.0:
		s.slash_age += dt
		if s.slash_age > 0.5:
			s.slash_age = -1.0

# --- attacker -----------------------------------------------------------------

## The attacker's pose at time `u` of the strike.
func compute_pose(u: float) -> StrikePose:
	var o: StrikePose = StrikePose.new()
	o.at(stage.a)
	if u < 0.0:
		return o
	_attack.pose(u, o)
	if _bounce and stage.impacted and u >= stage.impact_time:
		_bounce_pose(u, o)
	return o

## Knocked back off a shell: from the point of contact back home with a small hop.
func _bounce_pose(u: float, o: StrikePose) -> void:
	var q: float = clampf((u - stage.impact_time) / BOUNCE_SECONDS, 0.0, 1.0)
	var sv: float = q * q * (3.0 - 2.0 * q)
	o.x = lerpf(_contact.x, stage.a.x, sv)
	o.z = lerpf(_contact.z, stage.a.z, sv)
	o.y = lerpf(_contact.y, 0.0, sv) + sin(q * PI) * stage.cell * 0.45
	o.rot = -0.3 * stage.face * sin(q * PI)
	o.sx = 1.0
	o.sy = 1.0
	o.trail = false
	o.white = 0.0

func _on_impact() -> void:
	# Bring the two actors in front of the dimmed bystanders. A crush lands on top of
	# the victim; every other strike reads better with the victim in front.
	var crush: bool = stage.strike_type == PieceDef.StrikeType.CRUSH or stage.strike_type == PieceDef.StrikeType.GRAB
	_holder.z_index = 2 if crush else 1
	stage.victim.z_index = 1 if crush else 2
	_attack.impact()

# --- rendering ----------------------------------------------------------------

func _render() -> void:
	var s: StrikeStage = stage
	s.pose = compute_pose(s.t)
	_place_pose(s.attacker, s.pose, true)
	s.attacker_material.set_shader_parameter(&"flash", s.pose.white)
	s.attacker_material.set_shader_parameter(&"alpha", 0.0 if s.attacker_gone else s.pose.alpha)
	var trail_limit: int = _attack.trail_limit()
	if s.pose.trail and s.hs <= 0.0 and not s.attacker_gone:
		_trail.append(s.pose)
		if _trail.size() > trail_limit:
			_trail.pop_front()
	elif not s.pose.trail and not _trail.is_empty():
		_trail.pop_front()
	var alpha_step: float = _attack.ghost_alpha_step()
	for index: int in range(_ghosts.size()):
		var ghost: Sprite2D = _ghosts[index]
		ghost.visible = index < _trail.size()
		if ghost.visible:
			_place_pose(ghost, _trail[index], false)
			(ghost.material as ShaderMaterial).set_shader_parameter(&"alpha", 0.06 + index * alpha_step)
	if not s.split:
		_update_victim()
	for body: StrikeBody in s.bodies:
		s.place_body(body)
	_apply_camera()

func _place_pose(sprite: Sprite2D, pose: StrikePose, move_holder: bool) -> void:
	var s: StrikeStage = stage
	var ground: Vector3 = Vector3(pose.x, 0.0, pose.z + s.stand)
	var scale_value: float = float(sprite.get_meta("base_scale", 1.0)) * s.proj.scale_at(ground)
	if move_holder:
		_holder.position = s.proj.project(ground)
	sprite.position = s.proj.project(Vector3(ground.x, pose.y, ground.z)) - _holder.position
	sprite.scale = Vector2(scale_value * pose.sx, scale_value * pose.sy)
	sprite.rotation = pose.rot

func _update_victim() -> void:
	var s: StrikeStage = stage
	var ground: Vector3 = s.foot(s.b)
	var scale_value: float = float(s.victim.get_meta("base_scale", 1.0)) * s.proj.scale_at(ground)
	var look: StrikeLook = StrikeLook.new()
	look.position = s.proj.project(ground)
	s.victim_material.set_shader_parameter(&"flash", 1.0 if s.impacted and s.rt < 0.07 else 0.0)
	if not s.impacted:
		if s.t - s.wobble_time < 0.28:
			look.jitter = roundf(sin((s.t - s.wobble_time) * 70.0) * 1.5)
	else:
		look.jitter = float(randi_range(-1, 1))
		_reaction.look(s.victim_material, look)
		if look.rotation != null:
			s.victim.rotation = float(look.rotation)
	s.victim.position = look.position + Vector2(look.jitter * s.unit, 0.0)
	s.victim.scale = Vector2(scale_value, scale_value) * look.stretch

func _focus() -> float:
	if not stage.impacted:
		return 0.0
	var rise: float = minf(1.0, stage.rt / 0.08)
	return rise * (1.0 if stage.rt < 0.8 else maxf(0.0, 1.0 - (stage.rt - 0.8) / 0.35))

## Zoom punch and shake around the impact point, and dimming of the bystanders.
func _apply_camera() -> void:
	if stage.victim_only:
		return
	var s: StrikeStage = stage
	var focus: float = _focus()
	var strength: float = s.shake * s.shake * 3.4 * s.unit
	var offset: Vector2 = Vector2(roundf(randf_range(-1.0, 1.0) * strength), roundf(randf_range(-1.0, 1.0) * strength))
	var zoom: float = 1.0 + 0.1 * s.smooth(focus) + 0.07 * s.punch
	var impact_point: Vector2 = s.proj.project(Vector3(s.b.x, 8.0 * s.unit, s.b.z))
	s.view.set_camera(Transform2D(0.0, Vector2(zoom, zoom), 0.0, impact_point * (1.0 - zoom) + offset))
	_dim_bystanders(1.0 - 0.62 * focus)

func _reset_camera() -> void:
	if stage.view == null or stage.victim_only:
		return
	stage.view.set_camera(Transform2D.IDENTITY)
	_dim_bystanders(1.0)

func _dim_bystanders(alpha: float) -> void:
	var sprites: Dictionary = stage.view.standing_sprites()
	for square: Variant in sprites:
		var sprite: Sprite2D = sprites[square] as Sprite2D
		if is_instance_valid(sprite):
			sprite.self_modulate.a = 1.0 if square == stage.to_square else alpha

func _draw_ground() -> void:
	var s: StrikeStage = stage
	if s.fx.projection == null:
		return
	var canvas: Node2D = s.view.ground_canvas()
	s.fx.draw_ground(canvas)
	if _phase != Phase.PLAYING:
		return
	if not s.victim_only:
		_attack.draw_ground(canvas)
	if s.pose.alpha > 0.05 and not s.victim_only:
		_draw_shadow(canvas, s.pose.x, s.pose.z, s.pose.y, 1.0, s.pose.alpha)
	if not s.split:
		_draw_shadow(canvas, s.b.x, s.b.z, 0.0, 1.0)
	for body: StrikeBody in s.bodies:
		if body.y > s.proj.height_for_pixels(2.0 * s.unit):
			_draw_shadow(canvas, body.x + body.ox, body.z, body.y, 0.75)

func _draw_shadow(canvas: CanvasItem, x: float, z: float, height: float, size: float, alpha: float = 1.0) -> void:
	var s: StrikeStage = stage
	var shrink: float = maxf(0.35, 1.0 - height / (45.0 * s.unit))
	var radius: float = s.cell * 0.33 * size * shrink
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(16):
		var angle: float = TAU * index / 16.0
		points.append(s.proj.project(Vector3(x + cos(angle) * radius, 0.0, z + sin(angle) * radius)))
	canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.36 * shrink * alpha))

func _draw_air() -> void:
	var s: StrikeStage = stage
	if s.fx.projection == null:
		return
	var canvas: Node2D = s.view.air_canvas()
	s.fx.draw_air(canvas)
	if _phase == Phase.PLAYING and s.victim_only:
		_reaction.draw_air(canvas)
	elif _phase == Phase.PLAYING:
		_attack.draw_air(canvas)
		_reaction.draw_air(canvas)
		if s.slash_age >= 0.0:
			_draw_slash(canvas)
		if s.pose.dizzy:
			_draw_dizzy(canvas)
	if s.flash > 0.0 and _phase != Phase.IDLE:
		var impact_point: Vector2 = s.proj.project(Vector3(s.b.x, 8.0 * s.unit, s.b.z))
		canvas.draw_circle(impact_point, ((1.0 - s.flash) * 18.0 + 4.0) * s.unit, Color(1.0, 0.98, 0.9, s.flash * 0.9))
		canvas.draw_rect(Rect2(Vector2(-2000.0, -2000.0), Vector2(5000.0, 5000.0)), Color(1.0, 1.0, 1.0, s.flash * 0.16))

func _draw_slash(canvas: CanvasItem) -> void:
	var s: StrikeStage = stage
	var progress: float = s.slash_age / 0.5
	var centre: Vector2 = s.proj.project(Vector3(s.b.x, s.proj.height_for_pixels(s.victim_height * 0.45), s.b.z + s.stand))
	var reach: Vector2 = Vector2(cos(s.slash_angle), sin(s.slash_angle)) * 28.0 * s.unit * minf(1.0, s.slash_age / 0.06)
	canvas.draw_line(centre - reach, centre + reach, Color(1.0, 1.0, 1.0, (1.0 - progress) * 0.35), (5.0 * (1.0 - progress) + 1.0) * s.unit)
	canvas.draw_line(centre - reach, centre + reach, Color(1.0, 1.0, 1.0, 1.0 - progress), maxf(s.unit, 1.0))

func _draw_dizzy(canvas: CanvasItem) -> void:
	var s: StrikeStage = stage
	var head: Vector2 = s.proj.project(Vector3(s.pose.x, s.proj.height_for_pixels(14.0 * s.unit), s.pose.z + s.stand))
	for index: int in range(3):
		var angle: float = s.t * 7.0 + index * 2.1
		var star: Vector2 = head + Vector2(cos(angle) * 6.0, sin(angle) * 2.0) * s.unit
		var color: Color = Color("#fff3b0") if index % 2 == 1 else Color("#e0b45c")
		canvas.draw_rect(Rect2(star - Vector2(0.5, 1.5) * s.unit, Vector2(1.0, 3.0) * s.unit), color)
		canvas.draw_rect(Rect2(star - Vector2(1.5, 0.5) * s.unit, Vector2(3.0, 1.0) * s.unit), color)
