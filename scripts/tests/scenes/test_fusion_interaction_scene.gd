extends SceneTree

const TEST_PATH := "user://test_fusion_interaction_scene.save"

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_expect(manager.create_run(42424242, RunState.MODE_STANDARD, true), "fusion scene test creates a Run")
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
	manager.current_run.pending_choice = {
		"choice_version": 1,
		"type": "battle_reward",
		"title": "Original Offers",
		"description": "Saved candidates",
		"allow_leave": false,
		"options": [{
			"id": "recipe_offer",
			"label": "Lancer Blueprint",
			"enabled": true,
			"payload": {"kind": "fusion", "recipe_id": "pawn_knight_lancer"},
		}],
	}
	_expect(manager.save_active_run() == OK, "fusion source offer saves")
	_expect(manager.submit_run_interaction("recipe_offer") == OK, "selecting a recipe saves fusion preview")
	var packed: PackedScene = load("res://scenes/run/RunInteractionScene.tscn") as PackedScene
	var scene: RunInteractionScene = packed.instantiate() as RunInteractionScene
	root.add_child(scene)
	await process_frame
	await process_frame
	_expect(scene.title_label.text == "Lancer Blueprint", "fusion preview uses localized recipe title")
	_expect(scene.choices.get_child_count() == 2, "fusion preview shows confirm and cancel actions")
	_expect((scene.choices.get_child(0) as Button).text == "Confirm Fusion", "fusion confirm action is localized")
	_expect((scene.choices.get_child(1) as Button).text == "Back to Offers", "fusion cancel action is localized")
	scene.queue_free()
	await process_frame
	manager.abandon_run()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("[PASS] Fusion interaction scene test" if failures == 0 else "[FAIL] Fusion interaction scene test")
	quit(0 if failures == 0 else 1)
