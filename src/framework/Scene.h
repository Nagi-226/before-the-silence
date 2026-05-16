#pragma once
#include "engine/Engine.h"

/// 场景基类 — 吸收 javidx9 生命周期模式。
/// 每个场景（菜单/游戏/结算）派生自此基类。
class Scene : public Engine
{
public:
    /// 场景标识
    enum class Type {
        Menu,
        Game,
        Victory,
        Defeat
    };

    virtual ~Scene() = default;

    /// 获取当前场景类型
    virtual Type getType() const = 0;

    /// 是否请求切换场景
    bool shouldTransition() const { return m_shouldTransition; }

    /// 目标场景类型
    Type getTransitionTarget() const { return m_transitionTarget; }

protected:
    /// 请求切换到指定场景
    void requestTransition(Type target) {
        m_shouldTransition = true;
        m_transitionTarget = target;
    }

private:
    bool m_shouldTransition = false;
    Type m_transitionTarget = Type::Game;
};
