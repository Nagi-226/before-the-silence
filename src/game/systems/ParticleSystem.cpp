#include "game/systems/ParticleSystem.h"
#include "math/MathAddon.h"
#include <cstdlib>
#include <cmath>

ParticleSystem::ParticleSystem(int maxParticles)
    : m_poolSize(maxParticles < MAX_POOL ? maxParticles : MAX_POOL)
{
}

void ParticleSystem::emit(const Particle& p) {
    if (m_count < m_poolSize) {
        m_pool[m_count++] = p;
    } else {
        m_pool[m_oldest] = p;
        m_oldest = (m_oldest + 1) % m_poolSize;
    }
}

void ParticleSystem::emitSpark(Vector2D pos, Vector2D normal, int count) {
    for (int i = 0; i < count; ++i) {
        float angle = std::atan2(normal.y, normal.x) + (rand() % 100 - 50) * 0.015f;
        float speed = 3.0f + static_cast<float>(rand() % 100) * 0.05f;
        Particle p;
        p.position = pos;
        p.velocity = Vector2D(std::cos(angle), std::sin(angle)) * speed;
        p.lifetime = 0.15f + static_cast<float>(rand() % 100) * 0.002f;
        p.maxLifetime = p.lifetime;
        p.r = 255; p.g = 200 + (rand() % 55); p.b = 50;
        p.size = 1.5f;
        emit(p);
    }
}

void ParticleSystem::emitBlood(Vector2D pos, int count) {
    for (int i = 0; i < count; ++i) {
        float angle = static_cast<float>(rand() % 628) * 0.01f;
        float speed = 1.5f + static_cast<float>(rand() % 100) * 0.03f;
        Particle p;
        p.position = pos;
        p.velocity = Vector2D(std::cos(angle), std::sin(angle)) * speed;
        p.lifetime = 0.4f + static_cast<float>(rand() % 100) * 0.003f;
        p.maxLifetime = p.lifetime;
        p.r = 180 + (rand() % 75); p.g = 0; p.b = 0;
        p.size = 2.0f + static_cast<float>(rand() % 100) * 0.02f;
        emit(p);
    }
}

void ParticleSystem::emitExplosion(Vector2D pos, int count) {
    for (int i = 0; i < count; ++i) {
        float angle = static_cast<float>(rand() % 628) * 0.01f;
        float speed = 4.0f + static_cast<float>(rand() % 100) * 0.08f;
        Particle p;
        p.position = pos;
        p.velocity = Vector2D(std::cos(angle), std::sin(angle)) * speed;
        p.lifetime = 0.6f + static_cast<float>(rand() % 100) * 0.005f;
        p.maxLifetime = p.lifetime;
        p.r = 255; p.g = 160 + (rand() % 95); p.b = 30;
        p.size = 3.0f + static_cast<float>(rand() % 100) * 0.03f;
        emit(p);
    }
}

void ParticleSystem::update(float dT) {
    for (int i = 0; i < m_count; ) {
        auto& p = m_pool[i];
        p.position += p.velocity * dT;
        p.velocity.y += 2.0f * dT;  // gravity
        p.lifetime -= dT;
        if (p.isDead()) {
            p = m_pool[--m_count];  // swap with last, re-check this slot
        } else {
            ++i;
        }
    }
    // Reset oldest pointer when pool empties
    if (m_count == 0) m_oldest = 0;
}

void ParticleSystem::clear() {
    m_count = 0;
    m_oldest = 0;
}
