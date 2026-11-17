class_name PieceMotionProfileDatabase
extends RefCounted

const DefaultContentType = preload("res://scripts/content/DefaultContent.gd")

static func get_profile(id: StringName) -> PieceMotionProfile:
	var profile: PieceMotionProfile = DefaultContentType.registry().motion_profile(id)
	return profile if profile != null else DefaultContentType.registry().motion_profile(&"queen")
