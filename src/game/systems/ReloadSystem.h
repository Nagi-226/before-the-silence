#pragma once
#include "game/components/WeaponComponent.h"

class Input;

/// 换弹系统 — 管理武器换弹状态机。
///   IDLE ←→ RELOADING → 完成换弹 → IDLE
class ReloadSystem
{
public:
    /// 处理玩家换弹逻辑（每帧调用，含 R 键检测）
    /// @param weapon 武器组件（读写）
    /// @param input  输入（检测 R 键）
    /// @param dT     帧间隔
    void update(WeaponComponent& weapon, const Input& input, float dT);

    /// 自动换弹计时推进（敌人等无输入实体使用）
    /// 调用方需自行触发 isReloading（当 ammoClip==0 且 ammoReserve>0 时）
    void updateReloadTimer(WeaponComponent& weapon, float dT);
};
