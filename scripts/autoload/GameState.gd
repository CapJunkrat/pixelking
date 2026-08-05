extends Node

## 鍏ㄥ眬娓告垙鐘舵€佸崟渚嬨€?## P1闃舵:鍙寔鏈夊綋鍓嶈繖涓€灞€妫嬬殑 BoardState,渚涗换浣曡剼鏈闂€?## P4闃舵(Roguelike妗嗘灦)浼氬湪杩欓噷鎵╁睍:gold銆乺elics銆乺ecruited_pieces銆亀ave_index 绛夈€?
var board: BoardState = null

## Persistent and consumable objects share the same challenger inventory.
var challenger_items: Array[ChallengerItemDef] = []

## 鐜╁鍦≧oguelike閲屾搷鎺х殑涓€鏂?P4闃舵寮曞叆鏁屾垜姒傚康鍚庝細鐢ㄥ埌)
var player_color: int = GameRules.PieceColor.WHITE

func _ready() -> void:
	start_new_game()

func start_new_game() -> void:
	board = BoardState.new()
	board.remove_all_pawns()
	challenger_items.clear()

## 灏濊瘯璧颁竴姝ユ銆傝繑鍥?true 琛ㄧず璧板瓙鎴愬姛銆?## 杩欐槸缁橴I灞?AI灞傝皟鐢ㄧ殑缁熶竴鍏ュ彛,鍐呴儴璐熻矗鏍￠獙鍚堟硶鎬с€佹墽琛屻€佸箍鎾簨浠躲€?
func try_move(from: Vector2i, to: Vector2i, promotion_id: String = "queen") -> bool:
	if board == null:
		return false
	var result := board.make_move(from, to, promotion_id)
	if not result.get("success", false):
		return false

	EventBus.move_made.emit(from, to, result)
	EventBus.turn_changed.emit(board.turn)

	if result.get("checkmate", false):
		EventBus.checkmate.emit(board.turn)
	elif result.get("stalemate", false):
		EventBus.stalemate.emit(board.turn)
	elif result.get("check", false):
		EventBus.check_declared.emit(board.turn)

	return true
