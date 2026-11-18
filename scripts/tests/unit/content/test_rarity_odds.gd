extends SceneTree

## Offered pieces roll a rarity first: rare, epic and legendary pieces turn up often,
## and more often deeper in the map.

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var table: BattleRewardTableDef = RunContentDatabase.battle_reward_table()
	for progress: float in [0.0, 1.0]:
		var rng: RunRngService = RunRngService.new()
		rng.initialize(77)
		var counts: Array[int] = [0, 0, 0, 0]
		var draws: int = 4000
		for _i: int in range(draws):
			counts[RarityOdds.rarity_of(RarityOdds.pick(table.recruit_piece_ids, rng, &"reward_rng", progress))] += 1
		var odds: Array[int] = RarityOdds.weights(progress)
		for tier: int in range(4):
			var share: float = 100.0 * counts[tier] / draws
			_expect(absf(share - odds[tier]) < 3.0, "progress %.0f: rarity %d is offered %.1f%% of the time (aim %d%%)" % [progress, tier, share, odds[tier]])
		print("  progress %.1f -> common/rare/epic/legendary %s" % [progress, counts])
	var early: Array[int] = RarityOdds.weights(0.0)
	var late: Array[int] = RarityOdds.weights(1.0)
	_expect(early[0] <= 30 and early[1] + early[2] + early[3] >= 70, "even the first battles offer mostly rare-or-better pieces")
	_expect(late[2] + late[3] > early[2] + early[3], "epic and legendary grow more likely deeper in the map")
	var only_common: RunRngService = RunRngService.new()
	only_common.initialize(3)
	_expect(PieceDefDatabase.get_def(RarityOdds.pick(["pawn"], only_common, &"reward_rng", 0.0)) != null, "a short list still yields a piece")
	print("[PASS] Rarity odds test" if not failed else "[FAIL] Rarity odds test")
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)
