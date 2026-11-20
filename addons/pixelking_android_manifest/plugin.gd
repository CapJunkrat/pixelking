@tool
extends EditorPlugin

## Registers the export plugin that adds PixelKing's extra Android manifest entries.

var _export_plugin: EditorExportPlugin = null

func _enter_tree() -> void:
	_export_plugin = preload("res://addons/pixelking_android_manifest/android_manifest_export.gd").new()
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
