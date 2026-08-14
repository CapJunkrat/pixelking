class_name PieceMotionProfile
extends Resource

enum PathType { LINEAR, ARC }

@export var id: StringName = &"linear"
@export var path_type: PathType = PathType.LINEAR
@export_range(0.0, 1.0, 0.01) var move_duration: float = 0.12
@export_range(0.0, 1.0, 0.01) var capture_duration: float = 0.22
@export_range(0.0, 2.0, 0.05) var arc_height_cells: float = 0.0

func is_valid() -> bool:
	return not id.is_empty() and move_duration >= 0.0 and capture_duration >= move_duration
