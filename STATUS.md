# STATUS — 开发进度实时追踪

> **本文件用途**：AI Agent 集群交接的唯一进度入口。任何 agent 接手前先读本文件，即可对齐项目定位、当前进度与下一步工作。
> **更新约定**：每完成一个开发里程碑（功能/重构/修复批次）后，在「最新进展」顶部追加一条，并同步刷新「当前状态快照」与「待办」。

**最后更新**: 2026-08-08 · 最新提交 `9b4acf4` · 分支 `master`（跟踪 `origin/master` @ https://github.com/Nagi-226/Signal_Lost）

---

## 项目定位（30 秒版）

Signal Lost 是复古 DOOM 风 FPS：2057 年侦察兵深入远东废墟感染区，穿越变异体围攻抵达撤离信标。仓库为**双引擎**结构：

- **C++ 原版**（SDL2 + C++17，raycasting 伪 3D）：功能完备、127 测试通过，现为**受保护归档**，不再加新特性。
- **Godot 重制版**（Godot 4.6 + GDScript，`godot/` 目录）：**当前活跃开发线**。路线 B = 真 3D 几何 + 复古呈现层（240×135 SubViewport、最近邻过滤、距离雾、billboard 精灵）。

数据同源：两版本共用 `assets/config/*.json` 数值配置与 LevelData 地图数据。

## 当前状态快照

| 维度 | 状态 |
| --- | --- |
| 活跃开发线 | Godot 重制版（`godot/`） |
| 分支策略 | `master`=有效主线；`dev1`/`dev2`=功能开发+验证分支，**用户实机验收合格后方可合入 master** |
| 最新提交 | 见 git log（本条目随里程碑更新） |
| 游戏完成度 | 双地图可完整通关（找信标撤离），菜单/简报/HUD/音效齐备 |
| 武器系统 | 手枪（半自动 20 发，初始持有）+ 冲锋枪（全自动 30 发，场景拾取获得） |
| 武器升级 | 通用升级组件（一级/二级，每图各 1 个，需按顺序获取）：弹匣 手枪 20→25→30 / 冲锋枪 30→40→50，伤害 32→40→50 |
| 切换绑定 | Q / 鼠标滚轮循环切换（事件驱动，经 `Main._unhandled_input`） |
| 回归测试 | SmokeTest 33 断言全过：`godot --path godot --headless res://scenes/tests/SmokeTest.tscn` |
| 用户验收 | 2026-08-09 升级组件改动已实机验收通过并合入 master |

## 最新进展（新 → 旧）

- **2026-08-09** — **通用武器升级组件（一/二级）+ 精英变异体改名**（dev1 开发，用户实机验收后合入 master）。weapons.json 新增 `upgradeComponents.levels/spawns` 配置驱动；弹匣 手枪 20→25→30 / 冲锋枪 30→40→50，伤害统一 32→40→50；顺序约束（二级需先完成一级改装，越级拾取拦截+toast，拾取物保留）；新符号 u/U（青/橙光晕 48×41 素材，`godot/tools/gen_upgrade_component_sprites.py` 生成）；`enemy_names` 变异体小BOSS→精英变异体；SmokeTest 24→33 断言并改物理帧驱动（headless 渲染/物理帧不同步踩坑）；README 武器/拾取物表同步
- **2026-08-08** `9b4acf4` — 新增 STATUS.md 进度追踪体系（本文件），CLAUDE.md / README.md 加入口指引；此前 `399b3ae` 新增 README（门面文档）、项目更名 Signal Lost（原 Retro FPS），仓库首次推送 GitHub
- **2026-08-08** `47ac39a` — **Phase 3：冲锋枪场景拾取 + Q/滚轮切换**。owned 持有模型（初始仅手枪）；`pickupSpawns` 配置生成 W 拾取物（map0 @ (20,35) / map1 @ (14,10)，不动 C++ 同源地图）；`grant_weapon` 首拾补满弹匣+自动切换，重复拾取转 30 备弹；移除 1/2 键；拾取精灵 48×41 金色光晕版；SmokeTest 扩至 24 断言
- **2026-08-08** `aa6ce5d` — 双击启动器 `启动Godot版.bat`（自动定位 WinGet 安装的 Godot 真实 exe）
- **2026-08** `5c3b3ce` — **Phase 2：双武器系统 + 数值重构 + 敌人攻击帧**。手枪半自动/冲锋枪全自动；血量 100→升级 120，敌血 80/100/300，伤害 32，敌伤×5；敌人开火切持枪攻击贴图
- **2026-08** `bfbc494` — AI 生成素材全套升级（菜单背景/墙地纹理/HUD/敌人拾取精灵）
- **2026-08** `ea39f5d` — 产品层补齐（菜单/简报/HUD/音效集成）
- **2026-08** `2aa1fb7` — 路线 B 原型（真 3D + 复古呈现层验证）
- **保护点** `d5a42a1` — C++ 版 v0.6.1 冻结归档，此后 C++ 侧不再演进

## 待办 / 下一步

1. 下一阶段规划见 `docs/plans/2026-08-09-godot-下一阶段规划.md`：HUD 小地图 / 室外场景与地形突破 / 敌人受击死亡动画与第一人称手部换弹素材 / 剧情背景改公司生物兵器失控
2. 武器拾取音效目前复用 `Energy Orb.ogg`，待用户提供专属音效偏好
3. 候选方向（待用户拍板）：新武器/敌人种类、难度选择接入 Godot 版、存档系统、更多地图

## 交接须知（Agent 必读）

**关键路径与工具链**

- Godot 4.6.2 经 WinGet 安装，真实进程名 `Godot_v4.6.2-stable_win64`（`Get-Process godot` 会假阴性）
- 回归命令：`godot --path godot --headless res://scenes/tests/SmokeTest.tscn`（24 断言）
- C++ 版回归：`ctest --test-dir build -C Debug --output-on-failure`（127 测试）

**硬性约束**

- `godot/scripts/levels/LevelData.gd` 自动生成，**不可手改**；关卡数值改动走 `assets/config/*.json`
- 不修改 `prototypes/`、`src-legacy/`；C++ CMake target 名 `RetroFPS`（exe 名）属受保护构建产物，不动
- 提交消息以 `自检: ①②③④ 通过` 结尾（仓库既有风格）
- **用户驱动协作**：Write/Edit 前需用户确认，未经指示不提交

**已验证的技术方案（避免重复踩坑）**

- 脉冲输入（Q/滚轮）测试：`Input.parse_input_event` 注入 + `await get_tree().physics_frame` 等帧
- 窗口实证：SubViewport `get_texture().get_image().save_png()` 拿像素级渲染，比窗口截屏可靠
- 视线验证：截图/观察前先用 `PhysicsRayQueryParameters3D` 射线确认相机与目标间无墙体遮挡（排除玩家/目标自身 RID）

**文档索引**

| 文件 | 内容 |
| --- | --- |
| `STATUS.md`（本文件） | 进度快照与交接入口 |
| `PROJECT.md` | 项目全量上下文（架构/Agent 团队/规则/钩子，C++ 时代编写） |
| `CLAUDE.md` | Agent 配置索引 + 协作协议 |
| `README.md` | 对外门面 |
| `design/` · `docs/superpowers/plans/` | 设计规格与历史开发计划 |
