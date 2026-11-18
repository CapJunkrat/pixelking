class_name RunSummaryService
extends RefCounted

## The end of a run: won after the third act's Boss, or lost. Endless runs end only by
## losing, and report how many acts they cleared.
func stage(run_state: RunState, won: bool) -> void:
	var battles_won: int = int(run_state.run_statistics.get("battles_won", 0))
	var acts_cleared: int = int(run_state.run_statistics.get("acts_cleared", run_state.act_index))
	run_state.run_statistics["run_won"] = won
	var title_key: String = "SUMMARY_WON_TITLE" if won else ("SUMMARY_ENDLESS_TITLE" if run_state.mode == RunState.MODE_ENDLESS else "SUMMARY_LOST_TITLE")
	var description_key: String = "SUMMARY_WON_TEXT" if won else ("SUMMARY_ENDLESS_TEXT" if run_state.mode == RunState.MODE_ENDLESS else "SUMMARY_LOST_TEXT")
	var pending: Dictionary = RunChoiceBuilder.pending("run_summary", "", "", [], true)
	pending["title_key"] = title_key
	pending["description_key"] = description_key
	pending["description_args"] = [acts_cleared, battles_won, run_state.gold]
	run_state.pending_choice = pending
