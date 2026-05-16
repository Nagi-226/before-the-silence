#pragma once
#include "math/Vector2D.h"

/// 单个粒子。
struct Particle {
    Vector2D position;
    Vector2D velocity;
    float lifetime = 0.0f;
    float maxLifetime = 0.0f;
    unsigned char r=255, g=255, b=255;
    float size = 2.0f;

    bool isDead() const { return lifetime <= 0.0f; }
    float alpha() const { return maxLifetime > 0.0f ? lifetime / maxLifetime : 0.0f; }
};

/// 粒子系统 — 固定预分配池，热路径零分配。
class ParticleSystem
{
public:
    static constexpr int DEFAULT_MAX_PARTICLES = 300;
    static constexpr int MAX_POOL = 512;

    explicit ParticleSystem(int maxParticles = DEFAULT_MAX_PARTICLES);

    /// 发射粒子（O(1) — 追加或覆盖最旧）
    void emit(const Particle& p);
    void emitSpark(Vector2D pos, Vector2D normal, int count = 8);
    void emitBlood(Vector2D pos, int count = 6);
    void emitExplosion(Vector2D pos, int count = 20);

    /// 更新所有粒子 + 压缩死亡粒子（swap-with-last）
    void update(float dT);

    /// 活跃粒子指针 + 数量（用于渲染遍历）
    const Particle* activeParticles() const { return m_pool; }
    int activeCount() const { return m_count; }

    void clear();

private:
    Particle m_pool[MAX_POOL];
    int m_count = 0;
    int m_poolSize;  // runtime limit, <= MAX_POOL
    int m_oldest = 0;
};
