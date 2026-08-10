class_name ChallengerTray
extends Control

const SLOT_COUNT := 6

@onready var heading: Label = $TreasureTray/Margin/Slots/TitlePlaque/Heading
@onready var slot_row: HBoxContainer = $TreasureTray/Margin/Slots/SlotRow

var challenger_slots: Array[Button] = []

func _ready() -> void:
	for index: int in range(SLOT_COUNT):
		challenger_slots.append(slot_row.get_node("ChallengerSlot%d" % index) as Button)
	heading.text = _text("BATTLE_CHALLENGER")

func slots() -> Array[Button]:
	return challenger_slots

func refresh(items: Array[ChallengerItemDef]) -> void:
	if challenger_slots.is_empty():
		return
	for index: int in range(challenger_slots.size()):
		var slot: Button = challenger_slots[index]
		if index >= items.size():
			slot.icon = null
			slot.text = ""
			slot.tooltip_text = _text("BATTLE_EMPTY_SLOT")
			slot.disabled = true
		else:
			var item: ChallengerItemDef = items[index]
			slot.icon = item.icon
			slot.text = "" if item.icon != null else String(item.id).left(2).to_upper()
			slot.tooltip_text = _text(String(item.display_name_key))
			slot.disabled = not item.is_consumable()

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
