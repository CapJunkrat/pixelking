class_name StrikeStage
extends RefCounted

## Everything one strike animation shares between the director and the two halves of
## the choreography (StrikeAttack and StrikeReaction): where the actors stand, the
## clock, the effects, the sprites and the bodies the victim breaks into, plus the
## helpers they all use. The director owns one stage, resets it at the start of every
## strike and steps it; attacks and reactions read and change it through `s`.
##
## Units: positions are world units on the board plane (y is height); "design units"
## are 1/18 of a cell (`unit`), as in the prototypes in docs/prototypes/.

const PIECE_SHADER: Shader = preload("res://assets/shaders/strike_piece.gdshader")

var view: BattleBoardView = null
var proj: BoardProjection = null
var fx: StrikeFx = StrikeFx.new()
## Plays only the victim's side of a strike (an extra victim of the same blow, such
## as every enemy a boomerang passes through): no attacker, no camera, no attack art.
var victim_only: bool = false
## A returning strike may lose its attacker to a death effect before it can return.
var returning_attacker_alive: bool = true
## Where the victim's egg is laid (Ember Bird / Flame Phoenix), set before play().
var egg_square: Vector2i = Vector2i(-1, -1)
## The captured piece drawn in the attacker's colours (Thousand Faces wears it briefly).
var mimic_texture: Texture2D = null

var attack_id: StringName = &""
## The attack's timing (StrikeAttack.timing()).
var attack: Dictionary = {}
var attack_obj: StrikeAttack = null
var reaction: StringName = &""
var reaction_obj: StrikeReaction = null
var strike_type: int = PieceDef.StrikeType.NONE
var underdog: bool = false
var power: float = 1.0
var victim_weight: int = PieceDef.WeightClass.MEDIUM
var attacker_height: float = 0.0
var play_speed: float = 1.0
var to_square: Vector2i = Vector2i(-1, -1)
## Set when the attacker is destroyed with its victim (Powder Keg).
var attacker_gone: bool = false

var cell: float = 36.0
var unit: float = 2.0
var stand: float = 0.0
## Attacker's square, victim's square, the attacker's destination and the turning
## point of a bent move, in world units.
var a: Vector3 = Vector3.ZERO
var b: Vector3 = Vector3.ZERO
var dest: Vector3 = Vector3.ZERO
var corner: Vector3 = Vector3.ZERO
## Attack direction on the board, and which way the attacker faces on screen (+1 / -1).
var dir: Vector2 = Vector2.RIGHT
var face: float = 1.0
var slash_angle: float = 0.0

## Strike clock (seconds since the start), remaining hit-stop, and seconds since impact.
var t: float = 0.0
var hs: float = 0.0
var rt: float = -1.0
var impacted: bool = false
var split: bool = false
var impact_time: float = 0.0
var done_time: float = 0.0
var end_time: float = 0.0
var settle_time: float = 0.0
var shake: float = 0.0
var punch: float = 0.0
var flash: float = 0.0
var slash_age: float = -1.0
var wobble_time: float = -9.0
var rows_broken: int = 0
var brick_out: bool = false

var attacker_texture: Texture2D = null
var victim_texture: Texture2D = null
var victim_chunks: PieceChunks = null
var victim_height: float = 0.0
var jag_seed: float = 0.0
var jag_base: float = 0.42
var plane_origin: Vector2 = Vector2(0.5, 0.55)
var brick: Rect2 = Rect2()

var attacker: Sprite2D = null
var attacker_material: ShaderMaterial = null
var victim: Sprite2D = null
var victim_material: ShaderMaterial = null
var bodies: Array[StrikeBody] = []
## The attacker's pose this frame.
var pose: StrikePose = StrikePose.new()
## The attacker's pose at any time of the strike (the director's), for a body carried
## along with it.
var pose_at: Callable = Callable()
## Keys of one-off effects that already went off this strike (see once()).
var _done: Dictionary = {}

## Forgets what the last strike set off.
func reset_strike() -> void:
	_done = {}
	attacker_gone = false

## Seconds after impact at which the standing victim falls apart.
func split_time() -> float:
	return reaction_obj.split_time()

## World height of whatever is left of the victim, so a stomping piece can ride it down.
func victim_top() -> float:
	if not impacted:
		return proj.height_for_pixels(victim_height)
	if split:
		return 0.0
	return proj.height_for_pixels(maxf(reaction_obj.standing_pixels(), 0.0))


# --- geometry -------------------------------------------------------------------

## `point` lifted by `height` design units.
func up(point: Vector3, height: float) -> Vector3:
	return Vector3(point.x, height * unit, point.z)

## `point` moved `distance` world units along the attack direction.
func along(point: Vector3, distance: float) -> Vector3:
	return Vector3(point.x + dir.x * distance, point.y, point.z + dir.y * distance)

## Where a sprite standing on `point` puts its feet.
func foot(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z + stand)

func on_board(point: Vector3) -> bool:
	var half: float = proj.board_size * cell * 0.5
	return absf(point.x) < half and absf(point.z) < half

## Height of a fraction of the attacker / victim sprite, in world units.
func attacker_at(fraction: float) -> float:
	return proj.height_for_pixels(attacker_height * fraction)

func victim_at(fraction: float) -> float:
	return proj.height_for_pixels(victim_height * fraction)

func screen_dir() -> Vector2:
	var line: Vector2 = proj.project(b) - proj.project(a)
	return line.normalized() if line.length() > 0.001 else Vector2.RIGHT

func victim_centre(fraction: float = 0.5) -> Vector2:
	return proj.project(Vector3(b.x, victim_at(fraction), b.z + stand))

## A point `cells` cells short of the target along the attack line.
func toward(cells: float) -> Vector3:
	return along(b, -cell * cells)

func screen(point: Vector3) -> Vector2:
	return proj.project(Vector3(point.x, point.y, point.z + stand))

func vc(fraction: float = 0.5) -> Vector3:
	return Vector3(b.x, victim_at(fraction), b.z)

# --- units, easing and timing -------------------------------------------------------

func n(value: float) -> float:
	return value * unit

## Height of `px` rows of the 12-row prototype sprite, on the attacker / victim.
func ah(px: float) -> float:
	return attacker_at(px / 12.0)

func vh(px: float) -> float:
	return victim_at(px / 12.0)

func weight3(values: Array) -> float:
	return float(values[clampi(victim_weight, 0, 2)])

func progress(u: float, start: float, length: float) -> float:
	return clampf((u - start) / length, 0.0, 1.0)

func smooth(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)

func ease_out(u: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u)

func ease_in(u: float) -> float:
	return u * u

## Clamped to 0..1 first (the new pieces' prototypes use these).
func smooth01(u: float) -> float:
	return smooth(clampf(u, 0.0, 1.0))

func ease_in01(u: float) -> float:
	return ease_in(clampf(u, 0.0, 1.0))

func ease_out01(u: float) -> float:
	return ease_out(clampf(u, 0.0, 1.0))

func absorb_duration() -> float:
	return [0.55, 0.75, 1.0][victim_weight]

func melt_duration() -> float:
	return [0.7, 0.9, 1.15][victim_weight]

func arcane_duration() -> float:
	return [0.4, 0.55, 0.75][victim_weight]

func arcane_lift() -> float:
	var q: float = clampf(rt / arcane_duration(), 0.0, 1.0)
	return cell * 0.38 * ease_out(q) * (0.45 if victim_weight == PieceDef.WeightClass.HEAVY else 1.0)

func burn_time() -> float:
	return weight3([0.6, 0.8, 1.0])

func flatten_y() -> float:
	return lerpf(1.0, 0.2, ease_out01(rt / (split_time() - 0.05)))

func once(key: StringName) -> bool:
	if _done.has(key):
		return false
	_done[key] = true
	return true

func settle_into(o: StrikePose, start: Vector3, u: float, at: float, duration: float, hop: float) -> void:
	var q: float = clampf((u - at) / duration, 0.0, 1.0)
	o.at(start.lerp(dest, smooth(q)))
	o.y = hop * unit * sin(q * PI)

func mouth() -> Vector3:
	return Vector3(pose.x + dir.x * n(5.0), pose.y + ah(7.0), pose.z + dir.y * n(5.0))

## Where a fallen Ember Bird / Flame Phoenix waits for rebirth: the square its egg was
## laid on (from the move result), else its own corner.
func rebirth_corner() -> Vector3:
	if egg_square.x >= 0:
		return proj.square_world(egg_square)
	var size: int = proj.board_size
	var own_corner: Vector2i = Vector2i(0, 0) if b.z >= 0.0 else Vector2i(size - 1, size - 1)
	return proj.square_world(own_corner)

# --- effects --------------------------------------------------------------------

func event_puff(at: Vector3, count: int, big: float) -> void:
	fx.puff(at, count, big)

func event_sparks(at: Vector3, count: int, bias: float, speed: float) -> void:
	fx.spark_burst(at, count, dir, bias, speed)

func ring_at(at: Vector3, cells: float, life: float, color: Color) -> void:
	fx.ring(at.x, at.z, cell * cells, life, color)

func part(at: Vector3, velocity: Vector3, color: Color, life: float, gravity: float, size: float = 1.0) -> void:
	fx.add_part(Vector3(at.x, at.y, at.z + stand), velocity * unit, color, size * unit, life, gravity * unit)

func fire_color() -> Color:
	return StrikePalette.FIRE[randi() % StrikePalette.FIRE.size()]

func set_tint(material: ShaderMaterial, color: Color, amount: float) -> void:
	material.set_shader_parameter(&"tint", color)
	material.set_shader_parameter(&"tint_amount", amount)

# --- drawing --------------------------------------------------------------------

func pixel(canvas: CanvasItem, at: Vector2, color: Color, size: float = 1.0) -> void:
	var side: float = size * unit
	canvas.draw_rect(Rect2(at - Vector2(side, side) * 0.5, Vector2(side, side)), color)

func pixel_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	canvas.draw_line(from, to, color, maxf(width * unit, 1.0))

func ellipse(canvas: CanvasItem, centre: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(21):
		var angle: float = TAU * index / 20.0
		points.append(centre + Vector2(cos(angle) * radius, sin(angle) * radius * 0.7))
	canvas.draw_polyline(points, color, maxf(unit, 1.0))

func ground_disc(canvas: CanvasItem, centre: Vector3, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * index / 24.0
		points.append(proj.project(Vector3(centre.x + cos(angle) * radius, 0.0, centre.z + sin(angle) * radius)))
	canvas.draw_colored_polygon(points, color)

func ground_dots(canvas: CanvasItem, centre: Vector3, radius: float, count: int, turn: float, color: Color) -> void:
	for index: int in range(count):
		var angle: float = TAU * index / count + turn
		var dot: Vector2 = proj.project(Vector3(centre.x + cos(angle) * radius, 0.0, centre.z + sin(angle) * radius))
		canvas.draw_rect(Rect2(dot - Vector2(0.5, 0.5) * unit, Vector2(unit, unit)), color)

# --- the victim's pieces -----------------------------------------------------------

func piece_material(chunks: PieceChunks) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PIECE_SHADER
	material.set_shader_parameter(&"used", chunks.used_uv())
	material.set_shader_parameter(&"aspect", chunks.aspect)
	material.set_shader_parameter(&"grid", float(PieceChunks.ROWS))
	material.set_shader_parameter(&"plane_origin", plane_origin)
	material.set_shader_parameter(&"plane_dir", Vector2(cos(slash_angle), sin(slash_angle)))
	material.set_shader_parameter(&"jag_base", jag_base)
	material.set_shader_parameter(&"jag_seed", jag_seed)
	material.set_shader_parameter(&"crack_from_right", 1.0 if face < 0.0 else 0.0)
	material.set_shader_parameter(&"hole_center", Vector2(chunks.aspect * 0.5, 0.5))
	material.set_shader_parameter(&"brick", Vector4(brick.position.x, brick.position.y, brick.end.x, brick.end.y))
	return material

func jag(x: float) -> float:
	var q: float = (floorf(x * PieceChunks.ROWS) + 0.5) / PieceChunks.ROWS
	var row: float = floorf(jag_base * PieceChunks.ROWS) + floorf(sin(q * 19.0 + jag_seed) * 1.6 + 0.5) + floorf(sin(q * 47.0 + jag_seed * 1.7) * 0.9 + 0.5)
	return (row + 0.5) / PieceChunks.ROWS

## Script-side mirror of the cuts the strike shader makes for the same `mask`.
func mask_keeps(mask: Dictionary, p: Vector2) -> bool:
	var plane_keep: float = float(mask.get("plane_keep", 0.0))
	if plane_keep != 0.0:
		var side: float = (p.x - plane_origin.x) * sin(slash_angle) - (p.y - plane_origin.y) * cos(slash_angle)
		if side * plane_keep < 0.6 / PieceChunks.ROWS:
			return false
	var jag_keep: float = float(mask.get("jag_keep", 0.0))
	if jag_keep > 0.0 and p.y > jag(p.x) - 0.25 / PieceChunks.ROWS:
		return false
	if jag_keep < 0.0 and p.y < jag(p.x) + 0.25 / PieceChunks.ROWS:
		return false
	var brick_mode: float = float(mask.get("brick_mode", 0.0))
	if brick_mode > 0.5:
		var inside: bool = p.x >= brick.position.x and p.x <= brick.end.x and p.y >= brick.position.y and p.y <= brick.end.y
		if (brick_mode < 1.5 and inside) or (brick_mode > 1.5 and not inside):
			return false
	return true

func select(keep: Callable) -> PackedInt32Array:
	var indices: PackedInt32Array = PackedInt32Array()
	for index: int in range(victim_chunks.points.size()):
		if keep.call(victim_chunks.points[index]):
			indices.append(index)
	return indices

func foot_pivot() -> Vector2:
	return Vector2(victim_chunks.aspect * 0.5, 1.0)

func random_chunk() -> int:
	return randi() % victim_chunks.points.size() if victim_chunks.points.size() > 0 else -1

## A part of the victim that moves on its own. `pivot` defaults to the part's centroid.
func make_body(mask: Dictionary, pivot: Variant = null) -> StrikeBody:
	var body: StrikeBody = StrikeBody.new()
	body.indices = select(func(p: Vector2) -> bool: return mask_keeps(mask, p))
	if pivot == null:
		var sum: Vector2 = Vector2.ZERO
		for index: int in body.indices:
			sum += victim_chunks.points[index]
		body.pivot = sum / maxf(body.indices.size(), 1.0) if not body.indices.is_empty() else foot_pivot()
	else:
		body.pivot = pivot
	body.material = piece_material(victim_chunks)
	for key: String in mask:
		body.material.set_shader_parameter(StringName(key), mask[key])
	body.sprite = view.make_piece_sprite(victim_texture)
	body.sprite.material = body.material
	body.sprite.offset = -(Vector2(victim_chunks.used.position) + body.pivot * float(victim_chunks.used.size.y))
	body.sprite.z_index = victim.z_index
	body.x = b.x + (body.pivot.x - victim_chunks.aspect * 0.5) * victim_height
	body.y = proj.height_for_pixels((1.0 - body.pivot.y) * victim_height)
	body.z = b.z
	view.piece_layer().add_child(body.sprite)
	bodies.append(body)
	place_body(body)
	return body

## A body that topples over the base corner facing away from the attacker.
func make_tip_body(mask: Dictionary, start_speed: float, accel: float, slide: float, land_shake: float, big: bool) -> void:
	var base_corner: Vector2 = Vector2(victim_chunks.aspect if face > 0.0 else 0.0, 1.0)
	var body: StrikeBody = make_body(mask, base_corner)
	body.kind = &"tip"
	body.tip_speed = start_speed
	body.tip_accel = accel
	body.slide = slide * unit
	body.land_shake = land_shake
	body.land_big = big

func split_along_slash(heavy: bool) -> void:
	var first: StrikeBody = make_body({"plane_keep": -1.0})
	var second: StrikeBody = make_body({"plane_keep": 1.0})
	var upper: StrikeBody = first if first.pivot.y <= second.pivot.y else second
	var lower: StrikeBody = second if upper == first else first
	var normal: Vector2 = Vector2(-sin(slash_angle), cos(slash_angle))
	if normal.dot(upper.pivot - lower.pivot) < 0.0:
		normal = -normal
	var tangent: Vector2 = Vector2(cos(slash_angle), sin(slash_angle))
	if tangent.y < 0.0:
		tangent = -tangent
	for body: StrikeBody in [upper, lower]:
		body.glow = true
		body.heavy = heavy
		body.normal = normal
		body.tangent = tangent
	upper.kind = &"slash_upper"
	lower.kind = &"slash_lower"

func shatter(body: StrikeBody, force: float = 1.0) -> void:
	var origin: Vector3 = Vector3(body.x + body.ox, maxf(0.0, body.y - proj.height_for_pixels(body.oy)), body.z + stand)
	debris(body.indices, body.pivot, origin, {
		"vel": Vector3(body.vx * 0.4, maxf(20.0 * unit, body.vy * 0.2) * force, body.vz * 0.4),
		"rot": body.rot,
		"spread": 30.0 * force,
	})
	body.dead = true
	if is_instance_valid(body.sprite):
		body.sprite.queue_free()

## Breaks the given chunks of the victim into loose particles. `pivot` is the chunk
## point that sits at `origin`; `vel` is in world units, `spread`/`gravity` in design units.
func debris(indices: PackedInt32Array, pivot: Vector2, origin: Vector3, options: Dictionary = {}) -> void:
	var velocity: Vector3 = options.get("vel", Vector3.ZERO)
	var rotation: float = float(options.get("rot", 0.0))
	var spread: float = float(options.get("spread", 30.0)) * unit
	var every: int = int(options.get("every", 1))
	var gravity: float = float(options.get("gravity", 260.0)) * unit
	var life_min: float = float(options.get("life_min", 1.0))
	var life_max: float = float(options.get("life_max", 1.6))
	var color_override: Variant = options.get("color", null)
	var radial: float = float(options.get("radial", 2.0))
	var chunk: float = victim_height / PieceChunks.ROWS
	for order: int in range(indices.size()):
		if order % every != 0:
			continue
		var index: int = indices[order]
		var local: Vector2 = ((victim_chunks.points[index] - pivot) * victim_height).rotated(rotation)
		var position: Vector3 = Vector3(origin.x + local.x, maxf(0.0, origin.y - proj.height_for_pixels(local.y)), origin.z)
		var speed: Vector3 = Vector3(
			velocity.x + randf_range(-spread, spread) + local.x * radial,
			velocity.y + randf_range(0.0, spread * 1.2),
			velocity.z + randf_range(-spread, spread) * 0.6)
		fx.add_part(position, speed, victim_chunks.colors[index] if color_override == null else color_override as Color, chunk * (1.7 if randf() < 0.25 else 1.0), randf_range(life_min, life_max), gravity)

## Explodes the victim into chunks, some of them burning.
func fire_debris(indices: PackedInt32Array, at_foot: Vector3, lift: float, spread: float, radial: float, burning: float) -> void:
	var plain: PackedInt32Array = PackedInt32Array()
	var lit: PackedInt32Array = PackedInt32Array()
	for index: int in indices:
		if randf() < burning:
			lit.append(index)
		else:
			plain.append(index)
	debris(plain, foot_pivot(), at_foot, {"vel": Vector3(0.0, lift * unit, 0.0), "spread": spread, "radial": radial})
	debris(lit, foot_pivot(), at_foot, {"vel": Vector3(0.0, lift * unit, 0.0), "spread": spread, "radial": radial, "color": StrikePalette.FIRE[2]})

func place_body(body: StrikeBody) -> void:
	var ground: Vector3 = Vector3(body.x, 0.0, body.z + stand)
	var scale_value: float = float(body.sprite.get_meta("base_scale", 1.0)) * proj.scale_at(ground)
	var jitter: float = float(randi_range(-1, 1)) * unit if body.jitter and rt < body.shatter_at else 0.0
	body.sprite.position = proj.project(Vector3(ground.x, body.y, ground.z)) + Vector2(body.ox + jitter, body.oy)
	body.sprite.scale = Vector2(scale_value, scale_value) * body.scale_mul
	body.sprite.rotation = body.rot
	if body.glow:
		body.material.set_shader_parameter(&"edge_glow", clampf(1.0 - body.age / 0.55, 0.0, 1.0))

# --- body motion ----------------------------------------------------------------

func step_free(body: StrikeBody, dt: float) -> void:
	body.vy -= body.gravity * dt
	body.x += body.vx * dt
	body.y += body.vy * dt
	body.z += body.vz * dt
	body.rot += body.vr * dt
	if body.shatter_ground and body.vy < 0.0 and body.y < proj.height_for_pixels(3.0 * unit):
		shatter(body, 0.9)
		fx.ring(body.x, body.z, cell * 0.5, 0.3)
		if body.poof:
			fx.puff(Vector3(body.x, 3.0 * unit, body.z), 10, 1.0)
	elif rt >= body.shatter_at:
		shatter(body, 0.35 if body.crumble else 0.7)
		if body.crumble:
			fx.puff(Vector3(body.x, 2.0 * unit, body.z), 7, 0.8)

func step_tip(body: StrikeBody, dt: float) -> void:
	if body.slide > 0.0 and body.age < 0.15:
		var k: float = 1.0 - body.age / 0.15
		body.x += dir.x * body.slide * dt * k
		body.z += dir.y * body.slide * dt * k
	if body.landed < 0.0:
		body.tip_speed += body.tip_accel * dt
		body.angle += body.tip_speed * dt
		if body.angle >= 1.5:
			body.angle = 1.5
			body.landed = body.age
			shake = maxf(shake, body.land_shake)
			var reach: float = body.x + face * cell * 0.55
			fx.ring(reach, body.z, cell * (1.2 if body.land_big else 0.6), 0.45 if body.land_big else 0.3)
			fx.puff(Vector3(reach, 2.0 * unit, body.z), 14 if body.land_big else 6, 1.3 if body.land_big else 0.8)
			if body.land_big:
				fx.crack_decal(reach, body.z, 4, cell * 0.8)
	body.rot = face * body.angle
	if body.landed >= 0.0 and body.age - body.landed > 0.08:
		shatter(body, 0.8)

func step_low_fly(body: StrikeBody, dt: float) -> void:
	var rest_height: float = proj.height_for_pixels(4.0 * unit)
	if body.phase == 0:
		body.vy -= 320.0 * unit * dt
		body.x += body.vx * dt
		body.y += body.vy * dt
		body.z += body.vz * dt
		body.rot += body.vr * dt
		if body.vy < 0.0 and body.y < rest_height:
			body.bounce += 1
			fx.puff(Vector3(body.x, unit, body.z), 3, 0.6)
			if body.bounce < 2:
				body.vy = 42.0 * unit
				body.vx *= 0.72
				body.vz *= 0.72
				body.vr *= 0.6
			else:
				body.phase = 1
				body.y = rest_height
				body.lie = roundf(body.rot / (PI * 0.5)) * PI * 0.5
				if is_zero_approx(body.lie):
					body.lie = face * PI * 0.5
		return
	var friction: float = pow(0.03, dt)
	body.vx *= friction
	body.vz *= friction
	body.x += body.vx * dt
	body.z += body.vz * dt
	body.rot += (body.lie - body.rot) * minf(1.0, dt * 14.0)
	if randf() < 0.5:
		fx.puff(Vector3(body.x, unit, body.z), 1, 0.45)
	if Vector2(body.vx, body.vz).length() < 14.0 * unit:
		shatter(body, 0.8)
		fx.ring(body.x, body.z, cell * 0.45, 0.3)

func step_slash_upper(body: StrikeBody) -> void:
	var hold: float = 0.32 if body.heavy else 0.24
	var accel: float = (110.0 if body.heavy else 190.0) * unit
	var fall: float = 0.5 if body.heavy else 0.38
	var apart: float = ease_out(clampf(body.age / 0.08, 0.0, 1.0)) * 3.0 * unit
	var offset: Vector2 = body.normal * apart
	if body.age > hold:
		var since: float = body.age - hold
		offset += body.tangent * 0.5 * accel * since * since
		body.rot = (-1.0 if body.tangent.x < 0.0 else 1.0) * 1.3 * since
		if since > fall:
			body.ox = offset.x
			body.oy = offset.y
			shatter(body, 1.0 if body.heavy else 0.8)
			fx.ring(body.x + offset.x, body.z, cell * (0.7 if body.heavy else 0.45), 0.3)
			if body.heavy:
				shake = maxf(shake, 0.7)
			return
	body.ox = offset.x
	body.oy = offset.y

func step_slash_lower(body: StrikeBody) -> void:
	var hold: float = 0.32 if body.heavy else 0.24
	var fall: float = 0.5 if body.heavy else 0.38
	var apart: float = ease_out(clampf(body.age / 0.08, 0.0, 1.0)) * 1.5 * unit
	body.ox = -body.normal.x * apart
	body.oy = -body.normal.y * apart
	if body.age > hold:
		body.rot = (-1.0 if -body.normal.x < 0.0 else 1.0) * 0.35 * smooth(clampf((body.age - hold) / 0.4, 0.0, 1.0))
	if body.age > hold + fall + 0.1:
		shatter(body, 0.6)
