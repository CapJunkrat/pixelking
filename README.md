# PixelKing (像素国王) —— 像素风国际象棋Roguelike

> **历史文档 / 已过时：** 本项目采用快速 Vibe Coding 节奏，当前实现迭代速度高于文档维护速度。下文仅保留为早期阶段参考，实际功能、场景与测试状态请以当前工程为准。
>
> 当前产品结论、Roguelike 规则、PK-02/PK-03 架构方向及后续行动计划请阅读：[`docs/PIXELKING_PRODUCT_AND_ARCHITECTURE_PLAN.md`](docs/PIXELKING_PRODUCT_AND_ARCHITECTURE_PLAN.md)。

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
- 自动化测试按 `unit / integration / scenes / smoke / characterization / e2e` 分层，并由显式 Manifest 管理。
- 统一入口：`scripts/tests/runner/run_all_tests.gd`，支持按 layer 或 domain 过滤。

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
# 全量测试
godot --headless --path . --script res://scripts/tests/runner/run_all_tests.gd

# 只跑单元测试
godot --headless --path . --script res://scripts/tests/runner/run_all_tests.gd -- --layer=unit

# 只跑 battle 领域
godot --headless --path . --script res://scripts/tests/runner/run_all_tests.gd -- --domain=battle
```

Runner 会逐文件隔离执行，最后输出通过/失败文件数并返回可靠退出码。

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
	├── runner/                   # Manifest、全量入口、Node 方法入口
	├── unit/                     # 单对象、纯规则和确定性测试
	├── integration/              # 跨服务、存档和事务边界测试
	├── scenes/                   # 场景结构、信号连接和输入测试
	├── smoke/                    # Autoload、素材、字体和本地化契约
	├── characterization/         # 待移除旧接口的兼容行为锁定
	└── e2e/                      # 玩家关键旅程
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
