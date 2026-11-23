extends SceneTree

## Fusion blueprints on the choice screen (shop and battle reward) are drawn as
## A + B = result; holding a piece opens its card, letting go closes it without picking
## the blueprint, and a short tap still picks it.
##   CAPTURE_DIR=<dir> Godot --path . --script res://scripts/tests/scenes/test_fusion_recipe_cards.gd
## (with rendering) also saves screenshots of the cards and of an open piece card.

const TEST_PATH := "user://test_fusion_recipe_cards.save"

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(360, 740)
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_expect(manager.create_run(51515151, RunState.MODE_STANDARD, true), "recipe card test creates a Run")
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		manager.submit_opening_draft_choice(str(candidates[0]))
	manager.current_run.allocate_piece("pawn", false)
	manager.current_run.allocate_piece("knight", false)
	manager.ensure_run_map()
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		if Content.map_node(node.node_type_id).is_battle:
			manager.select_map_node(node_id)
			break
	manager.begin_deployment()
	manager.confirm_deployment()
	manager.start_current_battle()
	manager.apply_battle_outcome(true)
	manager.current_run.pending_choice = RunChoiceBuilder.pending("battle_reward", "Victory", "", [
		RunChoiceBuilder.option("recipe_offer", "Lancer Blueprint", "fusion", {"recipe_id": "pawn_knight_lancer"}),
		RunChoiceBuilder.option("take_gold", "Gold", "gold", {"amount": 12}),
	] as Array[Dictionary], false)
	# Untyped: naming the scene's class here would compile it (and the piece card, which
	# uses the Localization autoload by name) before the autoloads exist.
	var scene: Node = (load("res://scenes/run/RunInteractionScene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var view: FusionRecipeView = _find_view(scene)
	_expect(view != null, "the blueprint card draws its recipe")
	if view == null:
		_finish(scene, manager)
		return
	var pieces: Array[TextureRect] = view.piece_controls()
	var ids: Array[String] = []
	var drawn: bool = true
	for picture: TextureRect in pieces:
		ids.append(str(picture.get_meta("piece_def_id")))
		drawn = drawn and picture.texture != null
	_expect(ids == ["pawn", "knight", "lancer"] and drawn, "it shows Pawn + Knight = Lancer as pictures")
	await _capture("recipe_cards")
	var info: Control = scene.get_node("PieceInfo") as Control

	for index: int in range(pieces.size()):
		var at: Vector2 = pieces[index].get_global_rect().get_center()
		_touch(at, true)
		await create_timer(FusionRecipeView.HOLD_SECONDS + 0.25).timeout
		_expect(info.visible, "holding %s opens its card" % ids[index])
		if index == 2:
			await _capture("recipe_piece_info")
		_touch(at, false)
		await process_frame
		_expect(not info.visible, "letting go of %s closes the card" % ids[index])
		_expect(str(manager.current_run.pending_choice.get("type", "")) == "battle_reward", "the release after holding %s picks nothing" % ids[index])

	var tap_at: Vector2 = pieces[0].get_global_rect().get_center()
	_touch(tap_at, true)
	await process_frame
	_touch(tap_at, false)
	await process_frame
	await process_frame
	_expect(str(manager.current_run.pending_choice.get("type", "")) == "fusion_confirmation", "a short tap on the recipe still picks the blueprint")
	_finish(scene, manager)

func _find_view(node: Node) -> FusionRecipeView:
	if node is FusionRecipeView:
		return node as FusionRecipeView
	for child: Node in node.get_children():
		var found: FusionRecipeView = _find_view(child)
		if found != null:
			return found
	return null

func _touch(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	root.push_input(event)

func _capture(label: String) -> void:
	var directory: String = OS.get_environment("CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [directory, label])

func _finish(scene: Node, manager: AppRunManager) -> void:
	scene.queue_free()
	await process_frame
	manager.abandon_run()
	print("[PASS] Fusion recipe card test" if failures == 0 else "[FAIL] Fusion recipe card test")
	quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error(message)
