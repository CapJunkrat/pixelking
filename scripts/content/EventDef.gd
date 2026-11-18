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
@export var options: Array[Dictionary] = []

func is_valid() -> bool:
	return not id.is_empty() and not title.is_empty() and safe_gold >= 0 and risky_gold >= 0
