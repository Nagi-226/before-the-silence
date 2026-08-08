#include "engine/Input.h"
#include <cstring>
#include <iostream>

Input::Input() {
    std::memset(m_keyState, 0, sizeof(m_keyState));
    std::memset(m_keyPrev, 0, sizeof(m_keyPrev));
}

void Input::update() {
    // 保存上一帧状态用于 pressed/released 检测
    std::memcpy(m_keyPrev, m_keyState, sizeof(m_keyState));
    m_mousePrev = m_mouseState;

    // 重置每帧标志
    m_mouseDeltaX = 0;
    m_mouseDeltaY = 0;
    m_fullscreenPressed = false;

    // v0.6.3: 恢复原始 SDL_GetKeyboardState 轮询方式（src-legacy 证明可靠）
    // 直接读取 SDL 内部键盘状态数组，不依赖事件队列的 KEYDOWN/KEYUP 时序
    int numKeys = 0;
    const Uint8* kbState = SDL_GetKeyboardState(&numKeys);
    int copyLen = (numKeys < SDL_NUM_SCANCODES) ? numKeys : SDL_NUM_SCANCODES;
    std::memcpy(m_keyState, kbState, copyLen);

    // 鼠标相对位移
    int mx, my;
    m_mouseState = SDL_GetRelativeMouseState(&mx, &my);
    m_mouseDeltaX = mx;
    m_mouseDeltaY = my;

    // 仅处理退出/特殊键/鼠标按钮事件
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
        case SDL_QUIT:
            m_shouldQuit = true;
            break;

        case SDL_KEYDOWN:
            if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) {
                m_shouldQuit = true;
            }
            if (event.key.keysym.scancode == SDL_SCANCODE_F11) {
                if (!event.key.repeat) {
                    m_fullscreenPressed = true;
                }
            }
            break;

        default:
            break;
        }
    }
}

// —— 键盘查询 ——

bool Input::isKeyHeld(SDL_Scancode key) const {
    return m_keyState[key];
}

bool Input::isKeyPressed(SDL_Scancode key) const {
    return m_keyState[key] && !m_keyPrev[key];
}

bool Input::isKeyReleased(SDL_Scancode key) const {
    return !m_keyState[key] && m_keyPrev[key];
}

// —— 鼠标查询 ——

bool Input::isMouseHeld(Uint8 button) const {
    return (m_mouseState & SDL_BUTTON(button)) != 0;
}

bool Input::isMousePressed(Uint8 button) const {
    bool current = (m_mouseState & SDL_BUTTON(button)) != 0;
    bool previous = (m_mousePrev & SDL_BUTTON(button)) != 0;
    return current && !previous;
}

bool Input::isFullscreenToggled() const {
    return m_fullscreenPressed;
}
