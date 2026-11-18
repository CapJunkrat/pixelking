class_name AppSceneRoutes
extends RefCounted

const MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const OPENING_DRAFT := "res://scenes/run/OpeningDraftScene.tscn"
const PATH_MAP := "res://scenes/run/PathMapScene.tscn"
## The pre-battle preview (it replaced the manual deployment screen).
const DEPLOYMENT := "res://scenes/run/PreBattleScene.tscn"
const BATTLE := "res://scenes/battle/BattleScene.tscn"
const RUN_INTERACTION := "res://scenes/run/RunInteractionScene.tscn"
const ROSTER := "res://scenes/run/RosterScene.tscn"

static func navigate(tree: SceneTree, scene_path: String) -> Error:
	if tree == null or scene_path.is_empty():
		return ERR_INVALID_PARAMETER
	return tree.change_scene_to_file(scene_path)
