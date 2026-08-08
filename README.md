# Signal Lost

> **信号中断。** 2057 年，远东废墟区。前哨站已与指挥部失联三个月——你是被派入该区域的侦察兵，任务：穿越变异体感染区，找到撤离信标。
>
> *Signal Lost — a retro boomer shooter. Fight through mutant-infested ruins to reach the extraction beacon.*

Signal Lost 是一款复古第一人称射击游戏，仓库内包含**双引擎**实现：SDL2 + C++17 原版，以及采用「真 3D 几何 + 复古呈现层」技术的 Godot 4.6 重制版。节奏快、不刷分、不拖沓——拿枪，向前，活着撤离。

> 开发进度与 AI 协作交接 → [STATUS.md](STATUS.md)

## 世界观与关卡

- **第一关 · 前哨站废墟**：地表感染区。沿途搜集补给，避免恋战，抵达仍在发送信号的撤离信标。
- **第二关 · 地下研究所**：前哨站地下失控的研究设施。主控核心仍在运转，变异体巢穴围绕其分布，大型变异体的攻击远比地表个体致命。

通关条件：抵达撤离信标。死亡即「信号中断」，指挥部将该区域标记为极度危险。

## 操作

| 输入 | 动作 |
| --- | --- |
| WASD | 移动 |
| 鼠标 | 视角 / 瞄准 |
| 左键 | 射击 |
| R | 换弹 |
| Q / 鼠标滚轮 | 切换武器 |
| ESC | 菜单 |

## 武器与拾取

双武器共享备弹池。冲锋枪不再初始持有，需要在场景中拾取获得（每张地图各 1 把）：首次拾取补满弹匣并自动切换，重复拾取转为 30 发备弹。

| 武器 | 类型 | 弹匣 | 获取方式 |
| --- | --- | --- | --- |
| 手枪 | 半自动 | 20 发 | 初始持有 |
| 冲锋枪 | 全自动 | 30 发 | 场景拾取（金色光晕标识） |

| 符号 | 拾取物 | 效果 |
| --- | --- | --- |
| H | 急救包 | 恢复生命 |
| C | 数据芯片 | 升级货币 |
| A | 弹药箱 | 补充后备弹药 |
| h | 纳米强化剂 | 消耗 10 芯片，提升生命上限 |
| a | 扩展弹匣 | 消耗 10 芯片，提升弹药上限 |
| w | 神经加速器 | 消耗 10 芯片，提升射速 |
| W | 冲锋枪 | 获得冲锋枪 |

## 敌人

| 敌人 | 生命 | 定位 |
| --- | --- | --- |
| 变异体 | 80 | 基础个体 |
| 变异体步兵 | 100 | 一线火力 |
| 变异体小 BOSS | 300 | 大型个体，高攻击 |

全武器单发伤害 32。Godot 版每张地图生成 136 个敌人、385 个拾取物。

## 双引擎架构

### Godot 重制版（活跃开发）

路线 B 方案：**真 3D 几何 + 复古呈现层**。

- Godot 4.6，GDScript
- 240×135 低分辨率 SubViewport + 最近邻过滤，还原像素颗粒感
- 距离雾 + billboard 精灵（敌人 / 拾取物），营造 DOOM 式氛围
- 配置驱动：与 C++ 版共用同一套 JSON 数据源（`assets/config/*.json`），关卡由 LevelData 程序化生成，双版本数值同源

### C++ 原版（归档维护）

- SDL2 + C++17，5 层架构
- 127 项单元测试全部通过，零编译警告
- 双地图 / 3 难度 / 完整游戏循环，raycasting 伪 3D 渲染

## 快速开始

### Godot 版（推荐）

1. 安装 Godot 4.6+：`winget install GodotEngine.GodotEngine`
2. 双击 `启动Godot版.bat`

也可以直接在 Godot 编辑器中导入 `godot/` 目录运行。

### C++ 版

- **直接游玩**：运行 `dist-v1.0.1.0/Retro First Person Shooter.exe`（含运行库安装程序）
- **源码构建**：需要 MSVC + CMake + vcpkg

```bat
cmake --build build --config Release --target RetroFPS
启动游戏.bat
```

## 项目结构

```
├── src/              C++ 原版源码（engine / framework / game / math）
├── src-legacy/       历史版本源码存档
├── assets/           C++ 版资产（config / images / sounds）
├── tests/            C++ 单元测试
├── godot/            Godot 重制版（活跃开发）
│   ├── assets/       配置 / 精灵 / 音效（JSON 与 C++ 版同源）
│   ├── scenes/       场景（main / player / entities / weapons / ui / tests）
│   └── scripts/      GDScript（autoload / player / enemies / pickups / levels …）
├── design/           设计文档与规格
├── docs/             开发计划与复盘
├── dist-v1.0.1.0/    C++ 版预构建发行包
├── 启动Godot版.bat    一键启动 Godot 版
├── 启动游戏.bat       一键启动 C++ 版
├── STATUS.md         开发进度实时追踪（AI 交接入口）
└── PROJECT.md        项目全量上下文（协作入口文档）
```

## 测试

```bash
# Godot 版冒烟测试（24 断言：武器持有模型 / 场景拾取 / Q 与滚轮切换 / 金币 / 射击 / 通关）
godot --path godot --headless res://scenes/tests/SmokeTest.tscn

# C++ 版单元测试（127 项）
ctest --test-dir build -C Debug --output-on-failure
```

## 技术栈

Godot 4.6 · GDScript · SDL2 · C++17 · CMake · vcpkg
