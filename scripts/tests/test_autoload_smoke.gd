extends SceneTree

## 楠岃瘉 autoload (GameState/EventBus) 鍦ㄧ湡瀹為」鐩繍琛岀幆澧冧笅鍙敤銆?## 杩愯: godot --headless --path game --script res://scripts/tests/test_autoload_smoke.gd

func _init() -> void:
	print("===== Autoload 鍐掔儫娴嬭瘯 =====")

	# 绛変竴甯?纭繚 autoload 鐨?_ready() 宸茬粡璺戣繃
	await process_frame

	var game_state := root.get_node("GameState")
	var event_bus := root.get_node("EventBus")

	var ok := true
	if game_state == null:
		print("[FAIL] GameState autoload 鏈壘鍒?)
		ok = false
	elif game_state.board == null:
		print("[FAIL] GameState.board 鏈垵濮嬪寲")
		ok = false
	else:
		print("[PASS] GameState autoload 姝ｅ父,鍒濆妫嬬洏宸茬敓鎴?)

	if event_bus == null:
		print("[FAIL] EventBus autoload 鏈壘鍒?)
		ok = false
	else:
		print("[PASS] EventBus autoload 姝ｅ父")

	# 閫氳繃 GameState.try_move 璧颁竴姝ョ湡瀹炵殑妫?椤哄甫楠岃瘉淇″彿骞挎挱涓嶄細鎶ラ敊
	var got_signal := [false]  # GDScript鐨刲ambda鎸夊€兼崟鑾峰眬閮ㄥ彉閲?杩欓噷鐢ㄦ暟缁勫綋鍙彉瀹瑰櫒
	event_bus.move_made.connect(func(_f, _t, _r): got_signal[0] = true)

	var success: bool = game_state.try_move(Vector2i(1, 0), Vector2i(0, 2))  # Knight move in the pawn-free battle setup
	if success and got_signal[0]:
		print("[PASS] 閫氳繃 GameState.try_move 璧板瓙鎴愬姛,骞舵纭箍鎾?move_made 淇″彿")
	else:
		print("[FAIL] try_move 鎴栦俊鍙峰箍鎾紓甯?(success=%s, got_signal=%s)" % [success, got_signal[0]])
		ok = false

	var illegal: bool = game_state.try_move(Vector2i(0, 0), Vector2i(0, 5))
	if not illegal:
		print("[PASS] 闈炴硶璧板瓙琚纭嫆缁?)
	else:
		print("[FAIL] 闈炴硶璧板瓙绔熺劧琚帴鍙椾簡")
		ok = false

	print("===== 缁撴灉: %s =====" % ("鍏ㄩ儴閫氳繃" if ok else "瀛樺湪澶辫触"))
	quit(0 if ok else 1)
