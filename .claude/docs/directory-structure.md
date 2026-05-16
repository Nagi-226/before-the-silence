# 目录结构

```text
/
├── CLAUDE.md                    # 主配置 — 入口文档
├── .claude/                     # Agent 定义、技能、钩子、规则、文档
│   ├── agents/                  # 专用子 Agent 定义
│   ├── skills/                  # 项目级自定义技能
│   ├── hooks/                   # 自动化钩子脚本
│   ├── rules/                   # 按文件类型的编码规则
│   └── docs/                    # 技术文档（标准、偏好、规则）
├── src/                         # 游戏源代码
│   ├── engine/                  # 引擎层 — SDL2 封装
│   ├── framework/               # 框架层 — 通用游戏框架
│   ├── game/                    # 游戏层
│   │   ├── components/          # 纯数据组件
│   │   ├── entities/            # 游戏实体
│   │   └── systems/             # 逻辑系统
│   └── math/                    # 数学工具
├── assets/                      # 游戏资源（图像、音频、字体、数据）
│   ├── images/                  # .bmp 精灵与纹理
│   ├── sounds/                  # .ogg 音效
│   └── fonts/                   # 字体文件
├── tests/                       # 测试套件
│   ├── unit/                    # 单元测试
│   └── integration/             # 集成测试
├── tools/                       # 构建和工具链
├── design/                      # 游戏设计文档
│   └── spec/                    # 架构与功能规格
├── prototypes/                  # 废弃原型（与 src/ 隔离）
│   └── MyObject-FPS/            # 引用的javidx9控制台引擎原型
└── production/                  # 项目管理
    ├── session-state/           # 会话状态（gitignored）
    └── session-logs/            # 会话审计日志（gitignored）
```

## 文件命名约定

- **源文件**: PascalCase — `UnitPlayer.cpp`, `Vector2D.h`
- **资源文件**: 含空格原样保留 — `Alien Large.bmp`, `Energy Orb.ogg`
- **测试文件**: `test_<模块名>.cpp`
- **设计文档**: `YYYY-MM-DD-<主题>-design.md`
