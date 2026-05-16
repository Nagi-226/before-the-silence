#pragma once
#include "math/Vector2D.h"

/// 位置 + 朝向组件 — 纯数据，不含行为。
/// 所有有空间位置的实体（Player/Enemy/Projectile/Pickup）均包含此组件。
struct Transform {
    Vector2D position;
    float angle = 0.0f;  // 弧度

    Transform() = default;
    Transform(const Vector2D& pos, float ang = 0.0f) : position(pos), angle(ang) {}

    /// 向前方向单位向量
    Vector2D forward() const { return Vector2D(angle); }
};
