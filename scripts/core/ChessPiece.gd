extends RefCounted
class_name ChessPiece

## 棋盘上的一枚棋子实例。
## 注意:def 是"这是什么棋子"(数据定义,可共享),
## 而 has_moved / instance_id 等是"这一枚具体棋子"的状态。

var def: PieceDef
var color: int  # GameRules.PieceColor.WHITE / BLACK
var has_moved: bool = false

## Run-wide growth carried between battles (see PieceInstanceState).
var capture_count: int = 0
var learned_def_ids: Array[String] = []
## Per-battle state.
var shell_left: int = 0
var revives_left: int = 0
## For an egg: the piece that hatches from it, and the turn serial it hatches on.
var hatch_piece: ChessPiece = null
var hatch_serial: int = 0
## Cannot be captured while BoardState.turn_serial is below this value.
var shield_until_serial: int = 0
## Cannot move while BoardState.turn_serial is below this value (Freeze Charm).
var frozen_until_serial: int = 0
## Square where the piece started this battle (revival point).
var origin: Vector2i = Vector2i(-1, -1)
## Once-per-battle abilities already spent, by ability id.
var used_abilities: Dictionary = {}

## 全局自增实例id,方便未来遗物/升级系统追踪"这一枚具体棋子"
static var _next_instance_id: int = 1
var instance_id: int = 0

func _init(p_def: PieceDef = null, p_color: int = 0, allocate_instance_id: bool = true) -> void:
	def = p_def
	color = p_color
	reset_battle_state()
	if allocate_instance_id:
		instance_id = _next_instance_id
		_next_instance_id += 1

## Creates an independent runtime-state copy for move validation and AI search.
## It preserves the logical piece identity and does not consume a new real instance ID.
static func create_with_instance_id(p_def: PieceDef, p_color: int, persistent_id: int) -> ChessPiece:
	var piece: ChessPiece = ChessPiece.new(p_def, p_color, false)
	piece.instance_id = persistent_id
	_next_instance_id = maxi(_next_instance_id, persistent_id + 1)
	return piece

func reset_battle_state() -> void:
	shell_left = def.shell_hits if def != null else 0
	revives_left = 1 if def != null and def.revive_after_turns > 0 else 0
	shield_until_serial = 0
	used_abilities = {}

func clone_for_simulation() -> ChessPiece:
	var copy: ChessPiece = ChessPiece.new(def, color, false)
	copy.instance_id = instance_id
	copy.has_moved = has_moved
	copy.capture_count = capture_count
	copy.learned_def_ids = learned_def_ids.duplicate()
	copy.shell_left = shell_left
	copy.revives_left = revives_left
	copy.hatch_piece = hatch_piece.clone_for_simulation() if hatch_piece != null else null
	copy.hatch_serial = hatch_serial
	copy.shield_until_serial = shield_until_serial
	copy.frozen_until_serial = frozen_until_serial
	copy.origin = origin
	copy.used_abilities = used_abilities.duplicate()
	return copy

func is_shielded(turn_serial: int) -> bool:
	return turn_serial < shield_until_serial

func has_used(ability: StringName) -> bool:
	return used_abilities.has(ability)

func get_id() -> String:
	return def.id if def != null else "?"
