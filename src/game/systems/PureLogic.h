#pragma once
#include "game/components/WeaponComponent.h"
#include "math/Vector2D.h"

/// 从 SDL2 依赖 System 中提取的纯逻辑函数，可独立测试。

// —— ReloadSystem 纯逻辑 ——

/// 推进换弹计时器，完成后转移弹药。与 Input 解耦。
/// @return true 如果换弹完成（状态变为 IDLE）
inline bool reloadTimerUpdate(WeaponComponent& weapon, float dT) {
    if (!weapon.isReloading) return false;

    weapon.reloadTimer += dT;
    if (weapon.reloadTimer >= weapon.reloadTime) {
        int needed = weapon.clipSize - weapon.ammoClip;
        int transfer = (needed < weapon.ammoReserve) ? needed : weapon.ammoReserve;
        weapon.ammoClip += transfer;
        weapon.ammoReserve -= transfer;
        weapon.isReloading = false;
        weapon.reloadTimer = 0.0f;
        return true;
    }
    return false;
}

/// 自动触发换弹（弹夹空且有备弹时）
inline bool autoReloadStart(WeaponComponent& weapon) {
    if (weapon.ammoClip <= 0 && weapon.ammoReserve > 0 && !weapon.isReloading) {
        weapon.isReloading = true;
        weapon.reloadTimer = 0.0f;
        return true;
    }
    return false;
}

// —— 碰撞检测纯逻辑 ——

/// 检查两点是否在指定半径内（2D 圆形碰撞）
inline bool isWithinRadius(Vector2D a, Vector2D b, float radius) {
    return a.distanceTo(b) < radius;
}

// —— 射击冷却纯逻辑 ——

/// 推进射击冷却计时器
inline void updateCooldown(WeaponComponent& weapon, float dT) {
    if (weapon.cooldownTimer > 0.0f) {
        weapon.cooldownTimer -= dT;
    }
}

/// 尝试射击：消耗弹药、重置冷却。返回 true 如果成功射击。
inline bool tryFire(WeaponComponent& weapon) {
    if (!weapon.canShoot()) return false;
    weapon.ammoClip--;
    weapon.cooldownTimer = 1.0f / weapon.fireRate;
    return true;
}
