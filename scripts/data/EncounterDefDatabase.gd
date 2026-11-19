class_name EncounterDefDatabase
extends RefCounted

static func get_def(id: StringName) -> EncounterDef:
	var registry: ContentRegistry = DefaultContent.registry()
	return registry.encounter(id) if registry != null else null

static func has_def(id: StringName) -> bool:
	return get_def(id) != null

## The encounter of `node` in this run. A Boss node draws one of its act's Bosses
## (any Boss in the acts past the third), the same one for the same battle seed.
static func for_node(run_state: RunState, node: MapNodeState) -> EncounterDef:
	if node == null:
		return null
	var node_definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id)
	if node_definition == null or not node_definition.is_battle:
		return null
	if node.node_type_id != &"boss" or run_state == null:
		return get_def(node_definition.encounter_def_id)
	var pool: Array[EncounterDef] = bosses_for_act(run_state.act_index)
	if pool.is_empty():
		return get_def(node_definition.encounter_def_id)
	return pool[absi(run_state.current_encounter_seed) % pool.size()]

## The Bosses that can close act `act_index` (0 = Act 1); every Boss after Act 3.
static func bosses_for_act(act_index: int) -> Array[EncounterDef]:
	var result: Array[EncounterDef] = []
	for definition: EncounterDef in all_defs():
		if definition.is_boss and definition.act > 0 and (act_index >= RunState.ACT_COUNT or definition.act == act_index + 1):
			result.append(definition)
	return result

## The encounter of the run's current node.
static func for_current(run_state: RunState) -> EncounterDef:
	if run_state == null or run_state.map_state == null:
		return null
	return for_node(run_state, run_state.map_state.get_node(run_state.current_node_id))

static func all_defs() -> Array[EncounterDef]:
	var registry: ContentRegistry = DefaultContent.registry()
	return registry.ordered_encounters() if registry != null else []

## Every Boss that can lead an act, by id.
static func boss_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition: EncounterDef in all_defs():
		if definition.is_boss and definition.act > 0:
			ids.append(String(definition.id))
	return ids
