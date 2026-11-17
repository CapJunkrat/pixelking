class_name BattleRunResult
extends RefCounted

var success: bool = true
var has_active_run: bool = false
var retry_visible: bool = true
var exit_text: String = ""
var exit_text_key: StringName = &"BATTLE_RESULT_MAIN_MENU"
var error: Error = OK
var pending_type: StringName = &""
