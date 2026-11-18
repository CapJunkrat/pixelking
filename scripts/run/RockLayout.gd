class_name RockLayout
extends RefCounted

## Where rocks stand in a battle. Rocks only appear in the no-man's-land rows between the
## two deployment zones, always as a mirrored pair (x, y) / (size-1-x, size-1-y) so
## neither side is favoured, and there are more of them deeper into the map. The same
## seed always gives the same rocks.

static func generate(seed_value: int, layer: int, total_layers: int, board_size: int = BoardState.DEFAULT_SIZE) -> Array[Vector2i]:
	var rocks: Array[Vector2i] = []
	if layer <= 0:
		return rocks
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5eed_7c0c
	var progress: float = clampf(float(layer) / float(maxi(1, total_layers - 1)), 0.0, 1.0)
	var pairs: int = 0
	if progress < 0.4:
		pairs = rng.randi_range(0, 1)
	elif progress < 0.75:
		pairs = 1
	else:
		pairs = rng.randi_range(1, 2)
	var near_row: int = DeploymentState.PLAYER_ROWS
	var far_row: int = board_size - 1 - DeploymentState.PLAYER_ROWS
	if far_row < near_row:
		return rocks
	var tries: int = 0
	while rocks.size() < pairs * 2 and tries < 40:
		tries += 1
		var square: Vector2i = Vector2i(rng.randi_range(0, board_size - 1), rng.randi_range(near_row, far_row))
		var mirror: Vector2i = Vector2i(board_size - 1 - square.x, board_size - 1 - square.y)
		if square == mirror or square in rocks or mirror in rocks:
			continue
		rocks.append(square)
		rocks.append(mirror)
	return rocks
