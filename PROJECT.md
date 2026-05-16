# Retro FPS — 项目全量上下文

> 复古伪3D第一人称射击游戏。基于 SDL2 + C++17，10人 AI Agent 团队协作开发。
> **当前版本: v0.4.0** | 目标: 达到 Build Engine 级别伪3D天花板效果
> 本文档是项目唯一入口 — Cursor / Claude Code / 任何 AI 读取本文档即可完整衔接工作。

---

## 1. 技术栈

| 组件 | 选型 |
|------|------|
| 语言 | C++17（无扩展） |
| 渲染 | SDL2 GPU加速（SDL_Renderer），240×135 内部分辨率 |
| 音频 | SDL2_mixer（44100Hz, .ogg, 32通道） |
| 字体 | SDL2_ttf（UTF-8 中文优先，微软雅黑回退链） |
| 构建 | CMake 3.20+（Visual Studio 2022 / Ninja） |
| 平台 | Windows（架构保持跨平台能力） |
| 编码 | UTF-8（MSVC `/utf-8`） |

---

## 2. 五层架构

```
┌──────────────────────────────────────────────┐
│  🎮 Game Layer — 具体游戏逻辑                  │
│  components/ entities/ systems/               │
│  依赖方向: game → level → engine → math       │
├──────────────────────────────────────────────┤
│  🗺️ Level Layer — 关卡数据 + 碰撞             │
│  Level (map data, isWall, moveWithWallSlide)  │
├──────────────────────────────────────────────┤
│  ⚙️ Framework Layer — 通用游戏框架             │
│  GameLoop SceneManager                        │
├──────────────────────────────────────────────┤
│  🔧 Engine Layer — SDL2封装                   │
│  Engine Renderer Input Audio ResourceCache    │
├──────────────────────────────────────────────┤
│  📐 Math Layer — 纯计算零依赖                  │
│  Vector2D MathAddon                           │
└──────────────────────────────────────────────┘
```

**关键设计原则:**
- 组合优于继承（Player = Transform + Health + Weapon，不再 Unit→Sprite 继承链）
- javidx9 生命周期: `OnCreate() → OnUpdate(dT) → OnDestroy()`
- 数据驱动: 数值从配置/关卡数据加载，不硬编码
- 引擎层绝对不能引用游戏层（`engine ← game` 严格单向）
- Level 层独立于引擎（仅依赖 Math），不依赖 SDL2
- 热路径零分配: update/draw 循环不创建新对象

---

## 3. 文件结构（当前状态）

```
/
├── PROJECT.md                   ← 本文档（所有 AI 入口）
├── CLAUDE.md                    ← Claude Code 专用入口
├── CMakeLists.txt               ← CMake 构建系统
├── vcpkg.json                   ← vcpkg manifest（备选安装方式）
│
├── src/
│   ├── math/                    ✅ v0.2.0 已完成
│   │   ├── Vector2D.h/cpp       # 2D向量（const正确, 比较算子, distanceTo）
│   │   └── MathAddon.h/cpp      # 角度转换, lerp, clamp, wrapAngle, decayTimer
│   ├── engine/                  ✅ v0.2.1
│   │   ├── Engine.h             # OnCreate/OnUpdate/OnDestroy 基类
│   │   ├── Renderer.h/cpp       # SDL2 渲染封装
│   │   ├── Input.h/cpp          # 键盘/鼠标抽象
│   │   ├── Audio.h/cpp          # SDL2_mixer 音效封装
│   │   └── ResourceCache.h/cpp  # 纹理/音效/字体统一缓存
│   ├── framework/               ✅ v0.2.4
│   │   ├── GameLoop.h           # 固定时间步长主循环（header-only template）
│   │   └── Scene.h              # 场景基类
│   ├── game/                    ✅ v0.3.0
│   │   ├── components/          # Transform, Health, WeaponComponent
│   │   ├── entities/            # Player, Enemy, Projectile, Pickup
│   │   ├── systems/             # Movement, Combat, Pickup, Render, EnemyAI, Reload
│   │   └── Level.h/cpp          # 168×68 符号地图（独立 retrofps_level 库）
│   └── main.cpp                 ✅ 五层组装完成
│
├── cmake/                       ✅ v0.2.0
│   ├── FindSDL2.cmake           # 跨平台 SDL2 查找模块
│   ├── FindSDL2_mixer.cmake     # SDL2_mixer 查找
│   └── FindSDL2_ttf.cmake       # SDL2_ttf 查找
│
├── tests/unit/                  ✅ v0.2.0
│   ├── test_vector2d.cpp        # 24 用例，100% 通过
│   └── test_mathaddon.cpp       # 25 用例，100% 通过
│
├── .claude/
│   ├── agents/                  ✅ 10个Agent（见第4节）
│   ├── rules/                   ✅ 3个规则（见第5节）
│   ├── hooks/                   ✅ 2个钩子（见第6节）
│   └── docs/                    # coding-standards / technical-preferences / coordination-rules / directory-structure
│
├── scripts/
│   └── setup_sdl2.ps1           # SDL2 自动下载安装脚本
│
├── assets/                      # 14 .bmp + 5 .ogg
├── design/spec/                 # 架构设计规格
├── src-legacy/                  # v0.1.0 遗留代码（参考用，不修改）
└── prototypes/                  # 废弃原型（保留参考）
```

---

## 4. Agent 团队（10人完整配置）

所有 Agent 定义在 `.claude/agents/` 下。每个 Agent 有明确的领域边界、职责清单和禁止事项。

### 技术团队

#### 4.1 Lead Programmer（主程）
- **文件:** `.claude/agents/lead-programmer.md`
- **工具:** Read, Glob, Grep, Write, Edit, Bash
- **模型:** sonnet | **最大轮次:** 20 | **内存:** project
- **技能:** code-review, architecture-decision, tech-debt
- **职责:** 架构决策、代码审查、API设计、重构策略、跨模块协调
- **触发:** 架构变更、多文件重构

#### 4.2 Engine Programmer（引擎程序员）
- **文件:** `.claude/agents/engine-programmer.md`
- **工具:** Read, Glob, Grep, Write, Edit, Bash
- **模型:** sonnet | **最大轮次:** 20
- **职责:** SDL2封装（Renderer/Input/Audio/ResourceCache）、性能关键代码
- **规则:** 热路径零分配、引擎禁止引用游戏层、RAII资源管理

#### 4.3 Gameplay Programmer（游戏逻辑程序员）
- **文件:** `.claude/agents/gameplay-programmer.md`
- **工具:** Read, Glob, Grep, Write, Edit, Bash
- **模型:** sonnet | **最大轮次:** 20
- **职责:** 组件/实体/System、战斗/拾取/移动/敌人AI
- **规则:** 数据驱动、组件纯数据、state machine显式转换表、delta time

#### 4.4 UI Programmer（UI程序员）
- **文件:** `.claude/agents/ui-programmer.md`
- **工具:** Read, Glob, Grep, Write, Edit, Bash
- **模型:** sonnet | **最大轮次:** 20
- **职责:** HUD/弹药/血量/准星/换弹进度条/小地图/效果叠加
- **规则:** UI只读显示、中文直接写、不修改游戏状态

#### 4.5 QA Tester（测试员）
- **文件:** `.claude/agents/qa-tester.md`
- **工具:** Read, Glob, Grep, Write, Edit, Bash
- **模型:** sonnet | **最大轮次:** 10
- **职责:** 测试用例/Bug报告/回归验证
- **规范:** Arrange-Act-Assert, 每个特性5类测试（正常/零/最大/负/边界）

### 设计团队

#### 4.6 Game Designer（游戏设计师）
- **文件:** `.claude/agents/game-designer.md`
- **来源:** agency-agents
- **职责:** 数值平衡、GDD编写、武器参数、敌人配置、拾取物概率
- **8节GDD标准:** 概述→玩家体验→详细规则→公式→边界情况→依赖→可调参数→验收标准

#### 4.7 Level Designer（关卡设计师）
- **文件:** `.claude/agents/level-designer.md`
- **来源:** agency-agents
- **职责:** 地图布局、敌人放置、拾取物分布、节奏弧线
- **地图规范:** 168×68字符网格, X=墙/S=出生/F=终点/0-2=敌人/H-C-A=拾取

#### 4.8 Technical Artist（技术美术）🆕
- **文件:** `.claude/agents/technical-artist.md`
- **来源:** agency-agents | **工具:** Read, Glob, Grep, Write, Edit, Bash | **模型:** sonnet | **最大轮次:** 20
- **职责:** 纹理/VFX/粒子管线、后处理效果（受击闪红/屏幕震动/视角晃动/距离雾）、视觉性能预算
- **伪3D增强路线图:** 纹理墙→渐变天空→纹理地板→粒子系统→动态光照→天气效果

#### 4.9 Game Audio Engineer（游戏音频工程师）🆕
- **文件:** `.claude/agents/game-audio-engineer.md`
- **来源:** agency-agents | **工具:** Read, Glob, Grep, Write, Edit, Bash | **模型:** sonnet | **最大轮次:** 20
- **职责:** SDL2_mixer音频架构、SFX系统、环境音效、自适应音乐、音频性能
- **通道分配:** 0-23 SFX / 24 音乐 / 25-27 环境 / 28-31 UI
- **自适应音乐参数:** CombatIntensity (0-1), PlayerHealth (0-1)

#### 4.10 Narrative Designer（叙事设计师）🆕
- **文件:** `.claude/agents/narrative-designer.md`
- **来源:** agency-agents | **工具:** Read, Glob, Grep, Write, Edit, Bash | **模型:** sonnet | **最大轮次:** 20
- **职责:** 世界观构建、关卡叙事嵌入、中文文本内容
- **叙事传递:** 环境叙事→简报文字→拾取文本→胜利/失败→敌人设计
- **中文优先:** 所有叙事内容直接用中文撰写

### Agent 分工映射

| 工作内容 | 委托 Agent |
|----------|-----------|
| 架构决策 / 代码审查 | lead-programmer |
| SDL2 引擎代码 | engine-programmer |
| 游戏逻辑 / 战斗 / AI | gameplay-programmer |
| HUD / 文字渲染 / 菜单 | ui-programmer |
| 纹理 / 粒子 / 后处理 | technical-artist |
| 音效 / 音乐 / 环境音 | game-audio-engineer |
| 剧情 / 文本 / 世界观 | narrative-designer |
| 数值 / GDD / 武器参数 | game-designer |
| 地图 / 敌人位置 / 拾取 | level-designer |
| 测试 / Bug报告 | qa-tester |

---

## 5. 代码规则（`.claude/rules/`）

### engine-code.md
- **路径:** `src/engine/**`
- 热路径（update/draw）零分配
- 引擎代码绝对不能依赖游戏层
- 公共API注释中必须有使用示例
- 优化前后Profile测量

### gameplay-code.md
- **路径:** `src/game/**`
- 所有游戏数值从外部配置加载
- 所有时间依赖使用 delta time
- 组件纯数据不含逻辑
- 不直接引用UI代码

### ui-code.md
- **路径:** `src/game/systems/RenderSystem.*`, `src/engine/Renderer.*`
- UI只能读游戏状态，绝对不能修改
- 所有面向玩家的字符串直接用中文
- UI渲染不阻塞游戏循环

---

## 6. 自动化钩子（`.claude/hooks/`）

| 钩子 | 触发时机 | 作用 |
|------|---------|------|
| `validate-commit.sh` | git commit 前 | 验证引擎层不引用游戏层、检查硬编码数值、TODO归属 |
| `validate-push.sh` | git push 前 | 保护分支 push 警告（main/master） |
| `validate-assets.sh` | Write/Edit assets/ 后 | 文件命名规范（小写_下划线）、JSON 合法性 |
| `session-start.sh` | 会话开始时 | 注入项目上下文（分支/提交/版本目标/代码健康） |

---

## 7. 编码标准

### 命名约定
| 类型 | 风格 | 示例 |
|------|------|------|
| 类/结构体 | PascalCase | `Vector2D`, `UnitPlayer` |
| 函数/方法 | camelCase | `update()`, `checkOverlap()` |
| 成员变量 | camelCase | `healthMax`, `ammoClip` |
| 常量/枚举 | PascalCase | `symbolWall`, `Mode::playing` |
| 文件名 | PascalCase | `Game.cpp`, `TextureLoader.h` |
| 测试文件 | `test_<模块>.cpp` | `test_vector2d.cpp` |

### 禁止模式
- ❌ 全局单例 — 依赖注入
- ❌ 裸 new/delete — `std::unique_ptr` / `std::shared_ptr`
- ❌ 头文件 `using namespace`
- ❌ 魔法数字 — 命名常量
- ❌ `#pragma once` 以外的 include guard
- ❌ 冗余注释 — 代码自我解释，注释只解释"为什么"

### AI 友好约定
1. 一个文件一个职责
2. 显式依赖（构造函数参数列出所有依赖）
3. 每个 System 可独立测试
4. 中文 UI 优先

---

## 8. 技术偏好（ADR 决策记录）

| ADR | 决策 | 原因 |
|-----|------|------|
| ADR-001 | 保留 SDL2 | 伪3D渲染 SDL2 完全胜任 |
| ADR-002 | 组件化重构 | 继承链僵硬，组合更灵活 |
| ADR-003 | 默认中文 UI | 中文玩家优先，减少本地化开销 |
| ADR-004 | javidx9 生命周期 | OnCreate/OnUpdate/OnDestroy 清晰简洁 |

### 渲染参数
- 内部分辨率: **240×135** → 放大显示
- 目标帧率: **60 FPS**（固定时间步长 dT=1/60）
- FOV: **60°**（π/3 弧度）
- 精灵尺寸: **16×16** 像素

### 游戏参数（v0.1.0 基线）
| 参数 | 当前值 |
|------|--------|
| 玩家血量 | 20 |
| 弹夹容量 | 30 |
| 备弹 | 90 |
| 换弹时间 | 2.0s |
| 射击间隔 | 0.1s |
| 移动速度 | 7.0f |
| 小怪/中怪/大怪血量 | 1 / 3 / 6 |

---

## 9. 版本路线图 v0.2.0 → v0.5.0

```
v0.2.0 ✅ 地基 — CMake + Math Layer 49/49 测试通过
v0.2.1 ✅ 引擎 — Engine Rendering/Input/Audio/ResourceCache
v0.2.2 ✅ 组件 — Transform/Health/WeaponComponent + 实体
v0.2.3 ✅ 系统 — 6个逻辑系统全部完成
v0.2.4 ✅ 框架 — GameLoop + Scene 基础
v0.2.5 ✅ 换弹 — 武器系统完整（R键/自动换弹/HUD进度条）
v0.2.6 ✅ 反馈 — 纹理墙/受击闪红/屏幕震动/枪口闪光/视角晃动
v0.2.7 ✅ 氛围 — 渐变天空/距离雾/小地图
v0.2.8 ✅ 稳定 — 测试增至 68/68（新增 Level/Health/Weapon 测试）
v0.2.9 ✅ 打磨 — 视觉效果全链路打通
v0.3.0 ✅ 里程碑 — 版本标记，文档收尾，全项目审查 + 30+ 修复
v0.3.1 ✅ 架构 — Level 层独立 + 游戏参数外部化（JSON 配置）
v0.3.2 ✅ 系统 — System 实例化 + 依赖注入（全部 System 可单元测试）
v0.3.3 ✅ 渲染 — 纹理地板/天花板 + 多墙壁材质 + 敌人动画 + 粒子/光照
v0.3.4 ✅ 拾取 — 浮动动画 + 弹痕贴花系统（FIFO 64上限）
v0.3.5 ✅ 光照 — 动态光照（火把闪烁 + LightSource 结构体）
v0.4.0 ✅ 里程碑 — 127+ 测试通过 + 天气/水下/Y-shearing 已实现 + 全链路可测试架构
v0.4.1 🔜 音效 — 音频系统完善（game-audio-engineer 主导）
v0.4.2 🔜 关卡 — 地图扩展 + 敌人放置 + 拾取物分布（level-designer 主导）
v0.4.3 🔜 叙事 — 中文剧情简报/胜利失败文本/拾取物说明（narrative-designer 主导）
v0.4.4 🔜 打磨 — 全项目审查 + Bug 修复 + 性能调优（lead-programmer 主导）
v0.4.5 🔜 菜单 — 主菜单/暂停/设置/游戏结束界面（ui-programmer 主导）
v0.5.0 🔜 里程碑 — 完整可发布 DEMO（菜单→游戏→胜利/失败完整流程）
```

> 详细实现计划: `docs/superpowers/plans/2026-05-16-v0.4.1-to-v0.5.0-plan.md`
> 版本依赖: v0.4.1(音频) ∥ v0.4.2(关卡) → v0.4.3(叙事) → v0.4.4(审查) → v0.4.5(菜单) → v0.5.0(里程碑)

### v0.4.1 目标：音频系统完善（5 任务，game-audio-engineer 主导）

| # | 任务 | 文件 | 关键内容 |
|---|------|------|---------|
| 4.1.1 | Audio 模块增强 | `engine/Audio.h/cpp` | SoundType 枚举、通道分配 0-23 SFX/24 音乐/25-27 环境/28-31 UI、分组音量控制、3D 空间化距离衰减 |
| 4.1.2 | 射击+换弹音效 | `CombatSystem.cpp`, `ReloadSystem.cpp` | 玩家射击/敌人射击/换弹开始完成音效触发 |
| 4.1.3 | 拾取+受伤+脚步 | `PickupSystem.cpp`, `CombatSystem.cpp`, `MovementSystem.cpp` | 拾取触发音效、敌人受伤音效、移动脚步音效（空间化） |
| 4.1.4 | 区域环境音效 | `RenderSystem.cpp`, `Level.h` | 水下低通滤波器、区域风声音效、基于玩家位置触发 |
| 4.1.5 | 音频测试 | `tests/unit/test_audio.cpp` 新建 | Mock SDL2_mixer，通道分配/音量控制/3D定位测试 ≥ 5 用例 |

**验收:** 5 类 SFX 可触发、环境音效区域切换平滑、3D 空间化左右声道正确

### v0.4.2 目标：关卡内容扩展（4 任务，level-designer 主导）

| # | 任务 | 文件 | 关键内容 |
|---|------|------|---------|
| 4.2.1 | 地图符号扩展 | `Level.cpp` (levelData) | 起始房间→走廊迷宫→开阔大厅→Boss房→秘密房间，4 种墙壁材质区分区域 |
| 4.2.2 | 敌人分布+难度曲线 | `Level.cpp`, `enemies.json` | 区域1 小怪×8 → 区域2 小怪+中怪×15 → 区域3 中怪+大怪×10 → Boss房 大怪×3 |
| 4.2.3 | 拾取物经济学 | `Level.cpp`, `pickups.json` | 生命 H×12 / 金币 C×25 / 弹药 A×8 / 升级 h×2 a×2 w×1，总弹药≥需求×1.3 |
| 4.2.4 | 路径验证+测试 | `test_level.cpp`, `Level.cpp` | BFS 起点→终点可达、敌人≥20、拾取物≥50、走廊宽度≥1格、水域标记正确 |

**验收:** BFS 验证起点→终点可达、敌人≥20、拾取物≥50、新增测试 ≥ 5 用例

### v0.4.3 目标：叙事层集成（4 任务，narrative-designer 主导）

| # | 任务 | 文件 | 关键内容 |
|---|------|------|---------|
| 4.3.1 | NarrativeSystem 新建 | `NarrativeSystem.h/cpp` 新建 | 简报/胜利/失败/拾取描述/区域提示 5 类文本接口，从 narrative.json 加载 |
| 4.3.2 | 关卡简报+胜利失败文本 | `narrative.json` 新建, `main.cpp` | 3 种胜利条件文本 / 3 种死因文本 / 统计信息（消灭数/拾取数/命中率） |
| 4.3.3 | 拾取物中文说明+环境叙事 | `PickupSystem.cpp`, `RenderSystem.cpp` | 首次拾取弹出描述 2 秒、特定位置触发中文提示、敌人中文化命名 |
| 4.3.4 | 叙事测试 | `tests/unit/test_narrative.cpp` 新建 | 简报非空、胜利/失败文本正确、6 种拾取物映射完整、区域提示坐标匹配 |

**验收:** 所有中文文本 UTF-8 编码正确、7 种游戏状态各有对应文本、新测试 ≥ 8 用例

### v0.4.4 目标：全项目审查 + 打磨（6 任务，lead-programmer + qa-tester 主导）

根据项目规则（每 5 个小版本执行全项目审查），v0.3.0→v0.4.0 跨越 10 个版本，必须执行。

| # | 审查项 | 范围 | 产出 |
|---|--------|------|------|
| 4.4.1 | 可行性验收 | 全部 41 源文件 | 架构约束无违反、功能完整性核对、Debug+Release 双配置编译 |
| 4.4.2 | Bug 排查 | 全部 System+Entity | 空指针/数组越界/资源泄漏/浮点除零/整数溢出修复 |
| 4.4.3 | 代码冗余+耦合 | 5 层引用方向 | 相似代码提取、单文件>500行拆分、循环依赖检测、/W4 零警告 |
| 4.4.4 | 性能热点 | RenderSystem/Movement/Particles | 渲染≤10ms、逻辑≤5ms、Release 60FPS 稳定 |
| 4.4.5 | 测试缺口 | 功能清单对比 | 补充 test_combat/test_enemy_ai/test_render，目标 150+ 用例 |
| 4.4.6 | 数值平衡+边界 | GameConfig JSON | 大怪击杀所需弹药≤弹夹80%、窗口失焦暂停、分辨率切换、存档安全 |

**验收:** 引擎零 game 引用、编译零警告、60FPS 稳定、≥ 150 测试通过

### v0.4.5 目标：菜单系统（5 任务，ui-programmer 主导）

| # | 任务 | 新建文件 | 关键内容 |
|---|------|---------|---------|
| 4.5.1 | MenuScene 主菜单 | `scenes/MenuScene.h/cpp` | 渐变天空背景、"开始/继续/设置/退出" 中文菜单、↑↓/鼠标导航 |
| 4.5.2 | PauseScene 暂停 | `scenes/PauseScene.h/cpp` | ESC 触发、半透明模糊背景、"继续/重新开始/设置/返回主菜单" |
| 4.5.3 | SettingsScene 设置 | `scenes/SettingsScene.h/cpp` | 主音量/音效/音乐 0-100%、鼠标灵敏度、全屏切换、settings.json 持久化 |
| 4.5.4 | GameOverScene 结束 | `scenes/GameOverScene.h/cpp` | 统计面板(消灭数/拾取数/时间/命中率/S-D评级)、重新开始/返回主菜单 |
| 4.5.5 | 场景管理集成+测试 | `Scene.h`, `main.cpp`, `test_menu.cpp` | SceneManager push/pop/replace、场景间数据传递 |

**验收:** 5 个场景可用、中文 UI 全覆盖、设置持久化、菜单测试 ≥ 6 用例

### v0.5.0 目标：完整可发布 DEMO（3 任务，lead-programmer 主导）

| # | 任务 | 关键内容 |
|---|------|---------|
| 5.0.1 | 完整流程验证 | 端到端通关测试、失败路径测试、Alt+Tab/全屏切换/FPS 稳定性 |
| 5.0.2 | 文档更新 | PROJECT.md/CLAUDE.md/CMakeLists.txt 版本号更新至 v0.5.0 |
| 5.0.3 | Git 版本标记 | `git tag -a v0.5.0` |

**验收:** 完整游戏流程无阻断 Bug、全部测试 ≥ 150 通过、Release 60FPS、Git tag v0.5.0

---

## 10. 构建系统

### 快速开始（当前可用）
```bash
# 配置（Math Layer + 测试，不依赖 SDL2）
cmake -B build -G "Visual Studio 17 2022" -A x64 -DBUILD_TESTS=ON

# 构建数学库
cmake --build build --config Release --target retrofps_math

# 构建并运行测试
cmake --build build --config Release --target test_vector2d
cmake --build build --config Release --target test_mathaddon
./build/Release/test_vector2d.exe
./build/Release/test_mathaddon.exe
```

### 完整构建（需 SDL2）
方法一 — vcpkg:
```bash
E:\vcpkg\vcpkg.exe install sdl2 sdl2-mixer sdl2-ttf --triplet x64-windows
cmake -B build -G "Visual Studio 17 2022" -A x64 -DBUILD_TESTS=ON \
  -DCMAKE_TOOLCHAIN_FILE="E:/vcpkg/scripts/buildsystems/vcpkg.cmake"
```

方法二 — 手动下载:
```powershell
.\scripts\setup_sdl2.ps1
$env:SDL2_ROOT = ".\vendor\SDL2-2.30.3"
cmake -B build -G "Visual Studio 17 2022" -A x64 -DBUILD_TESTS=ON \
  -DSDL2_ROOT="$env:SDL2_ROOT"
```

---

## 11. 协作协议

**用户驱动的协作，非自主执行。** 每个任务遵循:

```
问题 → 选项 → 决策 → 草稿 → 批准
```

### 规则
- 使用 Write/Edit 工具前征求用户确认
- 多文件修改需显式批准完整变更集
- 用户未指示不提交代码
- Math Layer 修改可自动批准，其他层需确认

### 工作流
- **新功能:** brainstorming → writing-plans → executing-plans → code-review → verification
- **修Bug:** systematic-debugging → TDD（先写复现测试）→ 修复 → verification
- **代码审查:** requesting-code-review → receiving-code-review

---

## 12. 可用外部资源

### 已安装 Skills（skills.sh）
- `cpp-testing` (3.9K installs) — C++ 测试（GoogleTest/CTest）、覆盖率、sanitizer
- `cmake` (605 installs) — CMake 构建系统、find_package、target 管理
- `game-development` (332 installs) — 游戏开发最佳实践、可扩展架构
- `performance-profiling` (646 installs) — 性能测量、分析、优化
- `neat-freak` — 会话结束后文档/记忆同步

### 本地 Skills（E:\AISkills）
- `superpowers/` — brainstorming, TDD, debugging, code-review, verification, git-worktrees
- `andrej-karpathy-skills/` — LLM 编码行为指南（Karpathy 规范）
- `Antigravity_Awesome_skills/` — 社区技能库（700+ skills）
- `Anthropic_skills/` — Anthropic 官方技能
- `agent-sprite-forge-skill/` — 精灵生成

### 外部项目（已整合）
- `Claude-Code-Game-Studios` (E:\Open-Source Projects by others\Claude-Code-Game-Studios) — Agent 架构、规则、钩子、设计模板
- `agency-agents` (E:\Open-Source Projects by others\agency-agents) — 5 个 Game Dev Agent + NEXUS 策略框架
- `MetaGPT` — Role/Action/SOP 模式参考

### 项目设计资源
- `design/templates/` — GDD、关卡设计、测试计划模板（适配自 CCGS）
- `design/coordination-strategy.md` — NEXUS 协调策略 → 项目阶段映射
- `.claude/docs/` — 编码标准、技术偏好（ADR）、协作规则、目录结构

### MCP 服务器（可用）
- Context7 — 实时文档查询
- GitHub — 仓库操作
- Tencent Cloud COS — 对象存储
- EdgeOne Pages — 前端部署

### 知识库（可检索）
- 腾讯云API, 微信小程序, 微信云开发, TDesign, 微信支付, 腾讯地图小程序

---

## 13. 伪3D 视觉天花板目标

对标 **Build Engine** 级别（Duke Nukem 3D / Blood / Shadow Warrior），SDL2 可实现的最极致效果：

| 优先级 | 效果 | 版本 |
|--------|------|------|
| P0 | 纹理墙 + 5级距离阴影 | v0.2.6 |
| P0 | 渐变天空 + 距离雾 | v0.2.7 |
| P0 | 枪口闪光 + 受击反馈 + 视角晃动 | v0.2.6 |
| P1 | 纹理地板/天花板 | v0.3.x |
| P1 | 多种墙壁纹理 + 多帧敌人动画 | v0.3.x |
| P1 | 粒子系统（枪火/血雾/爆炸） | v0.4.x |
| P2 | 动态光源（火把闪烁） | v0.3.5 ✅ |
| P2 | 天气效果（雨/雪） | v0.4.0 ✅ |
| P2 | 水下/毒气区域特效 | v0.4.0 ✅ |
| P3 | 上下视角（Y-shearing） | v0.4.0 ✅ |
| P3 | 区域高度变化 | v0.6.x |

---

## 14. 会话恢复指南

任何 AI Agent 首次接入本项目时:
1. **阅读本文档** (PROJECT.md) — 获取全量上下文
2. **检查 CLAUDE.md** — 确认是否有新的更新
3. **检查 `.claude/agents/`** — 需要时可启用对应 Agent
4. **阅读 `.claude/docs/technical-preferences.md`** — 了解最新 ADR
5. **查看构建状态** — `cmake -B build ...` 和测试结果
6. **确认当前版本目标** — 见第9节路线图
