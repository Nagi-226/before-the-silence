#include "game/systems/CombatSystem.h"
#include "game/systems/ParticleSystem.h"
#include "game/systems/PureLogic.h"
#include "game/GameConfig.h"
#include "game/entities/Enemy.h"
#include "game/entities/Projectile.h"
#include <algorithm>

void CombatSystem::updatePlayerShooting(Player& player, const Input& input, float dT,
                                         std::vector<std::unique_ptr<Projectile>>& projectiles) {
    auto& w = player.weapon;

    updateCooldown(w, dT);

    if (w.isReloading) return;

    if (autoReloadStart(w)) return;

    if (input.isMouseHeld(SDL_BUTTON_LEFT) && tryFire(w)) {
        Vector2D dir = player.transform.forward();
        Vector2D spawnPos = player.transform.position + dir * m_weaponConfig.spawnOffset;
        projectiles.push_back(std::make_unique<Projectile>(
            spawnPos, dir, true, w.bulletSpeed, w.damage));

        player.muzzleFlashTimer = m_weaponConfig.spawnOffset > 0.0f
            ? m_weaponConfig.spawnOffset * 2.0f
            : 0.05f;
        m_particles.emitSpark(spawnPos, dir, 4);
    }
}

void CombatSystem::updateProjectiles(std::vector<std::unique_ptr<Projectile>>& projectiles,
                                      Player& player, std::vector<std::unique_ptr<Enemy>>& enemies, float dT) {
    for (auto& proj : projectiles) {
        // v0.4.7 拖尾：记录上一帧位置
        Vector2D prevPos = proj->transform.position;
        proj->transform.position += proj->direction * proj->speed * dT;
        proj->distanceTraveled += proj->speed * dT;

        // v0.4.9 墙壁碰撞
        int gx = static_cast<int>(proj->transform.position.x);
        int gy = static_cast<int>(proj->transform.position.y);
        if (Level::isWall(gx, gy)) {
            proj->collisionOccurred = true;
            m_particles.emitSpark(proj->transform.position, proj->direction * -1.0f, 3);
        }

        if (proj->collisionOccurred) continue;

        if (proj->shotFromPlayer) {
            for (auto& enemy : enemies) {
                if (!enemy->isAlive()) continue;
                if (proj->transform.position.distanceTo(enemy->transform.position) < m_pickupConfig.projectileRadius) {
                    enemy->health.takeDamage(proj->damage);
                    enemy->hurtTimer = Enemy::HURT_FLASH_TIME;
                    m_particles.emitBlood(enemy->transform.position, 4);
                    if (!enemy->isAlive()) {
                        enemy->state = Enemy::State::Dead;
                        enemy->corpseFadeTimer = Enemy::CORPSE_FADE_DURATION;
                        m_particles.emitExplosion(enemy->transform.position, 15);
                    }
                    proj->collisionOccurred = true;
                    break;
                }
            }
        }
        else {
            if (proj->transform.position.distanceTo(player.transform.position) < m_pickupConfig.projectileRadius) {
                player.health.takeDamage(proj->damage);
                proj->collisionOccurred = true;
                player.hurtTimer = Player::HURT_DURATION;
                player.shakeTimer = Player::SHAKE_DURATION;
            }
        }

        // 拖尾记录
        if (proj->shotFromPlayer && proj->distanceTraveled < proj->maxRange) {
            m_tracers.push_back({prevPos, proj->transform.position, 0.08f});
        }
    }

    projectiles.erase(
        std::remove_if(projectiles.begin(), projectiles.end(),
            [](const auto& p) { return p->shouldDestroy(); }),
        projectiles.end());
}

void CombatSystem::updateTracers(float dT) {
    for (auto& t : m_tracers) t.lifetime -= dT;
    m_tracers.erase(std::remove_if(m_tracers.begin(), m_tracers.end(),
        [](const TracerLine& t) { return t.lifetime <= 0.0f; }), m_tracers.end());
}
