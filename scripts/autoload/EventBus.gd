extends Node

## 全局信号总线。核心棋盘逻辑(BoardState等)是纯数据类,不依赖场景树,
## 所以它们不能直接发信号——由驱动它们的上层代码(比如未来的GameController)
## 转发到这里,UI/音效/动画等表现层只需要监听这里,不用关心逻辑层细节。

signal move_made(from: Vector2i, to: Vector2i, result: Dictionary)
signal turn_changed(new_turn: int)
signal check_declared(color: int)
signal checkmate(color: int)
signal stalemate(color: int)

## Roguelike 相关信号(P4阶段会用到,先占位)
signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)
signal relic_gained(relic_id: String)
signal gold_changed(new_amount: int)
