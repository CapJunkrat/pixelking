class_name ResponsiveSafeArea
extends MarginContainer

## Adds only the device cutout/system-gesture insets. Scene-authored offsets remain
## the ordinary visual padding, so desktop and 16:9 layouts are unchanged.
@export var apply_on_desktop: bool = false

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_safe_area)
	call_deferred("_apply_safe_area")

func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_apply_safe_area):
		get_viewport().size_changed.disconnect(_apply_safe_area)

func _apply_safe_area() -> void:
	var should_apply: bool = apply_on_desktop or OS.has_feature("mobile")
	if not should_apply:
		_set_safe_margins(0, 0, 0, 0)
		return
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var logical_size: Vector2 = get_viewport().get_visible_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0 or logical_size.x <= 0.0 or logical_size.y <= 0.0:
		_set_safe_margins(0, 0, 0, 0)
		return
	var margins: Vector4i = calculate_safe_margins(screen_size, safe_rect, logical_size)
	_set_safe_margins(margins.x, margins.y, margins.z, margins.w)

static func calculate_safe_margins(screen_size: Vector2i, safe_rect: Rect2i, logical_size: Vector2) -> Vector4i:
	if screen_size.x <= 0 or screen_size.y <= 0 or logical_size.x <= 0.0 or logical_size.y <= 0.0:
		return Vector4i.ZERO
	var safe_end: Vector2i = safe_rect.position + safe_rect.size
	return Vector4i(
		ceili(maxf(0.0, float(safe_rect.position.x) * logical_size.x / float(screen_size.x))),
		ceili(maxf(0.0, float(safe_rect.position.y) * logical_size.y / float(screen_size.y))),
		ceili(maxf(0.0, float(screen_size.x - safe_end.x) * logical_size.x / float(screen_size.x))),
		ceili(maxf(0.0, float(screen_size.y - safe_end.y) * logical_size.y / float(screen_size.y)))
	)

func _set_safe_margins(left: int, top: int, right: int, bottom: int) -> void:
	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)
