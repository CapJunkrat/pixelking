extends SceneTree

var failed: bool = false

func _init() -> void:
	var rng_script: Script = load("res://scripts/run/RunRngService.gd") as Script
	var first: RefCounted = rng_script.new() as RefCounted
	var second: RefCounted = rng_script.new() as RefCounted
	first.call("initialize", 123456789012345)
	second.call("initialize", 123456789012345)

	for stream_name: StringName in [&"map_rng", &"encounter_rng", &"reward_rng", &"shop_rng", &"event_rng", &"battle_rng", &"sacrifice_rng"]:
		_expect(int(first.call("randi", stream_name)) == int(second.call("randi", stream_name)), "same seed reproduces %s" % stream_name)

	var control: RefCounted = rng_script.new() as RefCounted
	var disturbed: RefCounted = rng_script.new() as RefCounted
	control.call("initialize", 777)
	disturbed.call("initialize", 777)
	disturbed.call("randi", &"map_rng")
	disturbed.call("randi", &"map_rng")
	_expect(int(control.call("randi", &"reward_rng")) == int(disturbed.call("randi", &"reward_rng")), "consuming map RNG does not alter reward RNG")

	var snapshot_source: RefCounted = rng_script.new() as RefCounted
	snapshot_source.call("initialize", 987654321)
	snapshot_source.call("randi", &"shop_rng")
	var snapshot: Dictionary = snapshot_source.call("snapshot_states") as Dictionary
	var expected_next: int = int(snapshot_source.call("randi", &"shop_rng"))
	var restored: RefCounted = rng_script.new() as RefCounted
	restored.call("initialize", 987654321)
	_expect(restored.call("restore_states", snapshot), "RNG stream states restore successfully")
	_expect(int(restored.call("randi", &"shop_rng")) == expected_next, "restored stream resumes at exact next value")
	_expect(not bool(restored.call("has_stream", &"typo_rng")), "unknown RNG stream is rejected")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _finish() -> void:
	print("[PASS] Run RNG test" if not failed else "[FAIL] Run RNG test")
	quit(1 if failed else 0)
