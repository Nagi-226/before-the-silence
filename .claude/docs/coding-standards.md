# 编码标准

## 通用规则

- C++17 标准，禁用扩展（`CMAKE_CXX_EXTENSIONS OFF`）
- 所有源文件 UTF-8 编码（MSVC: `/utf-8`）
- `#pragma once` 作为 include guard
- 不写冗余注释 — 代码应自解释，注释只解释"为什么"

## 命名约定

| 类型 | 风格 | 示例 |
|------|------|------|
| 类/结构体 | PascalCase | `UnitPlayer`, `Vector2D` |
| 函数/方法 | camelCase | `update()`, `checkOverlap()` |
| 成员变量 | camelCase | `healthMax`, `directionForward` |
| 常量/枚举 | PascalCase | `symbolWall`, `Mode::playing` |
| 文件名 | PascalCase | `Game.cpp`, `TextureLoader.h` |

## 类设计原则

### 组合优于继承
当前 `Unit : Sprite` 继承链已显僵硬。重构方向：
```
// 旧（继承）
class UnitPlayer : public Unit : public Sprite { ... };

// 新（组合）
class Player {
    Transform transform;
    Health health;
    WeaponComponent weapon;
    SpriteRenderer sprite;
};
```

### 数据驱动
- 游戏数值从 Level 数据文件读取，不硬编码
- 武器参数、敌人模板、拾取物概率全部外部配置
- 地图用符号字符定义（保持当前 Level::levelData 方式）

### 生命周期
所有对象遵循 javidx9 风格生命周期：
```
OnCreate()  →  初始化资源、加载数据
OnUpdate(dT) → 每帧逻辑更新
OnDestroy()  → 释放资源
```

## 禁止模式

- 禁止全局单例 — 所有依赖通过构造函数注入
- 禁止裸 new/delete — 使用 `std::unique_ptr` / `std::shared_ptr`
- 禁止在头文件 using namespace
- 禁止魔法数字 — 用命名常量替代
- Game.cpp 不得超过 200 行 — 职责拆分到 System

## AI Agent 友好约定

1. **一个文件一个职责** — Agent 读单个文件就能理解一个完整概念
2. **显式依赖** — 构造函数参数列出所有依赖，不隐藏
3. **可测试单元** — 每个 System 可独立测试，不依赖完整游戏循环
4. **中文 UI 优先** — 所有面向玩家的字符串直接用中文
