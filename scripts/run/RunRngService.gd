class_name RunRngService
extends RefCounted

const STREAM_NAMES: Array[StringName] = [
	&"map_rng",
	&"encounter_rng",
	&"reward_rng",
	&"shop_rng",
	&"event_rng",
	&"battle_rng",
	&"sacrifice_rng",
]

const STREAM_SALTS: Dictionary = {
	&"map_rng": 7640891576956012809,
	&"encounter_rng": 4354685564936845355,
	&"reward_rng": 1609587929392839161,
	&"shop_rng": 2685821657736338717,
	&"event_rng": 3935559000370003845,
	&"battle_rng": 7046029254386353131,
	&"sacrifice_rng": 1028521323065827507,
}

var run_seed: int = 0
var _streams: Dictionary = {}

func initialize(seed_value: int) -> void:
	run_seed = seed_value
	_streams.clear()
	for stream_name: StringName in STREAM_NAMES:
		var generator: RandomNumberGenerator = RandomNumberGenerator.new()
		generator.seed = _derive_seed(seed_value, int(STREAM_SALTS[stream_name]))
		_streams[stream_name] = generator

func has_stream(stream_name: StringName) -> bool:
	return _streams.has(stream_name)

func randi(stream_name: StringName) -> int:
	var generator: RandomNumberGenerator = _generator(stream_name)
	return int(generator.randi()) if generator != null else 0

func randi_range(stream_name: StringName, from: int, to: int) -> int:
	var generator: RandomNumberGenerator = _generator(stream_name)
	return generator.randi_range(from, to) if generator != null else from

func randf(stream_name: StringName) -> float:
	var generator: RandomNumberGenerator = _generator(stream_name)
	return generator.randf() if generator != null else 0.0

func pick_index(stream_name: StringName, size: int) -> int:
	if size <= 0:
		return -1
	return self.randi_range(stream_name, 0, size - 1)

func snapshot_states() -> Dictionary:
	var result: Dictionary = {}
	for stream_name: StringName in STREAM_NAMES:
		var generator: RandomNumberGenerator = _generator(stream_name)
		if generator == null:
			return {}
		result[String(stream_name)] = generator.state
	return result

func restore_states(states: Dictionary) -> bool:
	if _streams.is_empty():
		initialize(run_seed)
	for stream_name: StringName in STREAM_NAMES:
		var key: String = String(stream_name)
		if not states.has(key):
			return false
		var generator: RandomNumberGenerator = _generator(stream_name)
		if generator == null:
			return false
		generator.state = int(states[key])
	return true

func _generator(stream_name: StringName) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		push_error("Unknown Run RNG stream: %s" % stream_name)
		return null
	return _streams[stream_name] as RandomNumberGenerator

func _derive_seed(seed_value: int, salt: int) -> int:
	var mixed: int = seed_value ^ salt
	mixed ^= mixed >> 30
	mixed *= 6364136223846793005
	mixed ^= mixed >> 27
	return mixed
