#include "game/systems/EnemyAISystem.h"
#include "game/systems/ReloadSystem.h"
#include "game/systems/PureLogic.h"
#include "game/GameConfig.h"
#include "game/Level.h"
#include "game/entities/Projectile.h"
#include "math/MathAddon.h"
#include <cmath>

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
            if (distToPlayer < detRange && canSee) {
                enemy->state = Enemy::State::Alert;
            }
            break;

        case Enemy::State::Alert:
            enemy->playerVisibleTimer += dT;
            if (distToPlayer < atkRange) {
                enemy->state = Enemy::State::Attacking;
            }
            else if (distToPlayer > detRange * 1.5f) {
                enemy->state = Enemy::State::Idle;
            }
            else {
                Vector2D dir = player.transform.position - enemy->transform.position;
                enemy->transform.position += dir.normalize() * mvSpeed * dT;
                enemy->state = Enemy::State::Chasing;
            }
            break;

        case Enemy::State::Chasing: {
            if (distToPlayer < atkRange) {
                enemy->state = Enemy::State::Attacking;
            }
            else if (distToPlayer > detRange * 1.5f || !canSee) {
                enemy->state = Enemy::State::Idle;
                enemy->playerVisibleTimer = 0.0f;
            }
            else {
                Vector2D dir = player.transform.position - enemy->transform.position;
                Vector2D move = dir.normalize() * mvSpeed * dT;
                Level::moveWithWallSlide(enemy->transform.position.x, enemy->transform.position.y,
                                         move.x, move.y);
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
                    Vector2D dir = (player.transform.position - enemy->transform.position).normalize();
                    projectiles.push_back(std::make_unique<Projectile>(
                        enemy->transform.position + dir * 0.5f,
                        dir, false, w.bulletSpeed, w.damage));
                }
            }
            break;

        case Enemy::State::Dead:
            break;
        }
    }

    enemies.erase(
        std::remove_if(enemies.begin(), enemies.end(),
            [](const auto& e) { return !e->isAlive(); }),
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
