class_name StrikeAttack
extends RefCounted

## The attacker's half of a strike animation: its timing, how it moves (pose), the
## effects on its timeline and at the moment of impact, and anything it draws (a lance,
## an arrow, a beam). One subclass per attack in scripts/battle/strike/attacks/, listed
## in StrikeLibrary. The director creates one for every strike and gives it the
## strike's StrikeStage `s`; everything shared lives there.
##
## Conventions (from the prototypes in docs/prototypes/): `u` is seconds since the
## strike started at 1x speed, plain numbers are design units (1/18 of a cell) scaled
## by `s.unit`.

var s: StrikeStage = null

## {"impact", "done", "end", "hitstop", "shake"}: when the blow lands, when the
## attacker has settled, the hard cap (all in seconds), the hit-stop and the shake.
func timing() -> Dictionary:
	return {}

## When the attacker has settled; the timing's "done" unless it depends on the strike.
func done_time() -> float:
	return float(timing()["done"])

## The turning square of a bent move, when this attack decides it (null otherwise).
func corner(_from: Vector2i, _to: Vector2i) -> Variant:
	return null

## Timings that depend on the victim's weight or on how far the attacker travels.
## Returns true when it changed them (the end time then makes room for them).
func adjust_timing() -> bool:
	return false

## Whether the attacker springs back from a shell that absorbed the blow.
func keeps_bounce() -> bool:
	return true

## Effects on the timeline before the impact: [[seconds, Callable], ...].
func events() -> Array:
	return []

func pose(_u: float, _o: StrikePose) -> void:
	pass

func impact() -> void:
	pass

func draw_ground(_canvas: CanvasItem) -> void:
	pass

func draw_air(_canvas: CanvasItem) -> void:
	pass

## Ghosts left behind while the pose asks for a trail, and how their alpha steps.
func trail_limit() -> int:
	return 7

func ghost_alpha_step() -> float:
	return 0.05

## The strike's actors are being removed: free anything this attack added itself.
func clear() -> void:
	pass

# --- pose builders shared by several attacks ---------------------------------------

## Wind up backwards, dash in, squash on contact, settle onto the destination.
func dash(u: float, o: StrikePose, back: float, windup: float, dash_time: float, contact: float, settle: float = 0.3, hop: float = 1.5, white: float = 0.0, bob: float = 0.0) -> void:
	var start: Vector3 = s.along(s.a, -s.cell * back)
	var hit: Vector3 = s.toward(contact)
	var squash: float = 0.1
	if u < windup:
		var q: float = s.ease_out01(u / windup)
		o.at(s.a.lerp(start, q))
		o.sx = 1.0 + 0.08 * q
		o.sy = 1.0 - 0.1 * q
		o.white = white * q * (0.7 + 0.3 * sin(u * 50.0))
		return
	if u < windup + dash_time:
		var q: float = (u - windup) / dash_time
		o.at(start.lerp(hit, s.ease_in01(q)))
		o.sx = 0.92
		o.sy = 1.08
		o.trail = true
		o.y = s.n(bob) * absf(sin(q * PI * 3.0))
		return
	if u < windup + dash_time + squash:
		var q: float = (u - windup - dash_time) / squash
		o.at(hit)
		o.sx = 1.0 + 0.2 * sin(q * PI)
		o.sy = 1.0 - 0.18 * sin(q * PI)
		return
	s.settle_into(o, hit, u, windup + dash_time + squash, settle, hop)

## Stays put to shoot or throw, recoils, then walks onto the destination (which is its
## own square after a ranged capture).
func ranged(u: float, o: StrikePose, windup: float, recoil: float, walk_at: float, walk: float, lean: float) -> void:
	if u < windup:
		var sway: float = sin(clampf(u / (windup * 0.9), 0.0, 1.0) * PI * 0.5)
		o.rot = -lean * sway * s.face
		o.sy = 1.0 + 0.05 * sway
		return
	if u < windup + recoil:
		var q: float = (u - windup) / recoil
		o.at(s.along(s.a, -s.n(2.5) * sin(q * PI)))
		o.rot = lerpf(lean * 0.8, 0.0, q) * s.face
		return
	if u < walk_at:
		return
	var q: float = s.progress(u, walk_at, walk)
	o.at(s.a.lerp(s.dest, s.smooth01(q)))
	o.y = absf(sin(q * PI * 3.0)) * s.n(2.0)
