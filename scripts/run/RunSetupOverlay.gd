class_name RunSetupOverlay
extends ColorRect

signal seed_confirmed(seed_value: int)
signal cancelled

@onready var title_label: Label = $Center/Panel/Content/Title
@onready var prompt_label: Label = $Center/Panel/Content/Prompt
@onready var seed_input: LineEdit = $Center/Panel/Content/SeedInput
@onready var error_label: Label = $Center/Panel/Content/ErrorLabel
@onready var random_button: Button = $Center/Panel/Content/Buttons/RandomButton
@onready var start_button: Button = $Center/Panel/Content/Buttons/StartButton
@onready var cancel_button: Button = $Center/Panel/Content/Buttons/CancelButton

func _ready() -> void:
	random_button.pressed.connect(_fill_random_seed)
	start_button.pressed.connect(_submit)
	cancel_button.pressed.connect(_cancel)
	seed_input.text_submitted.connect(func(_text: String) -> void: _submit())
	_apply_locale()
	hide()

func show_setup() -> void:
	error_label.text = ""
	seed_input.text = ""
	show()
	seed_input.grab_focus()

func show_error(message: String) -> void:
	error_label.text = message
	show()
	seed_input.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()

func _fill_random_seed() -> void:
	seed_input.text = str(_generate_seed())
	seed_input.caret_column = seed_input.text.length()

func _submit() -> void:
	var value_text: String = seed_input.text.strip_edges()
	if value_text.is_empty():
		value_text = str(_generate_seed())
	if not value_text.is_valid_int():
		error_label.text = Localization.text("RUN_SEED_INVALID")
		return
	var run_seed: int = value_text.to_int()
	if run_seed == 0:
		run_seed = 1
	hide()
	seed_confirmed.emit(run_seed)

func _cancel() -> void:
	hide()
	cancelled.emit()

func _generate_seed() -> int:
	var generated: int = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	return absi(generated) if generated != 0 else 1

func _apply_locale() -> void:
	title_label.text = Localization.text("RUN_SEED_TITLE")
	prompt_label.text = Localization.text("RUN_SEED_PROMPT")
	seed_input.placeholder_text = Localization.text("RUN_SEED_PLACEHOLDER")
	random_button.text = Localization.text("RUN_SEED_RANDOM")
	start_button.text = Localization.text("COMMON_CONFIRM")
	cancel_button.text = Localization.text("COMMON_CANCEL")
