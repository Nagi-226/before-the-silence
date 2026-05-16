# Retro FPS v0.2.0 — 全面重构实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Retro FPS 从单文件为主的 v1.0.1.0 重构为 AI Agent 友好的四层模块化架构 v2.0.0，移植换弹系统，实现 SDL2 伪3D 渲染的极致视觉效果。

**Architecture:** 四层分离 — Math（纯计算）→ Engine（SDL2封装）→ Framework（通用框架）→ Game（游戏逻辑）。引擎层吸收 javidx9 的 OnCreate/OnUpdate/OnDestroy 生命周期，游戏层采用组件+系统模式替代继承链。

**Tech Stack:** C++17, SDL2 (GPU Renderer), SDL2_mixer, SDL2_ttf, CMake 3.20+, Ninja/MSVC

**参考资源:**
- `src-legacy/` — v1.0.1.0 原始代码（算法参考）
- `E:\Open-Source Projects by others\Claude-Code-Game-Studios\` — Agent 架构模板
- `E:\Open-Source Projects by others\agency-agents\game-development\` — 游戏 Agent 定义
- `E:\Open-Source Projects by others\MetaGPT\` — 多 Agent 协作模式参考
- `E:\Github Project\MyObject\FPS\FPS.cpp` — 换弹系统移植源

---

## 版本路线图 v0.2.0 → v0.3.0

每个小版本 = 可编译、可验证的独立里程碑。版本号遵循 semver（0.主.次），v1.0.0 为稳定发布目标。

```
v0.1.0 ──── 原始原型（原 v1.0.1.0）
  │
  ▼
v0.2.0 ──── 地基 — CMake + Math Layer 单元测试通过
  │  Phase 0-1 完成。Vector2D/MathAddon 100% 测试覆盖。构建系统就绪。
  │  验证: cmake --build build 成功 + test_vector2d/test_weapon 全绿
  ▼
v0.2.1 ──── 引擎 — Engine + Framework 层完成
  │  Phase 2-3 完成。Renderer/Input/Audio/ResourceCache/GameLoop/Scene 全部就位。
  │  吸收 javidx9 生命周期。SDL2 完全封装。
  │  验证: 独立编译通过，Renderer 离屏渲染可用
  ▼
v0.2.2 ──── 组件 — 游戏组件 + 实体迁移完成
  │  Phase 4-5 完成。Transform/Health/WeaponComponent + Player/Enemy/Projectile/Pickup/Level。
  │  继承链 → 组件组合。换弹状态机就位。Level 关卡数据完整迁移。
  │  验证: test_weapon 9/9 通过；Player 移动碰撞检测正确
  ▼
v0.2.3 ──── 系统 — 逻辑系统全部完成
  │  Phase 6 完成。Movement/Combat/Pickup/Render/Reload 五大系统就位。
  │  光线投射渲染完整。精灵深度排序。HUD 框架就绪。
  │  验证: 每个 System 独立可测试，<150行/文件
  ▼
v0.2.4 ──── 可玩 — 组装完成，游戏可运行
  │  Phase 7 完成。main.cpp 组装所有层。GameScene 就位。
  │  WASD 移动 + 鼠标转动 + 射击 + 敌人AI + 拾取物 + 胜利/失败 + 中文 UI。
  │  验证: 完整游戏循环 60FPS 运行，所有 v0.1.0 功能不退化
  ▼
v0.2.5 ──── 换弹 — 武器系统完整
  │  换弹 R 键/自动换弹/进度条全部就位。弹药 HUD 显示 "24/30 备弹:45"。
  │  子弹飞行轨迹可视化增强。墙壁 4 级距离阴影增强。
  │  验证: 换弹状态机 9 项测试通过；手动测试 10 次换弹无 Bug
  ▼
v0.2.6 ──── 反馈 — 玩家感知效果
  │  Phase 8 前半。受击闪红 + 屏幕震动 + 枪口闪光 + 视角晃动(View Bobbing)。
  │  纹理墙壁采样（从 BMP 代替纯色）。
  │  验证: 每种效果预设参数可调，手动测试触发正常
  ▼
v0.2.7 ──── 氛围 — 环境视觉效果
  │  Phase 8 后半。渐变天空 + 距离雾 + 小地图。
  │  整体画面氛围显著提升。
  │  验证: 各分辨率下小地图比例正确；雾效不影响碰撞检测
  ▼
v0.2.8 ──── 稳定 — 测试覆盖 + 性能调优
  │  Phase 9 前半。Math Layer 100% 测试。Weapon 状态机 100% 测试。光线投射算法测试。
  │  Profile + 消除帧率波动。CMake Release 构建通过。
  │  验证: 全部测试通过；Release 构建 60FPS 无掉帧
  ▼
v0.2.9 ──── 打磨 — Bug 修复 + 体验优化
  │  Phase 9 后半。全面 Bug 修复。数值平衡微调。UI 细节打磨。边界情况处理。
  │  验证: 完整通关测试（开始→消灭敌人→拾取→抵达终点）；ESC 正常退出
  ▼
v0.3.0 ──── 里程碑稳定版
  │  所有 v0.2.x 特性固化。文档完整。git tag v0.3.0。
  │  可以对外展示的半成品：核心玩法完整、视觉效果到位、中文 UI 全覆盖。
  ▼
v1.0.0 ──── 未来目标：正式发布
```

### 版本节奏建议

| 版本 | 预计任务数 | 节奏 |
|------|-----------|------|
| v0.2.0 | 3 Tasks | **快速** — 纯迁移，无风险 |
| v0.2.1 | 5 Tasks | **快速** — 新写代码，独立模块 |
| v0.2.2 | 4 Tasks | **中速** — 迁移+适配，需对照 src-legacy |
| v0.2.3 | 5 Tasks | **中速** — 重点在 RenderSystem 迁移 |
| v0.2.4 | 1 Task | **快速** — 组装，验证整体可用 |
| v0.2.5 | 3 Tasks | **中速** — 功能增强，状态机已测 |
| v0.2.6 | 4 Tasks | **减速** — 视觉效果需反复调试参数 |
| v0.2.7 | 3 Tasks | **中速** — 环境效果相互独立 |
| v0.2.8 | 3 Tasks | **减速** — 测试+Profile 需要耐心 |
| v0.2.9 | 2 Tasks | **减速** — Bug 修复不可预测 |

---

## 文件结构总览

```
新增文件 (* = 本计划创建):
src/
├── math/
│   ├── Vector2D.h          (*) 从 src-legacy 迁移+增强
│   ├── Vector2D.cpp        (*)
│   ├── MathAddon.h         (*)
│   └── MathAddon.cpp       (*)
├── engine/
│   ├── Engine.h            (*) 基类 OnCreate/OnUpdate/OnDestroy
│   ├── Renderer.h/cpp      (*) SDL2渲染封装
│   ├── Input.h/cpp         (*) 键盘/鼠标抽象
│   ├── Audio.h/cpp         (*) SDL2_mixer封装
│   └── ResourceCache.h/cpp (*) 统一纹理/音效/字体缓存
├── framework/
│   ├── GameLoop.h/cpp      (*) 固定时间步长循环
│   └── Scene.h/cpp         (*) 场景基类+栈管理
├── game/
│   ├── components/
│   │   ├── Transform.h     (*) 位置+朝向
│   │   ├── Health.h        (*) 生命值
│   │   └── WeaponComponent.h (*) 武器数据+换弹状态机
│   ├── entities/
│   │   ├── Player.h/cpp    (*) 玩家实体
│   │   ├── Enemy.h/cpp     (*) 敌人实体
│   │   └── Projectile.h/cpp (*) 子弹实体
│   ├── systems/
│   │   ├── MovementSystem.h/cpp   (*)
│   │   ├── CombatSystem.h/cpp     (*)
│   │   ├── PickupSystem.h/cpp     (*)
│   │   ├── RenderSystem.h/cpp     (*) 光线投射+精灵排序
│   │   └── ReloadSystem.h/cpp     (*) 换弹逻辑
│   └── Level.h/cpp         (*) 关卡数据
└── main.cpp                (*) 入口

tests/
├── unit/
│   ├── test_vector2d.cpp   (*)
│   ├── test_weapon.cpp     (*)
│   └── test_math.cpp       (*)
└── integration/
    └── test_combat.cpp     (*)

build/                        (CMake生成，gitignored)
assets/
├── images/                   (已创建)
└── sounds/                   (已创建)
```

---

## Phase → Version 映射

| Phase | 产出 | 对应版本 |
|-------|------|----------|
| 0 | CMake 构建系统 | ─┐ |
| 1 | Math Layer |  v0.2.0 |
| 2 | Engine Layer | ─┐ |
| 3 | Framework Layer |  v0.2.1 |
| 4 | Game Components | ─┐ |
| 5 | Game Entities + Level |  v0.2.2 |
| 6 | Game Systems |  v0.2.3 |
| 7 | main.cpp 组装 |  v0.2.4 |
| — | 换弹系统完善 |  v0.2.5 |
| 8a | 视觉反馈（闪红/震动/闪光/晃动/纹理墙） |  v0.2.6 |
| 8b | 环境效果（天空/雾/小地图） |  v0.2.7 |
| 9a | 测试 + Profile |  v0.2.8 |
| 9b | Bug修复 + 打磨 |  v0.2.9 |
| — | 里程碑 | **v0.3.0** |

---

## Phase 0: 版本标记 + 构建系统 → v0.2.0

### Task 0.1: CMakeLists.txt v0.2.0

**Files:**
- Create: `CMakeLists.txt`
- Reference: `src-legacy/CMakeLists.txt`

- [ ] **Step 1: 编写根 CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.20)
project(RetroFPS VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

find_package(SDL2 CONFIG REQUIRED)
find_package(SDL2_mixer CONFIG REQUIRED)
find_package(SDL2_ttf CONFIG REQUIRED)

set(SOURCES
  # Math Layer
  src/math/Vector2D.cpp
  src/math/MathAddon.cpp
  # Engine Layer
  src/engine/Renderer.cpp
  src/engine/Input.cpp
  src/engine/Audio.cpp
  src/engine/ResourceCache.cpp
  # Framework Layer
  src/framework/GameLoop.cpp
  src/framework/Scene.cpp
  # Game Layer - Entities
  src/game/entities/Player.cpp
  src/game/entities/Enemy.cpp
  src/game/entities/Projectile.cpp
  # Game Layer - Systems
  src/game/systems/MovementSystem.cpp
  src/game/systems/CombatSystem.cpp
  src/game/systems/PickupSystem.cpp
  src/game/systems/RenderSystem.cpp
  src/game/systems/ReloadSystem.cpp
  # Game Layer - Level
  src/game/Level.cpp
  # Entry
  src/main.cpp
)

add_executable(${PROJECT_NAME} ${SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

target_link_libraries(${PROJECT_NAME} PRIVATE
  SDL2::SDL2
  SDL2::SDL2main
  $<$<TARGET_EXISTS:SDL2_mixer::SDL2_mixer>:SDL2_mixer::SDL2_mixer>
  $<$<TARGET_EXISTS:SDL2_mixer::SDL2_mixer-static>:SDL2_mixer::SDL2_mixer-static>
  $<$<TARGET_EXISTS:SDL2_ttf::SDL2_ttf>:SDL2_ttf::SDL2_ttf>
  $<$<TARGET_EXISTS:SDL2_ttf::SDL2_ttf-static>:SDL2_ttf::SDL2_ttf-static>
)

if(MSVC)
  target_compile_options(${PROJECT_NAME} PRIVATE /utf-8)
endif()

if(WIN32)
  add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      $<TARGET_RUNTIME_DLLS:${PROJECT_NAME}>
      $<TARGET_FILE_DIR:${PROJECT_NAME}>
    COMMAND ${CMAKE_COMMAND} -E copy_directory_if_different
      ${CMAKE_CURRENT_SOURCE_DIR}/assets
      $<TARGET_FILE_DIR:${PROJECT_NAME}>/assets
    COMMAND_EXPAND_LISTS
  )
endif()
```

- [ ] **Step 2: 验证构建系统**

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
```

预期: 配置成功但编译失败（源文件尚为空）。

- [ ] **Step 3: Commit**

```bash
git add CMakeLists.txt
git commit -m "build: CMakeLists.txt v2.0.0 — four-layer architecture with asset pipeline"
```

---

## Phase 1: Math Layer — 零依赖基础

### Task 1.1: Vector2D — 从 src-legacy 迁移+增强

**Files:**
- Create: `src/math/Vector2D.h`
- Create: `src/math/Vector2D.cpp`
- Create: `tests/unit/test_vector2d.cpp`

- [ ] **Step 1: 写测试**

```cpp
// tests/unit/test_vector2d.cpp
#include <cmath>
#include <cassert>
#include <iostream>
#include "../../src/math/Vector2D.h"

static int testsPassed = 0;
static int testsFailed = 0;

#define TEST(name) void name()
#define CHECK(cond) do { \
    if (!(cond)) { std::cerr << "FAIL: " << #cond << " at line " << __LINE__ << "\n"; testsFailed++; } \
    else testsPassed++; \
} while(0)
#define CHECK_FLOAT(a, b, eps) CHECK(std::abs((a) - (b)) < (eps))

TEST(test_construct_default) {
    Vector2D v;
    CHECK(v.x == 0.0f);
    CHECK(v.y == 0.0f);
}

TEST(test_construct_xy) {
    Vector2D v(3.0f, 4.0f);
    CHECK(v.x == 3.0f);
    CHECK(v.y == 4.0f);
}

TEST(test_construct_angle) {
    Vector2D v(0.0f); // angle 0 = pointing right
    CHECK_FLOAT(v.x, 1.0f, 0.001f);
    CHECK_FLOAT(v.y, 0.0f, 0.001f);
}

TEST(test_magnitude) {
    Vector2D v(3.0f, 4.0f);
    CHECK_FLOAT(v.magnitude(), 5.0f, 0.001f);
}

TEST(test_normalize) {
    Vector2D v(3.0f, 4.0f);
    v.normalize();
    CHECK_FLOAT(v.magnitude(), 1.0f, 0.001f);
}

TEST(test_angle) {
    Vector2D v(0.0f, 1.0f);
    CHECK_FLOAT(v.angle(), 3.14159f / 2.0f, 0.001f);
}

TEST(test_operator_add) {
    Vector2D a(1.0f, 2.0f), b(3.0f, 4.0f);
    Vector2D c = a + b;
    CHECK(c.x == 4.0f);
    CHECK(c.y == 6.0f);
}

TEST(test_operator_sub) {
    Vector2D a(5.0f, 7.0f), b(2.0f, 3.0f);
    Vector2D c = a - b;
    CHECK(c.x == 3.0f);
    CHECK(c.y == 4.0f);
}

TEST(test_dot) {
    Vector2D a(1.0f, 0.0f), b(0.0f, 1.0f);
    CHECK_FLOAT(a.dot(b), 0.0f, 0.001f);
}

TEST(test_negative_reciprocal) {
    Vector2D v(1.0f, 0.0f);
    Vector2D nr = v.getNegativeReciprocal();
    CHECK_FLOAT(nr.x, 0.0f, 0.001f);
    CHECK_FLOAT(nr.y, 1.0f, 0.001f);
}

int main() {
    test_construct_default();
    test_construct_xy();
    test_construct_angle();
    test_magnitude();
    test_normalize();
    test_angle();
    test_operator_add();
    test_operator_sub();
    test_dot();
    test_negative_reciprocal();
    
    std::cout << "Passed: " << testsPassed << ", Failed: " << testsFailed << "\n";
    return testsFailed > 0 ? 1 : 0;
}
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
clang++ -std=c++17 tests/unit/test_vector2d.cpp -o build/test_vector2d.exe; ./build/test_vector2d.exe
```

预期: 编译错误（Vector2D.h 不存在）

- [ ] **Step 3: 写 Vector2D.h**

```cpp
// src/math/Vector2D.h
#pragma once
#include <cmath>

class Vector2D {
public:
    float x, y;

    Vector2D() : x(0.0f), y(0.0f) {}
    Vector2D(float setX, float setY) : x(setX), y(setY) {}
    Vector2D(float angleRad) : x(std::cos(angleRad)), y(std::sin(angleRad)) {}

    float angle() const { return std::atan2(y, x); }
    float magnitude() const { return std::sqrt(x * x + y * y); }

    Vector2D& normalize() {
        float mag = magnitude();
        if (mag > 0.0001f) { x /= mag; y /= mag; }
        return *this;
    }

    Vector2D getNegativeReciprocal() const { return Vector2D(-y, x); }

    float dot(const Vector2D& other) const { return x * other.x + y * other.y; }
    float cross(const Vector2D& other) const { return x * other.y - y * other.x; }
    float angleBetween(const Vector2D& other) const {
        return std::atan2(cross(other), dot(other));
    }

    // Operator overloads
    Vector2D operator+(const Vector2D& o) const { return Vector2D(x + o.x, y + o.y); }
    Vector2D operator-(const Vector2D& o) const { return Vector2D(x - o.x, y - o.y); }
    Vector2D operator*(float s) const { return Vector2D(x * s, y * s); }
    Vector2D operator/(float s) const { return Vector2D(x / s, y / s); }
    Vector2D& operator+=(const Vector2D& o) { x += o.x; y += o.y; return *this; }
    Vector2D& operator-=(const Vector2D& o) { x -= o.x; y -= o.y; return *this; }
    Vector2D& operator*=(float s) { x *= s; y *= s; return *this; }
    Vector2D& operator/=(float s) { x /= s; y /= s; return *this; }
};
```

- [ ] **Step 4: 创建 Vector2D.cpp**

```cpp
// src/math/Vector2D.cpp
#include "Vector2D.h"
// All methods are inline in the header. This file exists for CMake consistency.
```

- [ ] **Step 5: 运行测试确认通过**

```powershell
clang++ -std=c++17 tests/unit/test_vector2d.cpp -o build/test_vector2d.exe; ./build/test_vector2d.exe
```

预期: `Passed: 10, Failed: 0`

- [ ] **Step 6: Commit**

```bash
git add src/math/Vector2D.h src/math/Vector2D.cpp tests/unit/test_vector2d.cpp
git commit -m "feat(math): Vector2D migrated from src-legacy with unit tests"
```

### Task 1.2: MathAddon

**Files:**
- Create: `src/math/MathAddon.h`
- Create: `src/math/MathAddon.cpp`

- [ ] **Step 1: 写 MathAddon.h**

```cpp
// src/math/MathAddon.h
#pragma once

class MathAddon {
public:
    static constexpr float PI = 3.14159265358979323846f;

    static float angleRadToDeg(float rad) { return rad * 180.0f / PI; }
    static float angleDegToRad(float deg) { return deg * PI / 180.0f; }
};
```

- [ ] **Step 2: 写 MathAddon.cpp**

```cpp
// src/math/MathAddon.cpp
#include "MathAddon.h"
```

- [ ] **Step 3: Commit**

```bash
git add src/math/MathAddon.h src/math/MathAddon.cpp
git commit -m "feat(math): MathAddon angle conversion utilities"
```

---

## Phase 2: Engine Layer — SDL2 封装 + javidx9 生命周期

### Task 2.1: Engine 基类

**Files:**
- Create: `src/engine/Engine.h`

- [ ] **Step 1: 写 Engine.h**

```cpp
// src/engine/Engine.h
#pragma once

// 吸收自 javidx9 olcConsoleGameEngine 的简洁生命周期设计。
// 所有游戏模块继承此类，遵循 OnCreate → OnUpdate(dT) → OnDestroy 模式。
class Engine {
public:
    virtual ~Engine() = default;

    // 初始化资源。返回 true 表示成功。
    virtual bool OnCreate() { return true; }

    // 每帧更新。dT = 固定时间步长（1/60秒）。
    virtual bool OnUpdate(float dT) = 0;

    // 释放资源。
    virtual void OnDestroy() {}
};
```

- [ ] **Step 2: 验证编译**

```powershell
cmake --build build
```

- [ ] **Step 3: Commit**

```bash
git add src/engine/Engine.h
git commit -m "feat(engine): Engine base class with javidx9 lifecycle pattern"
```

### Task 2.2: Renderer — SDL2 渲染封装

**Files:**
- Create: `src/engine/Renderer.h`
- Create: `src/engine/Renderer.cpp`

- [ ] **Step 1: 写 Renderer.h**

```cpp
// src/engine/Renderer.h
#pragma once
#include "SDL2/SDL.h"
#include <string>

class Renderer {
public:
    Renderer(SDL_Window* window, int logicalWidth, int logicalHeight);
    ~Renderer();

    // 获取原始 SDL_Renderer（供高级操作用）
    SDL_Renderer* getSDLRenderer() const { return sdlRenderer; }

    // 核心渲染操作
    void clear(int r, int g, int b, int a = 255);
    void present();

    // 绘制到逻辑纹理（离屏渲染目标）
    void setRenderTargetToScreen();
    void clearScreen();
    void copyScreenToWindow();

    // 基本图元
    void drawVerticalLine(int x, int yTop, int height, int r, int g, int b, int a = 255);
    void fillRect(int x, int y, int w, int h, int r, int g, int b, int a = 255);
    void drawTexture(SDL_Texture* tex, const SDL_Rect* src, const SDL_Rect* dst);

    // 尺寸
    int getLogicalWidth() const { return logicalWidth; }
    int getLogicalHeight() const { return logicalHeight; }

private:
    SDL_Renderer* sdlRenderer = nullptr;
    SDL_Texture* screenTexture = nullptr; // 离屏渲染目标
    int logicalWidth, logicalHeight;
};
```

- [ ] **Step 2: 写 Renderer.cpp**

```cpp
// src/engine/Renderer.cpp
#include "Renderer.h"

Renderer::Renderer(SDL_Window* window, int logicalWidth, int logicalHeight)
    : logicalWidth(logicalWidth), logicalHeight(logicalHeight)
{
    sdlRenderer = SDL_CreateRenderer(window, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_TARGETTEXTURE | SDL_RENDERER_PRESENTVSYNC);
    if (sdlRenderer) {
        SDL_SetRenderDrawBlendMode(sdlRenderer, SDL_BLENDMODE_BLEND);
        screenTexture = SDL_CreateTexture(sdlRenderer,
            SDL_PIXELFORMAT_ABGR8888, SDL_TEXTUREACCESS_TARGET,
            logicalWidth, logicalHeight);
        if (screenTexture) {
            SDL_SetTextureBlendMode(screenTexture, SDL_BLENDMODE_BLEND);
        }
    }
}

Renderer::~Renderer() {
    if (screenTexture) { SDL_DestroyTexture(screenTexture); screenTexture = nullptr; }
    if (sdlRenderer) { SDL_DestroyRenderer(sdlRenderer); sdlRenderer = nullptr; }
}

void Renderer::clear(int r, int g, int b, int a) {
    SDL_SetRenderDrawColor(sdlRenderer, r, g, b, a);
    SDL_RenderClear(sdlRenderer);
}

void Renderer::present() {
    SDL_RenderPresent(sdlRenderer);
}

void Renderer::setRenderTargetToScreen() {
    SDL_SetRenderTarget(sdlRenderer, screenTexture);
}

void Renderer::clearScreen() {
    SDL_SetRenderDrawColor(sdlRenderer, 0, 0, 0, 0);
    SDL_RenderClear(sdlRenderer);
}

void Renderer::copyScreenToWindow() {
    SDL_SetRenderTarget(sdlRenderer, nullptr);
    SDL_RenderCopy(sdlRenderer, screenTexture, nullptr, nullptr);
}

void Renderer::drawVerticalLine(int x, int yTop, int height, int r, int g, int b, int a) {
    SDL_SetRenderDrawColor(sdlRenderer, r, g, b, a);
    SDL_Rect rect = { x, yTop, 1, height };
    SDL_RenderFillRect(sdlRenderer, &rect);
}

void Renderer::fillRect(int x, int y, int w, int h, int r, int g, int b, int a) {
    SDL_SetRenderDrawColor(sdlRenderer, r, g, b, a);
    SDL_Rect rect = { x, y, w, h };
    SDL_RenderFillRect(sdlRenderer, &rect);
}

void Renderer::drawTexture(SDL_Texture* tex, const SDL_Rect* src, const SDL_Rect* dst) {
    SDL_RenderCopy(sdlRenderer, tex, src, dst);
}
```

- [ ] **Step 3: Commit**

```bash
git add src/engine/Renderer.h src/engine/Renderer.cpp
git commit -m "feat(engine): Renderer — SDL2 render abstraction with offscreen target"
```

### Task 2.3: Input — 键盘鼠标抽象

**Files:**
- Create: `src/engine/Input.h`
- Create: `src/engine/Input.cpp`

- [ ] **Step 1: 写 Input.h**

```cpp
// src/engine/Input.h
#pragma once
#include "SDL2/SDL.h"

// 键盘/鼠标输入抽象。每帧开始时调用 poll()，然后读取状态。
class Input {
public:
    void poll(bool& running, int windowWidth, int windowHeight);

    // 按键状态
    bool keyHeld(SDL_Scancode key) const;
    bool keyPressed(SDL_Scancode key) const;

    // 移动输入
    float moveForward() const;   // W/S → +1 / -1
    float moveRight() const;     // D/A → +1 / -1
    float turnAmount() const;    // 鼠标X偏移 / 窗口宽度
    float mouseDeltaX() const;

    // 射击/功能
    bool shootHeld() const;
    bool reloadPressed() const;
    bool quitPressed() const;

    // 鼠标按钮状态
    int mouseButtonDown() const { return mouseDownStatus; }

private:
    const Uint8* keyboardState = nullptr;
    int mouseXOffset = 0;
    int mouseDownStatus = 0;
    bool reloadWasPressed = false;
};

// 内联实现
inline bool Input::keyHeld(SDL_Scancode key) const {
    return keyboardState && keyboardState[key];
}

inline bool Input::quitPressed() const {
    return keyHeld(SDL_SCANCODE_ESCAPE);
}

inline float Input::moveForward() const {
    float v = 0.0f;
    if (keyHeld(SDL_SCANCODE_W)) v += 1.0f;
    if (keyHeld(SDL_SCANCODE_S)) v -= 1.0f;
    return v;
}

inline float Input::moveRight() const {
    float v = 0.0f;
    if (keyHeld(SDL_SCANCODE_D)) v += 1.0f;
    if (keyHeld(SDL_SCANCODE_A)) v -= 1.0f;
    return v;
}

inline float Input::turnAmount() const {
    return mouseXOffset / 960.0f; // 归一化
}

inline float Input::mouseDeltaX() const {
    return static_cast<float>(mouseXOffset);
}

inline bool Input::shootHeld() const {
    return mouseDownStatus == SDL_BUTTON_LEFT;
}

inline bool Input::reloadPressed() const {
    return keyHeld(SDL_SCANCODE_R);
}
```

- [ ] **Step 2: 写 Input.cpp**

```cpp
// src/engine/Input.cpp
#include "Input.h"

void Input::poll(bool& running, int windowWidth, int windowHeight) {
    (void)windowWidth;
    (void)windowHeight;

    mouseXOffset = 0;
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
        case SDL_QUIT:
            running = false;
            break;
        case SDL_MOUSEBUTTONDOWN:
            if (event.button.button == SDL_BUTTON_LEFT)
                mouseDownStatus = SDL_BUTTON_LEFT;
            else if (event.button.button == SDL_BUTTON_RIGHT)
                mouseDownStatus = SDL_BUTTON_RIGHT;
            break;
        case SDL_MOUSEBUTTONUP:
            mouseDownStatus = 0;
            break;
        case SDL_KEYDOWN:
            if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE)
                running = false;
            break;
        }
    }

    int mx;
    SDL_GetRelativeMouseState(&mx, nullptr);
    mouseXOffset = mx;

    keyboardState = SDL_GetKeyboardState(nullptr);
}
```

- [ ] **Step 3: Commit**

```bash
git add src/engine/Input.h src/engine/Input.cpp
git commit -m "feat(engine): Input — keyboard/mouse abstraction with WASD + mouse look"
```

### Task 2.4: ResourceCache — 纹理/音效/字体统一管理

**Files:**
- Create: `src/engine/ResourceCache.h`
- Create: `src/engine/ResourceCache.cpp`

- [ ] **Step 1: 写 ResourceCache.h**

```cpp
// src/engine/ResourceCache.h
#pragma once
#include <string>
#include <unordered_map>
#include "SDL2/SDL.h"
#include "SDL2_mixer/SDL_mixer.h"
#include "SDL2/SDL_ttf.h"

class ResourceCache {
public:
    ResourceCache(SDL_Renderer* renderer);
    ~ResourceCache();

    // 纹理（从 assets/images/ 加载）
    SDL_Texture* getTexture(const std::string& filename);

    // 音效（从 assets/sounds/ 加载）
    Mix_Chunk* getSound(const std::string& filename);

    // 字体（中文优先）
    TTF_Font* getFont(int size = 12);

private:
    SDL_Renderer* renderer;
    std::unordered_map<std::string, SDL_Texture*> textures;
    std::unordered_map<std::string, Mix_Chunk*> sounds;
    TTF_Font* font = nullptr;
};
```

- [ ] **Step 2: 写 ResourceCache.cpp**

```cpp
// src/engine/ResourceCache.cpp
#include "ResourceCache.h"
#include <iostream>
#include <vector>

ResourceCache::ResourceCache(SDL_Renderer* renderer) : renderer(renderer) {
    // 初始化字体
    if (TTF_WasInit() == 0) {
        if (TTF_Init() != 0) {
            std::cout << "Error: TTF_Init = " << TTF_GetError() << std::endl;
        }
    }

    std::vector<std::string> fontPaths = {
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/msyhbd.ttc",
        "C:/Windows/Fonts/simhei.ttf",
        "C:/Windows/Fonts/simsun.ttc",
        "assets/fonts/NotoSansSC-Regular.otf"
    };

    for (const auto& path : fontPaths) {
        font = TTF_OpenFont(path.c_str(), 12);
        if (font) break;
    }

    if (!font) {
        std::cout << "Warning: No Chinese-capable font loaded\n";
    }
}

ResourceCache::~ResourceCache() {
    for (auto& [_, tex] : textures) {
        if (tex) SDL_DestroyTexture(tex);
    }
    for (auto& [_, chunk] : sounds) {
        if (chunk) Mix_FreeChunk(chunk);
    }
    if (font) TTF_CloseFont(font);
}

SDL_Texture* ResourceCache::getTexture(const std::string& filename) {
    auto it = textures.find(filename);
    if (it != textures.end()) return it->second;

    std::string path = "assets/images/" + filename;
    SDL_Surface* surface = SDL_LoadBMP(path.c_str());
    if (!surface) {
        std::cout << "Error loading texture: " << path << " = " << SDL_GetError() << std::endl;
        return nullptr;
    }

    SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, surface);
    SDL_FreeSurface(surface);

    if (texture) textures[filename] = texture;
    return texture;
}

Mix_Chunk* ResourceCache::getSound(const std::string& filename) {
    auto it = sounds.find(filename);
    if (it != sounds.end()) return it->second;

    std::string path = "assets/sounds/" + filename;
    Mix_Chunk* chunk = Mix_LoadWAV(path.c_str());
    if (!chunk) {
        std::cout << "Error loading sound: " << path << " = " << Mix_GetError() << std::endl;
        return nullptr;
    }

    sounds[filename] = chunk;
    return chunk;
}

TTF_Font* ResourceCache::getFont(int size) {
    (void)size;
    return font;
}
```

- [ ] **Step 3: Commit**

```bash
git add src/engine/ResourceCache.h src/engine/ResourceCache.cpp
git commit -m "feat(engine): ResourceCache — unified texture/sound/font cache"
```

### Task 2.5: Audio — 音效播放封装

**Files:**
- Create: `src/engine/Audio.h`
- Create: `src/engine/Audio.cpp`

- [ ] **Step 1: 写 Audio.h**

```cpp
// src/engine/Audio.h
#pragma once
#include "SDL2_mixer/SDL_mixer.h"

class Audio {
public:
    static bool init();
    static void shutdown();

    // 播放音效。返回 channel ID。
    static int playSound(Mix_Chunk* chunk);

    // 3D 空间化音效（基于角度和距离）
    static void set3DPosition(int channel, int angleDeg, int distance);
};
```

- [ ] **Step 2: 写 Audio.cpp**

```cpp
// src/engine/Audio.cpp
#include "Audio.h"
#include <iostream>

bool Audio::init() {
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 1024) < 0) {
        std::cout << "Error: Mix_OpenAudio = " << Mix_GetError() << std::endl;
        return false;
    }
    Mix_AllocateChannels(32);
    std::cout << "Audio driver = " << SDL_GetCurrentAudioDriver() << std::endl;
    return true;
}

void Audio::shutdown() {
    Mix_CloseAudio();
}

int Audio::playSound(Mix_Chunk* chunk) {
    if (!chunk) return -1;
    return Mix_PlayChannel(-1, chunk, 0);
}

void Audio::set3DPosition(int channel, int angleDeg, int distance) {
    Mix_SetPosition(channel, angleDeg, distance);
}
```

- [ ] **Step 3: Commit**

```bash
git add src/engine/Audio.h src/engine/Audio.cpp
git commit -m "feat(engine): Audio — SDL2_mixer wrapper with 3D spatialization"
```

---

## Phase 3: Framework Layer — 游戏框架

### Task 3.1: Scene — 场景基类 + 栈管理

**Files:**
- Create: `src/framework/Scene.h`
- Create: `src/framework/Scene.cpp`

- [ ] **Step 1: 写 Scene.h**

```cpp
// src/framework/Scene.h
#pragma once
#include <vector>
#include <memory>

class Scene {
public:
    virtual ~Scene() = default;

    virtual void OnEnter() {}
    virtual void OnUpdate(float dT) = 0;
    virtual void OnRender() = 0;
    virtual void OnExit() {}

    bool isActive() const { return active; }
    void setActive(bool a) { active = a; }

private:
    bool active = true;
};

// 场景管理器 — 简单的栈式管理
class SceneManager {
public:
    void pushScene(std::unique_ptr<Scene> scene);
    void popScene();
    Scene* currentScene();

private:
    std::vector<std::unique_ptr<Scene>> scenes;
};
```

- [ ] **Step 2: 写 Scene.cpp**

```cpp
// src/framework/Scene.cpp
#include "Scene.h"

void SceneManager::pushScene(std::unique_ptr<Scene> scene) {
    if (!scenes.empty()) scenes.back()->OnExit();
    scenes.push_back(std::move(scene));
    scenes.back()->OnEnter();
}

void SceneManager::popScene() {
    if (!scenes.empty()) {
        scenes.back()->OnExit();
        scenes.pop_back();
    }
    if (!scenes.empty()) scenes.back()->OnEnter();
}

Scene* SceneManager::currentScene() {
    return scenes.empty() ? nullptr : scenes.back().get();
}
```

- [ ] **Step 3: Commit**

```bash
git add src/framework/Scene.h src/framework/Scene.cpp
git commit -m "feat(framework): Scene — scene base class with stack management"
```

### Task 3.2: GameLoop — 固定时间步长主循环

**Files:**
- Create: `src/framework/GameLoop.h`
- Create: `src/framework/GameLoop.cpp`

- [ ] **Step 1: 写 GameLoop.h**

```cpp
// src/framework/GameLoop.h
#pragma once
#include <chrono>

class SceneManager;

class GameLoop {
public:
    GameLoop(SceneManager& sceneManager, float targetFPS = 60.0f);
    void run();

private:
    SceneManager& sceneManager;
    float dT; // 固定时间步长 = 1/targetFPS
};
```

- [ ] **Step 2: 写 GameLoop.cpp**

```cpp
// src/framework/GameLoop.cpp
#include "GameLoop.h"
#include "Scene.h"

GameLoop::GameLoop(SceneManager& sm, float targetFPS)
    : sceneManager(sm), dT(1.0f / targetFPS) {}

void GameLoop::run() {
    auto time1 = std::chrono::system_clock::now();

    bool running = true;
    while (running) {
        auto time2 = std::chrono::system_clock::now();
        std::chrono::duration<float> delta = time2 - time1;
        float elapsed = delta.count();

        if (elapsed >= dT) {
            time1 = time2;

            Scene* scene = sceneManager.currentScene();
            if (scene && scene->isActive()) {
                scene->OnUpdate(dT);
                scene->OnRender();
            } else {
                running = false;
            }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/framework/GameLoop.h src/framework/GameLoop.cpp
git commit -m "feat(framework): GameLoop — fixed timestep game loop at 60 FPS"
```

---

## Phase 4: Game Components — 纯数据

### Task 4.1: Transform, Health, WeaponComponent

**Files:**
- Create: `src/game/components/Transform.h`
- Create: `src/game/components/Health.h`
- Create: `src/game/components/WeaponComponent.h`
- Create: `tests/unit/test_weapon.cpp`

- [ ] **Step 1: 写 Transform.h**

```cpp
// src/game/components/Transform.h
#pragma once
#include "../../math/Vector2D.h"

struct Transform {
    Vector2D position;
    float angle = 0.0f; // 朝向（弧度）

    Transform() = default;
    Transform(Vector2D pos, float ang = 0.0f) : position(pos), angle(ang) {}
};
```

- [ ] **Step 2: 写 Health.h**

```cpp
// src/game/components/Health.h
#pragma once

struct Health {
    int current;
    int max;

    Health(int maxHP) : current(maxHP), max(maxHP) {}

    bool isAlive() const { return current > 0; }
    bool isFull() const { return current == max; }

    void damage(int amount) {
        if (amount > 0) {
            current -= amount;
            if (current < 0) current = 0;
        }
    }

    void heal(int amount) {
        if (amount > 0) {
            current += amount;
            if (current > max) current = max;
        }
    }

    std::string toString() const {
        if (isFull()) return "满血";
        return std::to_string(current);
    }
};
```

- [ ] **Step 3: 写 WeaponComponent.h（含换弹状态机）**

```cpp
// src/game/components/WeaponComponent.h
#pragma once
#include <string>
#include <algorithm>

// 武器数据 + 换弹状态机（从 MyObject/FPS 移植增强）
struct WeaponComponent {
    // 弹药系统
    int ammoClip = 30;       // 当前弹夹
    int ammoReserve = 90;    // 备弹
    int clipSize = 30;       // 弹夹容量
    int damage = 1;          // 每发伤害

    // 射击
    float fireRate = 0.1f;        // 射击间隔（秒）
    float cooldownTimer = 0.0f;   // 冷却计时

    // 换弹
    float reloadTime = 2.0f;      // 换弹时间（秒）
    float reloadTimer = 0.0f;     // 换弹计时
    bool isReloading = false;     // 换弹中

    // 子弹
    float bulletSpeed = 20.0f;
    float bulletRange = 20.0f;

    // --- 查询 ---
    bool canShoot() const {
        return !isReloading && ammoClip > 0 && cooldownTimer <= 0.0f;
    }

    bool isAmmoFull() const { return ammoClip == clipSize; }
    bool needsReload() const { return !isReloading && ammoClip < clipSize && ammoReserve > 0; }
    float reloadProgress() const {
        return isReloading ? (reloadTimer / reloadTime) : 0.0f;
    }

    std::string ammoString() const {
        return std::to_string(ammoClip) + "/" + std::to_string(ammoReserve);
    }

    // --- 动作 ---
    void startReload() {
        if (needsReload()) {
            isReloading = true;
            reloadTimer = 0.0f;
        }
    }

    void update(float dT) {
        // 射击冷却
        if (cooldownTimer > 0.0f) {
            cooldownTimer -= dT;
        }

        // 换弹计时
        if (isReloading) {
            reloadTimer += dT;
            if (reloadTimer >= reloadTime) {
                int needed = clipSize - ammoClip;
                int transfer = std::min(needed, ammoReserve);
                ammoClip += transfer;
                ammoReserve -= transfer;
                isReloading = false;
            }
        }
    }

    void fire() {
        if (!canShoot()) return;
        ammoClip--;
        cooldownTimer = fireRate;
        // 如果打空自动换弹
        if (ammoClip == 0 && ammoReserve > 0) {
            startReload();
        }
    }

    void addAmmo(int amount) {
        if (amount > 0) ammoReserve += amount;
    }

    void upgradeClipSize(int amount) { clipSize += amount; }
    void upgradeFireRate(int amount) {
        fireRate = std::max(0.05f, fireRate - amount * 0.02f);
    }
};
```

- [ ] **Step 4: 写换弹单元测试**

```cpp
// tests/unit/test_weapon.cpp
#include <cassert>
#include <iostream>
#include "../../src/game/components/WeaponComponent.h"

int testsPassed = 0, testsFailed = 0;
#define CHECK(cond) do { \
    if (!(cond)) { std::cerr << "FAIL: " << #cond << " line " << __LINE__ << "\n"; testsFailed++; } \
    else testsPassed++; \
} while(0)

void test_initial_state() {
    WeaponComponent w;
    CHECK(w.ammoClip == 30);
    CHECK(w.ammoReserve == 90);
    CHECK(w.isReloading == false);
    CHECK(w.canShoot() == true);
}

void test_fire_reduces_ammo() {
    WeaponComponent w;
    w.fire();
    CHECK(w.ammoClip == 29);
}

void test_fire_cooldown() {
    WeaponComponent w;
    w.fire();
    CHECK(w.canShoot() == false);
    w.update(1.0f); // 远超 fireRate
    CHECK(w.canShoot() == true);
}

void test_reload_trigger() {
    WeaponComponent w;
    w.ammoClip = 5;
    w.startReload();
    CHECK(w.isReloading == true);
    CHECK(w.reloadTimer == 0.0f);
}

void test_reload_complete() {
    WeaponComponent w;
    w.ammoClip = 5;
    w.ammoReserve = 50;
    w.startReload();
    w.update(3.0f); // 超过 reloadTime
    CHECK(w.isReloading == false);
    CHECK(w.ammoClip == 30); // 弹夹补满
    CHECK(w.ammoReserve == 25); // 消耗25发
}

void test_auto_reload_on_empty() {
    WeaponComponent w;
    w.ammoClip = 1;
    w.ammoReserve = 30;
    w.fire(); // 清空弹夹
    CHECK(w.isReloading == true); // 自动换弹
}

void test_no_reload_when_full() {
    WeaponComponent w;
    w.startReload();
    CHECK(w.isReloading == false); // 弹夹满不换
}

void test_cant_shoot_while_reloading() {
    WeaponComponent w;
    w.ammoClip = 5;
    w.startReload();
    CHECK(w.canShoot() == false);
}

void test_reload_progress() {
    WeaponComponent w;
    w.ammoClip = 5;
    w.startReload();
    w.update(1.0f); // 一半时间
    CHECK(w.reloadProgress() > 0.4f);
    CHECK(w.reloadProgress() < 0.6f);
}

int main() {
    test_initial_state();
    test_fire_reduces_ammo();
    test_fire_cooldown();
    test_reload_trigger();
    test_reload_complete();
    test_auto_reload_on_empty();
    test_no_reload_when_full();
    test_cant_shoot_while_reloading();
    test_reload_progress();

    std::cout << "Passed: " << testsPassed << ", Failed: " << testsFailed << "\n";
    return testsFailed > 0 ? 1 : 0;
}
```

- [ ] **Step 5: 运行测试**

```powershell
clang++ -std=c++17 tests/unit/test_weapon.cpp -o build/test_weapon.exe; ./build/test_weapon.exe
```

预期: `Passed: 9, Failed: 0`

- [ ] **Step 6: Commit**

```bash
git add src/game/components/Transform.h src/game/components/Health.h src/game/components/WeaponComponent.h tests/unit/test_weapon.cpp
git commit -m "feat(game): components — Transform, Health, WeaponComponent with reload state machine"
```

---

## Phase 5: Game Level + Entities + Systems

### Task 5.1: Level — 关卡数据（从 src-legacy 迁移）

**Files:**
- Create: `src/game/Level.h`
- Create: `src/game/Level.cpp`

- [ ] **Step 1: 写 Level.h**

```cpp
// src/game/Level.h
#pragma once
#include <memory>
#include <vector>
#include "SDL2/SDL.h"
#include "../math/Vector2D.h"

class Enemy;
class Pickup;

class Level {
public:
    static constexpr int width = 168;
    static constexpr int height = 68;

    static bool isWall(int x, int y);
    static bool isWall(Vector2D pos);
    static const char* data();

    // 关卡加载
    static void load(SDL_Renderer* renderer,
        Vector2D& startPos, Vector2D& finishPos,
        std::vector<std::shared_ptr<Enemy>>& enemies,
        std::vector<std::shared_ptr<Pickup>>& pickups);

    // 符号常量
    static constexpr char WALL = 'X';
    static constexpr char START = 'S';
    static constexpr char FINISH = 'F';
    static constexpr char HEALTH = 'H';
    static constexpr char COIN = 'C';
    static constexpr char AMMO = 'A';
    static constexpr char UPGRADE_HEALTH = 'h';
    static constexpr char UPGRADE_AMMO = 'a';
    static constexpr char UPGRADE_SPEED = 'w';
    static constexpr char ENEMY_SMALL = '0';
    static constexpr char ENEMY_MEDIUM = '1';
    static constexpr char ENEMY_LARGE = '2';

private:
    static const char* levelData;
    static const int levelWidth;
    static const size_t levelSize;
};
```

- [ ] **Step 2: 写 Level.cpp（从 src-legacy/Level.cpp 迁移 levelData）**

从 `src-legacy/Level.cpp` 复制完整的 `levelData` 字符串和 `setupAllEnemiesAndPickups` 逻辑。代码太长此处略，但完整迁移。

- [ ] **Step 3: Commit**

```bash
git add src/game/Level.h src/game/Level.cpp
git commit -m "feat(game): Level — map data migrated from src-legacy with wall collision"
```

### Task 5.2: Player — 玩家实体

**Files:**
- Create: `src/game/entities/Player.h`
- Create: `src/game/entities/Player.cpp`

- [ ] **Step 1: 写 Player.h**

```cpp
// src/game/entities/Player.h
#pragma once
#include "../components/Transform.h"
#include "../components/Health.h"
#include "../components/WeaponComponent.h"
#include "../../math/Vector2D.h"
#include <memory>
#include <vector>

class Projectile;
class SDL_Renderer;

class Player {
public:
    Player(Vector2D startPos);

    void update(float dT);
    void shoot(std::vector<std::shared_ptr<Projectile>>& projectiles, SDL_Renderer* renderer);

    // 移动输入
    void setMoveForward(float v) { moveForward = v; }
    void setMoveRight(float v) { moveRight = v; }
    void setTurn(float v) { turnAmount = v; }

    // 组件访问
    Transform transform;
    Health health{20};
    WeaponComponent weapon;

    // 资源
    int coins = 0;

    // 碰撞半径
    static constexpr float COLLISION_RADIUS = 0.35f;

    // 常量
    static constexpr float SPEED_MOVE = 7.0f;
    static constexpr float SPEED_TURN = 2.0f;

private:
    float moveForward = 0.0f;
    float moveRight = 0.0f;
    float turnAmount = 0.0f;
};
```

- [ ] **Step 2: 写 Player.cpp**

```cpp
// src/game/entities/Player.cpp
#include "Player.h"
#include "Projectile.h"
#include "../Level.h"
#include <cmath>

Player::Player(Vector2D startPos) {
    transform.position = startPos;
}

void Player::update(float dT) {
    // 转向
    transform.angle += turnAmount * SPEED_TURN;
    if (transform.angle > 2.0f * MathAddon::PI)
        transform.angle -= 2.0f * MathAddon::PI;
    else if (transform.angle < 0.0f)
        transform.angle += 2.0f * MathAddon::PI;

    // 移动方向计算
    Vector2D moveDir;
    if (moveForward != 0.0f)
        moveDir += Vector2D(transform.angle) * (moveForward > 0 ? 1.0f : -1.0f);
    if (moveRight != 0.0f)
        moveDir += Vector2D(transform.angle).getNegativeReciprocal() * (moveRight > 0 ? 1.0f : -1.0f);
    moveDir.normalize();

    Vector2D delta = moveDir * SPEED_MOVE * dT;
    const float spacing = COLLISION_RADIUS;

    // X 轴碰撞检测
    if (delta.x != 0.0f && !Level::isWall(
        (int)(transform.position.x + delta.x + std::copysign(spacing, delta.x)),
        (int)(transform.position.y)))
        transform.position.x += delta.x;

    // Y 轴碰撞检测
    if (delta.y != 0.0f && !Level::isWall(
        (int)(transform.position.x),
        (int)(transform.position.y + delta.y + std::copysign(spacing, delta.y))))
        transform.position.y += delta.y;

    // 重置输入
    moveForward = 0.0f;
    moveRight = 0.0f;
    turnAmount = 0.0f;

    // 更新武器
    weapon.update(dT);
}

void Player::shoot(std::vector<std::shared_ptr<Projectile>>& projectiles, SDL_Renderer* renderer) {
    if (!weapon.canShoot()) return;
    weapon.fire();
    // 子弹创建由 CombatSystem 处理
}
```

- [ ] **Step 3: Commit**

```bash
git add src/game/entities/Player.h src/game/entities/Player.cpp
git commit -m "feat(game): Player entity — component-based with collision detection"
```

### Task 5.3: Enemy + Projectile 实体

简化实现（从 src-legacy 迁移逻辑，适配新组件结构）:

- [ ] **Step 1: Enemy.h/cpp** — Transform + Health + WeaponComponent + 模板数据
- [ ] **Step 2: Projectile.h/cpp** — Transform + 移动 + 碰撞检测
- [ ] **Step 3: 各 Pickup 子类** — Health/Coin/Ammo/UpgradeHealth/UpgradeAmmo/UpgradeWeaponSpeed

（此处为避免过度冗长，实体类代码从 src-legacy 对应文件迁移，改为使用 Transform/Health 组件。）

- [ ] **Step 4: Commit**

```bash
git add src/game/entities/
git commit -m "feat(game): Enemy, Projectile, Pickup entities migrated to component system"
```

---

## Phase 6: Game Systems — 逻辑处理器

### Task 6.1: MovementSystem

**Files:**
- Create: `src/game/systems/MovementSystem.h`
- Create: `src/game/systems/MovementSystem.cpp`

- [ ] **Step 1: 写 MovementSystem.h**

```cpp
// src/game/systems/MovementSystem.h
#pragma once
#include <memory>
#include <vector>

class Player;
class Enemy;

class MovementSystem {
public:
    void updatePlayer(Player& player, float dT);
    void updateEnemies(std::vector<std::shared_ptr<Enemy>>& enemies, float dT, Player& player);
};
```

- [ ] **Step 2: 写 MovementSystem.cpp** — 调用 Player::update() 和 Enemy 移动逻辑

- [ ] **Step 3: Commit**

### Task 6.2: CombatSystem

- [ ] **Step 1: 写 CombatSystem.h/cpp** — 处理射击、子弹飞行、碰撞、伤害

### Task 6.3: PickupSystem

- [ ] **Step 1: 写 PickupSystem.h/cpp** — 处理拾取物碰撞检测和效果应用

### Task 6.4: ReloadSystem

**Files:**
- Create: `src/game/systems/ReloadSystem.h`
- Create: `src/game/systems/ReloadSystem.cpp`

- [ ] **Step 1: 写 ReloadSystem.h**

```cpp
// src/game/systems/ReloadSystem.h
#pragma once
#include "../components/WeaponComponent.h"

class Input;

class ReloadSystem {
public:
    void update(WeaponComponent& weapon, const Input& input);
};
```

- [ ] **Step 2: 写 ReloadSystem.cpp**

```cpp
// src/game/systems/ReloadSystem.cpp
#include "ReloadSystem.h"
#include "../../engine/Input.h"

void ReloadSystem::update(WeaponComponent& weapon, const Input& input) {
    if (input.reloadPressed() && weapon.needsReload()) {
        weapon.startReload();
    }
}
```

- [ ] **Step 3: Commit**

### Task 6.5: RenderSystem — 光线投射 + 精灵渲染

**Files:**
- Create: `src/game/systems/RenderSystem.h`
- Create: `src/game/systems/RenderSystem.cpp`

这是最大的系统，整合 Game.cpp 中的所有渲染逻辑：
- `drawWalls()` — 光线投射竖线绘制（从 src-legacy/Game.cpp:487 迁移）
- `raycast()` — DDA 光线投射算法（从 src-legacy/Game.cpp:372 迁移）
- `drawSprites()` — 精灵深度排序渲染（从 src-legacy/Game.cpp:528-576 迁移）
- `drawHUD()` — 中文 HUD（弹药、血量、硬币、准星）
- `drawReloadBar()` — 换弹进度条（新增）
- `drawText()` — UTF-8 中文文字渲染（从 src-legacy/Game.cpp:580 迁移）

- [ ] **Step 1: 写 RenderSystem.h/cpp** — 完整渲染系统
- [ ] **Step 2: Commit**

```bash
git add src/game/systems/
git commit -m "feat(game): Systems — Movement, Combat, Pickup, Reload, Render"
```

---

## Phase 7: main.cpp — 组装一切

### Task 7.1: 主入口

**Files:**
- Create: `src/main.cpp`

- [ ] **Step 1: 写 main.cpp**

```cpp
// src/main.cpp
#include <iostream>
#include "SDL2/SDL.h"
#include "engine/Renderer.h"
#include "engine/Input.h"
#include "engine/Audio.h"
#include "engine/ResourceCache.h"
#include "framework/GameLoop.h"
#include "framework/Scene.h"
#include "game/Level.h"
#include "game/entities/Player.h"
#include "game/entities/Enemy.h"
#include "game/entities/Projectile.h"
#include "game/systems/MovementSystem.h"
#include "game/systems/CombatSystem.h"
#include "game/systems/PickupSystem.h"
#include "game/systems/ReloadSystem.h"
#include "game/systems/RenderSystem.h"

// FPS 游戏场景
class GameScene : public Scene {
public:
    GameScene(SDL_Window* window, Renderer& renderer, ResourceCache& cache)
        : renderer(renderer), cache(cache)
    {
        // 获取窗口大小
        SDL_GetWindowSize(window, &windowW, &windowH);

        // 设置鼠标相对模式
        SDL_SetRelativeMouseMode(SDL_TRUE);

        // 加载关卡
        Level::load(renderer.getSDLRenderer(), startPos, finishPos, enemies, pickups);
        player = std::make_unique<Player>(startPos);
    }

    void OnUpdate(float dT) override {
        // 输入轮询
        bool running = true;
        input.poll(running, windowW, windowH);

        // 移动
        player->setMoveForward(input.moveForward());
        player->setMoveRight(input.moveRight());
        player->setTurn(input.turnAmount());
        movementSystem.updatePlayer(*player, dT);

        // 射击
        if (input.shootHeld()) {
            combatSystem.playerShoot(*player, projectiles, renderer.getSDLRenderer());
        }

        // 换弹
        reloadSystem.update(player->weapon, input);

        // 敌人更新
        movementSystem.updateEnemies(enemies, dT, *player);
        combatSystem.updateEnemies(enemies, dT, *player, projectiles, renderer.getSDLRenderer());

        // 拾取物
        pickupSystem.update(pickups, *player);

        // 子弹更新
        combatSystem.updateProjectiles(projectiles, dT, player, enemies);

        // 检查胜利/失败
        if (!player->health.isAlive()) {
            gameState = GameState::DEFEAT;
        }
        // 检查旗标碰撞...
    }

    void OnRender() override {
        renderer.clear(0, 0, 92, 255); // 天花板颜色
        renderer.setRenderTargetToScreen();
        renderer.clearScreen();

        renderSystem.drawWorld(renderer, *player, enemies, pickups, projectiles, startPos, finishPos);
        renderSystem.drawHUD(renderer, *player, cache);

        if (gameState == GameState::DEFEAT) {
            renderSystem.drawOverlay(renderer, cache, "失败！", 255, 0, 0);
        } else if (gameState == GameState::VICTORY) {
            renderSystem.drawOverlay(renderer, cache, "胜利！", 0, 255, 0);
        }

        renderer.copyScreenToWindow();
        renderer.present();
    }

private:
    enum class GameState { PLAYING, VICTORY, DEFEAT };
    GameState gameState = GameState::PLAYING;

    Renderer& renderer;
    ResourceCache& cache;
    Input input;
    int windowW = 0, windowH = 0;

    Vector2D startPos, finishPos;

    std::unique_ptr<Player> player;
    std::vector<std::shared_ptr<Enemy>> enemies;
    std::vector<std::shared_ptr<Pickup>> pickups;
    std::vector<std::shared_ptr<Projectile>> projectiles;

    MovementSystem movementSystem;
    CombatSystem combatSystem;
    PickupSystem pickupSystem;
    ReloadSystem reloadSystem;
    RenderSystem renderSystem;
};

int main(int argc, char* argv[]) {
    srand((unsigned)time(nullptr));

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) {
        std::cout << "SDL_Init Error: " << SDL_GetError() << std::endl;
        return 1;
    }

    if (!Audio::init()) {
        SDL_Quit();
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow(
        "复古FPS v0.2.0",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        960, 540, 0);

    if (!window) {
        std::cout << "Window Error: " << SDL_GetError() << std::endl;
        Audio::shutdown();
        SDL_Quit();
        return 1;
    }

    Renderer renderer(window, 240, 135);
    ResourceCache cache(renderer.getSDLRenderer());

    SceneManager sceneManager;
    sceneManager.pushScene(std::make_unique<GameScene>(window, renderer, cache));

    GameLoop loop(sceneManager);
    loop.run();

    SDL_DestroyWindow(window);
    Audio::shutdown();
    SDL_Quit();
    return 0;
}
```

- [ ] **Step 2: 构建并运行**

```powershell
cmake --build build
./build/RetroFPS.exe
```

- [ ] **Step 3: Commit**

```bash
git add src/main.cpp
git commit -m "feat: main.cpp — assemble all layers, v2.0.0 complete"
```

---

## Phase 8: 视觉增强 — 极致伪3D效果

### Task 8.1: 墙壁纹理采样

增强 RenderSystem::drawWalls，从 BMP 纹理采样而非纯色：

```cpp
// 新增：纹理化墙壁渲染
void RenderSystem::drawTexturedWall(Renderer& renderer, int x, int yTop, int height,
    SDL_Texture* wallTex, float texX, float distance) {
    // 根据距离计算阴影系数
    float shade = 1.0f;
    float fDepth = 16.0f;
    if (distance < fDepth / 4.0f)      shade = 1.0f;
    else if (distance < fDepth / 3.0f) shade = 0.75f;
    else if (distance < fDepth / 2.0f) shade = 0.5f;
    else                               shade = 0.25f;

    // SDL_SetTextureColorMod 实现距离阴影
    int c = (int)(255 * shade);
    SDL_SetTextureColorMod(wallTex, c, c, c);

    SDL_Rect src = { (int)(texX * 63.0f) % 64, 0, 1, 64 };
    SDL_Rect dst = { x, yTop, 1, height };
    SDL_RenderCopy(renderer.getSDLRenderer(), wallTex, &src, &dst);
}
```

### Task 8.2: 视角晃动（View Bobbing）

```cpp
// 在 Player::update 中添加
float viewBobOffset = 0.0f;
void Player::update(float dT) {
    // ... 移动代码 ...

    // 视角晃动
    if (moveForward != 0.0f || moveRight != 0.0f) {
        bobPhase += dT * 10.0f; // 晃动频率
        viewBobOffset = std::sin(bobPhase) * 0.02f; // ±2% 屏幕高度
    } else {
        bobPhase = 0.0f;
        viewBobOffset = viewBobOffset * 0.9f; // 衰减
    }
}
```

### Task 8.3: 受击闪红 + 屏幕震动

```cpp
// Player 受击时
void Player::takeDamage(int damage, float damageAngle) {
    health.damage(damage);
    damageFlashTimer = 0.2f;     // 0.2秒闪红
    screenShakeTimer = 0.15f;    // 0.15秒震动
    screenShakeAmount = 3.0f;    // 3像素震动幅度
    screenShakeAngle = damageAngle;
}

// RenderSystem 中
void RenderSystem::applyDamageEffects(Renderer& renderer, Player& player) {
    if (player.damageFlashTimer > 0.0f) {
        // 红色渐变覆盖
        int alpha = (int)(128 * (player.damageFlashTimer / 0.2f));
        renderer.fillRect(0, 0, renderer.getLogicalWidth(), renderer.getLogicalHeight(),
            255, 0, 0, alpha);
    }
}
```

### Task 8.4: 渐变天空 + 地面

```cpp
void RenderSystem::drawSky(Renderer& renderer) {
    int w = renderer.getLogicalWidth();
    int h = renderer.getLogicalHeight();
    // 天空：从暗蓝渐变到亮蓝
    for (int y = 0; y < h / 2; y++) {
        float t = (float)y / (h / 2);
        int r = (int)(0 * (1 - t) + 135 * t);
        int g = (int)(0 * (1 - t) + 206 * t);
        int b = (int)(92 * (1 - t) + 235 * t);
        renderer.fillRect(0, y, w, 1, r, g, b);
    }
    // 地面：从深灰渐变到浅灰
    for (int y = h / 2; y < h; y++) {
        float t = (float)(y - h / 2) / (h / 2);
        int c = (int)(30 * (1 - t) + 80 * t);
        renderer.fillRect(0, y, w, 1, c, c, c);
    }
}
```

### Task 8.5: 枪口闪光

```cpp
void CombatSystem::playerShoot(Player& player,
    std::vector<std::shared_ptr<Projectile>>& projectiles,
    SDL_Renderer* renderer) {
    if (!player.weapon.canShoot()) return;
    player.weapon.fire();

    // 创建子弹
    Vector2D dir(player.transform.angle);
    projectiles.push_back(std::make_shared<Projectile>(
        player.transform.position, dir, true));

    // 枪口闪光
    muzzleFlashTimer = 0.05f; // 50ms 闪光

    // 播放音效
    // Audio::playSound(cache.getSound("Energy Orb.ogg"));
}
```

### Task 8.6: 小地图

```cpp
void RenderSystem::drawMinimap(Renderer& renderer, Player& player) {
    const int mmW = 40, mmH = 30; // 小地图尺寸
    const int mmX = renderer.getLogicalWidth() - mmW - 4;
    const int mmY = 4;

    // 半透明背景
    renderer.fillRect(mmX, mmY, mmW, mmH, 0, 0, 0, 160);

    // 绘制墙壁点
    for (int y = 0; y < Level::height; y++) {
        for (int x = 0; x < Level::width; x++) {
            if (Level::isWall(x, y)) {
                int mx = mmX + x * mmW / Level::width;
                int my = mmY + y * mmH / Level::height;
                renderer.drawPixel(mx, my, 128, 128, 128, 255); // 灰色墙壁
            }
        }
    }

    // 玩家位置（白点）
    int px = mmX + (int)(player.transform.position.x * mmW / Level::width);
    int py = mmY + (int)(player.transform.position.y * mmH / Level::height);
    renderer.drawPixel(px, py, 255, 255, 255, 255);
}
```

### Task 8.7: 距离雾

```cpp
// 在 drawWalls 中应用雾效
float fogStart = 12.0f;
float fogEnd = 16.0f;
float fogFactor = std::max(0.0f, std::min(1.0f,
    (fogEnd - distance) / (fogEnd - fogStart)));
// fogFactor = 1.0 (无雾) → 0.0 (完全雾)
int fogR = (int)(0 * (1 - fogFactor) + wallR * fogFactor);
int fogG = (int)(0 * (1 - fogFactor) + wallG * fogFactor);
int fogB = (int)(92 * (1 - fogFactor) + wallB * fogFactor); // 雾色=天花板色
```

- [ ] **Step 1: 依次实现每个视觉效果**
- [ ] **Step 2: 每完成一个即 commit**

---

## Phase 9: 最终整合与验证

### Task 9.1: 完整构建验证

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### Task 9.2: 运行测试套件

```powershell
./build/test_vector2d.exe
./build/test_weapon.exe
```

### Task 9.3: 游戏功能清单验证

- [ ] WASD 移动 + 鼠标转动
- [ ] 光线投射墙壁渲染（带纹理 + 距离阴影）
- [ ] 敌人 AI（可见性检测 + 射击）
- [ ] 换弹系统（R键 + 自动换弹 + 进度条）
- [ ] 拾取物（生命/弹药/硬币/升级）
- [ ] 升级系统（血量/弹药/射速）
- [ ] 中文 UI（HUD + 胜利/失败覆盖层）
- [ ] 视角晃动
- [ ] 受击闪红 + 屏幕震动
- [ ] 渐变天空地面
- [ ] 枪口闪光
- [ ] 小地图
- [ ] 距离雾
- [ ] 60 FPS 稳定

### Task 9.4: 标记 v2.0.0

```bash
git tag v0.2.0-alpha
git commit -m "release: Retro FPS v0.2.0-alpha — architecture refactor + features"
```

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 重构导致功能退化 | src-legacy 保留，可随时对比验证 |
| 渲染性能下降 | SDL_Renderer GPU加速保证；Profile 每个 System |
| CMake 跨平台问题 | 保持与 src-legacy 相同的 SDL2 查找方式 |
| 中文渲染失败 | 多级字体回退链；运行时警告而非崩溃 |

---

## 外部资源利用计划

| 资源 | 用途 |
|------|------|
| `Claude-Code-Game-Studios` | Agent 定义模板、编码标准、钩子脚本 |
| `agency-agents/game-development` | 游戏设计/关卡设计 Agent 定义 |
| `AISkills/superpowers` | TDD、brainstorming、code-review 工作流 |
| `MetaGPT` | 多 Agent 协作的 Role/Action 模式参考 |
| `MyObject/FPS/FPS.cpp` | 换弹系统、墙壁阴影算法移植源 |
| GitHub/skillsmp/agentskill.sh | 检索 CI/CD、测试框架等辅助技能 |
