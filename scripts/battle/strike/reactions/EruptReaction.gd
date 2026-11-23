class_name EruptReaction
extends StrikeReaction

## Rock spikes burst from the ground around it and throw it into the air.

func split_time() -> float:
	return 0.05

func on_split() -> void:
	var body: StrikeBody = s.make_body({})
	var toss: bool = s.reaction == &"toss"
	var push: float = s.weight3([70.0, 55.0, 40.0]) if toss else 15.0
	var sign: float = -1.0 if toss else 1.0
	body.vx = s.dir.x * push * sign * s.unit
	body.vz = s.dir.y * push * sign * s.unit
	body.vy = (s.weight3([200.0, 175.0, 150.0]) if toss else s.weight3([190.0, 165.0, 140.0])) * s.unit
	body.vr = (-14.0 if toss else 9.0) * s.face
	body.gravity = (320.0 if toss else 300.0) * s.unit
	body.shatter_ground = true
	body.poof = true

func draw_air(canvas: CanvasItem) -> void:
	if not s.impacted:
		return
	var rt: float = s.rt
	var b: Vector3 = s.b
	if rt > 1.1:
		return
	var k: float = rt / 0.12 if rt < 0.12 else (1.0 if rt < 0.7 else 1.0 - (rt - 0.7) / 0.4)
	for index: int in range(7):
		var angle: float = index / 7.0 * TAU
		var radius: float = s.cell * (0.22 if index % 2 == 1 else 0.32)
		var foot: Vector2 = s.proj.project(Vector3(b.x + cos(angle) * radius, 0.0, b.z + sin(angle) * radius))
		var height: int = roundi((7.0 if index % 2 == 1 else 10.0) * k)
		for y: int in range(height):
			var width: float = maxf(1.0, roundf((height - y) / 3.0))
			canvas.draw_rect(Rect2(foot + Vector2(-width * 0.5, -y - 1.0) * s.unit, Vector2(width, 1.0) * s.unit), Color("#bdbbc1") if y == height - 1 else Color("#6b6970"))
