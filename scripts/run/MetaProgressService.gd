class_name MetaProgressService
extends RefCounted

## What outlives a journey: codex pages found, lifetime statistics and achievements.
## Saved as JSON in user://. Version 3 replaced the old endless-mode unlock and best
## endless result with statistics (an old save's best result becomes best_acts).

const DEFAULT_PATH := "user://pixelking_meta.save"
const SAVE_VERSION := 3
## Statistics that only ever go up to a new best; the rest are running totals.
const BEST_STATS: Array[String] = ["best_acts", "best_run_kills", "best_run_fusions", "flawless_acts"]
const TOTAL_STATS: Array[String] = ["total_kills", "total_runs", "small_boss_wins"]

var save_path: String = DEFAULT_PATH

func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path

# --- statistics ---------------------------------------------------------------

## Every statistic an achievement can read, including the counted ones ("bosses",
## "codex").
func stats() -> Dictionary:
	var data: Dictionary = _load_data()
	var result: Dictionary = {}
	var stored: Dictionary = data.get("stats", {}) as Dictionary
	for key: String in BEST_STATS + TOTAL_STATS:
		result[key] = int(stored.get(key, 0))
	result["bosses"] = (data.get("bosses_beaten", []) as Array).size()
	result["codex"] = discovered_piece_ids().size()
	return result

func stat(key: String) -> int:
	return int(stats().get(key, 0))

## Raises best-of statistics and adds to totals in one save. `best` and `add` map stat
## keys to values; a best only changes when the new value beats it.
func record(best: Dictionary = {}, add: Dictionary = {}) -> Error:
	var data: Dictionary = _load_data()
	var stored: Dictionary = (data.get("stats", {}) as Dictionary).duplicate()
	var changed: bool = false
	for key: Variant in best:
		var value: int = int(best[key])
		if value > int(stored.get(key, 0)):
			stored[key] = value
			changed = true
	for key: Variant in add:
		var amount: int = int(add[key])
		if amount != 0:
			stored[key] = int(stored.get(key, 0)) + amount
			changed = true
	if not changed:
		return OK
	data["stats"] = stored
	return _save_data(data)

## A Boss falls: it joins the list of different Bosses beaten.
func record_boss(encounter_id: String) -> Error:
	var data: Dictionary = _load_data()
	var beaten: Array = (data.get("bosses_beaten", []) as Array).duplicate()
	if encounter_id.is_empty() or encounter_id in beaten:
		return OK
	beaten.append(encounter_id)
	beaten.sort()
	data["bosses_beaten"] = beaten
	return _save_data(data)

func bosses_beaten() -> Array[String]:
	var result: Array[String] = []
	for value: Variant in _load_data().get("bosses_beaten", []) as Array:
		result.append(str(value))
	return result

# --- achievements -------------------------------------------------------------

func unlocked_achievement_ids() -> Array[String]:
	var result: Array[String] = []
	for value: Variant in _load_data().get("achievements", []) as Array:
		result.append(str(value))
	return result

## Unlocks every achievement whose statistic has reached its target; returns the ones
## that are new this time, in catalog order.
func unlock_reached_achievements() -> Array[String]:
	var current: Dictionary = stats()
	var unlocked: Array[String] = unlocked_achievement_ids()
	var fresh: Array[String] = []
	for entry: Dictionary in AchievementCatalog.ENTRIES:
		var achievement_id: String = str(entry["id"])
		if achievement_id not in unlocked and AchievementCatalog.is_done(entry, current):
			fresh.append(achievement_id)
	if fresh.is_empty():
		return fresh
	var data: Dictionary = _load_data()
	var saved: Array = (data.get("achievements", []) as Array).duplicate()
	saved.append_array(fresh)
	data["achievements"] = saved
	if _save_data(data) != OK:
		return []
	return fresh

# --- codex --------------------------------------------------------------------

func discovered_piece_ids() -> Array[String]:
	var result: Array[String] = []
	var stored: Variant = _load_data().get("discovered_piece_ids", [])
	if stored is Array:
		for value: Variant in stored as Array:
			var piece_id: String = str(value)
			if Content.piece(piece_id) != null and piece_id not in result:
				result.append(piece_id)
	result.sort()
	return result

func is_piece_discovered(piece_id: String) -> bool:
	return piece_id in discovered_piece_ids()

func record_discovered_piece_ids(piece_ids: Array[String]) -> Error:
	var data: Dictionary = _load_data()
	var discovered: Array[String] = discovered_piece_ids()
	var changed: bool = false
	for piece_id: String in piece_ids:
		if Content.piece(piece_id) != null and piece_id not in discovered:
			discovered.append(piece_id)
			changed = true
	if not changed:
		return OK
	discovered.sort()
	data["discovered_piece_ids"] = discovered
	return _save_data(data)

# --- file ---------------------------------------------------------------------

func _empty_data() -> Dictionary:
	return {"version": SAVE_VERSION, "discovered_piece_ids": [], "stats": {}, "bosses_beaten": [], "achievements": []}

func _load_data() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return _empty_data()
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _empty_data()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _empty_data()
	return _migrate((parsed as Dictionary).duplicate(true))

## Older saves: version 2 had an endless-mode unlock and a best endless result. The best
## result (or Act 3 for a won journey) becomes the best number of acts cleared.
func _migrate(data: Dictionary) -> Dictionary:
	for key: String in ["discovered_piece_ids", "bosses_beaten", "achievements"]:
		if not data.get(key, null) is Array:
			data[key] = []
	if not data.get("stats", null) is Dictionary:
		data["stats"] = {}
	var stored: Dictionary = data["stats"]
	var old_best: int = int(data.get("best_endless_acts", 0))
	if bool(data.get("endless_unlocked", false)):
		old_best = maxi(old_best, RunState.ACT_COUNT)
	if old_best > int(stored.get("best_acts", 0)):
		stored["best_acts"] = old_best
	data.erase("best_endless_acts")
	data.erase("endless_unlocked")
	data["version"] = SAVE_VERSION
	return data

func _save_data(data: Dictionary) -> Error:
	data["version"] = SAVE_VERSION
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	return OK
