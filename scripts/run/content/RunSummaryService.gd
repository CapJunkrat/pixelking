class_name RunSummaryService
extends RefCounted

## The end of a journey: it only ends when the army falls with no retry left. The
## summary shows how far it went and how many enemies it defeated.
func stage(run_state: RunState, won: bool) -> void:
	var battles_won: int = int(run_state.run_statistics.get("battles_won", 0))
	var acts_cleared: int = int(run_state.run_statistics.get("acts_cleared", run_state.act_index))
	var kills: int = int(run_state.run_statistics.get("kills", 0))
	run_state.run_statistics["run_won"] = won
	var pending: Dictionary = RunChoiceBuilder.pending("run_summary", "", "", [], true)
	pending["title_key"] = "SUMMARY_TITLE"
	pending["description_key"] = "SUMMARY_TEXT"
	pending["description_args"] = [run_state.act_index + 1, acts_cleared, battles_won, kills, run_state.gold]
	run_state.pending_choice = pending
