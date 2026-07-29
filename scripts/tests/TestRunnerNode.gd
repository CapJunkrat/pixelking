extends Node

## 挂在 scenes/Main.tscn 上。在编辑器里直接点 Play(F5)就会跑一遍
## 核心象棋规则测试,并把结果显示在屏幕上 + 打印到"输出"面板。
## 这是P1阶段的临时验证入口;P2开始加真正的棋盘UI之后,
## 这个场景会被替换成真正的游戏主场景。

@onready var label: Label = $Label

func _ready() -> void:
	var suite := ChessRulesTestSuite.new()
	var result := suite.run_all()

	for line in result["log_lines"]:
		print(line)

	var summary := "P1 核心象棋规则测试\n\n通过: %d\n失败: %d\n\n(详细日志请看编辑器底部的\"输出\"面板)" % [
		result["pass_count"], result["fail_count"]
	]
	if label != null:
		label.text = summary
		label.add_theme_color_override("font_color", Color.RED if result["fail_count"] > 0 else Color.LIME_GREEN)
