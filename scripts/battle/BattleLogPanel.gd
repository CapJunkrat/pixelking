class_name BattleLogPanel
extends PanelContainer

const MAX_LINES := 5

@onready var log_label: RichTextLabel = $Margin/Log
var lines: Array[String] = []

func _ready() -> void:
	log_label.text = ""

func consume(events: Array[BattleEvent]) -> void:
	var captured_in_batch: bool = false
	for candidate: BattleEvent in events:
		if candidate.event_type == BattleCommandProcessor.EVENT_PIECE_CAPTURED:
			captured_in_batch = true
	for event: BattleEvent in events:
		var line: String = _format_event(event, captured_in_batch)
		if line.is_empty():
			continue
		lines.append(line)
	while lines.size() > MAX_LINES:
		lines.pop_front()
	log_label.text = "\n".join(lines)

func append_system_message(message: String) -> void:
	if message.is_empty():
		return
	lines.append(message)
	while lines.size() > MAX_LINES:
		lines.pop_front()
	log_label.text = "\n".join(lines)

func _format_event(event: BattleEvent, captured_in_batch: bool = false) -> String:
	var data: Dictionary = event.payload
	match event.event_type:
		BattleCommandProcessor.EVENT_ACTION_REJECTED:
			return "Action failed: %s" % str(data.get("error", "unavailable")).replace("_", " ")
		BattleCommandProcessor.EVENT_ITEM_USED:
			return "Used %s" % str(data.get("item_id", "item"))
		BattleCommandProcessor.EVENT_PIECE_MOVED:
			var piece_id: String = str(data.get("piece_def_id", "piece"))
			var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
			var verb: String = _movement_verb(BattleBoardView.presentation_kind_for(definition, captured_in_batch))
			return "%s %s  %s → %s" % [piece_id, verb, _square(data.get("from", Vector2i.ZERO)), _square(data.get("to", Vector2i.ZERO))]
		BattleCommandProcessor.EVENT_PIECE_CAPTURED:
			return "Captured %s" % str(data.get("piece_def_id", "piece"))
		BattleCommandProcessor.EVENT_EFFECT_APPLIED:
			return "Effect: %s" % str(data.get("effect_id", "effect"))
		BattleCommandProcessor.EVENT_CHECK_DECLARED:
			return "Check"
		BattleCommandProcessor.EVENT_BATTLE_ENDED:
			return "Battle ended: %s" % str(data.get("reason", "complete"))
		_:
			return ""

func _movement_verb(kind: StringName) -> String:
	match kind:
		&"teleport": return "teleports"
		&"bent_ray": return "turns"
		&"lob": return "launches"
		&"petrify": return "freezes nearby units at"
		&"chained_capture": return "chains a strike"
		_: return "moves"

func _square(value: Variant) -> String:
	if value is Vector2i:
		var square_position: Vector2i = value
		return "%s%d" % [String.chr(65 + square_position.x), square_position.y + 1]
	return "?"
