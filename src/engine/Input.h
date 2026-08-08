#pragma once
#include "SDL2/SDL.h"

/// 键盘 + 鼠标输入抽象 — v0.6.3 恢复 SDL_GetKeyboardState 轮询。
/// 原始 src-legacy 代码证明此方式在 Windows 下最可靠，
/// 不依赖 SDL_KEYDOWN/KEYUP 事件队列时序。
class Input
{
public:
    Input();

    /// 每帧开始时调用，刷新键盘/鼠标状态
    void update();

    // —— 键盘查询 ——
    bool isKeyHeld(SDL_Scancode key) const;
    bool isKeyPressed(SDL_Scancode key) const;
    bool isKeyReleased(SDL_Scancode key) const;

    // —— 鼠标查询 ——
    bool isMouseHeld(Uint8 button = SDL_BUTTON_LEFT) const;
    bool isMousePressed(Uint8 button = SDL_BUTTON_LEFT) const;
    int getMouseDeltaX() const { return m_mouseDeltaX; }
    int getMouseDeltaY() const { return m_mouseDeltaY; }

    // —— 退出 ——
    bool shouldQuit() const { return m_shouldQuit; }
    bool isFullscreenToggled() const;

private:
    // v0.6.3: SDL_GetKeyboardState 轮询（每帧从 SDL 内部状态同步）
    Uint8 m_keyState[SDL_NUM_SCANCODES] = {};
    Uint8 m_keyPrev[SDL_NUM_SCANCODES] = {};

    // 鼠标
    int m_mouseDeltaX = 0;
    int m_mouseDeltaY = 0;
    Uint32 m_mouseState = 0;
    Uint32 m_mousePrev = 0;

    bool m_shouldQuit = false;
    bool m_fullscreenPressed = false;
};
