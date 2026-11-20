# Google Play 上架资料（PixelKing）

本目录是上架 Google Play 用的全部资料。Godot 不会导入这个目录（有 `.gdignore`）。

| 文件 | 用途 |
|---|---|
| `icon-512.png` | 应用图标，512×512 |
| `feature-graphic-1024x500.jpg` | 宣传图，1024×500 |
| `screenshots/en-US/*.png` | 英文手机截图，1080×1920 |
| `screenshots/zh-CN/*.png` | 中文手机截图，1080×1920 |
| `privacy.html` | 隐私政策页面的源文件，线上地址见下 |

- **隐私政策网址：** https://capjunkrat.github.io/pixelking/privacy.html
- **发布包：** `export/PixelKing-release.aab`（不在仓库里，由 "Android Release" 预设导出）
- **包名：** `com.johnz.pixelking`（发布后不能再改）

---

## 1. 商店信息

字数上限：应用名称 30，简短描述 80，完整描述 4000。

### English (en-US)，建议设为默认语言

**App name**（26 字符）
```
PixelKing: Chess Roguelike
```

**Short description**（78 字符）
```
Recruit strange chess pieces, guard your King and march the Crown Road.
```

**Full description**
```
PixelKing is a single-player roguelike played on a chessboard.

You start with a King and a handful of pieces. Walk the Crown Road: fight battles, visit shops, rest sites and strange events, and grow your army along the way. Lose your King and the run is over.

The pieces don't all follow the rules you know. Archers shoot without moving, catapults lob over rocks, birds hatch from eggs, and some pieces fuse into stronger ones. Every run deals you a different map, different recruits and different enemies.

FEATURES
• 48 kinds of pieces: the classic six plus archers, mages, beasts, giants and stranger things, each with its own moves and strike animation
• Four Kings: the classic King plus the War, Shadow and Shield Kings, each with its own reach and ability
• Fusion and growth: 14 fusion recipes; pawns promote, squires level up
• The Crown Road: three acts, nine random bosses, then an endless mode
• Elites, shops, rest sites and 12 events along the way
• Relics and one-shot items that bend the rules
• A tilted 2.5D board that marks threatened and protected squares; tap any piece to see what it does
• Achievements
• English and Simplified Chinese
• Made for one-handed portrait play

No ads. No in-app purchases. No account. Works offline.
```

### 简体中文 (zh-CN)

**应用名称**
```
像素国王 PixelKing：象棋 Roguelike
```

**简短描述**
```
招募奇特棋子，守护你的王，踏上王冠之路。像素风国际象棋 Roguelike。
```

**完整描述**
```
PixelKing（像素国王）是一款在棋盘上进行的单人 Roguelike 游戏。

你从一位国王和几枚棋子出发，踏上王冠之路：打仗、逛商店、在营地休息、遭遇各种奇怪事件，一路壮大你的军队。国王倒下，这一局就结束了。

这里的棋子并不都守规矩：弓箭手原地射击，投石车越过岩石抛射，鸟从蛋里孵出来，有些棋子还能融合成更强的形态。每一局的地图、招募和敌人都不一样。

游戏特色
• 48 种棋子：经典的六种之外，还有弓手、法师、猛兽、巨人和各种奇怪的家伙，每种都有自己的走法和攻击动画
• 四位国王：经典国王，以及战争之王、暗影之王、护盾之王，各有不同的攻击范围和能力
• 融合与成长：14 种融合配方；兵可以升变，侍从可以升级
• 王冠之路：三幕、九个随机首领，通关后进入无尽模式
• 沿途有精英战、商店、营地和 12 种事件
• 改写规则的遗物与一次性道具
• 2.5D 倾斜棋盘，标出受威胁和受保护的格子；点任意棋子就能看到它会做什么
• 成就系统
• 简体中文与英文
• 为单手竖屏游玩设计

无广告，无内购，无需账号，可离线游玩。
```

### 其他设置

| 项目 | 填写 |
|---|---|
| 应用或游戏 | 游戏 |
| 免费或付费 | 免费（之后不能从免费改成付费） |
| 类别 | 策略（Strategy），也可以选桌面游戏（Board） |
| 标签 | Roguelike、国际象棋、策略、像素风、单人、离线 |
| 联系邮箱 | 填你自己的开发者邮箱 |
| 网站 | https://github.com/CapJunkrat/pixelking |

---

## 2. 应用内容（"政策 → 应用内容"里的各项声明）

以下答案依据当前代码整理：已导出的 AAB 不申请任何权限（包括联网），没有广告、统计、账号、内购，也没有第三方 SDK。**请你逐项确认后再提交，这些是以你的名义做出的声明。**

| 声明 | 建议答案 |
|---|---|
| 隐私政策 | https://capjunkrat.github.io/pixelking/privacy.html |
| 应用访问权限 | 所有功能无需特殊访问权限即可使用（不需要登录） |
| 广告 | 否，不含广告 |
| 内容分级 | 见下面第 3 节 |
| 目标受众群体和内容 | 建议选 **13 岁及以上**（13–15、16–17、18+）。勾选 13 岁以下会触发"家庭政策"的额外要求 |
| 新闻应用 | 否 |
| 数据安全 | 见下面第 4 节 |
| 政府应用 | 否 |
| 金融功能 | 不提供任何金融功能 |
| 健康 | 不是健康类应用 |
| 广告 ID | 否，不使用广告 ID |

---

## 3. 内容分级问卷（IARC）

- **类别：** 游戏
- **暴力：** 是，但只有幻想或卡通化的暴力：棋子互相攻击、被吃掉，有攻击动画，结局有"国王被处决"的演出。没有血腥、肢解或写实的人类暴力。如果问卷问到"暴力是否针对写实的人类角色"，答 **否**（都是棋子造型的角色）。
- **恐怖内容：** 否
- **性内容 / 裸露：** 否
- **粗俗语言：** 否
- **管制物品（毒品、酒精、烟草）：** 否
- **赌博 / 模拟赌博：** 否。商店用游戏内金币购买，没有真钱，也没有抽奖开箱。
- **用户互动 / 用户生成内容 / 聊天：** 否
- **分享用户位置：** 否
- **数字商品购买（内购）：** 否
- **随机物品（开箱）可用真钱购买：** 否

预计分级大约是 PEGI 7 或 ESRB Everyone 10+，以问卷最终结果为准。

---

## 4. 数据安全表

| 问题 | 答案 |
|---|---|
| 应用是否收集或分享所需的任何用户数据类型？ | **否** |
| 所有用户数据在传输过程中是否加密？ | 不适用（不传输任何数据） |
| 用户能否请求删除数据？ | 不适用。数据只保存在设备本地，卸载应用即删除 |

选"否"之后，商店页面会显示"不收集数据"和"不与第三方分享数据"。

---

## 5. 第一个版本的版本说明

**English**
```
First release. A pixel-art chess roguelike: 48 pieces, four Kings, three acts and an endless mode.
```

**简体中文**
```
首个版本。像素风国际象棋 Roguelike：48 种棋子、四位国王、三幕冒险与无尽模式。
```

---

## 6. 以后发新版本

1. 在 `export_presets.cfg` 里把 "Android Release" 的 `version/code` 加 1（每次上传都必须比上次大），并改 `version/name`。
2. 导出 AAB。签名信息通过环境变量传入，不写进仓库：
   ```bash
   K="$HOME/Library/Application Support/Godot/keystores"
   GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$K/pixelking-release.keystore" \
   GODOT_ANDROID_KEYSTORE_RELEASE_USER=pixelking \
   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(sed -n 's/^password=//p' "$K/pixelking-release-credentials.txt")" \
   godot --headless --path . --export-release "Android Release" export/PixelKing-release.aab
   ```
3. 在 Play Console 上传。配置好服务账号之后，可以改成用命令行上传。
