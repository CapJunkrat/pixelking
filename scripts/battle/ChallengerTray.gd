class_name ChallengerTray
extends Control

signal item_requested(slot_index: int)

const SLOT_COUNT := 6

@onready var heading: Label = $TreasureTray/Margin/Slots/TitlePlaque/Heading
@onready var slot_row: HBoxContainer = $TreasureTray/Margin/Slots/SlotRow

var challenger_slots: Array[Button] = []
var input_enabled: bool = true

func _ready() -> void:
	for index: int in range(SLOT_COUNT):
		var slot: Button = slot_row.get_node("ChallengerSlot%d" % index) as Button
		challenger_slots.append(slot)
		slot.pressed.connect(_on_slot_pressed.bind(index))
	heading.text = _text("BATTLE_CHALLENGER")

func slots() -> Array[Button]:
	return challenger_slots

func refresh(items: Array[ChallengerItemDef], usable_slots: Array[bool] = []) -> void:
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
			var item_name: String = _text(String(item.display_name_key))
			var description: String = _text(String(item.description_key))
			var usage: String = _text("ITEM_USAGE_CONSUMABLE") if item.is_consumable() else _text("ITEM_USAGE_PERSISTENT")
			slot.tooltip_text = "%s\n%s\n%s" % [item_name, description, usage]
			var can_use: bool = usable_slots[index] if index < usable_slots.size() else item.is_consumable()
			# Persistent relics stay hoverable because they are informative, not usable.
			slot.disabled = not input_enabled or (item.is_consumable() and not can_use)
			slot.add_theme_color_override("icon_disabled_color", Color(0.65, 0.65, 0.65, 1.0))

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	for slot: Button in challenger_slots:
		slot.disabled = not input_enabled

func _on_slot_pressed(index: int) -> void:
	if input_enabled:
		item_requested.emit(index)

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key
