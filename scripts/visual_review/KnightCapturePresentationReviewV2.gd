class_name KnightCapturePresentationReviewV2
extends Control

const CELL_SIZE := 60.0
const BOARD_ORIGIN := Vector2(30, 146)
const SOURCE_CELL := Vector2i(1, 1)
const TARGET_CELL := Vector2i(2, 3)

enum PresentationMode { COMPACT, STANDARD, CINEMATIC }

@onready var board_stage: Control = $BoardStage
@onready var grid: GridContainer = $BoardStage/Grid
@onready var dimmer: ColorRect = $BoardStage/Dimmer
@onready var selection_ring: TextureRect = $BoardStage/SelectionRing
@onready var target_glow: ColorRect = $BoardStage/TargetGlow
@onready var chess_knight: Sprite2D = $BoardStage/ChessKnight
@onready var lancer: AnimatedSprite2D = $BoardStage/Lancer
@onready var enemy_rook: AnimatedSprite2D = $BoardStage/EnemyRook
@onready var lance_glow: PointLight2D = $BoardStage/Lancer/LanceGlow
@onready var impact_flash: ColorRect = $BoardStage/ImpactFlash
@onready var phase_label: Label = $PhaseLabel
@onready var replay_button: Button = $ReplayButton
@onready var compact_button: Button = $ModeRow/Compact
@onready var standard_button: Button = $ModeRow/Standard
@onready var cinematic_button: Button = $ModeRow/Cinematic

var mode: PresentationMode = PresentationMode.CINEMATIC
var _playing: bool = false

func _ready() -> void:
	_build_grid()
	replay_button.pressed.connect(play_capture_example)
	compact_button.pressed.connect(_select_mode.bind(PresentationMode.COMPACT))
	standard_button.pressed.connect(_select_mode.bind(PresentationMode.STANDARD))
	cinematic_button.pressed.connect(_select_mode.bind(PresentationMode.CINEMATIC))
	_refresh_mode_buttons()
	play_capture_example.call_deferred()

func _build_grid() -> void:
	if grid.get_child_count() > 0:
		return
	for y: int in range(5):
		for x: int in range(5):
			var square: ColorRect = ColorRect.new()
			square.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			square.color = Color("#203848") if (x + y) % 2 == 0 else Color("#b89b68")
			square.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(square)

func _select_mode(value: PresentationMode) -> void:
	if _playing:
		return
	mode = value
	_refresh_mode_buttons()
	play_capture_example()

func _refresh_mode_buttons() -> void:
	compact_button.button_pressed = mode == PresentationMode.COMPACT
	standard_button.button_pressed = mode == PresentationMode.STANDARD
	cinematic_button.button_pressed = mode == PresentationMode.CINEMATIC

func play_capture_example() -> void:
	if _playing:
		return
	_playing = true
	_set_controls_disabled(true)
	_reset_example()
	match mode:
		PresentationMode.COMPACT:
			await _play_compact()
		PresentationMode.STANDARD:
			await _play_standard()
		PresentationMode.CINEMATIC:
			await _play_cinematic()
	_set_controls_disabled(false)
	_playing = false

func _play_compact() -> void:
	phase_label.text = "COMPACT — chess silhouette, arc and fast fracture"
	await _show_selection(0.06)
	await _move_sprite_arc(chess_knight, 0.22, 28.0)
	await _hit_stop(0.025)
	await _destroy_rook(24.0, 0.24)
	await _settle_as_chess_piece()

func _play_standard() -> void:
	phase_label.text = "STANDARD — quick statue unfold"
	await _show_selection(0.10)
	await _transform_to_lancer(0.16)
	phase_label.text = "STANDARD — mounted leap and diving lance"
	lancer.speed_scale = 1.6
	lancer.play("dive_attack")
	await _move_sprite_arc(lancer, 0.34, 48.0)
	await _hit_stop(0.05)
	await _destroy_rook(18.0, 0.36)
	await _transform_back(0.14)
	await _settle_as_chess_piece()

func _play_cinematic() -> void:
	phase_label.text = "CINEMATIC — target lock and statue crack"
	await _show_selection(0.16)
	var darken: Tween = create_tween()
	darken.tween_property(dimmer, "modulate:a", 0.32, 0.14)
	await darken.finished
	await _transform_to_lancer(0.28)
	phase_label.text = "CINEMATIC — rear and charge the lance tip"
	lancer.speed_scale = 0.72
	lancer.play("dive_attack")
	var charge: Tween = create_tween().set_parallel(true)
	charge.tween_property(lance_glow, "energy", 2.4, 0.22).set_trans(Tween.TRANS_QUAD)
	charge.tween_property(lancer, "scale", Vector2(1.28, 1.28), 0.22).set_trans(Tween.TRANS_BACK)
	await charge.finished
	phase_label.text = "CINEMATIC — realistic leap, magical arc"
	await _move_sprite_arc(lancer, 0.52, 68.0)
	phase_label.text = "CINEMATIC — 50 ms hit stop"
	await _hit_stop(0.05)
	phase_label.text = "CINEMATIC — recoil, crack, five-part collapse"
	await _destroy_rook(12.0, 0.72)
	phase_label.text = "CINEMATIC — reform into the chess knight"
	await _transform_back(0.24)
	await _settle_as_chess_piece()
	var restore: Tween = create_tween()
	restore.tween_property(dimmer, "modulate:a", 0.0, 0.18)
	await restore.finished

func _show_selection(duration: float) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(selection_ring, "modulate:a", 1.0, duration)
	tween.tween_property(target_glow, "modulate:a", 0.8, duration)
	tween.tween_property(chess_knight, "scale", Vector2(1.16, 1.16), duration).set_trans(Tween.TRANS_BACK)
	await tween.finished

func _transform_to_lancer(duration: float) -> void:
	lancer.position = chess_knight.position
	lancer.scale = Vector2(0.34, 0.34)
	lancer.modulate = Color(0.65, 1.45, 1.35, 0.0)
	lancer.show()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(chess_knight, "scale", Vector2(0.22, 1.42), duration)
	tween.tween_property(chess_knight, "modulate", Color(0.8, 1.8, 1.6, 0.0), duration)
	tween.tween_property(lancer, "scale", Vector2(1.18, 1.18), duration).set_trans(Tween.TRANS_BACK)
	tween.tween_property(lancer, "modulate", Color.WHITE, duration * 0.75)
	await tween.finished
	chess_knight.hide()

func _move_sprite_arc(sprite: Node2D, duration: float, arc_height: float) -> void:
	var source: Vector2 = _cell_center(SOURCE_CELL)
	var target: Vector2 = _cell_center(TARGET_CELL)
	var peak: Vector2 = source.lerp(target, 0.5) + Vector2(0, -arc_height)
	var ascent: Tween = create_tween().set_parallel(true)
	ascent.tween_property(sprite, "position", peak, duration * 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ascent.tween_property(selection_ring, "modulate:a", 0.0, duration * 0.35)
	await ascent.finished
	if mode == PresentationMode.CINEMATIC:
		await get_tree().create_timer(0.035).timeout
	var descent: Tween = create_tween().set_parallel(true)
	descent.tween_property(sprite, "position", target, duration * 0.48).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	descent.tween_property(lance_glow, "energy", 3.2, duration * 0.36)
	await descent.finished

func _hit_stop(duration: float) -> void:
	impact_flash.position = _cell_center(TARGET_CELL) - impact_flash.size * 0.5
	impact_flash.scale = Vector2(0.2, 0.2)
	impact_flash.modulate.a = 1.0
	impact_flash.show()
	_shake_board()
	await get_tree().create_timer(duration).timeout
	var flash: Tween = create_tween().set_parallel(true)
	flash.tween_property(impact_flash, "scale", Vector2(1.7, 1.7), 0.13)
	flash.tween_property(impact_flash, "modulate:a", 0.0, 0.13)

func _destroy_rook(animation_speed: float, minimum_duration: float) -> void:
	enemy_rook.speed_scale = animation_speed / 5.0
	enemy_rook.play("destroy")
	var origin_x: float = _cell_center(TARGET_CELL).x
	var recoil: Tween = create_tween()
	recoil.tween_property(enemy_rook, "position:x", origin_x + 4.0, 0.035)
	recoil.tween_property(enemy_rook, "position:x", origin_x - 5.0, 0.035)
	recoil.tween_property(enemy_rook, "position:x", origin_x + 3.0, 0.035)
	recoil.tween_property(enemy_rook, "position:x", origin_x, 0.04)
	await get_tree().create_timer(minimum_duration).timeout
	enemy_rook.hide()

func _transform_back(duration: float) -> void:
	chess_knight.position = _cell_center(TARGET_CELL)
	chess_knight.scale = Vector2(0.25, 1.35)
	chess_knight.modulate = Color(0.7, 1.6, 1.45, 0.0)
	chess_knight.show()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(lancer, "scale", Vector2(0.25, 0.25), duration)
	tween.tween_property(lancer, "modulate:a", 0.0, duration)
	tween.tween_property(chess_knight, "scale", Vector2(1.14, 1.14), duration).set_trans(Tween.TRANS_BACK)
	tween.tween_property(chess_knight, "modulate", Color.WHITE, duration * 0.7)
	await tween.finished
	lancer.hide()

func _settle_as_chess_piece() -> void:
	chess_knight.position = _cell_center(TARGET_CELL)
	chess_knight.show()
	chess_knight.modulate = Color.WHITE
	var settle: Tween = create_tween()
	settle.tween_property(chess_knight, "scale", Vector2(0.9, 0.82), 0.06)
	settle.tween_property(chess_knight, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK)
	target_glow.modulate.a = 0.24
	phase_label.text = "%s COMPLETE — final rule state is a knight on the target" % _mode_name()
	await settle.finished

func _reset_example() -> void:
	var source: Vector2 = _cell_center(SOURCE_CELL)
	var target: Vector2 = _cell_center(TARGET_CELL)
	board_stage.position = BOARD_ORIGIN
	dimmer.modulate.a = 0.0
	chess_knight.position = source
	chess_knight.scale = Vector2.ONE
	chess_knight.modulate = Color.WHITE
	chess_knight.show()
	lancer.position = source
	lancer.scale = Vector2.ONE
	lancer.modulate = Color.WHITE
	lancer.stop()
	lancer.frame = 0
	lancer.hide()
	lance_glow.energy = 0.0
	enemy_rook.position = target
	enemy_rook.scale = Vector2(0.78, 0.78)
	enemy_rook.modulate = Color.WHITE
	enemy_rook.stop()
	enemy_rook.frame = 0
	enemy_rook.show()
	selection_ring.position = source - selection_ring.size * 0.5
	selection_ring.modulate.a = 0.0
	target_glow.position = target - target_glow.size * 0.5
	target_glow.modulate.a = 0.0
	impact_flash.position = target - impact_flash.size * 0.5
	impact_flash.scale = Vector2.ONE
	impact_flash.modulate = Color(0.35, 1.0, 0.92, 0.9)
	impact_flash.hide()

func _shake_board() -> void:
	var shake: Tween = create_tween()
	shake.tween_property(board_stage, "position", BOARD_ORIGIN + Vector2(5, -2), 0.03)
	shake.tween_property(board_stage, "position", BOARD_ORIGIN + Vector2(-4, 2), 0.03)
	shake.tween_property(board_stage, "position", BOARD_ORIGIN, 0.05)

func _set_controls_disabled(value: bool) -> void:
	replay_button.disabled = value
	compact_button.disabled = value
	standard_button.disabled = value
	cinematic_button.disabled = value

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5)

func _mode_name() -> String:
	return ["COMPACT", "STANDARD", "CINEMATIC"][mode]
