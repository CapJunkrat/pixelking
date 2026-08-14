class_name PieceMotionProfileDatabase
extends RefCounted

static var _cache: Dictionary = {}

static func get_profile(id: StringName) -> PieceMotionProfile:
	if _cache.is_empty():
		_build()
	return _cache.get(id, _cache.get(&"queen")) as PieceMotionProfile

static func _build() -> void:
	_add(&"pawn", PieceMotionProfile.PathType.LINEAR, 0.12, 0.22, 0.0)
	_add(&"knight", PieceMotionProfile.PathType.ARC, 0.12, 0.22, 0.8)
	_add(&"bishop", PieceMotionProfile.PathType.LINEAR, 0.10, 0.22, 0.0)
	_add(&"rook", PieceMotionProfile.PathType.LINEAR, 0.10, 0.22, 0.0)
	_add(&"queen", PieceMotionProfile.PathType.LINEAR, 0.12, 0.22, 0.0)
	_add(&"king", PieceMotionProfile.PathType.LINEAR, 0.14, 0.22, 0.0)

static func _add(id: StringName, path_type: PieceMotionProfile.PathType, move_duration: float, capture_duration: float, arc: float) -> void:
	var profile: PieceMotionProfile = PieceMotionProfile.new()
	profile.id = id
	profile.path_type = path_type
	profile.move_duration = move_duration
	profile.capture_duration = capture_duration
	profile.arc_height_cells = arc
	_cache[id] = profile
