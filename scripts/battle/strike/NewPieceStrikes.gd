class_name NewPieceStrikes
extends RefCounted

## Strike animations of the pieces from plan §27, ported from
## docs/prototypes/new_pieces_src (new_block*.js). StrikeDirector owns the timeline,
## sprites, bodies and effects; this class supplies what is specific to the new pieces:
## attacker poses, projectiles and overlays, impact effects, and the new victim
## reactions (including the reactions some pieces always play when they are captured).
## Conventions follow StrikeDirector: `u` is seconds since the strike started, plain
## numbers are design units scaled by `d._unit`, sprite heights are given in the
## prototype's 12-row pixels and converted with _ah()/_vh().

const ORANGE := Color(1.0, 0.59, 0.24)
const WATER := Color(0.47, 0.75, 1.0)
const FOAM := Color(0.9, 0.965, 1.0)
const GOLDEN := Color(1.0, 0.886, 0.588)
const MOON := Color(0.63, 0.78, 1.0)
const VIOLET := Color(0.78, 0.63, 1.0)
const SOUND := Color(0.745, 0.667, 1.0)
const STONE := Color(0.745, 0.737, 0.769)
const HOLY_WHITE := Color(1.0, 0.965, 0.847)
const ASH: Array[Color] = [Color("#3a3540"), Color("#5d5862"), Color("#2a262e")]
const FIRE: Array[Color] = [Color("#fff0b0"), Color("#ffd27a"), Color("#ff8a3c"), Color("#ff5a2a")]
const GLASS: Array[Color] = [Color("#bff3ff"), Color("#e6c8ff"), Color("#fff3c4"), Color("#c8ffd9"), Color.WHITE]

## impact / done / end in seconds at 1x speed, like StrikeDirector.ATTACKS. Entries for
## the Ember Bird and Thousand Faces are adjusted per victim in dynamic_timing().
const ATTACKS := {
	&"swift_courier": {"impact": 0.44, "done": 1.05, "end": 2.0, "hitstop": 0.11, "shake": 0.6},
	&"tide_knight": {"impact": 0.62, "done": 1.25, "end": 2.3, "hitstop": 0.12, "shake": 1.2},
	&"echo": {"impact": 0.72, "done": 2.05, "end": 2.6, "hitstop": 0.06, "shake": 0.5},
	&"chameleon": {"impact": 0.5, "done": 1.95, "end": 2.6, "hitstop": 0.08, "shake": 0.4},
	&"sentry": {"impact": 0.44, "done": 0.95, "end": 2.0, "hitstop": 0.1, "shake": 0.8},
	&"falconer": {"impact": 0.62, "done": 1.25, "end": 2.0, "hitstop": 0.08, "shake": 0.45},
	&"vanguard": {"impact": 0.4, "done": 0.9, "end": 1.9, "hitstop": 0.08, "shake": 0.55},
	&"squire": {"impact": 0.52, "done": 1.9, "end": 2.4, "hitstop": 0.09, "shake": 0.5},
	&"stand_in": {"impact": 0.7, "done": 1.25, "end": 2.2, "hitstop": 0.11, "shake": 0.8},
	&"powder_keg": {"impact": 0.5, "done": 1.1, "end": 2.0, "hitstop": 0.08, "shake": 0.7},
	&"ember_bird": {"impact": 0.7, "done": 2.3, "end": 3.2, "hitstop": 0.08, "shake": 0.5},
	&"gargoyle": {"impact": 0.66, "done": 2.15, "end": 2.6, "hitstop": 0.12, "shake": 1.2},
	&"crystal_mage": {"impact": 0.66, "done": 1.8, "end": 2.3, "hitstop": 0.1, "shake": 0.6},
	&"ranger": {"impact": 0.58, "done": 1.9, "end": 2.3, "hitstop": 0.1, "shake": 0.6},
	&"sun_moon_monk": {"impact": 0.62, "done": 1.2, "end": 2.3, "hitstop": 0.13, "shake": 1.0},
	&"antelope": {"impact": 0.74, "done": 1.5, "end": 2.4, "hitstop": 0.1, "shake": 0.9},
	&"war_king": {"impact": 0.68, "done": 1.3, "end": 2.5, "hitstop": 0.15, "shake": 1.6},
	&"shadow_king": {"impact": 0.66, "done": 1.45, "end": 2.2, "hitstop": 0.13, "shake": 0.8},
	&"shield_king": {"impact": 0.56, "done": 1.15, "end": 2.3, "hitstop": 0.11, "shake": 1.3},
	&"lantern_bearer": {"impact": 0.62, "done": 1.9, "end": 2.4, "hitstop": 0.08, "shake": 0.4},
	&"martyr": {"impact": 0.6, "done": 1.75, "end": 2.2, "hitstop": 0.08, "shake": 0.5},
	&"stone_giant": {"impact": 1.0, "done": 2.45, "end": 2.9, "hitstop": 0.16, "shake": 1.8},
	&"blast_catapult": {"impact": 1.05, "done": 1.2, "end": 2.6, "hitstop": 0.16, "shake": 2.0},
	&"sky_archer": {"impact": 1.2, "done": 1.3, "end": 2.5, "hitstop": 0.14, "shake": 1.1},
	&"flame_phoenix": {"impact": 0.78, "done": 1.95, "end": 2.6, "hitstop": 0.12, "shake": 1.2},
	&"thousand_faces": {"impact": 0.95, "done": 3.2, "end": 3.5, "hitstop": 0.08, "shake": 0.5},
}

## Victim reactions owned by this class.
const REACTIONS: Array[StringName] = [
	&"swallow", &"radiance", &"resonance", &"burn", &"erupt", &"toss", &"flatten", &"blast",
	&"skewer", &"inferno", &"mimic", &"keg", &"ember", &"shell", &"glass", &"halo", &"chip", &"rebirth",
]

## Pieces whose capture always plays their own reaction, whoever captures them.
const VICTIM_REACTIONS := {
	&"powder_keg": &"keg", &"ember_bird": &"ember", &"gargoyle": &"shell", &"crystal_mage": &"glass",
	&"martyr": &"halo", &"stone_giant": &"chip", &"flame_phoenix": &"rebirth",
}

var d: StrikeDirector = null
var _done: Dictionary = {}
var _phantom: Sprite2D = null
var _phantom_material: ShaderMaterial = null
var _attacker_texture_saved: Texture2D = null
## Set when the attacker is destroyed with its victim (Powder Keg).
var attacker_gone: bool = false

static func has_attack(attack_id: StringName) -> bool:
	return ATTACKS.has(attack_id)

static func reaction_for_type(strike_type: int) -> StringName:
	match strike_type:
		PieceDef.StrikeType.DEVOUR: return &"swallow"
		PieceDef.StrikeType.HOLY: return &"radiance"
		PieceDef.StrikeType.RESONANCE: return &"resonance"
		PieceDef.StrikeType.BURN: return &"burn"
		PieceDef.StrikeType.ERUPT: return &"erupt"
		PieceDef.StrikeType.TOSS: return &"toss"
		PieceDef.StrikeType.FLATTEN: return &"flatten"
		PieceDef.StrikeType.BLAST: return &"blast"
		PieceDef.StrikeType.SKEWER: return &"skewer"
		PieceDef.StrikeType.INFERNO: return &"inferno"
		PieceDef.StrikeType.MIMIC: return &"mimic"
	return &""

## The reaction a captured piece always plays, or &"" to use the attacker's.
static func victim_reaction(victim_id: StringName) -> StringName:
	var definition: PieceDef = PieceDefDatabase.get_def(String(victim_id))
	var key: StringName = StringName(definition.art_key()) if definition != null else victim_id
	return VICTIM_REACTIONS.get(key, &"")

## Reactions in which the victim survives the hit (shell pieces).
static func victim_survives(reaction: StringName) -> bool:
	return reaction == &"shell" or reaction == &"chip"

func handles(reaction: StringName) -> bool:
	return reaction in REACTIONS

func reset() -> void:
	_done = {}
	attacker_gone = false
	clear()

func clear() -> void:
	if is_instance_valid(_phantom):
		_phantom.queue_free()
	_phantom = null
	_attacker_texture_saved = null

# --- helpers ------------------------------------------------------------------

func _n(value: float) -> float:
	return value * d._unit

## Height of `px` rows of the 12-row prototype sprite, on the attacker / victim.
func _ah(px: float) -> float:
	return d._attacker_at(px / 12.0)

func _vh(px: float) -> float:
	return d._victim_at(px / 12.0)

func _vc(fraction: float = 0.5) -> Vector3:
	return Vector3(d._b.x, d._victim_at(fraction), d._b.z)

## A point `cells` cells short of the target along the attack line.
func _toward(cells: float) -> Vector3:
	return d._along(d._b, -d._cell * cells)

func _screen(point: Vector3) -> Vector2:
	return d._proj.project(Vector3(point.x, point.y, point.z + d._stand))

func _px(canvas: CanvasItem, at: Vector2, color: Color, size: float = 1.0) -> void:
	var side: float = size * d._unit
	canvas.draw_rect(Rect2(at - Vector2(side, side) * 0.5, Vector2(side, side)), color)

func _line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	canvas.draw_line(from, to, color, maxf(width * d._unit, 1.0))

func _fire() -> Color:
	return FIRE[randi() % FIRE.size()]

func _part(at: Vector3, velocity: Vector3, color: Color, life: float, gravity: float, size: float = 1.0) -> void:
	d.fx.add_part(Vector3(at.x, at.y, at.z + d._stand), velocity * d._unit, color, size * d._unit, life, gravity * d._unit)

func _weight3(values: Array) -> float:
	return float(values[clampi(d._victim_weight, 0, 2)])

func _once(key: StringName) -> bool:
	if _done.has(key):
		return false
	_done[key] = true
	return true

func _smooth(u: float) -> float:
	return StrikeDirector._smooth(clampf(u, 0.0, 1.0))

func _ease_in(u: float) -> float:
	return StrikeDirector._ease_in(clampf(u, 0.0, 1.0))

func _ease_out(u: float) -> float:
	return StrikeDirector._ease_out(clampf(u, 0.0, 1.0))

func _q(u: float, start: float, length: float) -> float:
	return clampf((u - start) / length, 0.0, 1.0)

# --- pose builders --------------------------------------------------------------

## Wind up backwards, dash in, squash on contact, settle onto the destination.
func _dash(u: float, o: StrikeDirector.Pose, back: float, windup: float, dash: float, contact: float, settle: float = 0.3, hop: float = 1.5, white: float = 0.0, bob: float = 0.0) -> void:
	var start: Vector3 = d._along(d._a, -d._cell * back)
	var hit: Vector3 = _toward(contact)
	var squash: float = 0.1
	if u < windup:
		var q: float = _ease_out(u / windup)
		o.at(d._a.lerp(start, q))
		o.sx = 1.0 + 0.08 * q
		o.sy = 1.0 - 0.1 * q
		o.white = white * q * (0.7 + 0.3 * sin(u * 50.0))
		return
	if u < windup + dash:
		var q: float = (u - windup) / dash
		o.at(start.lerp(hit, _ease_in(q)))
		o.sx = 0.92
		o.sy = 1.08
		o.trail = true
		o.y = _n(bob) * absf(sin(q * PI * 3.0))
		return
	if u < windup + dash + squash:
		var q: float = (u - windup - dash) / squash
		o.at(hit)
		o.sx = 1.0 + 0.2 * sin(q * PI)
		o.sy = 1.0 - 0.18 * sin(q * PI)
		return
	d._settle_into(o, hit, u, windup + dash + squash, settle, hop)

## Stays put to shoot or throw, recoils, then walks onto the destination (which is its
## own square after a ranged capture).
func _ranged(u: float, o: StrikeDirector.Pose, windup: float, recoil: float, walk_at: float, walk: float, lean: float) -> void:
	if u < windup:
		var s: float = sin(clampf(u / (windup * 0.9), 0.0, 1.0) * PI * 0.5)
		o.rot = -lean * s * d._face
		o.sy = 1.0 + 0.05 * s
		return
	if u < windup + recoil:
		var q: float = (u - windup) / recoil
		o.at(d._along(d._a, -_n(2.5) * sin(q * PI)))
		o.rot = lerpf(lean * 0.8, 0.0, q) * d._face
		return
	if u < walk_at:
		return
	var q: float = _q(u, walk_at, walk)
	o.at(d._a.lerp(d._dest, _smooth(q)))
	o.y = absf(sin(q * PI * 3.0)) * _n(2.0)

# --- timeline -----------------------------------------------------------------

func dynamic_timing() -> bool:
	match d._attack_id:
		&"ember_bird":
			var burn: float = _burn_time()
			d._done_time = 0.75 + burn + 0.7
			d._end_time = 0.75 + burn + 1.4
			return true
		&"thousand_faces":
			var absorb: float = _absorb_at()
			d._done_time = absorb + 1.3
			d._end_time = absorb + 1.6
			return true
	return false

func _burn_time() -> float:
	return _weight3([0.6, 0.8, 1.0])

func _absorb_at() -> float:
	return float(ATTACKS[&"thousand_faces"]["impact"]) + _weight3([0.75, 0.9, 1.05])

func events() -> Array:
	var a: Vector3 = d._a
	match d._attack_id:
		&"swift_courier":
			return [[0.06, d._event_puff.bind(d._up(a, 1.0), 4, 0.5)], [0.26, d._event_puff.bind(d._up(a.lerp(d._b, 0.5), 1.0), 6, 0.7)]]
		&"tide_knight":
			return [[0.22, _ring_at.bind(a, 0.6, 0.35, WATER)]]
		&"squire":
			return [[0.4, _wobble_hit], [1.05, _level_up]]
		&"gargoyle":
			return [[0.38, _gargoyle_slam]]
		&"sun_moon_monk":
			return [[0.4, _sun_palm]]
		&"antelope":
			return [[0.22, d._event_puff.bind(d._up(a, 1.0), 7, 0.9)], [0.6, d._event_puff.bind(d._up(_toward(0.55), 1.0), 6, 0.8)]]
		&"war_king":
			return [[0.28, d._event_puff.bind(d._up(a, 1.0), 8, 1.0)]]
		&"shadow_king":
			return [[0.16, d._event_puff.bind(d._up(a, 3.0), 10, 0.9)], [0.4, d._event_puff.bind(d._up(d._along(d._b, d._cell * 0.6), 3.0), 8, 0.8)]]
		&"stone_giant":
			var stand: Vector3 = _toward(1.0)
			return [[0.1, _giant_step.bind(a.lerp(stand, 1.0 / 3.0))], [0.32, _giant_step.bind(a.lerp(stand, 2.0 / 3.0))], [0.54, _giant_step.bind(stand)]]
		&"blast_catapult":
			return [[0.42, _catapult_release]]
		&"sky_archer":
			return [[0.45, d._event_sparks.bind(Vector3(a.x, _ah(14.0), a.z), 6, 0.0, 0.5)]]
		&"flame_phoenix":
			return [[0.2, _ring_at.bind(a, 0.8, 0.4, ORANGE)], [0.2, d._event_puff.bind(d._up(a, 1.0), 6, 0.8)]]
		&"chameleon":
			return [[1.0, _chameleon_learn]]
	return []

func _ring_at(at: Vector3, cells: float, life: float, color: Color) -> void:
	d.fx.ring(at.x, at.z, d._cell * cells, life, color)

func _wobble_hit() -> void:
	d.fx.spark_burst(d._up(d._b, 9.0), 4, d._dir, 40.0, 0.4)
	d._wobble_time = d._t

func _level_up() -> void:
	d.fx.ring(d._dest.x, d._dest.z, d._cell * 0.7, 0.45, GOLDEN)
	d.fx.ring(d._dest.x, d._dest.z, d._cell * 0.4, 0.3, GOLDEN)
	for index: int in range(10):
		var angle: float = randf() * TAU
		_part(Vector3(d._dest.x + cos(angle) * _n(4.0), _ah(12.0), d._dest.z), Vector3(cos(angle) * 12.0, randf_range(20.0, 40.0), 0.0), Color("#ffe08a"), randf_range(0.5, 0.9), -10.0)

func _gargoyle_slam() -> void:
	d.fx.puff(d._up(d._a, 1.0), 10, 1.1)
	d.fx.ring(d._a.x, d._a.z, d._cell * 0.9, 0.4)
	d._shake = maxf(d._shake, 0.8)

func _sun_palm() -> void:
	d.fx.ring(d._b.x, d._b.z, d._cell * 0.8, 0.35, GOLDEN)
	d.fx.spark_burst(d._up(d._b, 8.0), 10, d._dir, 40.0, 0.6, GOLDEN)
	d._wobble_time = d._t
	d._hs = 0.06
	d._shake = maxf(d._shake, 0.5)

func _giant_step(at: Vector3) -> void:
	d.fx.puff(d._up(at, 1.0), 6, 0.9)
	d._shake = maxf(d._shake, 0.45)

func _catapult_release() -> void:
	d.fx.puff(d._up(d._a, 4.0), 6, 0.8)
	d._shake = maxf(d._shake, 0.4)

func _chameleon_learn() -> void:
	var green: Color = Color(0.59, 0.9, 0.59)
	d.fx.ring(d._a.x, d._a.z, d._cell * 0.55, 0.35, green)
	d.fx.spark_burst(d._up(d._a, 8.0), 8, Vector2.ZERO, 0.0, 0.4, green)

# --- attacker poses -------------------------------------------------------------

func pose(u: float, o: StrikeDirector.Pose) -> void:
	var a: Vector3 = d._a
	var face: float = d._face
	var c: float = d._cell
	match d._attack_id:
		&"swift_courier":
			var middle: Vector3 = a.lerp(d._b, 0.5)
			var hit: Vector3 = _toward(0.45)
			var over: Vector3 = d._along(hit, _n(4.0))
			if u < 0.06:
				o.sy = 0.88
				o.sx = 1.08
			elif u < 0.26:
				var q: float = (u - 0.06) / 0.2
				o.at(a.lerp(middle, q))
				o.y = c * 0.4 * 4.0 * q * (1.0 - q)
			elif u < 0.3:
				o.at(middle)
				o.sy = 0.85
				o.sx = 1.1
			elif u < 0.44:
				var q: float = (u - 0.3) / 0.14
				o.at(middle.lerp(hit, _ease_in(q)))
				o.rot = 0.08 * face
				o.sx = 1.12
				o.sy = 0.92
				o.trail = true
			elif u < 0.58:
				var q: float = (u - 0.44) / 0.14
				o.at(hit.lerp(over, _ease_out(q)))
				o.rot = 0.08 * face * (1.0 - q)
			else:
				d._settle_into(o, over, u, 0.75, 0.25, 1.5)
		&"tide_knight":
			var hit: Vector3 = _toward(0.5)
			var past: Vector3 = d._along(hit, _n(5.0))
			if u < 0.25:
				var s: float = sin(u / 0.25 * PI)
				o.rot = -0.32 * s * face
				o.y = c * 0.15 * s
			elif u < 0.62:
				var q: float = (u - 0.25) / 0.37
				o.at(a.lerp(hit, _ease_in(q)))
				o.y = c * 0.18 * q + absf(sin(q * PI * 3.0)) * _n(2.0)
				o.rot = 0.1 * face
				o.trail = q > 0.3
			elif u < 0.8:
				var q: float = (u - 0.62) / 0.18
				o.at(hit.lerp(past, _ease_out(q)))
				o.y = c * 0.18 * (1.0 - q)
				o.rot = 0.1 * face * (1.0 - q)
			else:
				d._settle_into(o, past, u, 0.9, 0.3, 1.0)
		&"echo":
			_ranged(u, o, 0.3, 0.1, 1.55, 0.45, -0.06)
		&"chameleon":
			if u < 0.3:
				var s: float = _smooth(u / 0.3)
				o.sy = 1.0 - 0.12 * s
				o.sx = 1.0 + 0.08 * s
				o.white = 0.3 if u > 0.2 else 0.0
			elif u < 0.95:
				o.sy = 0.88
				o.sx = 1.08
				o.rot = 0.05 * face
			elif u < 1.15:
				var w: float = sin((u - 0.95) / 0.2 * PI)
				o.sx = 1.0 + 0.2 * w
				o.sy = 1.0 - 0.1 * w
			elif u < 1.3:
				o.white = 0.4 * absf(sin(u * 40.0))
			else:
				var q: float = _q(u, 1.3, 0.6)
				o.at(a.lerp(d._dest, _smooth(q)))
				o.y = absf(sin(q * PI * 4.0)) * _n(1.0)
		&"sentry":
			_dash(u, o, 0.12, 0.3, 0.14, 0.5, 0.3, 0.0)
		&"falconer":
			if u < 0.3:
				o.rot = -0.12 * _smooth(u / 0.3) * face
				o.sy = 1.0 + 0.05 * _smooth(u / 0.3)
			elif u < 0.45:
				o.rot = lerpf(-0.12, 0.0, (u - 0.3) / 0.15) * face
			elif u > 1.05 and u < 1.2:
				o.sy = 1.0 - 0.06 * sin((u - 1.05) / 0.15 * PI)
		&"vanguard":
			_dash(u, o, 0.15, 0.24, 0.16, 0.5, 0.28, 1.0)
		&"squire":
			var hit: Vector3 = _toward(0.5)
			if u < 0.14:
				o.sy = 0.9
				o.sx = 1.06
			elif u < 0.34:
				var q: float = (u - 0.14) / 0.2
				o.at(a.lerp(hit, q))
				o.y = absf(sin(q * PI * 2.0)) * _n(2.0)
			elif u < 0.75:
				var k: float = sin(_q(u, 0.34, 0.1) * PI) if u < 0.44 else sin(_q(u, 0.44, 0.12) * PI)
				o.at(d._along(hit, _n(3.0) * k))
				o.sx = 1.0 + 0.08 * k
				o.sy = 1.0 - 0.06 * k
			else:
				d._settle_into(o, hit, u, 0.75, 0.25, 2.0)
		&"stand_in":
			var hit: Vector3 = _toward(0.5)
			var back: Vector3 = d._along(hit, -_n(4.0))
			if u < 0.25:
				o.rot = -0.15 * _smooth(u / 0.25) * face
			elif u < 0.5:
				o.rot = lerpf(-0.15, 0.05, (u - 0.25) / 0.25) * face
			elif u < 0.54:
				o.sy = 0.85
				o.sx = 1.1
			elif u < 0.7:
				var q: float = (u - 0.54) / 0.16
				o.at(a.lerp(hit, _ease_in(q)))
				o.y = c * 0.45 * sin(q * PI * 0.9)
				o.sx = 1.15
				o.sy = 0.9
				o.trail = true
			elif u < 0.86:
				var q: float = (u - 0.7) / 0.16
				o.at(hit.lerp(back, sin(q * PI * 0.5)))
				o.y = c * 0.1 * (1.0 - q)
			else:
				d._settle_into(o, back, u, 0.95, 0.28, 2.0)
		&"powder_keg":
			_dash(u, o, 0.18, 0.28, 0.22, 0.55, 0.3, 1.0, 0.0, 2.0)
		&"ember_bird":
			var flapping: bool = u < 0.75
			o.sy = 1.0 + (0.1 * sin(u * 28.0) if flapping else 0.0)
			o.sx = 1.0 - (0.05 * sin(u * 28.0) if flapping else 0.0)
			o.y = c * 0.12 * _smooth(u / 0.2) if flapping else 0.0
			var fly: float = 0.75 + _burn_time() + 0.2
			if u >= fly:
				var q: float = _q(u, fly, 0.5)
				o.at(a.lerp(d._dest, _smooth(q)))
				o.y = c * 0.9 * sin(q * PI)
				o.sy = 1.0 + 0.1 * sin(u * 40.0)
		&"gargoyle":
			if u < 0.3:
				var s: float = _smooth(u / 0.3)
				o.sy = 1.0 + 0.12 * s
				o.y = c * 0.1 * s
			elif u < 0.38:
				var q: float = (u - 0.3) / 0.08
				o.y = c * 0.1 * (1.0 - q)
				o.sy = 1.12 - 0.32 * q
				o.sx = 1.0 + 0.2 * q
			elif u < 0.55:
				var q: float = (u - 0.38) / 0.17
				o.sy = 0.8 + 0.2 * q
				o.sx = 1.2 - 0.2 * q
			elif u >= 1.5:
				var q: float = _q(u, 1.5, 0.6)
				var step: int = mini(1, floori(q * 2.0))
				var local: float = q * 2.0 - step
				o.at(a.lerp(d._dest, (step + _smooth(local)) * 0.5))
				o.y = sin(local * PI) * _n(3.0)
		&"crystal_mage":
			_ranged(u, o, 0.5, 0.16, 1.3, 0.45, 0.08)
		&"ranger":
			if u < 0.3:
				var s: float = _smooth(u / 0.3)
				o.rot = -0.22 * s * face
				o.sx = 1.0 + 0.05 * s
			elif u < 0.42:
				o.rot = lerpf(-0.22, 0.18, _ease_out((u - 0.3) / 0.12)) * face
			elif u < 0.6:
				o.rot = 0.18 * face * (1.0 - (u - 0.42) / 0.18)
			elif u > 1.05 and u < 1.2:
				o.sy = 1.0 - 0.06 * sin((u - 1.05) / 0.15 * PI)
			elif u >= 1.35:
				var q: float = _q(u, 1.35, 0.5)
				o.at(a.lerp(d._dest, _smooth(q)))
				o.y = absf(sin(q * PI * 3.0)) * _n(2.0)
		&"sun_moon_monk":
			var hit: Vector3 = _toward(0.6)
			if u < 0.28:
				var s: float = _smooth(u / 0.28)
				o.sy = 1.0 - 0.1 * s
				o.sx = 1.0 + 0.06 * s
				o.white = 0.35 * s * (0.6 + 0.4 * sin(u * 40.0))
			elif u < 0.4:
				var q: float = (u - 0.28) / 0.12
				o.at(a.lerp(hit, _ease_in(q)))
				o.sx = 1.1
				o.rot = 0.1 * face
			elif u < 0.52:
				var q: float = (u - 0.4) / 0.12
				o.at(d._along(hit, -_n(2.0) * sin(q * PI)))
				o.rot = lerpf(0.1, -0.18, _smooth(q)) * face
			elif u < 0.62:
				var q: float = (u - 0.52) / 0.1
				o.at(d._along(hit, _n(2.0) * q))
				o.rot = lerpf(-0.18, 0.16, _ease_in(q)) * face
				o.sx = 1.0 + 0.12 * q
			elif u < 0.85:
				var q: float = (u - 0.62) / 0.23
				o.at(d._along(hit, _n(2.0) * (1.0 - q)))
				o.rot = 0.16 * face * (1.0 - q)
			else:
				d._settle_into(o, hit, u, 0.9, 0.28, 1.0)
		&"antelope":
			var hit: Vector3 = _toward(0.55)
			if u < 0.22:
				var s: float = sin(u / 0.22 * PI * 0.5)
				o.sy = 1.0 - 0.2 * s
				o.sx = 1.0 + 0.1 * s
			elif u < 0.6:
				var q: float = (u - 0.22) / 0.38
				o.at(a.lerp(hit, q))
				o.y = c * 2.4 * 4.0 * q * (1.0 - q)
				o.rot = lerpf(-0.25, 0.2, q) * face
				o.trail = q > 0.3
			elif u < 1.2:
				o.at(hit)
				if u < 0.66:
					var q: float = (u - 0.6) / 0.06
					o.sy = 1.0 - 0.15 * sin(q * PI)
					o.sx = 1.0 + 0.1 * sin(q * PI)
				elif u < 0.74:
					o.rot = 0.35 * (u - 0.66) / 0.08 * face
					o.sy = 0.92
				elif u < 0.9:
					var q: float = (u - 0.74) / 0.16
					o.rot = lerpf(0.35, -0.3, _ease_out(q)) * face
					o.y = c * 0.15 * sin(q * PI)
				elif u < 1.05:
					o.rot = -0.3 * face * (1.0 - (u - 0.9) / 0.15)
			else:
				d._settle_into(o, hit, u, 1.2, 0.3, 2.0)
		&"war_king":
			var hit: Vector3 = _toward(0.45)
			if u < 0.28:
				var s: float = _smooth(u / 0.28)
				o.sy = 1.0 - 0.15 * s
				o.sx = 1.0 + 0.08 * s
				o.white = 0.5 * s * (0.7 + 0.3 * sin(u * 50.0))
			elif u < 0.55:
				var q: float = (u - 0.28) / 0.27
				o.at(a.lerp(hit, q))
				o.y = c * 2.2 * _ease_out(q)
				o.rot = -0.15 * face
				o.white = 0.5
			elif u < 0.6:
				o.at(hit)
				o.y = c * 2.2
				o.rot = -0.2 * face
				o.white = 0.6
			elif u < 0.68:
				var q: float = (u - 0.6) / 0.08
				o.at(hit)
				o.y = c * 2.2 * (1.0 - _ease_in(q))
				o.rot = 0.2 * face
				o.sy = 1.15
				o.sx = 0.9
				o.trail = true
			elif u < 1.0:
				o.at(hit)
				if u < 0.85:
					var q: float = (u - 0.68) / 0.17
					var w: float = sin(q * PI)
					o.sx = 1.0 + 0.25 * w
					o.sy = 1.0 - 0.2 * w
					o.rot = 0.2 * face * (1.0 - q)
			else:
				d._settle_into(o, hit, u, 1.0, 0.3, 1.0)
		&"shadow_king":
			var behind: Vector3 = d._along(d._b, c * 0.6)
			if not d._on_board(behind):
				behind = d._along(d._b, c * 0.35)
			if u < 0.16:
				var s: float = u / 0.16
				o.alpha = 1.0 - 0.5 * s
				o.sy = 1.0 + 0.1 * s
				o.sx = 1.0 - 0.2 * s
			elif u < 0.4:
				o.alpha = 0.0
			elif u < 1.1:
				o.at(behind)
				if u < 0.52:
					o.alpha = (u - 0.4) / 0.12
				elif u < 0.66:
					var q: float = (u - 0.52) / 0.14
					o.rot = lerpf(0.25, -0.35, _ease_in(q)) * -face
					o.at(d._along(behind, -_n(2.0) * q))
					o.white = 0.3
				else:
					var q: float = _q(u, 0.66, 0.25)
					o.at(d._along(behind, -_n(2.0) * (1.0 - q)))
					o.rot = 0.35 * face * (1.0 - q)
			else:
				d._settle_into(o, behind, u, 1.1, 0.35, 1.0)
		&"shield_king":
			_dash(u, o, 0.2, 0.34, 0.22, 0.55, 0.32, 1.0)
		&"lantern_bearer":
			_ranged(u, o, 0.5, 0.12, 1.45, 0.45, 0.06)
		&"martyr":
			_ranged(u, o, 0.45, 0.15, 1.3, 0.45, 0.1)
		&"stone_giant":
			var stand: Vector3 = _toward(1.0)
			if u < 0.1:
				o.sy = 0.92
				o.sx = 1.05
			elif u < 0.76:
				var q: float = (u - 0.1) / 0.66
				var step: int = mini(2, floori(q * 3.0))
				var local: float = q * 3.0 - step
				o.at(a.lerp(stand, (step + _smooth(local)) / 3.0))
				o.y = sin(local * PI) * _n(2.5)
				o.rot = (0.06 if step % 2 == 1 else -0.06) * face * sin(local * PI)
				var land: float = (local - 0.85) / 0.15 if local > 0.85 else 0.0
				o.sy = 1.0 - 0.08 * land
				o.sx = 1.0 + 0.05 * land
			elif u < 2.0:
				o.at(stand)
				if u < 0.9:
					var s: float = _smooth((u - 0.76) / 0.14)
					o.sy = 1.0 + 0.15 * s
					o.sx = 1.0 - 0.06 * s
					o.white = 0.15 * s
				elif u < 1.0:
					var q: float = _ease_in((u - 0.9) / 0.1)
					o.sy = lerpf(1.15, 0.9, q)
					o.sx = lerpf(0.94, 1.1, q)
					o.at(d._along(stand, _n(3.0) * q))
				elif u < 1.75:
					o.sy = 0.9
					o.sx = 1.1
					o.at(d._along(stand, _n(3.0)))
				elif u < 1.95:
					var q: float = _smooth((u - 1.75) / 0.2)
					o.sy = lerpf(0.9, 1.0, q)
					o.sx = lerpf(1.1, 1.0, q)
					o.at(d._along(stand, _n(3.0) * (1.0 - q)))
			else:
				d._settle_into(o, stand, u, 2.0, 0.45, 0.0)
		&"blast_catapult":
			if u < 0.4:
				var s: float = _smooth(u / 0.4)
				o.sx = 1.0 + 0.06 * s
				o.sy = 1.0 - 0.1 * s
				o.rot = -0.07 * s * face
			elif u < 0.52:
				o.rot = lerpf(-0.07, 0.1, _ease_out((u - 0.4) / 0.12)) * face
				o.sy = 1.05
			elif u < 0.8:
				o.rot = 0.1 * face * (1.0 - (u - 0.52) / 0.28)
		&"sky_archer":
			if u < 0.4:
				var s: float = _smooth(u / 0.4)
				o.sy = 1.0 - 0.12 * s
				o.sx = 1.0 + 0.05 * s
				o.rot = -0.15 * s * face
			elif u < 0.45:
				o.sy = 0.88
				o.rot = -0.15 * face
			elif u < 0.65:
				var q: float = (u - 0.45) / 0.2
				o.sy = lerpf(0.86, 1.0, _smooth(q))
				o.rot = -0.15 * face * (1.0 - q)
		&"flame_phoenix":
			var past: Vector3 = d._along(d._b, c * 1.1)
			if not d._on_board(past):
				past = d._along(d._b, c * 0.5)
			if u < 0.45:
				var s: float = _smooth(u / 0.45)
				o.y = c * 1.1 * s
				o.sy = 1.0 + 0.1 * sin(u * 30.0)
				o.white = 0.25 * s
			elif u < 0.86:
				var q: float = _ease_in((u - 0.45) / 0.41)
				o.at(a.lerp(past, q))
				o.y = lerpf(c * 1.1, c * 0.3, q)
				o.rot = 0.25 * face
				o.sx = 1.15
				o.sy = 0.9
				o.trail = true
				o.white = 0.35
			elif u < 1.5:
				var q: float = (u - 0.86) / 0.64
				o.at(past.lerp(d._dest, _smooth(q)))
				o.y = c * 0.3 + c * 1.2 * sin(q * PI)
				o.rot = lerpf(0.25, -0.15, q) * face
			else:
				o.at(d._dest)
				if u < 1.75:
					var q: float = (u - 1.5) / 0.25
					o.y = c * 0.3 * (1.0 - _ease_in(q))
					o.rot = -0.15 * face * (1.0 - q)
				elif u < 1.9:
					var w: float = sin((u - 1.75) / 0.15 * PI)
					o.sy = 1.0 - 0.15 * w
					o.sx = 1.0 + 0.12 * w
		&"thousand_faces":
			var stand: Vector3 = _toward(1.05)
			var absorb: float = _absorb_at()
			if u < 0.6:
				var q: float = u / 0.6
				o.at(a.lerp(stand, _smooth(q)))
				o.white = 0.8 if fmod(u, 0.1) < 0.03 else 0.0
				o.y = absf(sin(q * PI * 3.0)) * _n(1.5)
			elif u < absorb + 0.95:
				o.at(stand)
				if u < absorb:
					if u > 0.75:
						o.rot = 0.05 * face * sin(u * 12.0)
				elif u < absorb + 0.7:
					o.white = maxf(0.0, 1.0 - (u - absorb) / 0.2)
				else:
					o.white = (u - absorb - 0.7) / 0.15 if u < absorb + 0.85 else 0.0
			else:
				d._settle_into(o, stand, u, absorb + 0.95, 0.35, 1.0)
			_swap_attacker_form(u >= absorb and u < absorb + 0.85)

## Thousand Faces wears the captured piece's shape for a moment after absorbing it.
func _swap_attacker_form(as_victim: bool) -> void:
	if not is_instance_valid(d._attacker):
		return
	if as_victim and _attacker_texture_saved == null:
		_attacker_texture_saved = d._attacker.texture
		var worn: Texture2D = d.mimic_texture if d.mimic_texture != null else d._victim_texture
		d._attacker.texture = worn
		d._attacker.material = d._piece_material(PieceChunks.of(worn))
		d._attacker_material = d._attacker.material
	elif not as_victim and _attacker_texture_saved != null:
		d._attacker.texture = _attacker_texture_saved
		d._attacker.material = d._piece_material(PieceChunks.of(_attacker_texture_saved))
		d._attacker_material = d._attacker.material
		_attacker_texture_saved = null
		d.fx.spark_burst(Vector3(d._pose.x, 8.0 * d._unit, d._pose.z), 6, Vector2.ZERO, 0.0, 0.4, VIOLET)

# --- impact -----------------------------------------------------------------------

func impact() -> void:
	var b: Vector3 = d._b
	var fx: StrikeFx = d.fx
	var cell: float = d._cell
	match d._attack_id:
		&"swift_courier":
			d._slash_age = 0.0
			fx.spark_burst(d._up(b, 9.0), 9, d._dir, 60.0, 0.7, FOAM)
		&"tide_knight":
			fx.ring(b.x, b.z, cell * 1.3, 0.5, WATER)
			fx.ring(b.x, b.z, cell * 0.7, 0.32, FOAM)
			fx.spark_burst(d._up(b, 8.0), 18, d._dir, 60.0, 1.0, WATER)
			for index: int in range(30):
				_part(Vector3(b.x + randf_range(-5.0, 5.0) * d._unit, _vh(randf_range(2.0, 10.0)), b.z), Vector3(randf_range(-50.0, 50.0) + d._dir.x * 40.0, randf_range(40.0, 110.0), randf_range(-20.0, 20.0) + d._dir.y * 40.0), WATER if randf() < 0.5 else FOAM, randf_range(0.5, 0.9), 260.0, 2.0 if randf() < 0.3 else 1.0)
		&"echo":
			fx.ring(b.x, b.z, cell * 0.7, 0.35, SOUND)
		&"chameleon":
			fx.spark_burst(d._up(b, 9.0), 4, Vector2.ZERO, 0.0, 0.3, Color("#f08aa0"))
		&"sentry":
			fx.spark_burst(d._up(b, 8.0), 10, d._dir, 90.0, 0.7)
			fx.ring(b.x, b.z, cell * 0.7, 0.3)
		&"falconer", &"stand_in":
			fx.spark_burst(d._up(b, 10.0), 9, d._dir, 50.0, 0.6)
			fx.ring(b.x, b.z, cell * 0.5, 0.26)
		&"vanguard":
			fx.spark_burst(d._up(b, 8.0), 8, d._dir, 80.0, 0.6)
		&"squire":
			fx.spark_burst(d._up(b, 9.0), 9, d._dir, 80.0, 0.6)
		&"powder_keg":
			fx.spark_burst(d._up(b, 8.0), 8, d._dir, 40.0, 0.6)
			fx.ring(b.x, b.z, cell * 0.6, 0.3)
			fx.puff(d._up(b, 2.0), 6, 0.9)
		&"ember_bird":
			fx.spark_burst(d._up(b, 8.0), 8, Vector2.ZERO, 0.0, 0.5, ORANGE)
		&"gargoyle":
			fx.ring(b.x, b.z, cell * 1.2, 0.45)
			fx.puff(d._up(b, 2.0), 12, 1.3)
			fx.crack_decal(b.x, b.z, 8, cell * 0.9)
		&"crystal_mage":
			fx.spark_burst(d._up(b, 9.0), 12, d._dir, 80.0, 0.7, GLASS[0])
			fx.ring(b.x, b.z, cell * 0.6, 0.3, GLASS[0])
		&"ranger":
			d._slash_age = 0.0
			fx.spark_burst(d._up(b, 9.0), 8, d._dir, 50.0, 0.6)
		&"sun_moon_monk":
			fx.ring(b.x, b.z, cell * 1.2, 0.45, MOON)
			fx.ring(b.x, b.z, cell * 0.6, 0.3, Color(0.9, 0.94, 1.0))
			fx.spark_burst(d._up(b, 8.0), 12, d._dir, 60.0, 0.8, MOON)
		&"antelope":
			fx.spark_burst(d._up(b, 6.0), 8, d._dir, 40.0, 0.6)
			fx.puff(d._up(b, 2.0), 6, 0.8)
		&"war_king":
			d._slash_age = 0.0
			fx.ring(b.x, b.z, cell * 1.6, 0.55, GOLDEN)
			fx.ring(b.x, b.z, cell * 0.9, 0.35, GOLDEN)
			fx.puff(d._up(b, 2.0), 12, 1.3)
			fx.crack_decal(b.x, b.z, 10, cell * 1.3)
			fx.spark_burst(d._up(b, 6.0), 16, Vector2.ZERO, 0.0, 0.9, GOLDEN)
		&"shadow_king":
			d._slash_age = 0.0
			fx.spark_burst(d._up(b, 9.0), 8, -d._dir, 50.0, 0.6, Color(0.7, 0.59, 0.86))
		&"shield_king":
			fx.ring(b.x, b.z, cell * 1.3, 0.5, MOON)
			fx.ring(b.x, b.z, cell * 0.7, 0.3)
			fx.puff(d._up(b, 2.0), 9, 1.2)
			fx.spark_burst(d._up(b, 7.0), 8, d._dir, 40.0, 0.7, MOON)
		&"lantern_bearer":
			fx.ring(b.x, b.z, cell * 0.8, 0.4, GOLDEN)
		&"martyr":
			fx.spark_burst(d._up(b, 10.0), 7, d._dir, 30.0, 0.5, GOLDEN)
			fx.puff(d._up(b, 6.0), 10, 0.9)
			fx.ring(b.x, b.z, cell * 0.6, 0.3, GOLDEN)
		&"stone_giant":
			fx.ring(b.x, b.z, cell * 1.6, 0.55, STONE)
			fx.ring(b.x, b.z, cell * 0.9, 0.35)
			fx.crack_decal(b.x, b.z, 11, cell * 1.3)
			fx.spark_burst(d._up(b, 14.0), 10, Vector2.ZERO, 0.0, 0.7, STONE)
		&"blast_catapult":
			d._flash = 1.0
			fx.ring(b.x, b.z, cell * 2.0, 0.6, ORANGE)
			fx.ring(b.x, b.z, cell * 1.3, 0.45, Color(1.0, 0.9, 0.55))
			fx.ring(b.x, b.z, cell * 0.7, 0.3, ORANGE)
			fx.spark_burst(d._up(b, 8.0), 30, Vector2.ZERO, 0.0, 1.4, ORANGE)
			fx.puff(d._up(b, 4.0), 22, 2.0)
			fx.crack_decal(b.x, b.z, 12, cell * 1.5)
		&"sky_archer":
			fx.ring(b.x, b.z, cell * 1.3, 0.5, GOLDEN)
			fx.ring(b.x, b.z, cell * 0.6, 0.3, Color(1.0, 0.98, 0.9))
			fx.spark_burst(d._up(b, 4.0), 14, Vector2.ZERO, 0.0, 0.8, GOLDEN)
			for index: int in range(14):
				_part(Vector3(b.x + randf_range(-8.0, 8.0) * d._unit, _vh(randf_range(12.0, 24.0)), b.z), Vector3(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0), 0.0), Color("#ffe08a") if randf() < 0.5 else HOLY_WHITE, randf_range(1.2, 1.8), 12.0)
		&"flame_phoenix":
			fx.ring(b.x, b.z, cell * 1.3, 0.5, ORANGE)
			fx.ring(b.x, b.z, cell * 0.7, 0.35, Color(1.0, 0.9, 0.55))
			fx.spark_burst(d._up(b, 6.0), 18, d._dir, 40.0, 1.0, ORANGE)
		&"thousand_faces":
			fx.ring(b.x, b.z, cell * 0.8, 0.45, VIOLET)
			fx.spark_burst(d._up(b, 8.0), 8, Vector2.ZERO, 0.0, 0.5, VIOLET)

# --- victim -------------------------------------------------------------------

func split_time() -> float:
	match d._reaction:
		&"swallow": return _weight3([0.45, 0.55, 0.7])
		&"radiance", &"halo": return 0.75
		&"resonance": return _weight3([0.45, 0.6, 0.8])
		&"burn": return _burn_time()
		&"erupt": return 0.05
		&"toss": return 0.03
		&"flatten": return _weight3([0.55, 0.65, 0.75])
		&"blast": return 0.02
		&"skewer": return _weight3([0.28, 0.36, 0.45])
		&"inferno": return _weight3([0.45, 0.6, 0.75])
		&"mimic": return _weight3([0.75, 0.9, 1.05])
		&"keg": return 0.1
		&"ember": return 0.3
		&"glass": return 0.08
		&"rebirth": return 0.25
		&"shell", &"chip": return INF
	return 0.1

func _flatten_y() -> float:
	return lerpf(1.0, 0.2, _ease_out(d._rt / (split_time() - 0.05)))

func _mouth() -> Vector3:
	return Vector3(d._pose.x + d._dir.x * _n(5.0), d._pose.y + _ah(7.0), d._pose.z + d._dir.y * _n(5.0))

## How the standing victim looks this frame: {"world": Vector3 feet position,
## "stretch": Vector2, "jitter": float, "rot": float}. Missing keys keep the default.
func victim_state(material: ShaderMaterial) -> Dictionary:
	var rt: float = d._rt
	var split: float = split_time()
	var q: float = clampf(rt / split, 0.0, 1.0) if split < INF else 0.0
	var state: Dictionary = {}
	match d._reaction:
		&"swallow":
			var sc: float = 1.0 - 0.85 * _ease_in(q)
			var centre: Vector3 = _vc(0.5).lerp(_mouth(), _ease_in(q))
			state["world"] = Vector3(centre.x, maxf(0.0, centre.y - d._victim_at(0.5) * sc), centre.z + d._stand)
			state["stretch"] = Vector2(sc, sc)
			state["rot"] = q * q * 6.0 * d._face
			state["jitter"] = 0.0
		&"radiance", &"halo":
			var gold: Color = Color("#ffe08a") if d._reaction == &"halo" else HOLY_WHITE
			d._set_tint(material, gold, 0.75 * clampf(rt / 0.3, 0.0, 1.0))
			material.set_shader_parameter(&"clip_y", Vector2(clampf((rt - 0.25) / 0.5, 0.0, 1.0), 1.0))
			state["jitter"] = 0.0
		&"resonance":
			state["jitter"] = roundf(sin(rt * (60.0 + 80.0 * q)) * (0.5 + 2.0 * q))
			material.set_shader_parameter(&"crack_progress", q)
			d._set_tint(material, SOUND, 0.25 * q)
		&"burn":
			d._set_tint(material, ASH[2], 0.85 * q)
			state["jitter"] = 0.0
		&"flatten":
			var sy: float = _flatten_y()
			state["stretch"] = Vector2(lerpf(1.0, 1.7, (1.0 - sy) / 0.8), sy)
			state["jitter"] = roundf(randf_range(-1.0, 1.0) * (1.0 - sy))
		&"skewer", &"shell", &"chip":
			state["jitter"] = float(randi_range(-1, 1)) if rt < 0.2 else 0.0
			if d._reaction == &"shell":
				material.set_shader_parameter(&"crack_progress", clampf(rt / 0.3, 0.0, 1.0))
		&"inferno":
			d._set_tint(material, ORANGE.lerp(Color.WHITE, clampf(q * 2.0 - 1.0, 0.0, 1.0)), 0.3 + 0.6 * clampf(q * 2.0, 0.0, 1.0))
			state["jitter"] = roundf(randf_range(-1.0, 1.0) * q)
		&"mimic":
			d._set_tint(material, Color(0.55, 0.54, 0.58), clampf(q * 1.6, 0.0, 1.0))
			state["jitter"] = 0.0
		&"ember", &"rebirth":
			d._set_tint(material, ORANGE, (0.7 if d._reaction == &"ember" else 0.8) * q)
			state["jitter"] = roundf(randf_range(-1.0, 1.0) * q)
	return state

func reaction_tick() -> void:
	if d._hs > 0.0:
		return
	var rt: float = d._rt
	var b: Vector3 = d._b
	match d._reaction:
		&"radiance", &"halo":
			if rt > 0.25:
				var row: float = clampf((rt - 0.25) / 0.5, 0.0, 1.0)
				var front: PackedInt32Array = d._select(func(p: Vector2) -> bool: return absf(p.y - row) < 1.0 / StrikeDirector.ROWS)
				for _i: int in range(2):
					if front.is_empty():
						break
					var pick: int = front[randi() % front.size()]
					d._debris(PackedInt32Array([pick]), d._foot_pivot(), d._foot(b), {"vel": Vector3(0.0, 25.0 * d._unit, 0.0), "spread": 6.0, "gravity": -40.0, "life_min": 0.6, "life_max": 1.0, "radial": 0.0, "color": Color("#ffe08a") if randf() < 0.5 else HOLY_WHITE})
		&"burn":
			var row: float = 1.0 - clampf(rt / split_time(), 0.0, 1.0)
			var front: PackedInt32Array = d._select(func(p: Vector2) -> bool: return absf(p.y - row) < 1.5 / StrikeDirector.ROWS)
			for _i: int in range(2):
				if front.is_empty():
					break
				var pick: int = front[randi() % front.size()]
				d._debris(PackedInt32Array([pick]), d._foot_pivot(), d._foot(b), {"vel": Vector3(0.0, 25.0 * d._unit, 0.0), "spread": 6.0, "gravity": -60.0, "life_min": 0.2, "life_max": 0.4, "radial": 0.0, "color": FIRE[1 + randi() % 3]})
		&"inferno":
			if randf() < 0.9:
				_part(Vector3(b.x + randf_range(-5.0, 5.0) * d._unit, _vh(randf_range(0.0, 6.0)), b.z), Vector3(randf_range(-4.0, 4.0), randf_range(30.0, 60.0), 0.0), _fire(), randf_range(0.3, 0.6), -20.0)
		&"flatten":
			if randf() < 0.3:
				d.fx.puff(Vector3(b.x + randf_range(-6.0, 6.0) * d._unit, d._unit, b.z), 1, 0.5)
		&"shell":
			if _once(&"shell"):
				var edge: PackedInt32Array = d._select(func(p: Vector2) -> bool: return randf() < 0.3)
				d._debris(edge, d._foot_pivot(), d._foot(b), {"vel": Vector3(d._dir.x * 30.0, 40.0, d._dir.y * 30.0) * d._unit, "spread": 35.0, "radial": 2.5})
				d.fx.puff(d._up(b, 3.0), 8, 1.0)
		&"chip":
			if _once(&"chip"):
				d._brick = Rect2(0.0, 0.0, d._victim_chunks.aspect * 0.5, 0.5)
				d._victim_material.set_shader_parameter(&"brick", Vector4(0.0, 0.0, d._brick.end.x, d._brick.end.y))
				d._victim_material.set_shader_parameter(&"brick_mode", 1.0)
				var chunk: StrikeDirector.Body = d._make_body({"brick_mode": 2.0})
				chunk.material.set_shader_parameter(&"brick", Vector4(0.0, 0.0, d._brick.end.x, d._brick.end.y))
				chunk.vx = (-d._dir.y * 25.0 - 20.0) * d._unit
				chunk.vz = d._dir.x * 25.0 * d._unit
				chunk.vy = 70.0 * d._unit
				chunk.vr = -7.0
				chunk.gravity = 300.0 * d._unit
				chunk.shatter_ground = true
				chunk.poof = true
				d.fx.puff(d._up(b, 6.0), 8, 1.0)
				d.fx.spark_burst(d._up(b, 10.0), 8, Vector2.ZERO, 0.0, 0.6, STONE)

func on_split() -> void:
	var b: Vector3 = d._b
	var fx: StrikeFx = d.fx
	var whole: PackedInt32Array = d._victim_chunks.all_indices()
	var foot: Vector3 = d._foot(b)
	match d._reaction:
		&"swallow":
			var mouth: Vector3 = _mouth()
			d._debris(whole, d._foot_pivot(), Vector3(mouth.x, d._unit * 2.0, mouth.z + d._stand), {"vel": Vector3(0.0, 10.0 * d._unit, 0.0), "spread": 12.0, "every": 6, "life_min": 0.4, "life_max": 0.7})
		&"radiance":
			fx.ring(b.x, b.z, d._cell * 0.6, 0.4, GOLDEN)
		&"halo":
			fx.ring(b.x, b.z, d._cell * 0.6, 0.4, GOLDEN)
			fx.ring(b.x, b.z, d._cell * 1.5, 0.6, GOLDEN)
		&"resonance":
			for row: int in range(0, StrikeDirector.ROWS, 3):
				var band: PackedInt32Array = d._select(func(p: Vector2) -> bool: return int(p.y * StrikeDirector.ROWS) >= row and int(p.y * StrikeDirector.ROWS) < row + 3)
				d._debris(band, d._foot_pivot(), foot, {"vel": Vector3(0.0, (20.0 + (StrikeDirector.ROWS - row) * 2.0) * d._unit, 0.0), "spread": 35.0, "radial": 3.0})
			fx.ring(b.x, b.z, d._cell * 1.1, 0.45, SOUND)
			fx.spark_burst(d._up(b, 8.0), 10, Vector2.ZERO, 0.0, 0.6, SOUND)
			d._shake = maxf(d._shake, 0.6)
		&"burn":
			d._debris(whole, d._foot_pivot(), foot, {"vel": Vector3(0.0, 5.0 * d._unit, 0.0), "spread": 12.0, "gravity": 120.0, "life_min": 1.2, "life_max": 1.8, "radial": 0.6, "color": ASH[randi() % ASH.size()]})
			fx.puff(d._up(b, 6.0), 6, 0.9)
		&"erupt", &"toss":
			var body: StrikeDirector.Body = d._make_body({})
			var toss: bool = d._reaction == &"toss"
			var push: float = _weight3([70.0, 55.0, 40.0]) if toss else 15.0
			var sign: float = -1.0 if toss else 1.0
			body.vx = d._dir.x * push * sign * d._unit
			body.vz = d._dir.y * push * sign * d._unit
			body.vy = (_weight3([200.0, 175.0, 150.0]) if toss else _weight3([190.0, 165.0, 140.0])) * d._unit
			body.vr = (-14.0 if toss else 9.0) * d._face
			body.gravity = (320.0 if toss else 300.0) * d._unit
			body.shatter_ground = true
			body.poof = true
		&"flatten":
			d._debris(whole, d._foot_pivot(), foot, {"vel": Vector3(0.0, 6.0 * d._unit, 0.0), "spread": 45.0, "radial": 3.5, "gravity": 300.0})
			fx.puff(d._up(b, 1.0), 12, 1.4)
			d._shake = maxf(d._shake, 0.8)
		&"blast":
			_fire_debris(whole, foot, 110.0, 70.0, 5.0, 0.45)
		&"skewer":
			var keep_angle: float = d._slash_angle
			d._slash_angle = PI * 0.5
			for side: float in [-1.0, 1.0]:
				var half: StrikeDirector.Body = d._make_body({"plane_keep": side})
				half.material.set_shader_parameter(&"plane_dir", Vector2(0.0, 1.0))
				half.vx = -side * 35.0 * d._unit
				half.vy = 30.0 * d._unit
				half.vr = -side * 4.0
				half.gravity = 260.0 * d._unit
				half.shatter_ground = true
			d._slash_angle = keep_angle
		&"inferno":
			d._debris(whole, d._foot_pivot(), foot, {"vel": Vector3(0.0, 40.0 * d._unit, 0.0), "spread": 12.0, "gravity": -60.0, "life_min": 0.5, "life_max": 0.9, "radial": 0.8, "color": HOLY_WHITE})
			for index: int in range(whole.size() / 3):
				_part(Vector3(b.x + randf_range(-5.0, 5.0) * d._unit, _vh(randf_range(0.0, 12.0)), b.z), Vector3(randf_range(-6.0, 6.0), randf_range(30.0, 50.0), 0.0), _fire(), randf_range(0.5, 0.9), -60.0)
		&"mimic":
			d._debris(whole, d._foot_pivot(), foot, {"vel": Vector3(0.0, 6.0 * d._unit, 0.0), "spread": 14.0, "radial": 0.6, "gravity": 220.0, "life_min": 0.8, "life_max": 1.3, "color": Color(0.55, 0.54, 0.58)})
			fx.puff(d._up(b, 2.0), 8, 0.8)
		&"keg":
			_fire_debris(whole, foot, 90.0, 70.0, 6.0, 0.5)
			fx.spark_burst(d._up(b, 8.0), 26, Vector2.ZERO, 0.0, 1.3, ORANGE)
			fx.spark_burst(d._up(b, 8.0), 12, Vector2.ZERO, 0.0, 0.9, Color(1.0, 0.9, 0.55))
			fx.ring(b.x, b.z, d._cell * 1.8, 0.55, ORANGE)
			fx.ring(b.x, b.z, d._cell * 1.1, 0.4, Color(1.0, 0.9, 0.55))
			fx.ring(b.x, b.z, d._cell * 0.6, 0.3, ORANGE)
			fx.puff(d._up(b, 4.0), 20, 1.8)
			fx.crack_decal(b.x, b.z, 10, d._cell * 1.3)
			d._flash = 1.0
			d._shake = 1.9
			d._punch = 1.0
			_blow_up_attacker()
		&"ember":
			d._debris(whole, d._foot_pivot(), foot, {"vel": Vector3(0.0, 30.0 * d._unit, 0.0), "spread": 25.0, "gravity": -50.0, "life_min": 0.8, "life_max": 1.4, "radial": 1.5, "color": FIRE[2]})
			fx.spark_burst(d._up(b, 6.0), 14, Vector2.ZERO, 0.0, 0.7, ORANGE)
			fx.ring(b.x, b.z, d._cell * 0.8, 0.4, ORANGE)
		&"glass":
			d._debris(whole, d._foot_pivot(), foot, {"vel": Vector3(d._dir.x * 30.0, 45.0, d._dir.y * 30.0) * d._unit, "spread": 50.0, "radial": 3.0, "gravity": 150.0, "life_min": 1.4, "life_max": 2.2, "color": GLASS[randi() % GLASS.size()]})
			fx.spark_burst(d._up(b, 8.0), 14, Vector2.ZERO, 0.0, 0.8, Color(0.9, 0.98, 1.0))
			fx.ring(b.x, b.z, d._cell * 0.8, 0.35, Color(0.9, 0.98, 1.0))
		&"rebirth":
			fx.spark_burst(d._up(b, 8.0), 16, Vector2.ZERO, 0.0, 0.8, ORANGE)
			fx.ring(b.x, b.z, d._cell * 0.8, 0.4, ORANGE)

## Explodes the victim into chunks, some of them burning.
func _fire_debris(indices: PackedInt32Array, foot: Vector3, up: float, spread: float, radial: float, burning: float) -> void:
	var plain: PackedInt32Array = PackedInt32Array()
	var lit: PackedInt32Array = PackedInt32Array()
	for index: int in indices:
		if randf() < burning:
			lit.append(index)
		else:
			plain.append(index)
	d._debris(plain, d._foot_pivot(), foot, {"vel": Vector3(0.0, up * d._unit, 0.0), "spread": spread, "radial": radial})
	d._debris(lit, d._foot_pivot(), foot, {"vel": Vector3(0.0, up * d._unit, 0.0), "spread": spread, "radial": radial, "color": FIRE[2]})

## The piece that captured the Powder Keg is blown away with it.
func _blow_up_attacker() -> void:
	if not is_instance_valid(d._attacker):
		return
	attacker_gone = true
	var chunks: PieceChunks = PieceChunks.of(d._attacker_texture)
	var height: float = d._attacker_height
	var size: float = height / StrikeDirector.ROWS
	for index: int in range(chunks.points.size()):
		var point: Vector2 = chunks.points[index]
		var local: Vector2 = (point - Vector2(chunks.aspect * 0.5, 1.0)) * height
		var at: Vector3 = Vector3(d._pose.x + local.x, maxf(0.0, d._pose.y - d._proj.height_for_pixels(local.y)), d._pose.z + d._stand)
		var velocity: Vector3 = Vector3(-d._dir.x * 90.0 + local.x * 5.0 + randf_range(-40.0, 40.0), randf_range(60.0, 140.0), -d._dir.y * 90.0 + randf_range(-20.0, 20.0)) * d._unit
		d.fx.add_part(at, velocity, chunks.colors[index] if randf() < 0.6 else _fire(), size, randf_range(1.0, 1.6), 260.0 * d._unit)

# --- drawing ------------------------------------------------------------------

func draw_ground(canvas: CanvasItem) -> void:
	var u: float = d._t
	match d._attack_id:
		&"gargoyle":
			if u < 0.38 or (d._impacted and d._rt > 1.2):
				return
			var reach: int = floori(_q(u, 0.38, 0.28) * 40.0)
			var fade: float = 1.0 - d._rt / 1.2 if d._impacted else 1.0
			for index: int in range(reach):
				var k: float = index / 40.0
				var wiggle: float = sin(index * 1.7) * _n(2.5)
				var at: Vector3 = Vector3(lerpf(d._a.x, d._b.x, k) + d._dir.y * wiggle, 0.0, lerpf(d._a.z, d._b.z, k) - d._dir.x * wiggle)
				_px(canvas, _screen(at), Color(0.055, 0.035, 0.024, 0.85 * fade))
		&"blast_catapult":
			var shell: Array = _keg_shell(u)
			var glow: float = 0.0
			if d._impacted:
				glow = 0.55 * maxf(0.0, 1.0 - d._rt / 0.9)
			elif not shell.is_empty() and float(shell[1]) > 0.35:
				glow = 0.18 + 0.18 * sin(u * 40.0)
			if glow > 0.0:
				for dx: int in range(-1, 2):
					for dz: int in range(-1, 2):
						var centre: Vector3 = Vector3(d._b.x + dx * d._cell, 0.0, d._b.z + dz * d._cell)
						var corners: PackedVector2Array = PackedVector2Array()
						for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
							corners.append(d._proj.project(Vector3(centre.x + corner.x * d._cell, 0.0, centre.z + corner.y * d._cell)))
						canvas.draw_colored_polygon(corners, Color(1.0, 0.55 if d._impacted else 0.31, 0.2, glow))
			if not shell.is_empty():
				var at: Vector3 = shell[0]
				var q: float = shell[1]
				d._ground_disc(canvas, Vector3(at.x, 0.0, at.z + d._stand), _n(1.5 + 3.0 * q), Color(0.0, 0.0, 0.0, 0.15 + 0.3 * q))

func draw_air(canvas: CanvasItem) -> void:
	_draw_attack_air(canvas)
	_draw_reaction_air(canvas)

func _draw_attack_air(canvas: CanvasItem) -> void:
	var u: float = d._t
	var o: StrikeDirector.Pose = d._pose
	var face: float = d._face
	match d._attack_id:
		&"swift_courier":
			if u > 0.3 and u < 0.55:
				for _i: int in range(3):
					var back: float = randf_range(4.0, 14.0)
					var p: Vector2 = _screen(Vector3(o.x - d._dir.x * _n(back), o.y + _ah(randf_range(2.0, 12.0)), o.z - d._dir.y * _n(back)))
					_line(canvas, p, p - d._screen_dir() * _n(randf_range(4.0, 8.0)), Color(0.9, 0.96, 1.0, 0.55))
		&"tide_knight":
			if u > 0.25 and u < 0.62:
				var q: float = (u - 0.25) / 0.37
				var base: Vector2 = _screen(Vector3(o.x, 0.0, o.z))
				var along: Vector2 = d._screen_dir()
				var height: float = _n(3.0 + 7.0 * q)
				for index: int in range(-9, 5):
					var foot: Vector2 = base - along * index * _n(1.5)
					var top: float = height * maxf(0.0, 1.0 - absf(index + 2) / 8.0)
					canvas.draw_rect(Rect2(foot.x, foot.y - top, d._unit, top + d._unit), Color(0.31, 0.59, 0.9, 0.85))
					_px(canvas, Vector2(foot.x + d._unit * 0.5, foot.y - top), FOAM)
				if randf() < 0.8:
					_part(Vector3(o.x + randf_range(-4.0, 4.0) * d._unit, height, o.z), Vector3(randf_range(-20.0, 20.0) - d._dir.x * 30.0, randf_range(20.0, 50.0), randf_range(-6.0, 6.0) - d._dir.y * 30.0), WATER if randf() < 0.5 else FOAM, randf_range(0.3, 0.5), 220.0)
		&"echo":
			if u < 0.05 or (d._impacted and d._rt > 0.6):
				return
			var src: Vector3 = Vector3(d._a.x, _ah(8.0), d._a.z)
			var dst: Vector3 = _vc(0.5)
			for index: int in range(6):
				var phase: float = u * 2.2 - index * 0.17
				if phase < 0.0 or phase > 1.0:
					continue
				var centre: Vector2 = _screen(src.lerp(dst, phase))
				_ellipse(canvas, centre, _n(3.0 + 5.0 * phase), Color(SOUND, 0.8 * (1.0 - absf(phase - 0.5))))
			if d._impacted:
				var centre: Vector2 = _screen(dst)
				for index: int in range(2):
					_ellipse(canvas, centre, _n(6.0 + fmod(d._rt * 40.0 + index * 6.0, 12.0)), Color(SOUND, 0.6 * (1.0 - d._rt / 0.6)))
		&"chameleon":
			if u < 0.3 or u > 1.0 or (d._split and d._reaction == &"swallow"):
				return
			var mouth: Vector3 = _mouth()
			var tip: Vector3 = mouth.lerp(_vc(0.55), _ease_out((u - 0.3) / 0.2))
			if d._impacted and d._reaction == &"swallow":
				var q: float = clampf(d._rt / split_time(), 0.0, 1.0)
				tip = _vc(0.5).lerp(mouth, _ease_in(q))
			_line(canvas, _screen(mouth), _screen(tip), Color("#d4607a"), 2.0)
			_px(canvas, _screen(tip), Color("#f08aa0"), 3.0)
		&"sentry", &"vanguard":
			if d._impacted and d._rt > 0.25:
				return
			var reach: float = 13.0 if d._attack_id == &"sentry" else 11.0
			var hand: Vector3 = Vector3(o.x, o.y + _ah(8.0 if d._attack_id == &"sentry" else 7.0), o.z)
			var tip: Vector3 = Vector3(hand.x + d._dir.x * _n(reach), hand.y, hand.z + d._dir.y * _n(reach))
			_line(canvas, _screen(hand), _screen(tip), Color("#cfc2a0"))
			_px(canvas, _screen(tip), Color.WHITE)
		&"falconer":
			_draw_bird(canvas, _falcon_at(u), sin(u * 40.0), Color("#c8a070"))
		&"squire":
			if u > 0.3 and u < 0.6:
				var hand: Vector3 = Vector3(o.x, o.y + _ah(7.0), o.z)
				_line(canvas, _screen(hand), _screen(Vector3(hand.x + d._dir.x * _n(8.0), hand.y, hand.z + d._dir.y * _n(8.0))), Color("#dfe6f0"))
			if u > 1.05 and u < 1.85:
				var k: float = (u - 1.05) / 0.8
				var arrow: Vector2 = _screen(Vector3(o.x, o.y + _ah(16.0), o.z)) - Vector2(0.0, k * _n(8.0))
				var color: Color = Color(1.0, 0.886, 0.47, 1.0 - k)
				canvas.draw_rect(Rect2(arrow, Vector2(1.0, 5.0) * d._unit), color)
				canvas.draw_rect(Rect2(arrow + Vector2(-1.0, 1.0) * d._unit, Vector2(3.0, 1.0) * d._unit), color)
				canvas.draw_rect(Rect2(arrow + Vector2(-2.0, 2.0) * d._unit, Vector2(5.0, 1.0) * d._unit), color)
		&"stand_in":
			if u < 0.25 or u > 0.72:
				return
			var hand: Vector3 = Vector3(o.x + face * _n(3.0), o.y + _ah(8.0), o.z)
			var hook: Vector3 = hand.lerp(_vc(0.6), _ease_out((u - 0.25) / 0.21)) if u < 0.46 else _vc(0.6)
			var from: Vector2 = _screen(hand)
			var to: Vector2 = _screen(hook)
			var sag: Vector2 = Vector2(0.0, _n(3.0) if u < 0.5 else 0.0)
			var rope: PackedVector2Array = PackedVector2Array()
			for index: int in range(9):
				var s: float = index / 8.0
				rope.append(from.lerp(to, s) + sag * 4.0 * s * (1.0 - s))
			canvas.draw_polyline(rope, Color("#8a7a5a"), maxf(d._unit, 1.0))
			_px(canvas, to, Color("#dfe6f0"), 3.0)
		&"powder_keg":
			if randf() < 0.6:
				_part(Vector3(o.x, o.y + _ah(13.0), o.z), Vector3(randf_range(-15.0, 15.0), randf_range(15.0, 40.0), 0.0), Color("#ffd27a") if randf() < 0.5 else Color("#ff8a3c"), randf_range(0.15, 0.3), 80.0)
		&"ember_bird":
			for index: int in range(3):
				var start: float = 0.3 + index * 0.14
				if u < start:
					continue
				var q: float = _q(u, start, 0.26)
				if q >= 1.0 and (not d._impacted or d._rt > 0.5):
					continue
				var p: Vector3 = Vector3(d._a.x + face * _n(2.0), _ah(9.0), d._a.z).lerp(_vc(0.3 + index * 0.2), q)
				p.y += d._cell * 0.4 * 4.0 * q * (1.0 - q)
				var at: Vector2 = _screen(p)
				canvas.draw_rect(Rect2(at - Vector2(1.5, 0.5) * d._unit, Vector2(3.0, 1.0) * d._unit), Color("#ff5a2a"))
				_px(canvas, at, Color("#ffd27a"))
				if q < 1.0 and randf() < 0.7:
					_part(p, Vector3(randf_range(-8.0, 8.0), randf_range(0.0, 10.0), 0.0), FIRE[1 + randi() % 2], randf_range(0.15, 0.3), -20.0)
		&"crystal_mage":
			if u < 0.1 or d._impacted:
				return
			var alpha: float = _q(u, 0.1, 0.2)
			for index: int in range(3):
				var at: Vector2 = _screen(_shard(index, u))
				canvas.draw_rect(Rect2(at - Vector2(0.5, 1.5) * d._unit, Vector2(1.0, 3.0) * d._unit), Color(0.75, 0.95, 1.0, alpha))
				canvas.draw_rect(Rect2(at - Vector2(1.5, 0.5) * d._unit, Vector2(3.0, 1.0) * d._unit), Color(0.75, 0.95, 1.0, alpha))
				_px(canvas, at, Color(1.0, 1.0, 1.0, alpha))
		&"ranger":
			var boomerang: Variant = _boomerang(u)
			if boomerang != null:
				var at: Vector2 = _screen(boomerang as Vector3)
				var spin: float = u * 40.0
				canvas.draw_rect(Rect2(at - Vector2(2.5, 2.5) * d._unit, Vector2(5.0, 5.0) * d._unit), Color(0.9, 0.86, 0.75, 0.35))
				for arm: float in [0.0, 1.6]:
					for step: float in [0.0, 1.0, 2.0]:
						_px(canvas, at + Vector2(cos(spin + arm), sin(spin + arm)) * step * d._unit, Color("#c8a070"))
		&"sun_moon_monk":
			if u > 0.3 and u < 0.62:
				var palm: Vector3 = Vector3(o.x + d._dir.x * _n(5.0), o.y + _ah(7.0), o.z + d._dir.y * _n(5.0))
				_px(canvas, _screen(palm), Color("#ffe08a") if u < 0.45 else Color("#a0c8ff"), 3.0)
		&"shadow_king":
			if u > 0.16 and u < 0.42:
				var q: float = (u - 0.16) / 0.26
				for index: int in range(4):
					var angle: float = index / 4.0 * TAU + 0.6
					var radius: float = d._cell * 1.6 * (1.0 - q)
					var at: Vector2 = _screen(Vector3(d._b.x + cos(angle) * radius, _vh(6.0), d._b.z + sin(angle) * radius))
					canvas.draw_circle(at, _n(4.0), Color(0.16, 0.1, 0.24, 0.35 * (1.0 - q * 0.5)))
					canvas.draw_circle(at, _n(2.0), Color(0.43, 0.35, 0.55, 0.5 * (1.0 - q * 0.5)))
		&"shield_king":
			if u < 0.7:
				var alpha: float = u / 0.1 if u < 0.1 else (1.0 if u < 0.5 else 1.0 - (u - 0.5) / 0.2)
				var centre: Vector2 = _screen(Vector3(o.x, o.y + _ah(7.0), o.z))
				_ellipse(canvas, centre, _n(10.5), Color(MOON, 0.5 * alpha))
				canvas.draw_circle(centre, _n(10.0), Color(MOON, 0.08 * alpha))
		&"lantern_bearer":
			if u < 0.1 or (d._impacted and d._rt > 0.7):
				return
			var lamp: Vector2 = _screen(Vector3(d._a.x + face * _n(5.0), _ah(12.0), d._a.z))
			var glow: float = _q(u, 0.1, 0.4)
			canvas.draw_circle(lamp, _n(3.0 + 4.0 * glow), Color(1.0, 0.86, 0.51, 0.25 * glow))
			if u > 0.45:
				var target: Vector2 = _screen(_vc(0.5))
				var beam: float = 1.0 - d._rt / 0.7 if d._impacted else _q(u, 0.45, 0.17)
				canvas.draw_colored_polygon(PackedVector2Array([lamp, target + Vector2(-7.0, -8.0) * d._unit, target + Vector2(7.0, 8.0) * d._unit]), Color(1.0, 0.925, 0.667, 0.22 * beam))
		&"martyr":
			if u < 0.08 or u > 0.95:
				return
			var hand: Vector3 = Vector3(d._a.x + face * _n(3.0), _ah(8.0), d._a.z)
			var censer: Vector3 = _censer(u)
			var from: Vector2 = _screen(hand)
			var to: Vector2 = _screen(censer)
			for index: int in range(0, 10, 2):
				canvas.draw_line(from.lerp(to, index / 10.0), from.lerp(to, (index + 1) / 10.0), Color("#b8a070"), maxf(d._unit, 1.0))
			canvas.draw_rect(Rect2(to - Vector2(2.5, 1.5) * d._unit, Vector2(5.0, 4.0) * d._unit), Color("#2a1e2e"))
			canvas.draw_rect(Rect2(to - Vector2(1.5, 0.5) * d._unit, Vector2(3.0, 2.0) * d._unit), Color("#e0b45c"))
			if randf() < 0.5:
				_part(censer, Vector3(randf_range(-4.0, 4.0), randf_range(4.0, 10.0), 0.0), Color(0.85, 0.83, 0.8, 0.6), randf_range(0.4, 0.7), -5.0, 2.0)
		&"stone_giant":
			var fists: Variant = _fists(u)
			if fists == null:
				return
			# Two big stone fists with knuckles, drawn in the piece's ivory stone.
			for side: float in [-1.0, 1.0]:
				var at: Vector2 = _screen((fists as Vector3) + Vector3(side * _n(4.5), 0.0, 0.0))
				canvas.draw_rect(Rect2(at - Vector2(4.5, 7.0) * d._unit, Vector2(9.0, 8.0) * d._unit), Color("#2a1e2e"))
				canvas.draw_rect(Rect2(at - Vector2(3.5, 6.0) * d._unit, Vector2(7.0, 6.0) * d._unit), Color("#d9c9a3"))
				canvas.draw_rect(Rect2(at - Vector2(3.5, 6.0) * d._unit, Vector2(7.0, 1.0) * d._unit), Color("#fff3d6"))
				canvas.draw_rect(Rect2(at - Vector2(3.5, 1.0) * d._unit, Vector2(7.0, 1.0) * d._unit), Color("#9c8a68"))
				for knuckle: int in range(3):
					canvas.draw_rect(Rect2(at + Vector2(-2.0 + knuckle * 2.0, -5.0) * d._unit, Vector2(1.0, 3.0) * d._unit), Color("#9c8a68"))
		&"blast_catapult":
			var shell: Array = _keg_shell(u)
			if shell.is_empty():
				return
			var at: Vector2 = _screen(shell[0])
			var flip: bool = floori(u * 20.0) % 2 == 0
			canvas.draw_rect(Rect2(at - Vector2(2.5, 2.5) * d._unit, Vector2(5.0, 5.0) * d._unit), Color("#2a1e2e"))
			canvas.draw_rect(Rect2(at - Vector2(1.5, 1.5) * d._unit, Vector2(3.0, 3.0) * d._unit), Color("#8a5a3a"))
			canvas.draw_rect(Rect2(at + Vector2(-1.5 if flip else -0.5, -1.5) * d._unit, Vector2(1.0, 3.0) * d._unit), Color("#e0b45c"))
			_part(shell[0] + Vector3(0.0, _n(3.0), 0.0), Vector3(randf_range(-10.0, 10.0), randf_range(0.0, 15.0), 0.0), _fire(), randf_range(0.15, 0.3), 60.0)
		&"sky_archer":
			var c: float = d._cell
			if u > 0.45 and u < 0.72:
				var y: float = _ah(14.0) + (u - 0.45) / 0.27 * c * 7.0
				var head: Vector2 = _screen(Vector3(d._a.x, y, d._a.z))
				_line(canvas, head + Vector2(0.0, _n(10.0)), head, Color("#ffe08a"))
				_px(canvas, head, Color.WHITE)
			if u > 0.68 and u < 0.9:
				var k: float = sin((u - 0.68) / 0.22 * PI)
				var star: Vector2 = _screen(Vector3(d._b.x, c * 5.0, d._b.z))
				var r: float = roundf(1.0 + 3.0 * k)
				canvas.draw_rect(Rect2(star + Vector2(-r - 0.5, -0.5) * d._unit, Vector2(2.0 * r + 1.0, 1.0) * d._unit), Color("#fff3c4"))
				canvas.draw_rect(Rect2(star + Vector2(-0.5, -r - 0.5) * d._unit, Vector2(1.0, 2.0 * r + 1.0) * d._unit), Color("#fff3c4"))
			if u > 0.86 and not d._impacted:
				var q: float = _q(u, 0.86, float(ATTACKS[&"sky_archer"]["impact"]) - 0.86)
				var at: Vector2 = _screen(Vector3(d._b.x, lerpf(c * 5.0, _vh(14.0), _ease_in(q)), d._b.z))
				canvas.draw_line(at - Vector2(0.0, _n(30.0)), at, Color(1.0, 0.886, 0.588, 0.45), 3.0 * d._unit)
				for index: int in range(1, 8):
					_px(canvas, at + Vector2(-index, -2.0 - index) * d._unit, Color("#ffd27a"))
					_px(canvas, at + Vector2(index, -2.0 - index) * d._unit, Color("#ffd27a"))
				canvas.draw_rect(Rect2(at + Vector2(-0.5, -6.0) * d._unit, Vector2(1.0, 7.0) * d._unit), Color("#fff3c4"))
		&"flame_phoenix":
			var wings: float = 0.0
			if u < 0.45:
				wings = _smooth(u / 0.45)
			elif u < 0.86:
				wings = 1.0
			elif u < 1.5:
				wings = 1.0 - 0.4 * (u - 0.86) / 0.64
			elif u < 1.75:
				wings = 0.6 * (1.0 - (u - 1.5) / 0.25)
			if wings > 0.0:
				var flap: float = sin(u * 22.0) * 2.0
				for side: float in [-1.0, 1.0]:
					for index: int in range(2, 11):
						var k: float = index / 10.0
						var at: Vector2 = _screen(Vector3(o.x + side * _n(index) * wings, o.y + _ah(8.0 + (5.0 * sin(k * PI) + flap * k) * wings), o.z))
						canvas.draw_rect(Rect2(at, Vector2(1.0, 2.0) * d._unit), FIRE[mini(3, index / 3)])
				if randf() < 0.8:
					_part(Vector3(o.x + randf_range(-9.0, 9.0) * d._unit * wings, o.y + _ah(randf_range(6.0, 12.0)), o.z), Vector3(randf_range(-6.0, 6.0), randf_range(5.0, 20.0), 0.0), _fire(), randf_range(0.2, 0.4), -30.0)
			if u > 0.45 and u < 0.86:
				for _i: int in range(2):
					_part(Vector3(o.x + randf_range(-2.0, 2.0) * d._unit, 0.0, o.z + randf_range(-2.0, 2.0) * d._unit), Vector3(randf_range(-3.0, 3.0), randf_range(8.0, 20.0), 0.0), _fire(), randf_range(0.4, 0.8), -25.0)
		&"thousand_faces":
			if u > 0.7 and u < 1.0:
				var middle: Vector3 = Vector3((o.x + d._b.x) * 0.5, 0.0, (o.z + d._b.z) * 0.5)
				for index: int in range(16):
					if randf() < 0.3:
						continue
					var at: Vector2 = _screen(Vector3(middle.x, _vh(index), middle.z))
					canvas.draw_rect(Rect2(at - Vector2(2.5, 0.0) * d._unit, Vector2(5.0, 1.0) * d._unit), Color(0.78, 0.7, 1.0, 0.7) if index % 3 != 0 else Color(1.0, 1.0, 1.0, 0.9))
			_update_phantom()
			var absorb: float = _absorb_at()
			if u > absorb and u < absorb + 0.3 and randf() < 0.6:
				d.fx.spark_burst(Vector3(o.x, _ah(8.0), o.z), 2, Vector2.ZERO, 0.0, 0.4, VIOLET)

func _draw_reaction_air(canvas: CanvasItem) -> void:
	if not d._impacted:
		return
	var rt: float = d._rt
	var b: Vector3 = d._b
	match d._reaction:
		&"erupt":
			if rt > 1.1:
				return
			var k: float = rt / 0.12 if rt < 0.12 else (1.0 if rt < 0.7 else 1.0 - (rt - 0.7) / 0.4)
			for index: int in range(7):
				var angle: float = index / 7.0 * TAU
				var radius: float = d._cell * (0.22 if index % 2 == 1 else 0.32)
				var foot: Vector2 = d._proj.project(Vector3(b.x + cos(angle) * radius, 0.0, b.z + sin(angle) * radius))
				var height: int = roundi((7.0 if index % 2 == 1 else 10.0) * k)
				for y: int in range(height):
					var width: float = maxf(1.0, roundf((height - y) / 3.0))
					canvas.draw_rect(Rect2(foot + Vector2(-width * 0.5, -y - 1.0) * d._unit, Vector2(width, 1.0) * d._unit), Color("#bdbbc1") if y == height - 1 else Color("#6b6970"))
		&"skewer":
			if rt > 1.6:
				return
			var alpha: float = 1.0 if rt < 1.0 else 1.0 - (rt - 1.0) / 0.6
			var foot: Vector2 = _screen(Vector3(b.x, 0.0, b.z))
			var top: Vector2 = _screen(Vector3(b.x, d._victim_at(1.0) + _vh(8.0), b.z))
			_line(canvas, foot, top, Color(1.0, 0.878, 0.541, alpha))
			canvas.draw_rect(Rect2(top + Vector2(-1.5, 0.0) * d._unit, Vector2(3.0, 1.0) * d._unit), Color(1.0, 0.965, 0.847, alpha))
			canvas.draw_rect(Rect2(top + Vector2(-2.5, 1.0) * d._unit, Vector2(5.0, 1.0) * d._unit), Color(1.0, 0.965, 0.847, alpha))
		&"inferno":
			var split: float = split_time()
			if rt > split + 0.5:
				return
			var grow: float = clampf(rt / 0.15, 0.0, 1.0)
			var fade: float = 1.0 - (rt - split) / 0.5 if rt > split else 1.0
			var foot: Vector2 = _screen(Vector3(b.x, 0.0, b.z))
			for dx: int in range(-5, 6):
				var height: float = 30.0 * grow * (1.0 - absf(dx) / 6.0) * (0.75 + 0.25 * sin(rt * 35.0 + dx * 1.7))
				var green: float = 0.9 if absi(dx) < 2 else (0.63 if absi(dx) < 4 else 0.35)
				canvas.draw_rect(Rect2(foot + Vector2(dx, -height) * d._unit, Vector2(1.0, height) * d._unit), Color(1.0, green, 0.24, 0.55 * fade))
		&"ember":
			if not d._split:
				return
			var k: float = clampf((rt - 0.7) / 0.4, 0.0, 1.0)
			if k <= 0.0:
				return
			var at: Vector2 = _screen(Vector3(b.x, 0.0, b.z))
			var pulse: float = 0.6 + 0.4 * sin(rt * 8.0)
			canvas.draw_circle(at - Vector2(0.0, _n(4.0)), _n(6.0), Color(1.0, 0.59, 0.24, 0.3 * pulse * k))
			canvas.draw_rect(Rect2(at + Vector2(-2.0, -8.0) * d._unit, Vector2(5.0, 8.0) * d._unit), Color(0.165, 0.118, 0.18, k))
			canvas.draw_rect(Rect2(at + Vector2(-1.0, -7.0) * d._unit, Vector2(3.0, 6.0) * d._unit), Color(1.0, 0.7, 0.36, k))
			canvas.draw_rect(Rect2(at + Vector2(-1.0, -6.0) * d._unit, Vector2(1.0, 2.0) * d._unit), Color(1.0, 0.94, 0.69, k))
		&"chip":
			var at: Vector2 = _screen(Vector3(b.x, d._victim_at(1.0) + _vh(4.0), b.z))
			for index: int in range(3):
				var pip: Vector2 = at + Vector2(-4.0 + index * 4.0, 0.0) * d._unit
				var lost: bool = index == 0 and rt > 0.35
				canvas.draw_rect(Rect2(pip - Vector2(1.5, 1.5) * d._unit, Vector2(3.0, 3.0) * d._unit), Color("#0d0a14"))
				_px(canvas, pip, Color("#3a3540") if lost else Color("#bdbbc1"))
		&"rebirth":
			if not d._split:
				return
			var q: float = clampf((rt - 0.25) / 0.8, 0.0, 1.0)
			var home: Vector3 = _rebirth_corner()
			if q < 1.0:
				var p: Vector3 = Vector3(b.x, _vh(8.0), b.z).lerp(Vector3(home.x, _vh(5.0), home.z), _smooth(q))
				p.y += d._cell * 3.0 * sin(q * PI)
				var at: Vector2 = _screen(p)
				canvas.draw_circle(at, _n(5.0), Color(1.0, 0.59, 0.24, 0.35))
				canvas.draw_rect(Rect2(at - Vector2(2.5, 2.5) * d._unit, Vector2(5.0, 5.0) * d._unit), Color("#ff8a3c"))
				canvas.draw_rect(Rect2(at - Vector2(1.5, 1.5) * d._unit, Vector2(3.0, 3.0) * d._unit), Color("#fff0b0"))
				_part(p, Vector3(randf_range(-6.0, 6.0), randf_range(-4.0, 8.0), 0.0), _fire(), randf_range(0.25, 0.45), -10.0)
				if q > 0.97 and _once(&"landed"):
					d.fx.ring(home.x, home.z, d._cell * 0.6, 0.4, ORANGE)
					d.fx.spark_burst(d._up(home, 4.0), 10, Vector2.ZERO, 0.0, 0.6, ORANGE)
				return
			var foot: Vector2 = _screen(Vector3(home.x, 0.0, home.z))
			var pulse: float = 0.6 + 0.4 * sin(rt * 9.0)
			canvas.draw_circle(foot - Vector2(0.0, _n(4.0)), _n(6.0), Color(1.0, 0.59, 0.24, 0.3 * pulse))
			for index: int in range(-2, 3):
				var height: float = roundf((6.0 - absi(index) * 2.0) * (0.8 + 0.2 * sin(rt * 20.0 + index)))
				canvas.draw_rect(Rect2(foot + Vector2(index, -height) * d._unit, Vector2(1.0, height) * d._unit), Color("#fff0b0") if index == 0 else Color("#ff8a3c"))

func _ellipse(canvas: CanvasItem, centre: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(21):
		var angle: float = TAU * index / 20.0
		points.append(centre + Vector2(cos(angle) * radius, sin(angle) * radius * 0.7))
	canvas.draw_polyline(points, color, maxf(d._unit, 1.0))

func _draw_bird(canvas: CanvasItem, at: Vector3, flap: float, color: Color) -> void:
	var centre: Vector2 = _screen(at)
	var wing: float = -1.0 if flap > 0.0 else 1.0
	canvas.draw_rect(Rect2(centre - Vector2(1.5, 1.5) * d._unit, Vector2(3.0, 3.0) * d._unit), Color("#2a1e2e"))
	_px(canvas, centre, color)
	canvas.draw_rect(Rect2(centre + Vector2(-3.5, wing - 0.5) * d._unit, Vector2(2.0, 1.0) * d._unit), Color("#2a1e2e"))
	canvas.draw_rect(Rect2(centre + Vector2(1.5, wing - 0.5) * d._unit, Vector2(2.0, 1.0) * d._unit), Color("#2a1e2e"))
	_px(canvas, centre + Vector2(2.0 * d._face, 0.0) * d._unit, Color("#e0b45c"))

## The falcon leaves the arm, arcs over, dives into the target and flies back.
func _falcon_at(u: float) -> Vector3:
	var arm: Vector3 = Vector3(d._a.x + d._face * _n(4.0), _ah(11.0), d._a.z)
	var hit: Vector3 = _vc(0.6)
	var top: Vector3 = Vector3((arm.x + hit.x) * 0.5, d._cell * 2.2, (arm.z + hit.z) * 0.5)
	if u < 0.3:
		return arm
	if u < 0.62:
		var q: float = (u - 0.3) / 0.32
		return arm.lerp(top, q).lerp(top.lerp(hit, q), _ease_in(q))
	if u < 0.75:
		return hit + Vector3(0.0, (u - 0.62) * 30.0 * d._unit, 0.0)
	if u < 1.1:
		var q: float = (u - 0.75) / 0.35
		var from: Vector3 = hit + Vector3(0.0, _n(4.0), 0.0)
		var p: Vector3 = from.lerp(arm, _smooth(q))
		p.y = lerpf(from.y, arm.y, q) + d._cell * 1.2 * 4.0 * q * (1.0 - q)
		return p
	return arm

func _shard(index: int, u: float) -> Vector3:
	var angle: float = u * 9.0 + index * 2.1
	var home: Vector3 = Vector3(d._a.x + cos(angle) * _n(7.0), _ah(13.0) + sin(angle * 0.7) * _n(2.0), d._a.z + sin(angle) * _n(3.0))
	var start: float = 0.5 + index * 0.055
	if u < start:
		return home
	return home.lerp(_vc(0.5), _ease_in((u - start) / 0.11))

func _boomerang(u: float) -> Variant:
	if u < 0.38 or u > 1.12:
		return null
	var hand: Vector3 = Vector3(d._a.x + d._face * _n(3.0), _ah(9.0), d._a.z)
	var target: Vector3 = _vc(0.5)
	var side: Vector3 = Vector3(-d._dir.y, 0.0, d._dir.x) * d._cell * 1.2
	var q: float = (u - 0.38) / 0.74
	var angle: float = q * TAU
	var along: float = (1.0 - cos(angle)) * 0.5
	var out: float = sin(angle)
	var far: Vector3 = Vector3(target.x + d._dir.x * _n(6.0), target.y, target.z + d._dir.y * _n(6.0))
	var p: Vector3 = hand.lerp(far, along) + side * out * 0.5
	p.y = lerpf(hand.y, target.y, minf(1.0, along * 1.2)) + _n(3.0) * sin(angle)
	return p

func _censer(u: float) -> Vector3:
	var hand: Vector3 = Vector3(d._a.x + d._face * _n(3.0), _ah(8.0), d._a.z)
	if u < 0.1:
		return hand
	if u < 0.45:
		var angle: float = (u - 0.1) / 0.35 * PI * 4.0
		return hand + Vector3(cos(angle) * _n(6.0), _n(2.0) + sin(angle) * _n(2.0), sin(angle) * _n(6.0) * 0.6)
	var hit: Vector3 = _vc(0.6)
	if u < 0.6:
		var q: float = _ease_in((u - 0.45) / 0.15)
		var p: Vector3 = hand.lerp(hit, q)
		p.y += d._cell * 0.6 * sin(q * PI)
		return p
	if u < 0.9:
		return hit.lerp(hand, _smooth((u - 0.6) / 0.3))
	return hand

func _fists(u: float) -> Variant:
	if u < 0.76 or u > 1.95:
		return null
	var o: StrikeDirector.Pose = d._pose
	var shoulder: Vector3 = Vector3(o.x, o.y + _ah(14.0), o.z)
	var overhead: Vector3 = Vector3(o.x, o.y + _ah(22.0), o.z)
	var squash: float = _flatten_y() if d._impacted and d._reaction == &"flatten" else 1.0
	var top: Vector3 = Vector3(d._b.x, d._victim_at(squash) + _n(1.0), d._b.z)
	if u < 0.9:
		return shoulder.lerp(overhead, _smooth((u - 0.76) / 0.14))
	if u < 1.0:
		var q: float = _ease_in((u - 0.9) / 0.1)
		var p: Vector3 = overhead.lerp(top, q)
		p.y += d._cell * 0.8 * sin(q * PI)
		return p
	if u < 1.75:
		return top
	return top.lerp(shoulder, _smooth((u - 1.75) / 0.2))

## [world position, progress] of the powder keg in flight, or [] when not flying.
func _keg_shell(u: float) -> Array:
	var land: float = float(ATTACKS[&"blast_catapult"]["impact"])
	if u < 0.42 or u > land:
		return []
	var q: float = (u - 0.42) / (land - 0.42)
	var p: Vector3 = Vector3(d._a.x, _ah(15.0), d._a.z).lerp(Vector3(d._b.x, _vh(4.0), d._b.z), q)
	p.y += d._cell * 3.2 * 4.0 * q * (1.0 - q)
	return [p, q]

## The Flame Phoenix flies back to its own corner to wait for rebirth.
func _rebirth_corner() -> Vector3:
	var size: int = d._proj.board_size
	var corner: Vector2i = Vector2i(0, 0) if d._b.z >= 0.0 else Vector2i(size - 1, size - 1)
	return d._proj.square_world(corner)

## Thousand Faces: the victim's likeness lifts off as a white phantom and drifts into it.
func _update_phantom() -> void:
	if not d._impacted or d._split or d._reaction != &"mimic":
		if is_instance_valid(_phantom):
			_phantom.visible = false
		return
	if not is_instance_valid(_phantom):
		_phantom = d._view.make_piece_sprite(d._victim_texture)
		_phantom_material = d._piece_material(d._victim_chunks)
		_phantom_material.set_shader_parameter(&"flash", 1.0)
		_phantom.material = _phantom_material
		_phantom.z_index = 3
		d._view.piece_layer().add_child(_phantom)
	var q: float = clampf(d._rt / split_time(), 0.0, 1.0)
	var lift: float = (d._victim_at(1.0) + _n(4.0)) * _smooth(q / 0.35)
	var k: float = _smooth((q - 0.35) / 0.65)
	var spot: Vector3 = Vector3(d._b.x, 0.0, d._b.z).lerp(Vector3(d._pose.x, 0.0, d._pose.z), k)
	spot.y = lift * (1.0 - k) + _n(4.0) * k + d._cell * 0.5 * sin(k * PI)
	var ground: Vector3 = Vector3(spot.x, 0.0, spot.z + d._stand)
	var scale_value: float = float(_phantom.get_meta("base_scale", 1.0)) * d._proj.scale_at(ground) * (1.0 - 0.2 * k)
	_phantom.visible = true
	_phantom.position = d._proj.project(Vector3(ground.x, spot.y, ground.z))
	_phantom.scale = Vector2(scale_value, scale_value)
	_phantom_material.set_shader_parameter(&"alpha", 0.55 + 0.3 * clampf(q / 0.35, 0.0, 1.0))
