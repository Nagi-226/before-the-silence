---
paths:
  - "src/engine/**"
---

# 引擎层代码规则

- 热路径（update/draw 循环、渲染、物理）**零分配** — 预分配、池化、复用
- 所有引擎 API 必须是线程安全的，或明确标注单线程
- 优化前后测量 Profile，文档化测量数据
- 引擎代码**绝对不能**依赖游戏层代码（严格依赖方向：engine ← game）
- 每个公共 API 注释中必须有使用示例
- 公共接口变更需迁移指南
- 所有资源使用 RAII / 确定性清理
- 渲染管线使用离屏渲染目标（textureScreen）模式

## 示例

**正确**（零分配热路径）:
```cpp
// 预分配数组每帧复用
float listDepthDraw[240]; // 成员变量，drawWalls 中复用

void drawWalls(Renderer& renderer) {
    for (int x = 0; x < 240; x++) {
        // listDepthDraw 已在外部分配，不创建新对象
        listDepthDraw[x] = distance;
    }
}
```

**错误**（热路径中分配）:
```cpp
void drawWalls(Renderer& renderer) {
    std::vector<float> depths; // ❌ 每帧分配
    depths.reserve(240);       // ❌ 热路径中的内存操作
    // ...
}
```
