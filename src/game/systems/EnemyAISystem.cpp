#include "game/systems/EnemyAISystem.h"
#include "game/systems/ReloadSystem.h"
#include "game/systems/PureLogic.h"
#include "game/GameConfig.h"
#include "game/Level.h"
#include "game/entities/Projectile.h"
#include "math/MathAddon.h"
#include <cmath>
#include <cstring>

void EnemyAISystem::update(std::vector<std::unique_ptr<Enemy>>& enemies,
                            const Player& player,
                            std::vector<std::unique_ptr<Projectile>>& projectiles,
                            float dT) {
    for (auto& enemy : enemies) {
        if (!enemy->isAlive()) continue;

        MathAddon::decayTimer(enemy->hurtTimer, dT);

        float distToPlayer = enemy->transform.position.distanceTo(player.transform.position);
        bool canSee = canSeePlayer(*enemy, player);

        float detRange = enemy->detectionRange;
        float atkRange = enemy->attackRange;
        float mvSpeed = enemy->moveSpeed;

        switch (enemy->state) {
        case Enemy::State::Idle:
            // v0.6.2: 使用 BFS 检查是否有可达路径，无需直接视线也能触发追击
            if (distToPlayer < detRange) {
                Vector2D bfsDir = bfsPathfind(
                    static_cast<int>(enemy->transform.position.x),
                    static_cast<int>(enemy->transform.position.y),
                    static_cast<int>(player.transform.position.x),
                    static_cast<int>(player.transform.position.y));
                if (bfsDir.x != 0.0f || bfsDir.y != 0.0f) {
                    enemy->state = Enemy::State::Alert;
                }
            }
            break;

        case Enemy::State::Alert:
            enemy->playerVisibleTimer += dT;
            if (distToPlayer < atkRange && canSee) {
                enemy->state = Enemy::State::Attacking;
            }
            else if (distToPlayer > detRange * 1.5f) {
                enemy->state = Enemy::State::Idle;
                enemy->playerVisibleTimer = 0.0f;
            }
            else if (canSee) {
                // 有视线：直接冲向玩家
                Vector2D dir = player.transform.position - enemy->transform.position;
                float mg = dir.magnitude();
                if (mg > 0.001f) {
                    enemy->transform.position += dir / mg * mvSpeed * dT;
                }
                enemy->state = Enemy::State::Chasing;
            }
            else {
                // v0.6.2: 无视线但仍在探测范围内 → BFS 寻路绕墙
                Vector2D bfsDir = bfsPathfind(
                    static_cast<int>(enemy->transform.position.x),
                    static_cast<int>(enemy->transform.position.y),
                    static_cast<int>(player.transform.position.x),
                    static_cast<int>(player.transform.position.y));
                if (bfsDir.x != 0.0f || bfsDir.y != 0.0f) {
                    Vector2D move = bfsDir * mvSpeed * dT;
                    Level::moveWithWallSlide(enemy->transform.position.x, enemy->transform.position.y,
                                             move.x, move.y);
                }
                // 保持在 Alert 状态，继续用 BFS 寻找路径
            }
            break;

        case Enemy::State::Chasing: {
            if (distToPlayer < atkRange && canSee) {
                enemy->state = Enemy::State::Attacking;
            }
            else if (distToPlayer > detRange * 1.5f) {
                enemy->state = Enemy::State::Idle;
                enemy->playerVisibleTimer = 0.0f;
            }
            // v0.6.2: 丢失视线时回退到 Alert，启用 BFS 绕墙寻路
            else if (!canSee) {
                enemy->state = Enemy::State::Alert;
            }
            else {
                Vector2D dir = player.transform.position - enemy->transform.position;
                float mg = dir.magnitude();
                if (mg > 0.001f) {
                    Vector2D move = dir / mg * mvSpeed * dT;
                    Level::moveWithWallSlide(enemy->transform.position.x, enemy->transform.position.y,
                                             move.x, move.y);
                }
            }
            break;
        }

        case Enemy::State::Attacking:
            if (distToPlayer > atkRange * 1.5f) {
                enemy->state = Enemy::State::Chasing;
            }
            else if (!canSee) {
                enemy->state = Enemy::State::Alert;
            }
            else {
                auto& w = enemy->weapon;
                updateCooldown(w, dT);
                autoReloadStart(w);
                m_reloadSys.updateReloadTimer(w, dT);

                if (tryFire(w)) {
                    Vector2D diff = player.transform.position - enemy->transform.position;
                    float mg = diff.magnitude();
                    if (mg > 0.001f) {
                        Vector2D dir = diff / mg;
                        projectiles.push_back(std::make_unique<Projectile>(
                            enemy->transform.position + dir * 0.5f,
                            dir, false, w.bulletSpeed, w.damage));
                    }
                }
            }
            break;

        case Enemy::State::Dead:
            // v0.4.7 尸体淡出计时
            enemy->corpseFadeTimer -= dT;
            break;
        }
    }

    // v0.6.2 借鉴 DOOM P_RemoveMobj 帧末延迟删除模式：
    // 死亡敌人保留在场，等 corpseFadeTimer 衰减到 0 再移除，
    // 确保尸体淡出动画在渲染侧可见。
    enemies.erase(std::remove_if(enemies.begin(), enemies.end(),
        [](const auto& e) {
            return !e->isAlive() && e->corpseFadeTimer <= 0.0f;
        }),
        enemies.end());
}

bool EnemyAISystem::canSeePlayer(const Enemy& enemy, const Player& player) {
    Vector2D dir = player.transform.position - enemy.transform.position;
    float dist = dir.magnitude();
    if (dist > enemy.detectionRange) return false;

    Vector2D step = dir.normalize() * m_gameConfig.ddaStepSize;
    Vector2D current = enemy.transform.position;
    float traveled = 0.0f;

    while (traveled < dist) {
        current += step;
        traveled += m_gameConfig.ddaStepSize;
        if (Level::isWall(static_cast<int>(current.x), static_cast<int>(current.y))) {
            return false;
        }
    }
    return true;
}

// ============================================================================
// v0.6.2 BFS 网格寻路
// 借鉴 kadegutou/fps-raycasting-engine 的 BFS 地下城导航算法，
// 结合 DOOM REJECT 表概念：当视线被遮挡时，用 BFS 找到绕过墙壁的最短路径。
// ============================================================================

Vector2D EnemyAISystem::bfsPathfind(int startX, int startY, int targetX, int targetY,
                                     int maxSteps) {
    // 边界钳位
    if (startX < 0) startX = 0; if (startX >= Level::WIDTH)  startX = Level::WIDTH - 1;
    if (startY < 0) startY = 0; if (startY >= Level::HEIGHT) startY = Level::HEIGHT - 1;
    if (targetX < 0) targetX = 0; if (targetX >= Level::WIDTH)  targetX = Level::WIDTH - 1;
    if (targetY < 0) targetY = 0; if (targetY >= Level::HEIGHT) targetY = Level::HEIGHT - 1;

    // 起点或终点是墙壁 → 无路径
    if (Level::isWall(startX, startY) || Level::isWall(targetX, targetY)) {
        return Vector2D(0.0f, 0.0f);
    }

    // 同格 → 无需移动
    if (startX == targetX && startY == targetY) {
        return Vector2D(0.0f, 0.0f);
    }

    // 方向编码: 0=未访问, 1=上, 2=下, 3=左, 4=右
    static std::vector<uint8_t> visited;
    int gridSize = Level::WIDTH * Level::HEIGHT;
    if (static_cast<int>(visited.size()) < gridSize) {
        visited.resize(gridSize);
    }
    // 每帧重置 (仅重置 BFS 可能触及的区域太复杂，全重置 ~11KB 可接受)
    std::memset(visited.data(), 0, gridSize);

    // BFS 队列: 存储 (x, y) 编码为单个整数
    std::queue<int> q;
    int startIdx = startY * Level::WIDTH + startX;
    int targetIdx = targetY * Level::WIDTH + targetX;
    q.push(startIdx);
    visited[startIdx] = 5; // 起点标记 (非 0，与方向码区分)

    const int dx[4] = { 0, 0, -1, 1 };
    const int dy[4] = { -1, 1, 0, 0 };
    const uint8_t dirCode[4] = { 1, 2, 3, 4 }; // 上, 下, 左, 右
    const int reverseDx[5] = { 0, 0, 0, 1, -1 }; // dirCode→反向dx
    const int reverseDy[5] = { 0, 1, -1, 0, 0 }; // dirCode→反向dy

    int steps = 0;
    while (!q.empty() && steps < maxSteps) {
        int curIdx = q.front(); q.pop();
        int cx = curIdx % Level::WIDTH;
        int cy = curIdx / Level::WIDTH;
        ++steps;

        for (int d = 0; d < 4; ++d) {
            int nx = cx + dx[d];
            int ny = cy + dy[d];

            if (nx < 0 || nx >= Level::WIDTH || ny < 0 || ny >= Level::HEIGHT) continue;
            if (Level::isWall(nx, ny)) continue;

            int nIdx = ny * Level::WIDTH + nx;
            if (visited[nIdx] != 0) continue;

            visited[nIdx] = dirCode[d];

            if (nIdx == targetIdx) {
                // 回溯：从目标反向走回起点，记录方向
                int backX = targetX, backY = targetY;
                uint8_t prevDir = 0;
                while (!(backX == startX && backY == startY)) {
                    int backIdx = backY * Level::WIDTH + backX;
                    uint8_t cameFrom = visited[backIdx];
                    if (cameFrom == 5) break; // 到达起点
                    prevDir = cameFrom;
                    // 反向移动
                    backX += reverseDx[cameFrom];
                    backY += reverseDy[cameFrom];
                }
                // prevDir 就是从起点出发的第一步方向
                switch (prevDir) {
                case 1: return Vector2D(0.0f, -1.0f); // 上
                case 2: return Vector2D(0.0f,  1.0f); // 下
                case 3: return Vector2D(-1.0f, 0.0f); // 左
                case 4: return Vector2D( 1.0f, 0.0f); // 右
                default: return Vector2D(0.0f, 0.0f);
                }
            }

            q.push(nIdx);
        }
    }

    // 无路径
    return Vector2D(0.0f, 0.0f);
}
