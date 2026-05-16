#pragma once
#include "game/components/Transform.h"
#include "game/Level.h"
#include "math/Vector2D.h"

/// 子弹/投射物实体 — 组合模式。
class Projectile
{
public:
    Transform transform;
    Vector2D direction;              // 飞行方向（单位向量）
    float speed = 20.0f;
    int damage = 1;
    bool shotFromPlayer = false;
    bool collisionOccurred = false;
    float distanceTraveled = 0.0f;   // 已飞行距离
    float maxRange = 15.0f;          // 最大射程

    Projectile(Vector2D startPos, Vector2D dir, bool fromPlayer, float spd = 20.0f, int dmg = 1)
        : transform(startPos)
        , direction(dir.normalize())
        , speed(spd)
        , damage(dmg)
        , shotFromPlayer(fromPlayer)
    {}

    bool shouldDestroy() const {
        if (collisionOccurred) return true;
        if (distanceTraveled >= maxRange) return true;
        // 超出关卡边界
        int gx = static_cast<int>(transform.position.x);
        int gy = static_cast<int>(transform.position.y);
        if (gx < 0 || gx >= Level::WIDTH || gy < 0 || gy >= Level::HEIGHT) return true;
        return false;
    }
};
