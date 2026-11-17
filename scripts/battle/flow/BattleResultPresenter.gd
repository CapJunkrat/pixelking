class_name BattleResultPresenter
extends RefCounted

var panel: BattleResultPanel = null
var title_label: Label = null
var detail_label: Label = null
var retry_button: Button = null
var exit_button: Button = null
var localization: Node = null

func bind(result_panel: BattleResultPanel, localization_service: Node) -> void:
	localization = localization_service
	panel = result_panel
	title_label = panel.title_label
	detail_label = panel.detail_label
	retry_button = panel.retry_button
	exit_button = panel.exit_button
	retry_button.text = _text("BATTLE_RETRY")
	exit_button.text = _text("BATTLE_RESULT_MAIN_MENU")

func present(player_won: bool, draw: bool, run_result: BattleRunResult) -> void:
	var title_text: String
	var detail_text: String
	if draw:
		title_text = _text("BATTLE_DRAW")
		detail_text = _text("BATTLE_DRAW_DETAIL")
	elif player_won:
		title_text = _text("BATTLE_VICTORY")
		detail_text = _text("BATTLE_VICTORY_DETAIL")
	else:
		title_text = _text("BATTLE_DEFEAT")
		detail_text = _text("BATTLE_DEFEAT_DETAIL")
	if run_result != null:
		retry_button.visible = run_result.retry_visible
		exit_button.text = run_result.exit_text if not run_result.exit_text.is_empty() else _text(String(run_result.exit_text_key))
		if not run_result.success and run_result.error != OK:
			detail_text = "%s\nRun save error: %s" % [detail_text, error_string(run_result.error)]
	panel.present(title_text, detail_text)

func _text(key: String) -> String:
	return str(localization.call("text", key)) if localization != null else key
