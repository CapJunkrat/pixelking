# PixelKing 内容资源架构

## 权威入口

正式游戏内容由 `res://resources/content/default_catalog.tres` 显式引用。
运行时通过 `DefaultContent -> ContentRegistry` 建立只读 ID 索引；禁止扫描目录发现内置内容。

## 目录职责

- `res://assets/`：纹理、字体、音频、Shader 等表现资产。
- `res://resources/content/`：棋子、动作档案、配方、挑战者物品、奖励表、商店池、事件、休息点、地图与 Encounter 定义。
- `res://scripts/content/`：Catalog schema、Registry、验证及内容配置类型。
- `res://scripts/content/Content.gd`：唯一的内容查询入口（按稳定 ID 查棋子、配方、物品、事件、地图节点、Encounter 与 Run 表），只转发到 Registry，不得重新构造具体内容；`ContentText.gd` 负责内容的本地化名称。
- `res://scripts/run/content/`：按奖励、候选生成、融合、阵容和战斗结果拆分的 Run 内容领域服务。
- `res://scripts/run/RunContentService.gd`：仅保留兼容门面和薄分发，不得重新吸收具体规则或展示构造。
- `res://scripts/run/`：流程、资格、随机抽取、事务与效果执行，不得拥有具体内容池。
- `res://scripts/navigation/AppSceneRoutes.gd`：生产场景路径的唯一代码入口。

## 稳定身份规则

- 存档只保存稳定字符串 ID，不保存 Resource、显示名称、数组下标或资源路径。
- 已发布 ID 不得重命名；若必须替换，应增加显式迁移表。
- Catalog 数组顺序是确定性随机契约的一部分。调整顺序会改变相同 Seed 的结果。

## 新增内容 Definition of Done

新增复用现有机制的内容时必须：

1. 创建对应 `.tres`；
2. 使用唯一、非空的稳定 ID；
3. 加入 `default_catalog.tres` 的显式引用数组；
4. 使用已有本地化 Key 和显式资产引用；
5. 不在 Content、RunContentService 或 UI 中增加该内容的具体 ID；
6. 通过 `unit/content/test_content_catalog.gd` 的交叉引用验证；
7. 通过相关规则、确定性、完整 Run 与 Android 导出验证。

新增机制允许增加规则或效果脚本，但具体参数和内容组合仍应保存在 Resource 中。

## 禁止项

- 禁止 `DirAccess` 扫描正式内容目录；Android 导出会使用 remap，目录结果不能作为注册表。
- 禁止在服务中维护棋子、遗物、配方、事件、地图节点或敌方编成等具体 ID 数组。
- 禁止在生产脚本中散布 `res://scenes/` 路径；必须通过 `AppSceneRoutes`。
- 禁止从 Dictionary 遍历顺序建立随机候选池；必须使用 Catalog 中的有序数组。
- 禁止在生成候选后保存 Resource 对象；`pending_choice` 继续只保存可序列化 ID 与值。
- 禁止为了新增普通内容修改核心战斗或 Run 服务。

## 行为与配置边界

- Resource 定义“有什么”和可调参数。
- Registry 负责索引和交叉引用校验。
- Generator/Service 负责资格、RNG 消费和事务。
- RunState/BattleState 只保存运行状态与稳定 ID。
- UI 只消费生成结果，不决定权威规则。

## 战斗流程与 UI 边界

- `BattleTurnCoordinator` 只负责玩家/敌方回合、AI 调度、表现屏障和输入锁；不得访问 RunManager 或结果面板。
- `BattleRunResultCoordinator` 负责 Battle → Run 结算并返回结构化 `BattleRunResult`；不得直接操作 Control 或切换场景。
- `BattleResultPresenter` 只负责结果文案、按钮和 Overlay；不得执行战斗命令或提交 Run。
- `BattleFlowController` 仅连接事件和上述协作者，并保留兼容导航入口；禁止重新吸收终局规则、AI 实现或 Run pending 分支。
- 每批 BattleEvent 必须等待 `BattleAnimationPlayer.sequence_completed` 及 `BattleBoardView.presentations_completed` 后才可推进回合。
- 表现期间棋盘和挑战者道具输入必须锁定，Debug 快捷胜利也必须走相同的终局与结果展示通道。

## 战斗终局权威

- `BattleOutcomeEvaluator` 是 King capture、checkmate、stalemate、lone king 与 Encounter turn limit 的唯一规则入口。
- `BattleCommandProcessor.status` 是战斗是否结束、胜者、和棋与原因的唯一权威状态；UI 不得重复推导终局。
- `BattleFlowController` 只消费 `battle_ended` 事件并展示结果，结束后的命令必须由 Processor 返回 `battle_already_finished`。
- Debug 快捷胜利必须通过 `GameState.force_debug_victory() -> BattleCommandProcessor.force_finish()` 进入同一终局事件通道；禁止直接伪造结果面板或绕过 Run 结算。
- Debug 快捷胜利继续受 `OS.is_debug_build()` 和 session-only debug mode 双重限制。

## 战斗消耗品事务

- `BattleCommandProcessor.stage_item_use()` 必须在独立 Battle runtime 克隆上完成验证与效果结算，预演不得修改权威棋盘或库存。
- `BattleItemUsePlan` 保存预演后的棋盘、库存、Processor、精确槽位和稳定道具 ID。
- 活动 Run 中必须先由 `RunManager.consume_challenger_item()` 持久化消费；保存失败时不得发布预演状态或成功事件。
- 保存成功后，Battle runtime 必须在 `active_run_changed` 等 Run 信号前发布，确保观察者不会看到 Battle/Run 双写中间态。
- RunState 必须拒绝未注册的挑战者道具 ID，禁止通过跳过未知定义改变运行时槽位下标。

## 融合事务

- `Content.recipe()` 只负责配方查询；资格、容量和执行统一归 `FusionService`。
- `FusionPlan` 必须保存精确素材实例 ID、产物、来源候选、价格和原始 pending choice。
- 玩家选择图纸后先保存 `fusion_confirmation`，确认前不得消耗素材或扣除金币。
- 取消必须原样恢复原奖励或商店候选，禁止重新抽取 RNG。
- 普通融合产物进入 reserve，计划阶段必须完成容量预检。
- 王融合必须消耗且只消耗一个 King，结果也必须是 King，并保留原 King 实例 ID 和 active/deployment 身份。
- 奖励和商店必须共享同一计划、确认和执行服务，禁止新增第二套融合逻辑。

## 测试架构

测试位于 `res://scripts/tests/`，由 `runner/TestManifest.gd` 显式登记，禁止依赖文件扫描决定正式回归范围。

- `unit/`：单一领域对象、纯规则、确定性、验证与无副作用失败；不得实例化完整游戏场景。
- `integration/`：跨服务事务、Run/Battle 边界、持久化恢复与 Autoload 协作。
- `scenes/`：静态节点契约、信号连接、输入锁和一个主要交互；不得重复验证底层规则排列组合。
- `smoke/`：Autoload、Catalog 引用、字体、图标、皮肤和本地化资源可加载性。
- `e2e/`：完整玩家旅程，只保留少量黄金路径和关键失败路径。
- `runner/`：统一入口、显式清单和 Node 方法适配器，不承载业务断言。

每个行为应由最低可验证层负责一次：规则正确性在 unit，跨边界原子性在 integration，控件连线在 scenes，完整旅程在 e2e。上层只断言边界结果，不重复下层全部细节。

新增行为至少包含：成功路径、非法输入无副作用、确定性或幂等性、序列化恢复（若持久化）、事件只发一次（若发布事件）。时间相关测试必须等待正式 Signal 屏障，禁止依赖任意帧数。

测试公共准备统一放在 `support/`：`RunTestFixture` 负责 Draft/地图/战斗准备，`BattleTestFixture` 负责权威棋盘，`TestSaveSandbox` 负责 `.save/.tmp/.bak` 隔离清理，`SceneTreeTestCase` 负责一致的断言和退出码。禁止在新测试中复制整段 Run 准备或存档清理流程。

已建立专项覆盖：`BattleTurnCoordinator` 设置暂停/恢复、连续事件批次与 Timer 失效；Battle → Run 结算保存失败及重复提交；场景路由注册一致性；Catalog ID、旧/当前/未来内容版本；典型 Android 比例的安全区换算及主要场景挂载。真实设备的厂商 Cutout 返回值仍属于 APK 设备验收，不由 headless 测试伪造。

## 特殊棋子规则

首批 Ouroboros 风格内容使用稳定 ID：`assassin`、`royal_guard`、`catapult`、`bowman`、`portal_mage`、`unicorn_cavalry`、`centaur`、`manticore`、`gryphon`、`gorgon`，Catalog 内容版本为 3。

- 移动差异通过可复用 `MovementRule` 表达：Slide 支持最小距离、移动/吃子开关与穿越；Teleport 分离空格传送和相邻吃子；BentRay 表达强制空中间格的两段路径。
- 战斗能力只通过 `PieceDef` trait 表达，规则层禁止判断具体 ID。当前 trait 包括击杀额外行动、相邻冻结和冻结免疫。
- Assassin 额外行动可连续触发，但 King capture、checkmate、lone-king 和 turn limit 等终局优先；额外行动不推进 `turn_serial`，因此不能重置每方回合一次的道具使用窗口。
- Gorgon 冻结敌我相邻棋子且自身免疫；不能吃子，也不产生攻击格或将军。
- 每个新棋子必须同时拥有两个内置皮肤的白/黑方独立纹理，并通过 `test_piece_skin.gd` 验证。
