---
paths:
  - "src/game/systems/RenderSystem.*"
  - "src/game/systems/*HUD*"
  - "src/engine/Renderer.*"
---

# UI/HUD 代码规则

- UI 绝对不能拥有或直接修改游戏状态 — 只读显示
- 所有面向玩家的字符串直接用中文（本项目中文优先策略）
- HUD 渲染不阻塞游戏循环
- 支持缩放：所有文字大小参数化
- UI 元素通过 System 读取组件数据，不直接修改组件

## 示例

**正确**:
```cpp
void drawHUD(Renderer& renderer, Player& player, ResourceCache& cache) {
    // 只读访问组件
    std::string healthStr = player.health.toString(); // "满血" or "15"
    std::string ammoStr = player.weapon.ammoString();  // "24/30 备弹:45"
    drawText(renderer, cache, x, y, ammoStr);
}
```

**错误**:
```cpp
void drawHUD(Player& player) {
    player.health.current = 100; // ❌ UI 不能修改游戏状态
}
```
