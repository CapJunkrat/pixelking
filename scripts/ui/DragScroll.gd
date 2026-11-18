class_name DragScroll
extends Node

## Lets a finger scroll a ScrollContainer by dragging its content, not only its bar.
## A ScrollContainer scrolls under a touch drag only when the touch reaches it, and
## panels, rich text and buttons stop touches by default. This lets every control
## inside pass touches on (they still get their own taps), now and when the content
## is rebuilt later. Controls deliberately set to ignore touches are left alone.

static func enable(scroll: ScrollContainer) -> void:
	if scroll == null or scroll.has_node("DragScroll"):
		return
	var helper: DragScroll = DragScroll.new()
	helper.name = "DragScroll"
	scroll.add_child(helper)
	pass_through(scroll)

## Sets every control under `root` that stops touches to pass them on.
static func pass_through(root: Node) -> void:
	for child: Node in root.get_children():
		_pass(child)
		pass_through(child)

static func _pass(node: Node) -> void:
	var control: Control = node as Control
	if control != null and control.mouse_filter == Control.MOUSE_FILTER_STOP:
		control.mouse_filter = Control.MOUSE_FILTER_PASS

func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func _on_node_added(node: Node) -> void:
	var scroll: Node = get_parent()
	if scroll != null and node != self and scroll.is_ancestor_of(node):
		_pass(node)
