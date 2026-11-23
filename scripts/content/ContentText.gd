class_name ContentText
extends RefCounted

## Names of content in the current language, for the run services that build offer
## and outcome text. Reads the Localization autoload when the game is running; outside
## a scene tree (some tests) it falls back to the stored English name or the id.

## A relic's or an item's name.
static func item_name(id: StringName) -> String:
	var definition: ChallengerItemDef = Content.challenger_item(id)
	var localization: Node = _localization()
	if definition != null and localization != null:
		return str(localization.call("text", String(definition.display_name_key)))
	return String(id).replace("_", " ").capitalize()

## A fusion recipe's name.
static func recipe_name(recipe: FusionRecipeDef) -> String:
	if recipe == null:
		return ""
	var localization: Node = _localization()
	if localization != null and not recipe.display_name_key.is_empty():
		return str(localization.call("text", String(recipe.display_name_key)))
	return recipe.display_name

static func _localization() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("Localization") if loop is SceneTree else null
