#pragma once
#include "game/entities/Player.h"
#include "engine/Input.h"
#include <vector>
#include <memory>

class Enemy;
class Projectile;

struct WeaponConfig;
struct PickupConfig;
class ParticleSystem;

/// 战斗系统 — 射击、子弹飞行、伤害处理。
class CombatSystem
{
public:
    CombatSystem(const WeaponConfig& weaponConfig, const PickupConfig& pickupConfig,
                 ParticleSystem& particles)
        : m_weaponConfig(weaponConfig), m_pickupConfig(pickupConfig), m_particles(particles) {}

    /// 处理玩家射击（每帧调用）
    void updatePlayerShooting(Player& player, const Input& input, float dT,
                              std::vector<std::unique_ptr<Projectile>>& projectiles);

    /// 更新所有子弹位置 + 碰撞检测
    void updateProjectiles(std::vector<std::unique_ptr<Projectile>>& projectiles,
                           Player& player, std::vector<std::unique_ptr<Enemy>>& enemies, float dT);

    /// v0.4.7 弹道拖尾（上一帧位置 → 当前帧位置）
    struct TracerLine { Vector2D from; Vector2D to; float lifetime = 0.08f; };
    const std::vector<TracerLine>& getTracers() const { return m_tracers; }
    void updateTracers(float dT);

private:
    const WeaponConfig& m_weaponConfig;
    const PickupConfig& m_pickupConfig;
    ParticleSystem& m_particles;
    std::vector<TracerLine> m_tracers;
};
