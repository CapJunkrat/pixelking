class_name RunSummaryService
extends RefCounted

func stage(run_state: RunState, won: bool) -> void:
	var battles_won: int = int(run_state.run_statistics.get("battles_won", 0))
	var description: String = "Boss defeated. Endless mode is now unlocked." if won else "Defeated again with no retry left. The journey ends."
	run_state.run_statistics["run_won"] = won
	run_state.pending_choice = RunChoiceBuilder.pending(
		"run_summary",
		"Journey Complete" if won else "Journey Lost",
		"%s\nBattles won: %d\nGold: %d" % [description, battles_won, run_state.gold],
		[],
		true
	)
