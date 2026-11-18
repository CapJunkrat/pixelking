class_name EventDef
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = "A short risk-and-reward encounter."
@export var safe_gold: int = 12
@export var risky_gold: int = 25
@export var can_offer_relic: bool = true
## The event's choices. Each is a Dictionary:
##   id, label, detail       what the card shows
##   kind + its fields        the effect (see RunRewardService.apply); "random_item",
##                            "random_relic" and "random_piece" (pool: "common"/"rare")
##                            are rolled when the event opens, so the card can name them
##   cost (int)               gold paid up front; the card is disabled without it
##   chance (0-1)             probability of the effect; otherwise "fail" applies
##   fail (Dictionary)        the effect when the chance misses
##   success_text, fail_text  what the player is told afterwards
##   pay (Array)              effects paid whatever the outcome: lose_item, lose_retry
##   Event-only kinds resolved when it opens: train_best (your growing piece closest to
##   its next form; "times"), arm_pawn (a Pawn becomes a random common piece),
##   trade_weakest (your cheapest piece becomes a random rare one).
##   {reward}, {target}, {lost} in the texts name what is given, changed and taken.
@export var options: Array[Dictionary] = []
## Not offered before this map layer (0 = first).
@export var min_layer: int = 0
## The scene drawn above the event: sky colours, a glow, and what stands in it.
## Props: "altar", "cart", "campfire", "signpost", "well", "table", "tent", "chest",
## "banner", "piece:<id>" (yours), "enemy:<id>". A picture at
## res://assets/events/<id>.png replaces the drawn scene when present.
@export var sky_top: Color = Color("#141c33")
@export var sky_bottom: Color = Color("#3a2b4a")
@export var glow: Color = Color("#f5d58f")
@export var props: Array[String] = []

func is_valid() -> bool:
	return not id.is_empty() and not title.is_empty() and safe_gold >= 0 and risky_gold >= 0
