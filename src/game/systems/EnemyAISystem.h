#pragma once
#include "game/entities/Player.h"
#include "game/entities/Enemy.h"
#include "math/Vector2D.h"
#include <vector>
#include <memory>
#include <queue>
#include <unordered_map>

class Projectile;
class ReloadSystem;
struct GameplayConfig;

/// 敌人 AI 系统 — 行为状态机（Idle→Alert→Chasing→Attacking）。
/// v0.6.2: 添加 BFS 网格寻路，借鉴 kadegutou/fps-raycasting-engine 的敌人导航算法。
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

    /// v0.6.2 BFS 网格寻路：返回从敌人到玩家的下一步移动方向（归一化）
    /// 借鉴 DOOM 的 REJECT 表概念：当视线被遮挡时，用 BFS 找到绕墙路径。
    /// @return 归一化的移动方向向量，或零向量表示无法到达
    Vector2D bfsPathfind(int startX, int startY, int targetX, int targetY,
                         int maxSteps = 256);

    const GameplayConfig& m_gameConfig;
    ReloadSystem& m_reloadSys;
};
