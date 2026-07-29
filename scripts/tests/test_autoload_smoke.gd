extends SceneTree

## 验证 autoload (GameState/EventBus) 在真实项目运行环境下可用。
## 运行: godot --headless --path game --script res://scripts/tests/test_autoload_smoke.gd

func _init() -> void:
	print("===== Autoload 冒烟测试 =====")

	# 等一帧,确保 autoload 的 _ready() 已经跑过
	await process_frame

	var game_state := root.get_node("GameState")
	var event_bus := root.get_node("EventBus")

	var ok := true
	if game_state == null:
		print("[FAIL] GameState autoload 未找到")
		ok = false
	elif game_state.board == null:
		print("[FAIL] GameState.board 未初始化")
		ok = false
	else:
		print("[PASS] GameState autoload 正常,初始棋盘已生成")

	if event_bus == null:
		print("[FAIL] EventBus autoload 未找到")
		ok = false
	else:
		print("[PASS] EventBus autoload 正常")

	# 通过 GameState.try_move 走一步真实的棋,顺带验证信号广播不会报错
	var got_signal := [false]  # GDScript的lambda按值捕获局部变量,这里用数组当可变容器
	event_bus.move_made.connect(func(_f, _t, _r): got_signal[0] = true)

	var success: bool = game_state.try_move(Vector2i(4, 1), Vector2i(4, 2))  # e2-e3 on the default 5x5 board
	if success and got_signal[0]:
		print("[PASS] 通过 GameState.try_move 走子成功,并正确广播 move_made 信号")
	else:
		print("[FAIL] try_move 或信号广播异常 (success=%s, got_signal=%s)" % [success, got_signal[0]])
		ok = false

	var illegal: bool = game_state.try_move(Vector2i(0, 0), Vector2i(0, 5))
	if not illegal:
		print("[PASS] 非法走子被正确拒绝")
	else:
		print("[FAIL] 非法走子竟然被接受了")
		ok = false

	print("===== 结果: %s =====" % ("全部通过" if ok else "存在失败"))
	quit(0 if ok else 1)
