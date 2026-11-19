extends SceneTree

## Reads a battle code copied from the game and replays it.
##
##   godot --headless --path . --script res://scripts/tools/decode_battle.gd -- <code | file>
##   options: --boards=all   print the board after every step (default: start, mismatches, end)
##            --text         only print the decoded text
##
## Prints the line-up, every step with its fingerprint check, the first step where this
## build disagrees with the phone, and the board at the moment the code was copied
## compared with the snapshot the phone sent (plus anything its screen showed wrong).

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var source: String = ""
	var all_boards: bool = false
	var text_only: bool = false
	for arg: String in args:
		if arg == "--boards=all":
			all_boards = true
		elif arg == "--text":
			text_only = true
		else:
			source = arg
	if source.is_empty():
		print("usage: decode_battle.gd -- <battle code | file containing it>")
		quit(2)
		return
	if FileAccess.file_exists(source):
		source = FileAccess.get_file_as_string(source)
	var text: String = BattleRecord.decode_text(source)
	print("===== decoded =====")
	print(text)
	if text_only:
		quit(0)
		return
	var record: BattleRecord = BattleRecord.decode(source)
	if record == null:
		print("not a battle code")
		quit(2)
		return
	var built: Dictionary = record.build()
	if built.has("error"):
		print("cannot set up the battle: ", built["error"])
		quit(1)
		return
	print("\n===== start =====")
	print(BattleRecord.board_ascii(built["board"]))
	var report: Dictionary = record.replay()
	print("\n===== replay (%d steps) =====" % (report["steps"] as Array).size())
	var index: int = 0
	for step: Dictionary in report["steps"]:
		index += 1
		var matches: bool = bool(step["ok"]) and (str(step["expected"]).is_empty() or step["expected"] == step["hash"])
		var flag: String = "" if matches else ("   <-- REJECTED" if not bool(step["ok"]) else "   <-- differs (phone #%s, here #%s)" % [step["expected"], step["hash"]])
		print("%3d  %s%s" % [index, step["line"], flag])
		if all_boards or (not matches and index - 1 == int(report["first_mismatch"])):
			print(BattleRecord.board_ascii(step["board"]))
	var processor: BattleCommandProcessor = report.get("processor") as BattleCommandProcessor
	if processor != null:
		print("\n===== end of replay =====")
		print(BattleRecord.board_ascii(processor.board))
		var here: Array[String] = BattleRecord.snapshot_lines(processor.board)
		var phone: Array = record.context.get("snap", [])
		if not phone.is_empty():
			print("\n===== snapshot: phone vs replay =====")
			for line_index: int in range(maxi(phone.size(), here.size())):
				var a: String = str(phone[line_index]) if line_index < phone.size() else ""
				var b: String = here[line_index] if line_index < here.size() else ""
				print(("  same  " if a == b else "  DIFF  ") + a + ("" if a == b else "\n        " + b))
	if record.context.has("view"):
		print("\n===== the phone's screen disagreed with the rules =====")
		print(record.context["view"])
	var mismatch: int = int(report["first_mismatch"])
	print("\nfirst mismatch: %s" % ("none" if mismatch < 0 else "step %d" % (mismatch + 1)))
	quit(0 if mismatch < 0 else 1)
