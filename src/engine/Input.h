#pragma once
#include "SDL2/SDL.h"

/// 键盘 + 鼠标输入抽象。
/// 每帧调用 update() 刷新状态，然后通过查询方法获取输入。
class Input
{
public:
    Input();

    /// 每帧开始时调用，刷新键盘和鼠标状态
    void update();

    // —— 键盘查询 ——
    /// 按键是否当前被按住
    bool isKeyHeld(SDL_Scancode key) const;
    /// 按键是否在本帧刚被按下（上升沿）
    bool isKeyPressed(SDL_Scancode key) const;
    /// 按键是否在本帧刚被释放（下降沿）
    bool isKeyReleased(SDL_Scancode key) const;

    // —— 鼠标查询 ——
    /// 鼠标左键是否当前被按住
    bool isMouseHeld(Uint8 button = SDL_BUTTON_LEFT) const;
    /// 鼠标按键是否在本帧刚被按下
    bool isMousePressed(Uint8 button = SDL_BUTTON_LEFT) const;
    /// 鼠标 X 轴本帧相对位移（像素）
    int getMouseDeltaX() const { return m_mouseDeltaX; }
    /// 鼠标 Y 轴本帧相对位移（像素）
    int getMouseDeltaY() const { return m_mouseDeltaY; }

    // —— 退出 ——
    /// 是否请求退出（ESC 或窗口关闭）
    bool shouldQuit() const { return m_shouldQuit; }

    // —— 窗口事件 ——
    /// F11 是否在本帧被按下（用于全屏切换）
    bool isFullscreenToggled() const;

private:
    // 键盘状态：当前帧 vs 上一帧
    Uint8 m_keyState[SDL_NUM_SCANCODES] = {};
    Uint8 m_keyPrev[SDL_NUM_SCANCODES] = {};
    int m_numKeys = 0;

    // 鼠标
    int m_mouseDeltaX = 0;
    int m_mouseDeltaY = 0;
    Uint32 m_mouseState = 0;
    Uint32 m_mousePrev = 0;

    bool m_shouldQuit = false;
    bool m_fullscreenPressed = false;
};
