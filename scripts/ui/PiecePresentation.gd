class_name PiecePresentation
extends RefCounted

## Read-only base facts, shared by every piece-information surface. No ChessPiece
## state is accepted here: remaining shells, freeze, etc. belong to live status.
static func describe(definition: PieceDef) -> Dictionary:
	if definition == null:
		return {}
	var entries: Array[Dictionary] = []
	var geometry: Array[Dictionary] = []
	for rule: MovementRule in definition.resolved_movement_rules():
		var facts: Dictionary = {"kind": String(rule.rule_id())}
		for property: Dictionary in rule.get_property_list():
			var field: String = str(property.name)
			if field in ["min_distance", "max_distance", "directions", "initial_directions", "ray_directions", "jump_over_occupied", "hits_adjacent", "pierce", "breaks_rocks", "ranged", "smashes_rocks"]:
				facts[field] = rule.get(field)
		geometry.append(facts)
	var exceptions: Array[String] = [_t("INFO_NORMAL")]
	var movement_key: String = "INFO_MOVE_" + definition.id.to_upper()
	var movement: String = _t(movement_key)
	if movement == movement_key:
		movement = _t(PieceRulePreview.move_key(definition))
	var result: Dictionary = {
		"id": definition.id,
		"name": _t(String(definition.display_name_key)),
		"summary": _t("INFO_SUMMARY_" + definition.id.to_upper()),
		"movement": movement,
		"capture": _t(PieceRulePreview.attack_key(definition)),
		"traits": entries, "exceptions": exceptions, "geometry": geometry,
		"shell_layers": definition.shell_hits,
		"actions_per_turn": 2 if definition.extra_move_always else 1,
		"hatch_owner_turns": definition.revive_after_turns,
		"learn_capacity": definition.learn_capacity,
	}
	if not definition.is_egg and definition.id != "shadow_king":
		exceptions.append(_t("INFO_LANDING_RULE"))
	if definition.extra_move_always:
		_add(entries, "INFO_TWO_LABEL", "INFO_TWO_RULE")
	elif definition.extra_move_on_capture:
		_add(entries, "INFO_BONUS_LABEL", "INFO_BONUS_RULE")
	if definition.shell_hits > 0:
		entries.append({"label": _t("INFO_SHELL_LABEL") % definition.shell_hits, "rule": _t("INFO_SHELL_RULE") % definition.shell_hits})
	if definition.revive_after_turns > 0:
		var limit: String = _t("INFO_REVIVE_ALWAYS") if definition.revive_limit < 0 else _t("INFO_REVIVE_LIMIT") % definition.revive_limit
		if definition.revive_limit == 1:
			limit = _t("INFO_REVIVE_ONCE")
		entries.append({"label": _t("INFO_REVIVE_LABEL") % definition.revive_after_turns, "rule": (_t("INFO_REVIVE_RULE") % definition.revive_after_turns) + " " + limit})
		var egg: PieceDef = PieceDefDatabase.get_def(definition.egg_def_id)
		_add(entries, "INFO_HARD_LABEL" if egg != null and egg.egg_hardened else "INFO_FRAGILE_LABEL", "INFO_HARD_RULE" if egg != null and egg.egg_hardened else "INFO_FRAGILE_RULE")
	if definition.is_egg:
		_add(entries, "INFO_HARD_LABEL" if definition.egg_hardened else "INFO_FRAGILE_LABEL", "INFO_HARD_RULE" if definition.egg_hardened else "INFO_FRAGILE_RULE")
	if definition.learn_capacity > 0:
		entries.append({"label": _t("INFO_LEARN_LABEL") % definition.learn_capacity, "rule": _t("INFO_LEARN_RULE") % definition.learn_capacity})
	if definition.evolve_at_captures > 0:
		var evolved: PieceDef = PieceDefDatabase.get_def(definition.evolves_into)
		entries.append({"label": _t("INFO_EVOLVE_LABEL") % definition.evolve_at_captures, "rule": _t("INFO_EVOLVE_RULE") % [definition.evolve_at_captures, _t(String(evolved.display_name_key)) if evolved != null else definition.evolves_into]})
	if not definition.promotes_to.is_empty():
		var promoted: PieceDef = PieceDefDatabase.get_def(definition.promotes_to)
		entries.append({"label": _t("INFO_PROMOTE_LABEL"), "rule": _t("INFO_PROMOTE_RULE") % _t(String(promoted.display_name_key))})
	if definition.survives_checkmate_once:
		_add(entries, "INFO_LAST_LABEL", "INFO_LAST_RULE")
	if definition.id == "shadow_king":
		_add(entries, "INFO_SHADOW_LABEL", "INFO_SHADOW_RULE")
		exceptions.append(_t("INFO_SHADOW_LIMITS"))
	elif definition.is_king and definition.id != "king":
		exceptions.append(_t("INFO_NO_CASTLE"))
	if definition.id in ["echo", "thousand_faces"]:
		_add(entries, "INFO_ECHO_LABEL", "INFO_ECHO_RULE")
	if definition.id == "stand_in":
		_add(entries, "INFO_SWAP_LABEL", "INFO_SWAP_RULE")
	if definition.id in ["king", "pawn"]:
		exceptions.append(_t("INFO_CASTLE_RULE"))
	var bool_traits: Array = [
		[definition.immobilizes_adjacent, "IMMOBILIZE", "INFO_FREEZE_RULE"],
		[definition.immune_to_immobilization, "IMMUNE", "CODEX_TRAIT_IMMUNE"],
		[definition.explodes_when_captured, "EXPLODES", "INFO_EXPLODE_RULE"],
		[definition.shields_allies_when_captured, "SHIELDS", "INFO_SHIELD_RULE"],
		[definition.protects_adjacent_from_immobilization, "LANTERN", "CODEX_TRAIT_LANTERN"],
		[not definition.alternate_form_id.is_empty(), "TIDE", "CODEX_TRAIT_TIDE"],
		[definition.splash_on_ranged_capture, "SPLASH", "INFO_SPLASH_RULE"],
		[definition.immune_to_ranged, "RANGED_IMMUNE", "CODEX_TRAIT_RANGED_IMMUNE"],
	]
	for item: Array in bool_traits:
		if item[0]:
			_add(entries, "INFO_LABEL_" + str(item[1]), str(item[2]))
	for rule: MovementRule in definition.resolved_movement_rules():
		var slide: SlideMovementRule = rule as SlideMovementRule
		var shot: RangedAttackRule = rule as RangedAttackRule
		if slide != null and slide.smashes_rocks:
			_add(entries, "INFO_ROCK_LABEL", "INFO_ROCK_RULE")
		if shot != null:
			exceptions.append(_t("INFO_RANGED_LIMITS"))
			if not shot.hits_adjacent:
				exceptions.append(_t("INFO_ENGAGED_LIMITS"))
				_add(entries, "INFO_LABEL_RANGED", "CODEX_TRAIT_RANGED")
			else:
				_add(entries, "INFO_BEAM_LABEL", "INFO_BEAM_RULE")
			if shot.pierce:
				_add(entries, "INFO_LABEL_BOOMERANG", "CODEX_TRAIT_BOOMERANG")
			if shot.breaks_rocks:
				_add(entries, "INFO_LABEL_ROCKBREAKER", "CODEX_TRAIT_ROCKBREAKER")
	return result

static func _t(key: String) -> String:
	return str(Engine.get_main_loop().root.get_node("Localization").call("text", key))

static func _add(entries: Array[Dictionary], label_key: String, rule_key: String) -> void:
	entries.append({"label": _t(label_key), "rule": _t(rule_key)})
