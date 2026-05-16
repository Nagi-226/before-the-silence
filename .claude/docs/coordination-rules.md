# Agent 协作规则

## 架构参考：MetaGPT Role/Action/SOP 模式

本项目吸收 MetaGPT 的核心设计模式（不可直接用代码，MetaGPT 是 Python 项目）：

### Role（角色）= 领域职责
每个 Agent 拥有明确的领域边界，正如 MetaGPT 的 `architect.py`/`engineer.py`/`product_manager.py`。本项目各 Agent 定义见 `.claude/agents/`。

### Action（动作）= 原子操作
MetaGPT 中每个 Role 通过 Action 执行工作（如 `WriteCode`/`WriteTest`/`DebugError`）。本项目将这一理念体现在 System 的单一职责方法上：
```
MovementSystem::updatePlayer()    = 一个原子动作
CombatSystem::playerShoot()       = 一个原子动作
ReloadSystem::update()            = 一个原子动作
```

### SOP（标准操作流程）= 工作流
MetaGPT 用 Role 之间的消息传递定义 SOP。本项目用 Agent 协作规则定义 SOP：
```
design → write test → implement → review → verify → commit
```

---

## 角色分配

本项目使用以下 Agent 角色（从 CCGS 和 agency-agents 模式适配）：

| 角色 | 职责 | 触发条件 |
|------|------|----------|
| **Lead Programmer** | 架构决策、代码审查、跨模块协调 | 架构变更、多文件重构 |
| **Gameplay Programmer** | 游戏逻辑：战斗、拾取、移动 | 游戏层代码修改 |
| **Engine Programmer** | 引擎层：渲染、音频、输入封装 | 引擎层代码修改 |
| **UI Programmer** | HUD、菜单、文字渲染 | UI/HUD 相关修改 |
| **Technical Artist** | 纹理/VFX/粒子、后处理、视觉性能 | 视觉效果实现、纹理管线 |
| **Game Audio Engineer** | 音频架构、环境音效、音乐系统 | 音效系统设计、音频资源管理 |
| **Narrative Designer** | 世界观、角色、关卡叙事文本 | 剧情设计、文本内容、中文文案 |
| **Game Designer** | 数值平衡、关卡设计、敌人配置 | 游戏数据/关卡修改 |
| **Level Designer** | 地图设计、敌人放置、拾取物分布 | Level 数据修改 |
| **QA Tester** | 测试编写、Bug 报告、回归验证 | 测试相关 |

## 工作流协议

### 实现新功能
1. `brainstorming` → 理解需求，输出设计
2. `writing-plans` → 编写实现计划
3. `executing-plans` 或 `subagent-driven-development` → 执行实现
4. `requesting-code-review` → 代码审查
5. `verification-before-completion` → 验证通过
6. `finishing-a-development-branch` → 分支合并

### 修复 Bug
1. `systematic-debugging` → 根因分析
2. `test-driven-development` → 先写复现测试
3. 实现修复
4. `verification-before-completion` → 确认修复

### 代码审查
1. `requesting-code-review` → 发起审查
2. `receiving-code-review` → 处理反馈

## 文件修改规则

修改不同层级文件时的审批要求：

| 层级 | 单文件修改 | 多文件修改 |
|------|-----------|-----------|
| Math Layer | 自动批准 | 自动批准 |
| Engine Layer | 需确认 | 需确认 |
| Framework Layer | 需确认 | 需确认 |
| Game Layer | 需确认 | 需确认 |
| CLAUDE.md / 配置 | 需确认 | 需确认 |

## 禁止操作

- 不跳过 Git hooks（`--no-verify`）
- 不 force push 到 main/master
- 不修改 `.claude/settings.json` 中已有的权限配置（除非用户要求）
- 不删除或修改 `prototypes/` 目录（用于历史参考）

## 会话上下文管理

- 每次会话开始：检查 CLAUDE.md 变更，阅读相关 Agent 记忆
- 每次会话结束：运行 `neat-freak` 清理文档和记忆
- 重大决策后：更新 `.claude/docs/technical-preferences.md` 中的 ADR 日志
