# Retro FPS v0.2.0 重构设计规格

> 日期: 2026-05-13 | 状态: Draft | 作者: Nagi + Claude
> 从 v0.1.0（原名 v1.0.1.0 原型）重构升级。目标 v1.0.0 = 首个稳定发布版。

## 1. Overview

将现有 Retro FPS（SDL2 伪3D光线投射引擎）重构为 AI Agent 友好的模块化架构，同时从 MyObject/FPS 原型移植换弹系统和游戏增强功能。吸收 javidx9 olcConsoleGameEngine 的简洁生命周期设计理念，保持 SDL2 渲染后端不变。

## 2. 当前状态分析

### 现有文件（Retro-First-Person-Shooter-Code-1-0-1-0/）
| 文件 | 行数 | 职责 | 问题 |
|------|------|------|------|
| Game.cpp | 620 | 游戏循环、渲染、事件、碰撞、HUD | **太大**，职责过多 |
| Game.h | 86 | 声明 | 混合渲染/逻辑/UI |
| UnitPlayer.cpp | 175 | 玩家逻辑 | 依赖 Unit 继承 |
| UnitEnemy.cpp | 93 | 敌人AI | 耦合到 Game::raycast |
| Weapon.cpp | 99 | 武器系统 | 无换弹，ammo<0=无限弹 |
| Sprite.cpp | 105 | 精灵渲染 | 16px 硬编码 |
| Projectile.cpp | 57 | 子弹 | 缺少飞行可视化 |

### 从 MyObject/FPS 移植的特性
| 特性 | MyObject 实现 | 移植方式 |
|------|-------------|---------|
| **换弹系统** | `bIsReloading` + `fReloadTimer` + R键 | Weapon 组件内置 reload 状态机 |
| **弹药双轨** | 弹夹30 + 备弹90 | Weapon `ammoClip` + `ammoReserve` |
| **换弹进度条** | 控制台字符百分比 | SDL2 矩形进度条 + 文字百分比 |
| **子弹飞行渲染** | 控制台 '*' 字符 | 已有 Projectile 精灵，增强渲染 |
| **墙壁阴影分级** | 4级字符阴影 | 当前已有 `fColor` 分级，增强到4级 |

## 3. Architecture Design

### 3.1 四层架构

```
Layer 4: Game (游戏层)
  ├── components/    纯数据结构
  ├── entities/      游戏对象
  └── systems/       逻辑处理器

Layer 3: Framework (框架层)
  ├── GameLoop       固定时间步长
  └── Scene          场景管理栈

Layer 2: Engine (引擎层)
  ├── Renderer       SDL2渲染封装
  ├── Input          输入抽象
  ├── Audio          音效封装
  └── ResourceCache  统一资源管理

Layer 1: Math (数学层)
  ├── Vector2D       2D向量
  └── MathAddon      角度转换
```

### 3.2 组件设计

```cpp
// 纯数据结构，不含逻辑
struct Transform {
    Vector2D position;
    float angle;       // 朝向（弧度）
};

struct Health {
    int current;
    int max;
    bool isAlive() const { return current > 0; }
};

struct WeaponComponent {
    int ammoClip;          // 当前弹夹
    int ammoReserve;       // 备弹
    int clipSize;          // 弹夹容量
    float fireRate;        // 射击间隔（秒）
    float cooldownTimer;   // 冷却计时
    float reloadTime;      // 换弹时间
    float reloadTimer;     // 换弹计时
    bool isReloading;      // 换弹状态
    int damage;            // 伤害
    float bulletSpeed;     // 子弹速度
    float bulletRange;     // 子弹射程
};
```

### 3.3 换弹状态机

```
    ┌──────────────┐
    │   IDLE       │ ← 正常射击状态
    │  (可射击)     │
    └──┬────┬──────┘
       │    │
    按R键  弹夹=0且射击
       │    │
       ▼    ▼
    ┌──────────────┐
    │  RELOADING   │
    │  (计时中)     │
    └──────┬───────┘
           │ reloadTimer >= reloadTime
           ▼
    ┌──────────────┐
    │  完成换弹     │
    │ ammoClip=     │
    │ min(clipSize, │
    │ clipSize-     │
    │ ammoClip +    │
    │ ammoReserve)  │
    └──────┬───────┘
           │
           ▼ 回到 IDLE
```

### 3.4 系统依赖关系

```
MovementSystem → [Transform, Level::isBlockAtPos]
CombatSystem   → [WeaponComponent, Transform, Projectile列表]
PickupSystem   → [Transform, Health, WeaponComponent, Pickup列表]
RenderSystem   → [Transform, Level数据, Renderer]
ReloadSystem   → [WeaponComponent, Input]
```

## 4. Implementation Phases

### 版本路线图 v0.2.0 → v0.3.0

```
v0.2.0  地基 ── CMake + Math Layer 单元测试
v0.2.1  引擎 ── Engine + Framework 层
v0.2.2  组件 ── 游戏组件 + 实体迁移
v0.2.3  系统 ── 逻辑系统全部完成
v0.2.4  可玩 ── 组装完成，游戏可运行
v0.2.5  换弹 ── 武器系统完整（R键/自动换弹/进度条）
v0.2.6  反馈 ── 受击闪红/屏幕震动/枪口闪光/视角晃动/纹理墙
v0.2.7  氛围 ── 渐变天空/距离雾/小地图
v0.2.8  稳定 ── 测试覆盖 + 性能调优
v0.2.9  打磨 ── Bug修复 + 体验优化
v0.3.0  里程碑稳定版
```

### Phase 详情
- [ ] 创建 `src/engine/` — Renderer, Input, Audio, ResourceCache
- [ ] 创建 `src/framework/` — GameLoop, Scene
- [ ] 将现有 `main.cpp` 重构为使用新框架
- [ ] 验证：现有游戏功能不退化

### Phase 2: 组件化 — Game Layer 重构 (优先级: HIGH)
- [ ] 创建 `src/game/components/` — Transform, Health, WeaponComponent
- [ ] 重构 Player → 使用组件组合
- [ ] 重构 Enemy → 使用组件组合
- [ ] 创建 `src/game/systems/` — MovementSystem, CombatSystem, PickupSystem, RenderSystem
- [ ] 验证：游戏可玩性不变

### Phase 3: 特性移植 — MyObject/FPS (优先级: HIGH)
- [ ] 实现换弹系统（WeaponComponent 内置状态机）
- [ ] 实现换弹进度条 HUD
- [ ] 增强墙壁阴影分级（4级→适应 SDL2 颜色）
- [ ] 增强子弹飞行可视化
- [ ] 中文 UI 全覆盖检查

### Phase 4: AI Agent 基础设施 (优先级: MEDIUM)
- [ ] 添加 `.claude/agents/` 子 Agent 定义
- [ ] 添加 `.claude/rules/` 文件类型规则
- [ ] 配置 `.claude/hooks/` 自动化钩子
- [ ] 编写 Level 数据格式文档
- [ ] 编写引擎 API 文档

### Phase 5: 测试 (优先级: MEDIUM)
- [ ] Math Layer 单元测试（Vector2D, MathAddon）
- [ ] 换弹状态机单元测试
- [ ] 光线投射算法单元测试
- [ ] 碰撞检测集成测试

## 5. 移植细节

### 5.1 换弹系统

从 MyObject/FPS.cpp 移植的核心逻辑：

```cpp
// 换弹触发
if (input.reloadPressed && !weapon.isReloading 
    && weapon.ammoClip < weapon.clipSize 
    && weapon.ammoReserve > 0) {
    weapon.isReloading = true;
    weapon.reloadTimer = 0.0f;
}

// 换弹计时
if (weapon.isReloading) {
    weapon.reloadTimer += dT;
    if (weapon.reloadTimer >= weapon.reloadTime) {
        int needed = weapon.clipSize - weapon.ammoClip;
        int transfer = std::min(needed, weapon.ammoReserve);
        weapon.ammoClip += transfer;
        weapon.ammoReserve -= transfer;
        weapon.isReloading = false;
    }
}
```

HUD 增强：
- 当前：`"Max"` / 数字 / `"Low"` / `"Inf"`
- 新增：`"弹夹: 24/30  备弹: 45"` 格式
- 换弹中：显示进度条（绿色矩形从左到右填充）

### 5.2 墙壁阴影增强

当前代码已有 `fColor` 分3级（1.0, 0.5, 0.3），增强为：
- 极近 (< fDepth/4): fColor = 1.0（全亮）
- 近 (< fDepth/3): fColor = 0.75
- 中 (< fDepth/2): fColor = 0.5
- 远 (< fDepth): fColor = 0.25
- 角落: fColor = 0.15

### 5.3 输入映射

| 键位 | 功能 |
|------|------|
| W/A/S/D | 前后左右移动 |
| 鼠标移动 | 转动视角 |
| 鼠标左键 | 射击 |
| R 键 | 换弹（新增） |
| ESC | 退出 |
| F11 | 全屏切换（新增） |

## 6. Success Criteria

- [ ] 游戏正常启动，60FPS 稳定运行
- [ ] 现有所有功能不退化（移动、射击、敌人AI、拾取物、胜利/失败）
- [ ] 换弹系统完整可用（R键换弹、自动换弹、进度显示）
- [ ] 所有 UI 文字为中文
- [ ] Game.cpp 从 620 行缩减到 <200 行
- [ ] 每个 System 文件 <150 行
- [ ] CMake 构建成功，无警告
- [ ] Math Layer 100% 单元测试覆盖
