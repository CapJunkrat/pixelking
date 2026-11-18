class_name BattleResultSummary
extends RefCounted

## What happened in a finished battle, read from its event history: how it ended,
## captures on both sides, the player's best piece and what the player's pieces grew
## into. Presentation-only; it never changes battle or Run state.

var reason: StringName = &""
var player_moves: int = 0
var captured: int = 0
var lost: int = 0
## Definition id of the player's piece with the most captures, and how many.
var best_piece_id: String = ""
var best_captures: int = 0
## Lines such as {"kind": "evolved", "piece_def_id": "squire_lv2"}.
var growth: Array[Dictionary] = []

static func from_history(events: Array[BattleEvent], player_color: int) -> BattleResultSummary:
	var summary: BattleResultSummary = BattleResultSummary.new()
	var captures_by_piece: Dictionary = {}
	var def_by_piece: Dictionary = {}
	var mover_by_action: Dictionary = {}
	for event: BattleEvent in events:
		var data: Dictionary = event.payload
		match event.event_type:
			BattleCommandProcessor.EVENT_PIECE_MOVED:
				if int(data.get("color", -1)) == player_color:
					summary.player_moves += 1
					var instance_id: int = int(data.get("instance_id", 0))
					mover_by_action[event.action_id] = instance_id
					def_by_piece[instance_id] = str(data.get("piece_def_id", ""))
				else:
					mover_by_action.erase(event.action_id)
			BattleCommandProcessor.EVENT_PIECE_CAPTURED, BattleCommandProcessor.EVENT_PIECE_DESTROYED:
				if int(data.get("color", -1)) == player_color:
					summary.lost += 1
				else:
					summary.captured += 1
					if event.event_type == BattleCommandProcessor.EVENT_PIECE_CAPTURED and mover_by_action.has(event.action_id):
						var hunter: int = int(mover_by_action[event.action_id])
						captures_by_piece[hunter] = int(captures_by_piece.get(hunter, 0)) + 1
			BattleCommandProcessor.EVENT_PIECE_EVOLVED:
				if int(data.get("color", -1)) == player_color:
					summary.growth.append({"kind": "evolved", "piece_def_id": str(data.get("piece_def_id", ""))})
			BattleCommandProcessor.EVENT_MOVE_LEARNED:
				if mover_by_action.has(event.action_id):
					summary.growth.append({"kind": "learned", "piece_def_id": def_by_piece.get(mover_by_action[event.action_id], ""), "learned": str(data.get("learned", ""))})
			BattleCommandProcessor.EVENT_BATTLE_ENDED:
				summary.reason = StringName(str(data.get("reason", "")))
	for instance_id: Variant in captures_by_piece:
		var count: int = int(captures_by_piece[instance_id])
		if count > summary.best_captures:
			summary.best_captures = count
			summary.best_piece_id = str(def_by_piece.get(instance_id, ""))
	return summary
