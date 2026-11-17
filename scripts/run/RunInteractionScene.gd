class_name RunInteractionScene
extends Control

@onready var title_label: Label = $SafeArea/Layout/Title
@onready var status_label: Label = $SafeArea/Layout/Status
@onready var choices: VBoxContainer = $SafeArea/Layout/Choices
@onready var leave_button: Button = $SafeArea/Layout/LeaveButton
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager
@onready var localization: Node = get_node("/root/Localization")

func _ready() -> void:
	leave_button.pressed.connect(_on_leave)
	_render()

func _render() -> void:
	for child: Node in choices.get_children():
		child.queue_free()
	if run_manager.current_run == null or run_manager.current_run.pending_choice.is_empty():
		title_label.text = "No pending interaction"
		status_label.text = "Return to the journey map."
		leave_button.text = "Continue"
		return
	var pending: Dictionary = run_manager.current_run.pending_choice
	var type: String = str(pending.get("type", "interaction"))
	var title_key: String = str(pending.get("title_key", ""))
	title_label.text = _localized(title_key) if not title_key.is_empty() else str(pending.get("title", type.replace("_", " ").capitalize()))
	var description: String = str(pending.get("description", "Choose one option."))
	var description_key: String = str(pending.get("description_key", ""))
	if not description_key.is_empty():
		description = "%s\n\n%s" % [_localized(description_key), description]
	status_label.text = "%s\nGold: %d" % [description, run_manager.current_run.gold]
	var option_values: Array = pending.get("options", []) as Array
	for option_value: Variant in option_values:
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value as Dictionary
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		var label_key: String = str(option.get("label_key", ""))
		button.text = _localized(label_key) if not label_key.is_empty() else str(option.get("label", option.get("id", "Option")))
		button.set_meta("choice_id", str(option.get("id", "")))
		button.disabled = not bool(option.get("enabled", true))
		button.pressed.connect(_submit.bind(str(option.get("id", ""))))
		choices.add_child(button)
	leave_button.visible = bool(pending.get("allow_leave", false)) or type == "run_summary"
	leave_button.text = "Finish Run" if type == "run_summary" else "Leave"

func _submit(choice_id: String) -> void:
	var error: Error = run_manager.submit_run_interaction(choice_id)
	if error != OK:
		status_label.text = "That choice is unavailable."
		return
	_route_after_commit()

func _on_leave() -> void:
	if run_manager.current_run != null and str(run_manager.current_run.pending_choice.get("type", "")) == "run_summary":
		var finish_error: Error = run_manager.finish_run_summary()
		if finish_error != OK:
			status_label.text = "Unable to finish the Run: %s" % error_string(finish_error)
			return
		get_tree().change_scene_to_file(AppSceneRoutes.MAIN_MENU)
		return
	if run_manager.current_run != null and not run_manager.current_run.pending_choice.is_empty():
		var error: Error = run_manager.leave_run_interaction()
		if error != OK:
			status_label.text = "Cannot leave yet."
			return
	_route_after_commit()

func _route_after_commit() -> void:
	if run_manager.current_run == null:
		get_tree().change_scene_to_file(AppSceneRoutes.MAIN_MENU)
	elif not run_manager.current_run.pending_choice.is_empty():
		_render()
	else:
		get_tree().change_scene_to_file(run_manager.resume_scene_path())

func _localized(key: String) -> String:
	return str(localization.call("text", key)) if localization != null else key
