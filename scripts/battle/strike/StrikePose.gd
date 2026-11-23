class_name StrikePose
extends RefCounted

## Where and how the attacker stands in one frame of a strike: world position, squash
## and stretch, tilt, a white flash, alpha, and whether it leaves a ghost trail or sees
## stars. StrikeAttack.pose() fills one per frame; the director draws it.

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
