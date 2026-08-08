#pragma once
#include "game/components/Transform.h"
#include "game/components/Health.h"
#include "game/components/WeaponComponent.h"

/// 玩家实体 — 组合 Transform + Health + WeaponComponent + 视觉反馈状态。
class Player
{
public:
    Transform transform;
    Health health;
    WeaponComponent weapon;

    // —— 移动控制（Input → MovementSystem 写入） ——
    int moveForward = 0;    int moveRight = 0;
    float turnAmount = 0.0f;

    // —— 金币 + 升级 ——
    int coins = 0;
    int healthUpgrades = 0, ammoUpgrades = 0, speedUpgrades = 0;

    // —— 移动参数 ——
    static constexpr float MOVE_SPEED = 7.0f;
    static constexpr float TURN_SPEED = 2.0f;
    static constexpr int BASE_HEALTH = 20;

    // —— 视觉反馈状态 ——
    float hurtTimer = 0.0f;           // 受击闪红计时（s）
    float shakeTimer = 0.0f;          // 屏幕震动计时（s）
    float bobPhase = 0.0f;            // 视角晃动相位（rad）
    float muzzleFlashTimer = 0.0f;    // 枪口闪光计时（s）
    bool isMoving = false;            // 是否在移动（驱动视角晃动）

    static constexpr float HURT_DURATION = 0.3f;
    static constexpr float SHAKE_DURATION = 0.15f;
    static constexpr float BOBBING_SPEED = 8.0f;       // 晃动速度
    static constexpr float BOBBING_AMPLITUDE = 1.5f;   // 晃动幅度（像素）
    // v0.3.9 Y-shearing 上下视角
    float lookOffset = 0.0f;
    static constexpr float LOOK_SENSITIVITY = 0.03f;
    static constexpr float MAX_LOOK_OFFSET = 30.0f;

    // v0.4.4 武器模型动画
    int weaponAnimFrame = 0;           // 动画帧 [0,2]
    float weaponAnimTimer = 0.0f;      // 帧计时
    static constexpr int WEAPON_FRAMES = 3;
    static constexpr float WEAPON_FRAME_DURATION = 0.06f;

    // v0.4.6 游戏状态
    enum class State { Menu, Playing, Victory, Defeat };
    State gameState = State::Playing;

    static constexpr float MUZZLE_FLASH_DURATION = 0.05f;

    Player(Vector2D startPos)
        : transform(startPos)
        , health(BASE_HEALTH, BASE_HEALTH)
    {}
};
