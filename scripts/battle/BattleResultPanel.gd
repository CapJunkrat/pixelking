class_name BattleResultPanel
extends ColorRect

signal retry_requested
signal exit_requested

@onready var title_label: Label = $Center/Panel/Margin/Content/ResultTitle
@onready var detail_label: Label = $Center/Panel/Margin/Content/ResultDetail
@onready var retry_button: Button = $Center/Panel/Margin/Content/RetryButton
@onready var exit_button: Button = $Center/Panel/Margin/Content/ExitButton

func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	hide()

func present(title_text: String, detail_text: String) -> void:
	title_label.text = title_text
	detail_label.text = detail_text
	show()

func set_retry_visible(visible_value: bool) -> void:
	retry_button.visible = visible_value

func set_exit_text(value: String) -> void:
	exit_button.text = value
