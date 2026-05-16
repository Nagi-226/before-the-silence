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

private:
    const WeaponConfig& m_weaponConfig;
    const PickupConfig& m_pickupConfig;
    ParticleSystem& m_particles;
};
