#pragma once
#include <string>

/// 武器组件 — 纯数据 + 内置换弹状态机。
/// 用于 Player 和 Enemy 实体的武器参数。
struct WeaponComponent {
    // —— 弹药 ——
    int ammoClip = 30;          // 当前弹夹
    int ammoReserve = 90;       // 备弹
    int clipSize = 30;          // 弹夹容量

    // —— 射击 ——
    float fireRate = 10.0f;     // 每秒射击次数
    float cooldownTimer = 0.0f; // 冷却计时（秒），<=0 可射击
    int damage = 1;             // 每发伤害
    float bulletSpeed = 15.0f;  // 子弹速度
    float bulletRange = 10.0f;  // 子弹最大射程

    // —— 换弹 ——
    float reloadTime = 2.0f;    // 换弹总时间（秒）
    float reloadTimer = 0.0f;   // 换弹进度计时（秒）
    bool isReloading = false;   // 换弹状态

    // —— 查询 ——
    bool canShoot() const { return cooldownTimer <= 0.0f && ammoClip > 0 && !isReloading; }
    bool needsReload() const { return ammoClip < clipSize && ammoReserve > 0 && !isReloading; }
    bool ammoIsEmpty() const { return ammoClip == 0 && ammoReserve == 0; }

    // —— HUD 字符串 ——
    /// "24/30 备弹:45" / "Max" / "Inf" / "换弹中..."
    std::string ammoString() const {
        if (isReloading) return "换弹中...";
        if (ammoReserve < 0) return "Inf";
        return std::to_string(ammoClip) + "/" + std::to_string(clipSize)
             + " 备弹:" + std::to_string(ammoReserve);
    }
};
