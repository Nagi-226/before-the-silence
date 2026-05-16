# 设计模板索引

本目录包含从 Claude-Code-Game-Studios 和 agency-agents 适配的设计文档模板。

## 可用模板

| 模板 | 来源 | 用途 |
|------|------|------|
| `GDD-template.md` | CCGS `game-design-document.md` | 游戏设计文档 |
| `level-design-template.md` | CCGS `level-design-document.md` | 关卡设计文档 |
| `test-plan-template.md` | CCGS `test-plan.md` | 测试计划 |

## 上游模板库

完整模板库位于：
- **CCGS**: `E:\Open-Source Projects by others\Claude-Code-Game-Studios\.claude\docs\templates\`（29 个模板）
- **agency-agents**: `E:\Open-Source Projects by others\agency-agents\strategy\`

### CCGS 全部模板列表

| 模板 | 文件 | 本项目相关度 |
|------|------|-------------|
| 游戏概念 | `game-concept.md` | 高 |
| 游戏设计文档 | `game-design-document.md` | **已适配** |
| 游戏支柱 | `game-pillars.md` | 高 |
| 关卡设计 | `level-design-document.md` | **已适配** |
| HUD 设计 | `hud-design.md` | 高 |
| 难度曲线 | `difficulty-curve.md` | 高 |
| 经济模型 | `economy-model.md` | 中 |
| 阵营设计 | `faction-design.md` | 中 |
| 美术圣经 | `art-bible.md` | 高 |
| 音频圣经 | `sound-bible.md` | 高 |
| 角色表 | `narrative-character-sheet.md` | 中 |
| 玩家旅程 | `player-journey.md` | 中 |
| 交互模式库 | `interaction-pattern-library.md` | 中 |
| 用户体验规格 | `ux-spec.md` | 中 |
| 技术设计文档 | `technical-design-document.md` | 高 |
| 架构决策记录 | `architecture-decision-record.md` | 高（已有 ADR 在 technical-preferences.md） |
| 架构可追溯性 | `architecture-traceability.md` | 中 |
| 系统索引 | `systems-index.md` | 中 |
| 测试计划 | `test-plan.md` | **已适配** |
| 测试证据 | `test-evidence.md` | 中 |
| 冲刺计划 | `sprint-plan.md` | 低 |
| 里程碑定义 | `milestone-definition.md` | 中 |
| 发布检查清单 | `release-checklist-template.md` | 中 |
| 发布说明 | `release-notes.md` | 低 |
| 变更日志 | `changelog-template.md` | 低 |
| 事后回顾 | `post-mortem.md` | 低 |
| 事件响应 | `incident-response.md` | 低 |
| 风险登记 | `risk-register-entry.md` | 低 |
| 无障碍需求 | `accessibility-requirements.md` | 低 |

### agency-agents 策略资源

| 资源 | 路径 | 用途 |
|------|------|------|
| 6 阶段 Playbooks | `strategy/playbooks/phase-{0-6}-*.md` | 项目阶段管理框架 |
| 4 场景 Runbooks | `strategy/runbooks/scenario-*.md` | 特定场景应对策略 |
| Agent 激活模板 | `strategy/coordination/agent-activation-prompts.md` | Agent 协作提示模板 |
| 交接模板 | `strategy/coordination/handoff-templates.md` | Agent 间交接规范 |
| NEXUS 策略 | `strategy/nexus-strategy.md` | Agent 编排完整策略 |

## 使用方式

需要某个模板时，从上游路径复制并填入项目具体内容。不要修改上游模板。
