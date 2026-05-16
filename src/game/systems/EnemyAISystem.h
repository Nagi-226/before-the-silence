#pragma once
#include "game/entities/Player.h"
#include "game/entities/Enemy.h"
#include <vector>
#include <memory>

class Projectile;
class ReloadSystem;
struct GameplayConfig;

/// 敌人 AI 系统 — 行为状态机（Idle→Alert→Chasing→Attacking）。
class EnemyAISystem
{
public:
    EnemyAISystem(const GameplayConfig& gameConfig, ReloadSystem& reloadSys)
        : m_gameConfig(gameConfig), m_reloadSys(reloadSys) {}

    /// 更新所有敌人 AI
    void update(std::vector<std::unique_ptr<Enemy>>& enemies,
                const Player& player,
                std::vector<std::unique_ptr<Projectile>>& projectiles,
                float dT);

private:
    /// 检查敌人是否能看到玩家（简单 DDA 射线检测）
    bool canSeePlayer(const Enemy& enemy, const Player& player);

    const GameplayConfig& m_gameConfig;
    ReloadSystem& m_reloadSys;
};
