# 技术偏好

## 引擎 & 语言

- **引擎**: SDL2（GPU加速渲染器）
- **语言**: C++17
- **渲染**: SDL_Renderer（加速模式 + VSync + BlendMode）
- **音频**: SDL2_mixer（44100Hz, MIX_DEFAULT_FORMAT, 2通道, 1024采样）
- **字体**: SDL2_ttf（UTF-8, 中文优先）

## 输入 & 平台

- **目标平台**: Windows（架构保持跨平台能力）
- **输入方式**: 键盘 + 鼠标
- **主要输入**: 键盘 WASD 移动，鼠标转动视角，鼠标左键射击
- **特殊模式**: SDL_SetRelativeMouseMode（FPS 鼠标捕获）

## 渲染参数

- **内部分辨率**: 240×135（复古风格）
- **目标帧率**: 60 FPS（固定时间步长 dT = 1/60）
- **FOV**: 60°（π/3 弧度）
- **精灵尺寸**: 16×16 像素（标准）
- **视觉风格**: 复古伪3D，光线投射墙壁 + 精灵投影

## 资源格式

| 类型 | 格式 | 加载器 |
|------|------|--------|
| 纹理 | .bmp | TextureLoader（SDL2 SDL_LoadBMP） |
| 音效 | .ogg | SoundLoader（SDL2_mixer Mix_LoadWAV） |
| 字体 | .ttf/.ttc | SDL2_ttf TTF_OpenFont |

## 字体策略

中文 UI 字体回退链：
1. `C:/Windows/Fonts/msyh.ttc`（微软雅黑）
2. `C:/Windows/Fonts/msyhbd.ttc`（微软雅黑粗体）
3. `C:/Windows/Fonts/simhei.ttf`（黑体）
4. `C:/Windows/Fonts/simsun.ttc`（宋体）
5. `NotoSansSC-Regular.otf`（思源黑体 — 项目内）

## 架构决策日志

### ADR-001: 保留 SDL2，不换渲染后端
- **决策**: 继续使用 SDL2 GPU 渲染器
- **原因**: 伪3D FPS 的渲染需求（画竖线、缩放贴图、纯色填充）SDL2 完全胜任；换 OpenGL/Vulkan 增加数倍代码量无收益
- **版本**: v0.2.0（从 v0.1.0 重构升级，v1.0.0 为稳定发布目标）
- **日期**: 2026-05-13

### ADR-002: 组件化重构
- **决策**: 将 Unit→Sprite 继承链重构为组合模式
- **原因**: 当前继承链已显僵硬，新功能（换弹系统等）难以加入；组合模式更灵活且对 AI Agent 更友好
- **版本**: v0.2.0（从 v0.1.0 重构升级，v1.0.0 为稳定发布目标）
- **日期**: 2026-05-13

### ADR-003: 默认中文 UI
- **决策**: 所有面向玩家的字符串默认中文
- **原因**: 目标用户为中文玩家，减少本地化开销
- **版本**: v0.2.0（从 v0.1.0 重构升级，v1.0.0 为稳定发布目标）
- **日期**: 2026-05-13

### ADR-004: 吸收 javidx9 生命周期模式
- **决策**: 采用 OnCreate/OnUpdate/OnDestroy 生命周期范式
- **原因**: 清晰、简单，对开发者友好；不引入 olcConsoleGameEngine 的 Windows 控制台依赖
- **版本**: v0.2.0（从 v0.1.0 重构升级，v1.0.0 为稳定发布目标）
- **日期**: 2026-05-13
