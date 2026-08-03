class_name MovementProfile
extends Resource

## Inherits only ordinary movement rules. Piece identity and special actions
## such as castling remain on PieceDef and are never inherited through this link.
@export var parent: MovementProfile
@export var rules: Array[MovementRule] = []

func resolved_rules() -> Array[MovementRule]:
	var result: Array[MovementRule] = []
	_append_resolved(result, {})
	return result

func _append_resolved(result: Array[MovementRule], visited: Dictionary) -> void:
	var identity := get_instance_id()
	if visited.has(identity):
		push_warning("MovementProfile inheritance cycle detected")
		return
	visited[identity] = true
	if parent != null:
		parent._append_resolved(result, visited)
	for rule in rules:
		if rule != null and rule not in result:
			result.append(rule)
