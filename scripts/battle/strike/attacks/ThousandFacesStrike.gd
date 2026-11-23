class_name ThousandFacesStrike
extends StrikeAttack

## Walks up, draws the victim's likeness out as a white phantom and briefly wears its
## shape before settling.

const TIMING := {"impact": 0.95, "done": 3.2, "end": 3.5, "hitstop": 0.08, "shake": 0.5}

var _phantom: Sprite2D = null
var _phantom_material: ShaderMaterial = null
var _attacker_texture_saved: Texture2D = null

func timing() -> Dictionary:
	return TIMING

func adjust_timing() -> bool:
	var absorb: float = _absorb_at()
	s.done_time = absorb + 1.3
	s.end_time = absorb + 1.6
	return true

func clear() -> void:
	if is_instance_valid(_phantom):
		_phantom.queue_free()
	_phantom = null
	_attacker_texture_saved = null

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var stand: Vector3 = s.toward(1.05)
	var absorb: float = _absorb_at()
	if u < 0.6:
		var q: float = u / 0.6
		o.at(a.lerp(stand, s.smooth01(q)))
		o.white = 0.8 if fmod(u, 0.1) < 0.03 else 0.0
		o.y = absf(sin(q * PI * 3.0)) * s.n(1.5)
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
		s.settle_into(o, stand, u, absorb + 0.95, 0.35, 1.0)
	_swap_attacker_form(u >= absorb and u < absorb + 0.85)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 0.8, 0.45, StrikePalette.VIOLET)
	fx.spark_burst(s.up(b, 8.0), 8, Vector2.ZERO, 0.0, 0.5, StrikePalette.VIOLET)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var o: StrikePose = s.pose
	if u > 0.7 and u < 1.0:
		var middle: Vector3 = Vector3((o.x + s.b.x) * 0.5, 0.0, (o.z + s.b.z) * 0.5)
		for index: int in range(16):
			if randf() < 0.3:
				continue
			var at: Vector2 = s.screen(Vector3(middle.x, s.vh(index), middle.z))
			canvas.draw_rect(Rect2(at - Vector2(2.5, 0.0) * s.unit, Vector2(5.0, 1.0) * s.unit), Color(0.78, 0.7, 1.0, 0.7) if index % 3 != 0 else Color(1.0, 1.0, 1.0, 0.9))
	_update_phantom()
	var absorb: float = _absorb_at()
	if u > absorb and u < absorb + 0.3 and randf() < 0.6:
		s.fx.spark_burst(Vector3(o.x, s.ah(8.0), o.z), 2, Vector2.ZERO, 0.0, 0.4, StrikePalette.VIOLET)

func _absorb_at() -> float:
	return float(TIMING["impact"]) + s.weight3([0.75, 0.9, 1.05])

## Thousand Faces wears the captured piece's shape for a moment after absorbing it.
func _swap_attacker_form(as_victim: bool) -> void:
	if not is_instance_valid(s.attacker):
		return
	if as_victim and _attacker_texture_saved == null:
		_attacker_texture_saved = s.attacker.texture
		var worn: Texture2D = s.mimic_texture if s.mimic_texture != null else s.victim_texture
		s.attacker.texture = worn
		s.attacker.material = s.piece_material(PieceChunks.of(worn))
		s.attacker_material = s.attacker.material
	elif not as_victim and _attacker_texture_saved != null:
		s.attacker.texture = _attacker_texture_saved
		s.attacker.material = s.piece_material(PieceChunks.of(_attacker_texture_saved))
		s.attacker_material = s.attacker.material
		_attacker_texture_saved = null
		s.fx.spark_burst(Vector3(s.pose.x, 8.0 * s.unit, s.pose.z), 6, Vector2.ZERO, 0.0, 0.4, StrikePalette.VIOLET)

## Thousand Faces: the victim's likeness lifts off as a white phantom and drifts into it.
func _update_phantom() -> void:
	if not s.impacted or s.split or s.reaction != &"mimic":
		if is_instance_valid(_phantom):
			_phantom.visible = false
		return
	if not is_instance_valid(_phantom):
		_phantom = s.view.make_piece_sprite(s.victim_texture)
		_phantom_material = s.piece_material(s.victim_chunks)
		_phantom_material.set_shader_parameter(&"flash", 1.0)
		_phantom.material = _phantom_material
		_phantom.z_index = 3
		s.view.piece_layer().add_child(_phantom)
	var q: float = clampf(s.rt / s.split_time(), 0.0, 1.0)
	var lift: float = (s.victim_at(1.0) + s.n(4.0)) * s.smooth01(q / 0.35)
	var k: float = s.smooth01((q - 0.35) / 0.65)
	var spot: Vector3 = Vector3(s.b.x, 0.0, s.b.z).lerp(Vector3(s.pose.x, 0.0, s.pose.z), k)
	spot.y = lift * (1.0 - k) + s.n(4.0) * k + s.cell * 0.5 * sin(k * PI)
	var ground: Vector3 = Vector3(spot.x, 0.0, spot.z + s.stand)
	var scale_value: float = float(_phantom.get_meta("base_scale", 1.0)) * s.proj.scale_at(ground) * (1.0 - 0.2 * k)
	_phantom.visible = true
	_phantom.position = s.proj.project(Vector3(ground.x, spot.y, ground.z))
	_phantom.scale = Vector2(scale_value, scale_value)
	_phantom_material.set_shader_parameter(&"alpha", 0.55 + 0.3 * clampf(q / 0.35, 0.0, 1.0))
