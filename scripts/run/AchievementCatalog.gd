class_name AchievementCatalog
extends RefCounted

## Every achievement is a lifetime statistic reaching a target. The statistics live in
## the meta save (MetaProgressService.stats()); a few are counted here from other data
## (bosses beaten, codex pages). Adding an achievement = one line below plus its two
## strings ACH_<ID>_TITLE / ACH_<ID>_DESC (the description may use %d for the target).
##
## stat keys:
##   best_acts        most acts cleared in one journey
##   best_run_kills   most enemies defeated in one journey
##   total_kills      enemies defeated in all journeys
##   total_runs       journeys started
##   best_run_fusions most fusions in one journey
##   flawless_acts    most acts cleared in one journey without using a retry
##   small_boss_wins  Bosses beaten with at most 3 pieces on the board (King included)
##   bosses           different Bosses beaten (counted from the saved list)
##   codex            codex pages found
const ENTRIES: Array[Dictionary] = [
	{"id": "first_steps", "stat": "total_runs", "target": 1, "group": "journey"},
	{"id": "act_3", "stat": "best_acts", "target": 3, "group": "journey"},
	{"id": "act_5", "stat": "best_acts", "target": 5, "group": "journey"},
	{"id": "act_8", "stat": "best_acts", "target": 8, "group": "journey"},
	{"id": "act_12", "stat": "best_acts", "target": 12, "group": "journey"},
	{"id": "flawless_3", "stat": "flawless_acts", "target": 3, "group": "journey"},
	{"id": "run_kills_50", "stat": "best_run_kills", "target": 50, "group": "battle"},
	{"id": "run_kills_150", "stat": "best_run_kills", "target": 150, "group": "battle"},
	{"id": "total_kills_500", "stat": "total_kills", "target": 500, "group": "battle"},
	{"id": "total_kills_2000", "stat": "total_kills", "target": 2000, "group": "battle"},
	{"id": "small_army", "stat": "small_boss_wins", "target": 1, "group": "battle"},
	{"id": "all_bosses", "stat": "bosses", "target": -1, "group": "battle"},
	{"id": "first_fusion", "stat": "best_run_fusions", "target": 1, "group": "collection"},
	{"id": "codex_half", "stat": "codex", "target": -2, "group": "collection"},
	{"id": "codex_full", "stat": "codex", "target": -1, "group": "collection"},
]

## The highest piece count still called a "small army" for the small_army achievement.
const SMALL_ARMY := 3

## How many there are to find for "all" targets: every Boss, every codex page.
static func total_for(stat: String) -> int:
	match stat:
		"bosses":
			return Content.boss_ids().size()
		"codex":
			return codex_piece_ids().size()
	return 0

## Codex pages: every piece that is not an egg.
static func codex_piece_ids() -> Array[String]:
	var ids: Array[String] = []
	for piece_id: String in Content.piece_ids():
		var definition: PieceDef = Content.piece(piece_id)
		if definition != null and not definition.is_egg:
			ids.append(piece_id)
	return ids

## The target of an entry: a number, or -1 for "all" and -2 for "half" of the total.
static func target_of(entry: Dictionary) -> int:
	var target: int = int(entry.get("target", 1))
	if target == -1:
		return maxi(1, total_for(str(entry["stat"])))
	if target == -2:
		return maxi(1, ceili(float(total_for(str(entry["stat"]))) / 2.0))
	return target

static func value_of(entry: Dictionary, stats: Dictionary) -> int:
	return int(stats.get(str(entry["stat"]), 0))

static func is_done(entry: Dictionary, stats: Dictionary) -> bool:
	return value_of(entry, stats) >= target_of(entry)

static func entry(achievement_id: String) -> Dictionary:
	for candidate: Dictionary in ENTRIES:
		if str(candidate["id"]) == achievement_id:
			return candidate
	return {}

static func title_key(achievement_id: String) -> String:
	return "ACH_%s_TITLE" % achievement_id.to_upper()

static func desc_key(achievement_id: String) -> String:
	return "ACH_%s_DESC" % achievement_id.to_upper()
