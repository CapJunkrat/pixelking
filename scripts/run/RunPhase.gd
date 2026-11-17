class_name RunPhase
extends RefCounted

const OPENING_DRAFT: StringName = &"opening_draft"
const MAP: StringName = &"map"
const NODE_SELECTED: StringName = &"node_selected"
const NODE_INTERACTION: StringName = &"node_interaction"
const DEPLOYMENT: StringName = &"deployment"
const BATTLE_READY: StringName = &"battle_ready"
const BATTLE_ACTIVE: StringName = &"battle_active"
const POST_BATTLE_CHOICE: StringName = &"post_battle_choice"
const ROSTER_OVERFLOW: StringName = &"roster_overflow"
const FUSION_CONFIRMATION: StringName = &"fusion_confirmation"
const SACRIFICE: StringName = &"sacrifice"
const RUN_SUMMARY: StringName = &"run_summary"

const ALL: Array[StringName] = [
	OPENING_DRAFT,
	MAP,
	NODE_SELECTED,
	NODE_INTERACTION,
	DEPLOYMENT,
	BATTLE_READY,
	BATTLE_ACTIVE,
	POST_BATTLE_CHOICE,
	ROSTER_OVERFLOW,
	FUSION_CONFIRMATION,
	SACRIFICE,
	RUN_SUMMARY,
]

const INTERACTION_PHASES: Array[StringName] = [
	NODE_INTERACTION,
	POST_BATTLE_CHOICE,
	ROSTER_OVERFLOW,
	FUSION_CONFIRMATION,
	SACRIFICE,
	RUN_SUMMARY,
]

static func is_valid(phase: StringName) -> bool:
	return phase in ALL
