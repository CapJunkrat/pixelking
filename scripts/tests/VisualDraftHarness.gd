class_name VisualDraftHarness
extends Node

const TEST_PATH := "user://pixelking_visual_draft_test.save"

func _ready() -> void:
	var manager: AppRunManager = get_node("/root/RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	if not manager.create_run(778899, RunState.MODE_STANDARD, true):
		push_error("Could not create visual Run")
		return
	call_deferred("_open_draft")

func _open_draft() -> void:
	get_tree().change_scene_to_file("res://scenes/run/OpeningDraftScene.tscn")
