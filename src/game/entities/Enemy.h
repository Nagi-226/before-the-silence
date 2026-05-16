#pragma once
#include "game/components/Transform.h"
#include "game/components/Health.h"
#include "game/components/WeaponComponent.h"
#include <string>
#include <vector>

/// 敌人实体 — 组合模式。支持 3 种模板 + 多帧动画。
class Enemy
{
public:
    struct Template {
        std::string textureFile;
        int health;
        WeaponComponent weapon;
        bool canDropPickup;
        float detectionRange = 8.0f;
        float attackRange = 2.0f;
        float moveSpeed = 2.5f;
    };

    static const std::vector<Template> s_templates;

    // —— 组件 ——
    Transform transform;
    Health health;
    WeaponComponent weapon;
    bool canDropPickup = false;

    // —— AI 参数（从 Template 初始化，不同敌人可不同） ——
    float detectionRange = 8.0f;
    float attackRange = 2.0f;
    float moveSpeed = 2.5f;

    // —— AI 状态 ——
    enum class State { Idle, Alert, Chasing, Attacking, Dead };
    State state = State::Idle;

    // —— 反馈计时器 ——
    float hurtTimer = 0.0f;
    float playerVisibleTimer = 0.0f;
    static constexpr float HURT_FLASH_TIME = 0.2f;

    // —— v0.3.3 多帧动画 ——
    int animFrame = 0;           // 当前动画帧 [0, FRAME_COUNT)
    float animTimer = 0.0f;      // 帧切换计时（s）
    static constexpr int FRAME_COUNT = 4;       // 4帧动画
    static constexpr float FRAME_DURATION = 0.25f;  // 每帧 250ms
    static constexpr int FRAME_WIDTH = 32;     // 单帧宽度（像素）

    Enemy(Vector2D pos, const Template& tmpl)
        : transform(pos)
        , health(tmpl.health, tmpl.health)
        , weapon(tmpl.weapon)
        , canDropPickup(tmpl.canDropPickup)
        , detectionRange(tmpl.detectionRange)
        , attackRange(tmpl.attackRange)
        , moveSpeed(tmpl.moveSpeed)
    {}

    bool isAlive() const { return health.isAlive(); }

    /// 更新动画帧（每帧调用）
    void updateAnimation(float dT) {
        animTimer += dT;
        if (animTimer >= FRAME_DURATION) {
            animTimer -= FRAME_DURATION;
            animFrame = (animFrame + 1) % FRAME_COUNT;
        }
    }
};

inline const std::vector<Enemy::Template> Enemy::s_templates = {
    {"Alien Small.bmp",  1, WeaponComponent{}},                          // 0=小怪
    {"Alien Medium.bmp", 3, []{ auto w = WeaponComponent{}; w.ammoReserve = 9999; w.damage = 2; w.fireRate = 8.0f; w.bulletSpeed = 12.0f; return w; }()},
    {"Alien Large.bmp",  6, []{ auto w = WeaponComponent{}; w.ammoReserve = 9999; w.damage = 4; w.fireRate = 6.0f; w.bulletSpeed = 10.0f; return w; }()},
};
