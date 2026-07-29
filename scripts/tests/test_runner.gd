extends SceneTree

## 用 `godot --headless --path . --script res://scripts/tests/test_runner.gd` 运行。
## 命令行专用入口,真正的测试逻辑在 ChessRulesTestSuite.gd 里(与编辑器内可运行的
## scenes/Main.tscn 共用同一份测试代码)。

func _init() -> void:
	var suite := ChessRulesTestSuite.new()
	var result := suite.run_all()
	for line in result["log_lines"]:
		print(line)
	quit(1 if result["fail_count"] > 0 else 0)
