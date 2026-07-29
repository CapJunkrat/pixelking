# PixelKing (像素国王) —— 像素风国际象棋Roguelike

仿《衔尾蛇国王 The Ouroboros King》玩法:在小棋盘上以国王为核心,不断招募/升级各种棋子(含大量自定义特殊棋子),迎战一波波AI控制的敌方棋子,搭配遗物、商店构成完整roguelike循环。

## 当前进度:P0(项目骨架)+ P1(核心象棋规则引擎)已完成

**这一版还没有任何图形界面**,是纯逻辑层,专门先把"规则对不对"这件事做扎实,
因为后面的UI、AI、Roguelike系统全都要依赖这层的正确性。

### 已实现

- 标准8x8棋盘,标准开局
- 六种标准棋子的完整走法:兵(含双步/吃过路兵/升变)、马、象、车、后、王
- 王车易位(王翼/后翼),含"易位路径被攻击则禁止"的完整判断
- 将军 / 被牵制棋子无法走出会导致己方被将军的棋(pin检测)
- 将死 / 逼和(stalemate)判定
- 数据驱动的棋子定义系统(`PieceDef`):新增棋子只需要描述"滑动方向+跳跃偏移",
  不需要碰核心逻辑代码——这是专门为后面"千奇百怪的特殊棋子"打的地基
- 全局信号总线(`EventBus`)+ 全局状态单例(`GameState`),为后续UI/AI层预留了干净的接入点
- **两套自动化测试**,已经用真实 Godot 4.3 headless 引擎跑通,不是凭空写的代码:
  - `scripts/tests/test_runner.gd`:29个纯逻辑断言(愚人将杀、易位、吃过路兵、升变、牵制等)
  - `scripts/tests/test_autoload_smoke.gd`:验证 autoload 单例在真实运行环境下可用

## 如何打开 / 验证功能

1. 安装 [Godot 4.3+](https://godotengine.org/download)(你本地是4.7也完全没问题,向下兼容)
2. 用 Godot 打开这个文件夹(选择 `project.godot`)
3. **直接按 F5(或点右上角的 ▶ 播放按钮)** —— 已经设置好了主场景 `scenes/Main.tscn`,
   不会再弹出"选择主场景"的窗口了。运行后屏幕上会显示测试的通过/失败汇总,
   详细的每一条断言日志在编辑器底部的"输出"(Output)面板里能看到。

> 如果你之前点开项目时弹出过"尚未定义主场景"的窗口:那是因为当时项目里还没有
> 任何场景。现在已经加了 `scenes/Main.tscn` 并设置成了主场景,重新打开项目或者
> 直接按 F5 就不会再出现了。

## 如何跑测试(命令行,可选)

如果你更喜欢命令行,或者想在CI里跑:

```bash
# 纯逻辑规则测试(29个断言)
godot --headless --path . --script res://scripts/tests/test_runner.gd

# autoload/信号系统冒烟测试
godot --headless --path . --script res://scripts/tests/test_autoload_smoke.gd
```

看到 `结果: 29 通过 / 0 失败` 说明规则引擎是对的。

## 目录结构

```
project.godot
scenes/
└── Main.tscn               # 当前的主场景(P1阶段临时用来跑测试;P2会替换成真正的棋盘UI)
scripts/
├── core/
│   ├── GameRules.gd        # 颜色枚举(PieceColor)等全局规则常量
│   ├── ChessPiece.gd       # 棋子实例(类型+颜色+状态)
│   ├── MoveGenerator.gd    # 走法生成(数据驱动:滑动方向+跳跃偏移)
│   └── BoardState.gd       # 棋盘状态、合法走法过滤、将军/将死判定、执行走子
├── data/
│   ├── PieceDef.gd         # 棋子类型的数据定义(Resource)
│   └── PieceDefDatabase.gd # 标准6种棋子的定义;后续会扩展成加载特殊棋子
├── autoload/
│   ├── EventBus.gd         # 全局信号总线
│   └── GameState.gd        # 当前对局状态单例,UI/AI通过它调用 try_move()
└── tests/
	├── ChessRulesTestSuite.gd    # 测试断言的实际逻辑(被下面两个入口共用)
	├── test_runner.gd            # 命令行入口(headless)
	├── test_autoload_smoke.gd    # autoload/信号 冒烟测试(命令行入口)
	└── TestRunnerNode.gd         # 编辑器内Play按钮入口,挂在 scenes/Main.tscn 上
```

## 后续路线图

| 阶段 | 内容 |
|---|---|
| P2 | 像素棋盘UI:渲染棋盘/棋子、选中高亮、可行移动提示、点击走子、基础动画 |
| P3 | 简单AI(Minimax + Alpha-Beta剪枝,2-3层深度)作为敌方对手 |
| P4 | Roguelike框架:波次系统、招募UI、商店、遗物系统,先打通2-3个特殊棋子+2-3个遗物的完整流程 |
| P5 | 持续扩充特殊棋子/遗物/道具内容(数据驱动,可以不断迭代加量) |
| P6 | 像素美术精修、音效、过渡动画 |

随时可以回来找我继续下一阶段,或者调整任何一步的设计。
