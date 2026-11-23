class_name StrikeLook
extends RefCounted

## How the standing victim is drawn this frame, between the hit and the moment it
## falls apart. The director fills in the defaults; StrikeReaction.look() changes them.

## Screen position of the victim's feet.
var position: Vector2 = Vector2.ZERO
var stretch: Vector2 = Vector2.ONE
## Horizontal shake in design units.
var jitter: float = 0.0
## Tilt of the victim sprite, or null to leave it as it is.
var rotation: Variant = null
