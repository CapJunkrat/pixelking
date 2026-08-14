class_name KnightCapturePresentationReview
extends Control

const CELL_SIZE := 60.0
const BOARD_ORIGIN := Vector2(30, 130)
const SOURCE_CELL := Vector2i(1, 1)
const TARGET_CELL := Vector2i(2, 3)

@onready var board_stage: Control = $BoardStage
@onready var grid: GridContainer = $BoardStage/Grid
@onready var selection_ring: TextureRect = $BoardStage/SelectionRing
@onready var target_glow: ColorRect = $BoardStage/TargetGlow
@onready var knight: AnimatedSprite2D = $BoardStage/Knight
@onready var enemy: Sprite2D = $BoardStage/EnemyRook
@onready var impact_flash: ColorRect = $BoardStage/ImpactFlash
@onready var replay_button: Button = $ReplayButton
@onready var phase_label: Label = $PhaseLabel

var _playing: bool = false

func _ready() -> void:
	_build_grid()
	replay_button.pressed.connect(play_capture_example)
	play_capture_example.call_deferred()

func _build_grid() -> void:
	if grid.get_child_count() > 0:
		return
	for y: int in range(5):
		for x: int in range(5):
			var square: ColorRect = ColorRect.new()
			square.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			square.color = Color("#243b4a") if (x + y) % 2 == 0 else Color("#b69a67")
			square.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(square)

func play_capture_example() -> void:
	if _playing:
		return
	_playing = true
	replay_button.disabled = true
	_reset_example()
	phase_label.text = "1  SELECT — programmatic glow and lift"
	var select_tween: Tween = create_tween().set_parallel(true)
	select_tween.tween_property(selection_ring, "modulate:a", 1.0, 0.16)
	select_tween.tween_property(target_glow, "modulate:a", 0.85, 0.16)
	select_tween.tween_property(knight, "scale", Vector2(1.14, 1.14), 0.16).set_trans(Tween.TRANS_BACK)
	await select_tween.finished
	await get_tree().create_timer(0.12).timeout

	phase_label.text = "2  MOVE — fast arc, no walking cycle"
	var source: Vector2 = _cell_center(SOURCE_CELL)
	var target: Vector2 = _cell_center(TARGET_CELL)
	var arc_peak: Vector2 = source.lerp(target, 0.5) + Vector2(0, -42)
	var move_up: Tween = create_tween().set_parallel(true)
	move_up.tween_property(knight, "position", arc_peak, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move_up.tween_property(selection_ring, "modulate:a", 0.0, 0.12)
	await move_up.finished
	var move_down: Tween = create_tween()
	move_down.tween_property(knight, "position", target + Vector2(-13, 0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await move_down.finished

	phase_label.text = "3  CAPTURE — short sprite action + impact layers"
	knight.play("attack")
	await get_tree().create_timer(0.28).timeout
	impact_flash.position = target - impact_flash.size * 0.5
	impact_flash.show()
	var impact_tween: Tween = create_tween().set_parallel(true)
	impact_tween.tween_property(impact_flash, "modulate:a", 0.0, 0.22)
	impact_tween.tween_property(impact_flash, "scale", Vector2(1.45, 1.45), 0.22)
	impact_tween.tween_property(enemy, "modulate", Color(2.0, 2.0, 2.0, 0.0), 0.22)
	impact_tween.tween_property(enemy, "scale", Vector2(0.62, 0.62), 0.22)
	_shake_board()
	await impact_tween.finished
	knight.stop()
	knight.frame = 0
	knight.position = target
	knight.scale = Vector2.ONE
	target_glow.modulate.a = 0.0
	phase_label.text = "4  SETTLED — authority already decided; presentation ends"
	await get_tree().create_timer(0.35).timeout
	replay_button.disabled = false
	_playing = false

func _reset_example() -> void:
	var source: Vector2 = _cell_center(SOURCE_CELL)
	var target: Vector2 = _cell_center(TARGET_CELL)
	board_stage.position = BOARD_ORIGIN
	knight.position = source
	knight.scale = Vector2.ONE
	knight.stop()
	knight.frame = 0
	enemy.position = target
	enemy.scale = Vector2(0.78, 0.78)
	enemy.modulate = Color.WHITE
	enemy.show()
	selection_ring.position = source - selection_ring.size * 0.5
	selection_ring.modulate.a = 0.0
	target_glow.position = target - target_glow.size * 0.5
	target_glow.modulate.a = 0.0
	impact_flash.position = target - impact_flash.size * 0.5
	impact_flash.scale = Vector2.ONE
	impact_flash.modulate = Color(0.3, 1.0, 0.95, 0.9)
	impact_flash.hide()

func _shake_board() -> void:
	var shake: Tween = create_tween()
	shake.tween_property(board_stage, "position", BOARD_ORIGIN + Vector2(5, -2), 0.035)
	shake.tween_property(board_stage, "position", BOARD_ORIGIN + Vector2(-4, 2), 0.035)
	shake.tween_property(board_stage, "position", BOARD_ORIGIN, 0.05)

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5)
