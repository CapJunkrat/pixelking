class_name StrikeReaction
extends RefCounted

## The victim's half of a strike animation: how the struck piece looks between the
## hit and the moment it falls apart, what it falls apart into, and anything drawn
## around it. One subclass per reaction in scripts/battle/strike/reactions/, listed in
## StrikeLibrary; which one plays is decided by StrikeLibrary.reaction_for (strike
## type and weights) unless the victim always plays its own. This base class is the
## plain reaction used for an unknown id. Shares the strike's StrikeStage `s` with the
## attack.

var s: StrikeStage = null

## Seconds after impact at which the standing victim is replaced by its pieces.
func split_time() -> float:
	return 0.1

## Whether the victim survives the blow (a shell absorbs it).
func survives() -> bool:
	return false

## Pixels of the victim still standing after the hit, for a piece riding it down.
func standing_pixels() -> float:
	return 0.0

## Every frame after the impact until the split (not during the hit-stop for most).
func tick() -> void:
	pass

## The standing victim's look this frame (after the impact, before the split).
func look(_material: ShaderMaterial, _look: StrikeLook) -> void:
	pass

func on_split() -> void:
	pass

## Moves a body of a kind this reaction made; returns false for the stage's kinds.
func step_body(_body: StrikeBody, _dt: float) -> bool:
	return false

func draw_air(_canvas: CanvasItem) -> void:
	pass

## Applies a look given as {"world": feet position, "stretch", "jitter", "rot"}; a
## missing key keeps the default, and a missing "rot" stands the victim upright.
func apply_state(state: Dictionary, look_value: StrikeLook) -> void:
	if state.has("world"):
		var world: Vector3 = state["world"]
		look_value.position = s.proj.project(world)
	look_value.stretch = state.get("stretch", look_value.stretch)
	look_value.jitter = float(state.get("jitter", look_value.jitter))
	look_value.rotation = float(state.get("rot", 0.0))
