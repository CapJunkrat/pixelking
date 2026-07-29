extends Resource
class_name PieceDef

## 数据驱动的棋子定义。
## 标准棋子(车/马/象/后/王/兵)用下面这些字段就能描述出移动规则。
## 未来新增的"千奇百怪"的特殊棋子,只需要:
##   1) 新建一个 PieceDef (可以是.tres资源,也可以在代码里 new 出来)
##   2) 如果标准的"滑动方向 + 跳跃偏移"规则不够用(比如需要特殊技能触发逻辑),
##      再给 special_move_script 指一个自定义脚本,由 MoveGenerator 调用。
## 这样核心的 BoardState / MoveGenerator 代码基本不用改。

## 唯一id,例如 "pawn" "knight" "custom_reaper"
@export var id: String = ""

## 显示名称,例如 "兵" "收割者"
@export var display_name: String = ""

## 滑动方向列表(可以走任意格数,直到被挡住),例如车: [(1,0),(-1,0),(0,1),(0,-1)]
@export var slide_directions: Array[Vector2i] = []

## 滑动最大距离,标准棋子多为8(棋盘最大),国王/某些特殊棋子可设为1
@export var max_slide_distance: int = 8

## 跳跃偏移列表(不会被挡住,直接落到目标格),例如马: 8个(±1,±2)/(±2,±1)组合
@export var jump_offsets: Array[Vector2i] = []

## 是否是兵(有特殊的前进/吃子分离、双步、吃过路兵、升变规则)
@export var is_pawn: bool = false

## 是否是王(需要将军判定、易位规则)
@export var is_king: bool = false

## 特殊移动/技能脚本路径(P1阶段暂不使用,预留给后续"特殊棋子"扩展)
@export var special_move_script: String = ""

## 基础价值分(用于AI评估局面,王给一个很大的数)
@export var base_value: int = 0
