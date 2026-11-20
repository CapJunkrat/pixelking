extends SceneTreeTestCase

## Base facts must be complete in both languages, never fabricated live state.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path: String = "res://scripts/ui/PiecePresentation.gd"
	expect(ResourceLoader.exists(path), "one structured presentation source exists")
	if not ResourceLoader.exists(path):
		finish_test("Piece presentation test")
		return
	var presentation: GDScript = load(path) as GDScript
	var loc: Node = root.get_node("Localization")
	for locale: String in ["en", "zh_CN"]:
		loc.set_locale(locale, false)
		for id: String in PieceDefDatabase.all_ids():
			var facts: Dictionary = presentation.describe(PieceDefDatabase.get_def(id))
			expect(not str(facts.get("summary", "")).is_empty() and not "INFO_" in str(facts.summary), "%s %s: localized compact essentials" % [locale, id])
			expect(not str(facts.get("movement", "")).is_empty() and not str(facts.get("capture", "")).is_empty(), "%s %s: movement and capture are separate" % [locale, id])
			expect(facts.has("traits") and facts.has("exceptions") and not facts.has("status"), "%s %s: traits and exceptions, no runtime claims" % [locale, id])
			for entry: Dictionary in facts.traits:
				expect(not str(entry.label).is_empty() and not str(entry.rule).is_empty() and not str(entry.label).begins_with("INFO_"), "%s %s: meaningful trait label + full rule" % [locale, id])
		var stone: Dictionary = presentation.describe(PieceDefDatabase.get_def("stone_giant"))
		var separated_terms: Dictionary = {"en": {"stone_giant": "shell", "flame_phoenix": "egg", "ember_bird": "egg", "war_king": "every turn", "shield_king": "checkmate"}, "zh_CN": {"stone_giant": "外壳", "flame_phoenix": "蛋", "ember_bird": "蛋", "war_king": "每回合", "shield_king": "将死"}}
		for piece_id: String in separated_terms[locale]:
			var movement: String = presentation.describe(PieceDefDatabase.get_def(piece_id)).movement
			expect(not str(separated_terms[locale][piece_id]) in movement.to_lower(), "%s %s: movement does not repeat separately listed passive rules" % [locale, piece_id])
		expect(stone.shell_layers == 2, "Stone Giant definition exposes exactly two shell layers")
		var expected: Dictionary = {
			"en": {"stone_giant": ["2", "rock", "direct removal"], "archmage": ["stays", "adjacent"], "flame_phoenix": ["2", "owner", "hard", "no free"], "ember_bird": ["2", "fragile", "once"], "shield_king": ["1–2", "first checkmate", "all checking enemy non-King pieces", "shells and shields"], "shadow_king": ["1–3", "returns", "final", "permanent"], "war_king": ["1–2", "every turn", "same", "two"]},
			"zh_CN": {"stone_giant": ["2", "岩石", "直接清除"], "archmage": ["原位", "相邻"], "flame_phoenix": ["2", "己方", "硬", "没有空格"], "ember_bird": ["2", "易碎", "一次"], "shield_king": ["1–2", "首次被将死", "所有正在将军的敌方非国王棋子", "外壳与护盾"], "shadow_king": ["1–3", "返回", "最终", "常驻"], "war_king": ["1–2", "每回合", "同一", "两次"]},
		}
		for id: String in expected[locale]:
			var text: String = str(presentation.describe(PieceDefDatabase.get_def(id)))
			for term: String in expected[locale][id]:
				expect(term.to_lower() in text.to_lower(), "%s %s retains %s" % [locale, id, term])
	expect(PieceRulePreview.DEFAULT_GRID_SIZE == 7, "default preview contains all three-square rays")
	var queen_grid: GridContainer = PieceRulePreview.make_grid("queen", 7, 19, true)
	root.add_child(queen_grid)
	expect(not queen_grid.find_children("Continuation", "Label", true, false).is_empty(), "long rays have visible continuation arrows, not a finite seven-square claim")
	var shadow_grid: GridContainer = PieceRulePreview.make_grid("shadow_king", 7, 19, true)
	root.add_child(shadow_grid)
	expect(shadow_grid.find_children("Continuation", "Label", true, false).is_empty(), "finite three-square Shadow rays do not imply continuation")
	queen_grid.queue_free()
	shadow_grid.queue_free()
	finish_test("Piece presentation test")
