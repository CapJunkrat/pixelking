class_name RosterService
extends RefCounted

func move_to_active(run_state: RunState, instance_id: int) -> Error:
	if run_state == null or run_state.get_piece_state(instance_id) == null:
		return ERR_DOES_NOT_EXIST
	var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
	if piece.is_king:
		return ERR_UNAUTHORIZED
	if instance_id in run_state.active_piece_ids:
		return OK
	return OK if run_state.move_piece_to_active(instance_id) else ERR_UNAVAILABLE

func move_to_reserve(run_state: RunState, instance_id: int) -> Error:
	if run_state == null or run_state.get_piece_state(instance_id) == null:
		return ERR_DOES_NOT_EXIST
	var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
	if piece.is_king:
		return ERR_UNAUTHORIZED
	if instance_id in run_state.reserve_piece_ids:
		return OK
	return OK if run_state.move_piece_to_reserve(instance_id) else ERR_UNAVAILABLE

## Trades a battle-line piece for a reserve piece. With a formation on the board the
## reserve piece steps onto the square the other one leaves.
func swap(run_state: RunState, active_id: int, reserve_id: int) -> Error:
	if run_state == null or run_state.get_piece_state(active_id) == null or run_state.get_piece_state(reserve_id) == null:
		return ERR_DOES_NOT_EXIST
	if run_state.get_piece_state(active_id).is_king or run_state.get_piece_state(reserve_id).is_king:
		return ERR_UNAUTHORIZED
	var square: Vector2i = Vector2i(-1, -1)
	if run_state.deployment_state != null:
		square = run_state.deployment_state.player_position(active_id)
	if not run_state.swap_active_with_reserve(active_id, reserve_id):
		return ERR_UNAVAILABLE
	run_state.preferred_positions.erase(str(active_id))
	if square != Vector2i(-1, -1):
		run_state.preferred_positions[str(reserve_id)] = DeploymentState.position_value(square)
	return OK

func active_pieces(run_state: RunState) -> Array[PieceInstanceState]:
	return _pieces_for_ids(run_state, run_state.active_piece_ids if run_state != null else [])

func reserve_pieces(run_state: RunState) -> Array[PieceInstanceState]:
	return _pieces_for_ids(run_state, run_state.reserve_piece_ids if run_state != null else [])

func _pieces_for_ids(run_state: RunState, ids: Array[int]) -> Array[PieceInstanceState]:
	var result: Array[PieceInstanceState] = []
	if run_state == null:
		return result
	for instance_id: int in ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		if piece != null:
			result.append(piece)
	return result
