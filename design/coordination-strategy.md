# NEXUS 协调策略 — Retro FPS 适配

> 引用自 agency-agents `strategy/nexus-strategy.md` 和 6 阶段 playbooks。
> 将通用 NEXUS 框架映射到本项目 v0.2.0 → v0.3.0 路线图。

---

## 阶段映射

| NEXUS Phase | 本项目版本 | 核心产出 | Agent 配置 |
|-------------|-----------|----------|------------|
| Phase 0 — Discovery | v0.1.0（已完成） | 原型验证 | — |
| Phase 1 — Strategy | v0.2.0（已完成） | CMake + Math Layer + Agent 配置 | lead-programmer, game-designer |
| **Phase 2 — Foundation** | **v0.2.1–v0.2.3** | Engine + Framework + Game 层 | engine-programmer, gameplay-programmer |
| Phase 3 — Build | v0.2.4–v0.2.7 | 可玩构建 + 换弹 + 反馈 + 氛围 | all agents |
| Phase 4 — Hardening | v0.2.8–v0.2.9 | 测试覆盖 + 性能调优 + Bug 修复 | qa-tester, engine-programmer |
| Phase 5 — Launch | v0.3.0 | 稳定发布 | lead-programmer, qa-tester |
| Phase 6 — Operate | v0.3.x+ | 后续更新 | TBD |

## 当前阶段: Phase 2 — Foundation (v0.2.1–v0.2.3)

### Agent 激活序列

```
Workstream A: Engine Layer (engine-programmer)
  ├── Engine.h/cpp (OnCreate/OnUpdate/OnDestroy 基类)
  ├── Renderer.h/cpp (SDL2 渲染封装)
  ├── Input.h/cpp (键盘/鼠标抽象)
  ├── Audio.h/cpp (SDL2_mixer 封装)
  └── ResourceCache.h/cpp (纹理/音效/字体缓存)

Workstream B: Framework Layer (lead-programmer + gameplay-programmer)
  ├── GameLoop.h/cpp (固定时间步长主循环)
  └── Scene.h/cpp (场景基类)

Workstream C: Game Components (gameplay-programmer)
  ├── components/: Transform, Health, WeaponComponent
  ├── entities/: Player, Enemy, Projectile, Pickup
  └── Level.h/cpp (168×68 符号地图加载)
```

### 质量门禁

- [ ] Engine 层不引用 Game 层（validate-commit.sh 阻断）
- [ ] 热路径零分配（engine-code.md 规则）
- [ ] 所有游戏数值从配置加载（gameplay-code.md 规则）
- [ ] 单元测试覆盖所有 Math 层和新 Engine 层

## Dev↔QA Loop

```
实现 → 测试 → PASS → 下一任务
            → FAIL → 修复（最多 3 次）→ 仍 FAIL → 升级 lead-programmer
```

## 质量原则

- **证据优先**: 所有质量声明需附测试结果或截图
- **无门禁不过阶段**: Phase gate 不通过不进入下一阶段
- **上下文连续**: Agent 间交接携带完整上下文
- **快速失败**: 3 次重试后升级，不无限循环
