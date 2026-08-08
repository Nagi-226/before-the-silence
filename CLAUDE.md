# Signal Lost — v0.6.0

复古伪3D FPS。SDL2 + C++17，5 层架构，10 人 Agent 团队协作开发。
**127 测试 + 双地图/3难度/全游戏循环。详细 → PROJECT.md**
**127 测试全部通过。零编译警告。全特性就绪。**
**启动:** 双击 `启动游戏.bat` 或 `build/Release/RetroFPS.exe`
**计划:** `docs/superpowers/plans/2026-05-16-v0.4.1-to-v0.5.0-plan.md` (v0.4.1→v0.5.0)
**路线图:** `docs/superpowers/plans/2026-05-16-v0.5.0-to-v0.7.0-plan.md` (v0.5.0→v0.7.0)
**详细 → PROJECT.md**

## 快速构建

```bash
# 前置条件: E:\vcpkg 已安装 sdl2/sdl2-mixer/sdl2-ttf (x64-windows)
cmake -B build -DCMAKE_TOOLCHAIN_FILE=E:/vcpkg/scripts/buildsystems/vcpkg.cmake -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release --target RetroFPS
# 游戏位于: build/Release/RetroFPS.exe

# 单元测试
cmake .. -DBUILD_TESTS=ON  # 重新配置
cmake --build build --config Debug --target test_vector2d test_mathaddon test_level test_particles test_config test_pickup test_purelogic
ctest -C Debug --output-on-failure
```

### 已知修复 (2026-05-16)
- `GameConfig.cpp`: 修复 `loadGame()` 中 dda 段 JSON key 名不匹配 (`d["ddaMaxSteps"]`→`d["maxSteps"]`, `d["ddaStepSize"]`→`d["stepSize"]`)导致的 nlohmann::type_error 崩溃
- `CMakeLists.txt`: `find_package` 改为 CONFIG 优先，支持 vcpkg 集成
- `启动游戏.bat`: 增加 Release/Debug 自动检测

## 配置索引

| 类型 | 路径 | 说明 |
|------|------|------|
| 入口文档 | `PROJECT.md` | 全量项目上下文（架构/标准/路线图/构建） |
| Agent 定义 | `.claude/agents/` | 10 个专用 Agent |
| 编码规则 | `.claude/rules/` | engine-code / gameplay-code / ui-code |
| 自动化钩子 | `.claude/hooks/` | validate-commit / validate-push / validate-assets / session-start |
| 技术文档 | `.claude/docs/` | coding-standards / technical-preferences / coordination-rules / directory-structure |
| 设计文档 | `design/spec/` | 架构规格 |
| 实现计划 | `docs/superpowers/plans/` | 当前活跃计划 |

## 项目 Agents

| Agent | 来源 | 工具 | 职责 |
|-------|------|------|------|
| `lead-programmer` | CCGS | R/Gr/G/W/E/B | 架构决策、代码审查、API 设计、重构策略 |
| `engine-programmer` | CCGS | R/Gr/G/W/E/B | SDL2 引擎层：Renderer/Input/Audio/ResourceCache |
| `gameplay-programmer` | CCGS | R/Gr/G/W/E/B | 游戏逻辑：组件/实体/System 实现 |
| `ui-programmer` | CCGS | R/Gr/G/W/E/B | HUD/文字渲染/覆盖层/小地图 |
| `technical-artist` | agency | R/Gr/G/W/E/B | 纹理/VFX/粒子管线、后处理效果、视觉性能 |
| `game-audio-engineer` | agency | R/Gr/G/W/E/B | SDL2_mixer 音频架构、环境音效、自适应音乐 |
| `narrative-designer` | agency | R/Gr/G/W/E/B | 世界观构建、关卡叙事嵌入、中文文本内容 |
| `qa-tester` | CCGS | R/Gr/G/W/E/B | 测试用例/Bug 报告/回归清单 |
| `game-designer` | agency | R/Gr/G | 数值平衡、武器参数、拾取物概率 |
| `level-designer` | agency | R/Gr/G | 地图布局、敌人放置、资源分布 |

R=Read Gr=Grep G=Glob W=Write E=Edit B=Bash

## Rules（路径绑定）

| 规则 | 适用路径 | 核心约束 |
|------|----------|---------|
| `engine-code.md` | `src/engine/**` | 零热路径分配、严格依赖方向 engine←game |
| `gameplay-code.md` | `src/game/**` | 数据驱动、组件纯数据、delta time |
| `ui-code.md` | `src/game/systems/RenderSystem.*` | UI 只读显示、中文直接写 |

## Hooks

| 钩子 | 触发时机 | 作用 |
|------|---------|------|
| `session-start.sh` | SessionStart | 注入项目上下文（分支/提交/代码健康） |
| `validate-commit.sh` | PreToolUse (git commit) | 引擎层引用检查、硬编码数值检查、TODO 归属 |
| `validate-push.sh` | PreToolUse (git push) | 保护分支 push 警告 |
| `validate-assets.sh` | PostToolUse (Write/Edit) | assets/ 文件命名规范、JSON 合法性 |

## 可用 Skills

### 工作流 Skills（E:\AISkills\superpowers）
brainstorming / test-driven-development / systematic-debugging / writing-plans / executing-plans / subagent-driven-development / requesting-code-review / receiving-code-review / verification-before-completion / finishing-a-development-branch / using-git-worktrees / dispatching-parallel-agents

### 编码规范 Skills
- `andrej-karpathy-skills:karpathy-guidelines` — LLM 编码行为指南
- `simplify` — 代码简洁性审查
- `security-review` — 安全审查

### 领域 Skills（skills.sh 安装）
- `cpp-testing` — C++ 测试（GoogleTest/CTest），3.9K installs
- `cmake` — CMake 构建系统，605 installs
- `game-development` — 游戏开发最佳实践，332 installs
- `performance-profiling` — 性能分析与优化，646 installs
- `neat-freak` — 会话结束后文档/记忆同步

### 本地 Skills（E:\AISkills）
- `Antigravity_Awesome_skills/` — 社区技能库（700+ skills）
- `Anthropic_skills/` — Anthropic 官方技能
- `agent-sprite-forge-skill/` — 精灵生成

## 外部项目（已整合）

| 源项目 | 路径 | 整合内容 |
|--------|------|----------|
| Claude-Code-Game-Studios | `E:\Open-Source Projects by others\Claude-Code-Game-Studios` | 5 agents + 3 rules + 4 hooks + 4 docs |
| agency-agents | `E:\Open-Source Projects by others\agency-agents` | 5 agents (game-designer/level-designer/technical-artist/game-audio-engineer/narrative-designer) + strategy/playbooks + integrations/claude-code |
| MetaGPT | `E:\Open-Source Projects by others\MetaGPT` | Role/Action/SOP 模式参考 → coordination-rules.md |

## 协作协议

**用户驱动的协作，非自主执行。**
每个任务: **问题 → 选项 → 决策 → 草稿 → 批准**

- Write/Edit 前征求用户确认（Math Layer 除外）
- 多文件修改需显式批准完整变更集
- 用户未指示不提交代码
- 不跳过 Git hooks（`--no-verify`）
- 不 force push 到 main/master
- 不修改 `prototypes/` 和 `src-legacy/` 目录
- CodeBuddy 端同步开发，需交叉审查确保架构一致
- **每 5 个小版本 (v0.2.x → v0.2.x+5) 执行全项目审查**: 可行性验收 + Bug 排查 + 代码冗余 + 耦合检测 + 性能热点 + 测试缺口
