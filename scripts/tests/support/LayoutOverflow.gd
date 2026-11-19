class_name LayoutOverflow
extends RefCounted

## Visible controls that reach past `width` (the phone's logical width). Controls inside
## a ScrollContainer that scrolls sideways are allowed to; nothing else is.
static func find(root: Control, width: float, tolerance: float = 1.0) -> Array[String]:
	var found: Array[String] = []
	_walk(root, width, tolerance, found)
	return found

static func _walk(node: Node, width: float, tolerance: float, found: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Control:
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x > 0.0 and (rect.position.x < -tolerance or rect.end.x > width + tolerance):
			# Report the innermost culprit: a parent only when no child of it overflows.
			var before: int = found.size()
			for child: Node in node.get_children():
				_walk(child, width, tolerance, found)
			if found.size() == before:
				found.append("%s [%.0f..%.0f, min %.0f]" % [control.get_path(), rect.position.x, rect.end.x, control.get_combined_minimum_size().x])
			return
		if control is ScrollContainer and (control as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return
	for child: Node in node.get_children():
		_walk(child, width, tolerance, found)
