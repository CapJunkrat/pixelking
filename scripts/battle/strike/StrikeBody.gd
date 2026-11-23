class_name StrikeBody
extends RefCounted

## A piece of a struck victim that moves on its own (a half cut off, a body knocked
## flying), drawn as the victim's sprite masked to its chunks. `kind` picks how it
## moves: the stage's generic kinds ("free", "tip", "low_fly", "slash_upper",
## "slash_lower") or one the reaction steps itself (StrikeReaction.step_body).

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
