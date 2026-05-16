---
paths:
  - "src/game/**"
---

# 游戏层代码规则

- 所有游戏数值必须从外部配置/数据文件来，**绝对不硬编码**
- 所有时间依赖计算使用 delta time（帧率无关）
- 不直接引用 UI 代码 — 通过 System 接口通信
- 每个游戏系统必须暴露清晰接口
- 状态机必须有显式转换表，附带文档化的状态
- 所有游戏逻辑写单元测试 — 逻辑与渲染分离
- 组件纯数据不含逻辑，系统处理行为
- 不使用全局单例持有游戏状态 — 依赖注入

## 示例

**正确**（数据驱动）:
```cpp
// 从 Level 数据配置敌人
const std::vector<UnitEnemy::TemplateData> templates = {
    {"Alien Small.bmp", 1, Weapon(-1, 1), false},   // 小怪
    {"Alien Medium.bmp", 3, Weapon(15, 4), true},   // 中怪
    {"Alien Large.bmp", 6, Weapon(30, 8), true}     // 大怪
};
```

**错误**（硬编码）:
```cpp
// ❌ 硬编码游戏数值
if (!enemy.canSeePlayer()) return;  // enemy 不知道这个阈值
float shootRange = 10.0f;           // ❌ 应从模板数据来
```
