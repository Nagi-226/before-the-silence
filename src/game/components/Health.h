#pragma once

/// 生命值组件 — 纯数据，不含行为。
struct Health {
    int current = 0;
    int max = 0;

    Health() = default;
    Health(int cur, int maxHp) : current(cur), max(maxHp) {}

    bool isAlive() const { return current > 0; }
    bool isDead() const { return current <= 0; }

    /// 受伤（不低于 0）
    void takeDamage(int amount) {
        current -= amount;
        if (current < 0) current = 0;
    }

    /// 治疗（不超过 max）
    void heal(int amount) {
        current += amount;
        if (current > max) current = max;
    }

    /// 返回血条中文描述。返回 nullptr 表示用数字显示（normal 区间）。
    const char* toString() const {
        if (current >= max) return "满血";
        if (current <= 1)   return "濒死";
        // 返回 nullptr 表示用数字显示
        return nullptr;
    }
};
