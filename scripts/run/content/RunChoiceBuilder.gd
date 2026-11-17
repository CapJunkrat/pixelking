class_name RunChoiceBuilder
extends RefCounted

static func pending(type: String, title: String, description: String, options: Array[Dictionary], allow_leave: bool) -> Dictionary:
	return {
		"choice_version": 1,
		"type": type,
		"title": title,
		"description": description,
		"options": options,
		"allow_leave": allow_leave,
	}

static func option(id: String, label: String, kind: String, data: Dictionary, enabled: bool = true) -> Dictionary:
	var payload: Dictionary = data.duplicate(true)
	payload["kind"] = kind
	return {"id": id, "label": label, "enabled": enabled, "payload": payload}

static func find_option(pending_choice: Dictionary, choice_id: String) -> Dictionary:
	for value: Variant in pending_choice.get("options", []) as Array:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return (value as Dictionary).duplicate(true)
	return {}
